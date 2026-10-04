// The legacy executor keeps web builds functional without external WASM assets.
// It will be replaced by WasmDatabase when web becomes a deployment target.
// ignore_for_file: deprecated_member_use

import 'package:drift/drift.dart';
import 'package:drift/web.dart';

QueryExecutor createDatabaseConnection() => WebDatabase('agenda');
