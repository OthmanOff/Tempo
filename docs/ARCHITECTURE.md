# Architecture de l'application Agenda

## 1. Objectifs et contraintes

Agenda est une application personnelle, mono-utilisateur dans son premier cycle,
qui réunit calendrier, événements, tâches, projets, routines et capture rapide.
Elle doit rester utilisable sans réseau, offrir une saisie en quelques secondes et
éviter une architecture SaaS multi-tenant prématurée.

Principes directeurs :

- l'interface lit toujours les données locales ;
- une écriture locale est visible immédiatement puis synchronisée en arrière-plan ;
- les identifiants UUID sont générés par le client ;
- les tâches sans date sont un cas métier de premier ordre ;
- une tâche Inbox ne devient pas implicitement un événement ;
- les contrôleurs HTTP orchestrent, les services portent les règles métier ;
- les fonctions futures (CalDAV, Google, Outlook, IA) passent par des interfaces
  dédiées sans complexifier le MVP.

## 2. Vue d'ensemble

```text
Flutter UI
   │ observe / commande
   ▼
Riverpod + repositories
   │ transaction locale
   ▼
Drift / SQLite ── pending_operations
   │                       │
   └──────── SyncEngine ◄──┘
               │ REST + access token
               ▼
        AdonisJS 6 API
               │
        services métier
               │
          Lucid ORM
               │
          PostgreSQL
```

Le backend est l'autorité de synchronisation durable. Drift est toutefois la source
de lecture de l'UI : une panne réseau ne vide jamais les écrans et ne bloque pas la
création d'une tâche.

## 3. Monorepo

```text
agenda/
  app/                     application Flutter
    lib/
      app/                 composition de l'application
      core/
        api/               client HTTP et authentification
        database/          schéma Drift, DAOs, migrations locales
        sync/              queue et moteur de synchronisation
        notifications/     abstraction des notifications locales
        routing/           go_router
        theme/             thèmes clair et sombre
        utils/             fonctions transverses sans état
      features/
        auth/
        calendar/
        tasks/
        projects/
        routines/
        inbox/
        settings/
        today/
    test/
  backend/
    app/
      controllers/         adaptation HTTP uniquement
      models/              modèles Lucid
      repositories/        accès aux données et requêtes complexes
      services/            règles métier et orchestration
      validators/          validation VineJS
    database/migrations/
    start/routes.ts
    tests/
  docs/
```

Chaque feature Flutter utilise seulement les couches nécessaires : `data/` pour
les sources et implémentations de repositories, `domain/` pour les entités et
contrats stables, `presentation/` pour providers et widgets. Une feature simple
peut commencer avec `presentation/` seule puis se séparer quand sa logique apparaît.

## 4. Modèle de données

Toutes les entités synchronisées utilisent un UUID, `created_at`, `updated_at` et
`deleted_at` nullable. Les dates instantanées sont stockées en UTC ; le fuseau de
présentation par défaut est `Europe/Paris`. Les noms SQL sont en snake_case et les
propriétés TypeScript/Dart en camelCase.

### User

`id`, `email`, `password_hash`, `name`, `timezone`, timestamps. Un seul utilisateur
est attendu au MVP, mais l'authentification et les clés étrangères restent explicites.

### Project

`id`, `user_id`, `name`, `description?`, `icon?`, `color?`, `archived_at?`, timestamps.
L'archivage conserve l'historique sans masquer les relations.

### Task

`id`, `user_id`, `project_id?`, `parent_task_id?`, `title`, `description?`, `status`,
`priority`, `estimated_duration_minutes?`, `due_at?`, `scheduled_start_at?`,
`scheduled_end_at?`, `completed_at?`, `sort_order`, timestamps.

Contraintes métier principales :

- `status`: `inbox`, `todo`, `scheduled`, `in_progress`, `completed`, `cancelled` ;
- `priority`: `none`, `low`, `medium`, `high`, `urgent` ;
- une tâche non planifiée garde ses champs `scheduled_*` à `null` ;
- une tâche planifiée possède un début et une fin cohérents ;
- la suppression synchronisée renseigne `deleted_at` au lieu d'effacer immédiatement.

### Event

`id`, `user_id`, `project_id?`, `calendar_source_id?`, `title`, `description?`,
`location?`, `start_at`, `end_at`, `all_day`, `recurrence_rule?`, `source`,
`external_id?`, timestamps. Un index unique conditionnel sur la source et
`external_id` empêchera les doublons ICS.

### Routine

`id`, `user_id`, `project_id?`, `name`, `recurrence_rule`,
`preferred_duration_minutes`, `preferred_start_time?`, `enabled`, timestamps.
Les récurrences utilisent une RRULE iCalendar afin d'éviter un format propriétaire.

### CalendarSource

`id`, `user_id`, `name`, `type`, `url?`, `enabled`, `last_synced_at?`, timestamps.
Les types sont `local`, `ics_url`, `ics_file`. Les secrets ou credentials futurs ne
seront jamais placés dans l'URL en clair.

### PendingOperation (local uniquement)

`id`, `operation_type`, `entity_type`, `entity_id`, `payload_json`, `created_at`,
`retry_count`, `last_error?`. `operation_type` vaut `create`, `update` ou `delete`.
Un index sur `(created_at, retry_count)` permet de vider la queue dans l'ordre.

## 5. Stratégie offline-first

Une commande utilisateur s'exécute dans une transaction Drift : elle modifie la
table métier et ajoute l'opération correspondante à `pending_operations`. Riverpod
observe Drift et rafraîchit l'UI immédiatement. Le réseau n'est donc jamais sur le
chemin critique d'une interaction.

Le `SyncEngine` se déclenche au lancement, au retour de connectivité, au retour au
premier plan et manuellement. Il pousse d'abord les opérations locales, puis tire les
changements distants. Les opérations réussies sont retirées ; les erreurs transitoires
incrémentent `retry_count` avec backoff. Une erreur d'authentification suspend le push
jusqu'à reconnexion, sans perdre la queue.

La base locale est migrée par Drift. L'UI ne contourne pas les repositories et ne
consomme jamais directement Dio.

## 6. Protocole de synchronisation

### Push

`POST /sync/push` reçoit un lot d'opérations avec un identifiant d'opération unique,
le type d'entité, son UUID, le type d'action, le payload et `updatedAt`. Le serveur
mémorise les identifiants déjà traités : rejouer un lot produit le même résultat.

### Pull

`GET /sync/pull?since=<curseur>` renvoie les mutations, suppressions comprises, ainsi
qu'un nouveau curseur serveur. Un curseur opaque est préférable à l'horloge du client ;
la première version pourra utiliser un timestamp serveur strictement documenté.

### Conflits

Le `SyncService` applique initialement last-write-wins sur `updated_at`, en comparant
des instants UTC. Cette règle est isolée derrière une stratégie afin de permettre plus
tard une fusion par champ ou une résolution utilisateur. Les suppressions utilisent
des tombstones `deleted_at` conservés assez longtemps pour atteindre tous les clients.

## 7. Backend

L'API est versionnable sous `/api/v1`. Les routes authentifiées utilisent le guard
`access_tokens`. Les listes sont paginées ; `GET /events` exige `from` et `to` et ne
retourne jamais tout l'historique.

Services prévus :

- `TaskService` : transitions d'état, planification, déplanification, achèvement ;
- `CalendarService` : plages, occurrences et chevauchements ;
- `IcsService` : parsing VEVENT, UID, import et resynchronisation idempotente ;
- `SyncService` : lots, idempotence, tombstones et conflits ;
- `SchedulingService` : calcul futur de créneaux disponibles ;
- `NotificationService` côté Flutter : programmation locale indépendante du plugin.

Les repositories encapsulent Lucid lorsqu'une requête ou une politique de filtrage est
réutilisée. Une transaction métier démarre dans le service, pas dans le contrôleur.

## 8. Calendrier et planification

Les événements et tâches planifiées restent deux entités distinctes mais sont projetés
vers un modèle de présentation commun (`CalendarItem`). Les occurrences de routines
sont calculées pour la plage visible ; elles ne sont matérialisées que si une action
utilisateur l'exige. Le placement visuel est calculé à partir des minutes depuis minuit.
Les chevauchements sont groupés puis répartis en colonnes par interval partitioning.

Déposer une tâche à une heure met à jour `scheduled_start_at`, calcule
`scheduled_end_at` depuis la durée estimée (ou une durée par défaut explicitement
présentée), puis passe le statut à `scheduled`. L'opération entière est atomique.

`SchedulingService.findAvailableSlots({duration, from, to, workingHours})` recevra les
occupations déjà normalisées. Son contrat ne dépendra ni d'une IA ni de l'interface.

## 9. ICS

Les fichiers et URLs passent par le même pipeline : lecture, parsing, normalisation en
UTC, upsert par `(calendar_source_id, UID, RECURRENCE-ID)` puis mise à jour de
`last_synced_at`. Un échec ne remplace pas les événements valides précédents. Les URL
sont récupérées côté serveur avec délais, limites de taille et protections SSRF.

## 10. Sécurité et configuration

- mots de passe hachés par le provider AdonisJS ;
- access tokens stockés dans le keystore sécurisé de la plateforme, jamais dans Drift ;
- validation VineJS à toutes les frontières HTTP ;
- CORS limité aux origines de développement/production configurées ;
- URL API injectée par `--dart-define=API_URL=...` ;
- secrets backend dans `.env`, jamais versionnés ;
- imports ICS limités en taille et en temps d'exécution.

## 11. Tests et observabilité

Backend : tests fonctionnels des endpoints et tests unitaires des services critiques,
notamment création/planification, plage d'événements, import ICS et rejeu de sync.
Flutter : repositories avec base Drift en mémoire, parser quick-add, queue de sync et
calcul/layout de timeline. Les tests widget vérifient les états vide, chargement,
erreur et données réelles injectées.

Les logs backend sont structurés avec un identifiant de requête. Le moteur de sync
expose son dernier succès et sa dernière erreur à l'écran Réglages sans journaliser les
tokens ni le contenu sensible.

## 12. Décisions techniques principales

1. AdonisJS reste en version majeure 6 conformément au cahier des charges.
2. PostgreSQL est utilisé dès le développement pour éviter les écarts SQLite/production.
3. UUID côté client rend les créations offline et les retries naturellement adressables.
4. Drift est la seule source de lecture de l'UI ; Dio n'est utilisé que par la couche data.
5. Riverpod gère composition, cycles de vie et injection sans service locator global.
6. RRULE conserve l'interopérabilité des routines et événements récurrents.
7. Soft delete uniquement pour les entités synchronisées ; purge différée côté serveur.
8. Architecture par feature pragmatique : aucune couche vide n'est créée par principe.
9. Material 3 fournit l'accessibilité et le responsive ; les composants métier gardent
   des touch targets d'au moins 48 dp.
10. L'IA et les connecteurs calendaires restent derrière des contrats futurs, absents du MVP.

## 13. Découpage des phases

- Phase 1 : monorepo, projets exécutables, dépendances structurantes, thème, routeur,
  PostgreSQL de développement et présente documentation.
- Phase 2 : migrations et modèles métier avec UUID/tombstones.
- Phase 3 : API REST, validation, services et tests backend.
- Phase 4 : schéma Drift, DAOs et repositories locaux.
- Phase 5 : queue et moteur de synchronisation.
- Phases 6 à 10 : écrans, quick-add, drag & drop, ICS et notifications.
- Phase 11 : couverture critique, accessibilité, performance, polish et README final.
