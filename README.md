# Agenda

Centre de commande personnel réunissant calendrier, tâches, projets, routines et
Inbox rapide. Le produit est conçu en offline-first : l'application Flutter lira
et modifiera toujours la base Drift locale, puis synchronisera avec l'API AdonisJS.

## Monorepo

- `app/` : application Flutter (mobile prioritaire, web et desktop compatibles)
- `backend/` : API REST AdonisJS 6, TypeScript, Lucid et PostgreSQL
- `docs/` : documentation d'architecture et décisions techniques

La conception détaillée se trouve dans [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## État d'avancement

- Phase 1 : terminée — monorepo et fondations Flutter/AdonisJS.
- Phase 2 : terminée — migrations PostgreSQL et modèles Lucid métier.
- Phase 3 : terminée — services métier, validation et API REST authentifiée.
- Phase 4 : terminée — schéma Drift, repositories locaux et écritures offline atomiques.
- Phase 5 : terminée — moteur push/pull, idempotence serveur et reprise locale.
- Phase 6 : terminée — écrans Today, Calendar, Tasks, Projects et Settings.
- Phase 7 : terminée — quick-add global, parser français local et Inbox.
- Phase 8 : terminée — planification, déplacement et redimensionnement par glisser-déposer.
- Phase 9 : terminée — import de fichiers ICS et abonnements par URL.
- Phase 10 : terminée — notifications locales, permissions et rappels paramétrables.
- Phase 11 : terminée — authentification, finition, documentation et validation de livraison.

## Fonctionnalités

- vue Aujourd'hui et calendrier hebdomadaire avec déplacement/redimensionnement ;
- Inbox et saisie rapide en français (`demain 9h 30min`, jours de semaine) ;
- tâches, sous-tâches, projets, routines et créneaux planifiés ;
- fonctionnement local avec Drift, puis synchronisation push/pull idempotente ;
- compte personnel, jeton conservé dans le stockage sécurisé de l'appareil ;
- import de fichiers ICS et synchronisation d'abonnements ICS par URL ;
- rappels locaux paramétrables et thèmes clair/sombre.

## Démarrage rapide

Prérequis : Flutter avec Dart 3.8+, Node.js 20+, npm et Docker.

```bash
docker compose up -d postgres
cd backend
copy .env.example .env
npm install
node ace generate:key
node ace migration:run
npm run dev
```

Dans un second terminal :

```bash
cd app
flutter pub get
flutter run --dart-define=API_URL=http://localhost:3333
```

Sur un émulateur Android, utiliser généralement `http://10.0.2.2:3333` comme
`API_URL`. Les secrets de développement restent dans `backend/.env`, ignoré par Git.

Au premier lancement, choisir « Créer mon compte personnel ». L'application stocke
les données dans Drift immédiatement ; le moteur envoie ensuite les opérations en
attente et récupère les changements distants. Une interruption réseau ne supprime
donc aucune saisie locale.

## API

Toutes les routes métier sont sous `/api/v1` et utilisent un jeton Bearer, sauf
`POST /auth/register` et `POST /auth/login`. Les ressources disponibles sont
`projects`, `tasks`, `events`, `routines` et `calendar-sources`. La réplication
utilise `POST /sync/push` puis `GET /sync/pull?since=...`.

`GET /health` permet de vérifier le serveur sans authentification.

## Qualité

```bash
cd backend
npm run lint
npm run typecheck
npm test
npm run build

cd ../app
flutter analyze
flutter test
flutter build web
```

Les tests couvrent notamment le moteur de planification, le parsing ICS, les
contrats de modèles, le quick-add, les mutations locales atomiques, la file de
synchronisation et les calculs de rappels.

## Limites connues

- PostgreSQL doit être disponible pour les migrations et les tests d'intégration.
- Les abonnements ICS distants dépendent de l'accessibilité de leur URL depuis le serveur.
- Les notifications web dépendent des capacités et permissions du navigateur ; les
  rappels natifs Android/iOS constituent la cible principale.
