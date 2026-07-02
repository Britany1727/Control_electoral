# Cambios Realizados — Sincronización Offline (Veedor)

## Dependencias agregadas (pubspec.yaml)
- `hive: ^2.2.3`
- `hive_flutter: ^1.1.0`
- `connectivity_plus: ^6.0.0`
- `path_provider: ^2.1.0`

---

## Archivos Nuevos

### 1. `lib/features/veedor/data/models/acta_pendiente_model.dart`
Modelo para la cola de actas pendientes de sincronización.
- Campos: localId, actaId, fotoUrl, fotoLocalPath, mesaId, dignidad, totalSufragantes, votosNulos, votosBlancos, gpsLatitud, gpsLongitud, registradoPor, votosPorOrganizacion, syncStatus, createdAt, lastSyncedAt, conflictoDetalle
- Métodos: toMap(), fromMap(), copyWith()
- Estados de sync: pendiente, sincronizando, sincronizado, conflicto

### 2. `lib/features/veedor/data/datasources/veedor_local_datasource.dart`
Datasource local con Hive para persistencia offline.
- Abstracción: `VeedorLocalDatasource`
- Implementación: `VeedorLocalDatasourceImpl` — Box `actas_pendientes`
- Métodos: guardarPendiente, getPendientes, getPendientesSync, getPorLocalId, actualizarEstado (incluye fotoLocalPath), eliminar, contarPendientes, contarConflictos

### 3. `lib/features/veedor/presentation/sync/sync_event.dart`
Eventos sellados del SyncBloc.
- `StartSync` — inicia sincronización manual
- `ConnectivityChanged` — cambio en el estado de red
- `SyncNext` — procesa siguiente elemento de la cola
- `ResolverConflicto` — resuelve un conflicto (descartar local o sobrescribir remoto)

### 4. `lib/features/veedor/presentation/sync/sync_state.dart`
Estados sellados del SyncBloc.
- `SyncInitial`, `SyncIdle` (con conectividad, pendientes, conflictos)
- `SyncInProgress` (total, procesados)
- `SyncCompletado` (sincronizados, conflictos, errores)
- `ConflictoDetectado` (pendiente, remoteUpdatedAt, remoteData)
- `SyncError`

### 5. `lib/features/veedor/presentation/sync/sync_bloc.dart`
Bloc orquestador de sincronización.
- Monitorea `connectivity_plus` stream
- Auto-sync al recuperar conexión con elementos pendientes
- Procesa cola secuencialmente
- Estrategia de resolución de conflictos (ver sección aparte)
- Crea acta + votos + foto en Appwrite durante sync
- Marca conflictos localmente para resolución manual

---

## Archivos Modificados

### 6. `lib/features/veedor/data/datasources/veedor_remote_datasource.dart`
Dos métodos nuevos en abstract + impl:
- `getActaPorId(String actaId)` — obtiene documento acta remoto (para comparar updated_at)
- `eliminarActa(String actaId)` — elimina acta remota (para resolver conflicto sobrescribiendo)

### 7. `lib/features/veedor/data/repositories/veedor_repository_impl.dart`
- **Nueva dependencia**: `VeedorLocalDatasource localDatasource`
- **`registrarActa`**: try remoto → fallback: guarda en Hive, retorna `Acta(estado: 'pendiente_sync')`
- **`subirFotoActa`**: si actaId empieza con `local_`, guarda fotoLocalPath en Hive; si falla remoto, también guarda local
- Métodos helper: `_generateLocalId()` (formato `local_timestamp_random`), `_isLocalId()`

### 8. `lib/features/veedor/presentation/pages/registrar_acta_page.dart`
- Listener de `ActaRegistrada`: si `estado == 'pendiente_sync'` muestra SnackBar naranja ("guardada localmente — se sincronizará...")

### 9. `lib/features/veedor/presentation/pages/foto_acta_page.dart`
- Listener de `FotoSubida`: si `fotoUrl.startsWith('local:')` muestra SnackBar naranja ("guardada localmente — se subirá al sincronizar...")

### 10. `lib/features/veedor/presentation/pages/veedor_dashboard_page.dart`
- Nuevo import: `SyncBloc`, `SyncEvent`, `SyncState`
- AppBar: badge con conteo de pendientes + ícono de sync (naranja si hay pendientes, verde cloud_done si todo ok, gris si offline)
- Cuerpo: tarjeta de estado de sincronización debajo del perfil
  - `SyncIdle` con pendientes: muestra conteo + botón "Sincronizar" (si conectado) o ícono wifi_off
  - `SyncInProgress`: barra de progreso con fracción
  - `SyncCompletado`: resumen verde con sincronizados/conflictos
  - `SyncError`: tarjeta roja con mensaje

### 11. `lib/injection_container.dart`
Nuevos registros:
- `VeedorLocalDatasource` → `VeedorLocalDatasourceImpl`
- `Connectivity()` (connectivity_plus)
- `SyncBloc` (factory, con localDatasource, remoteDatasource, connectivity)
- `VeedorRepositoryImpl` ahora recibe `sl(), sl()` (remote + local)

### 12. `lib/main.dart`
- Import: `hive_flutter`, `SyncBloc`
- `Hive.initFlutter()` antes de `di.init()`
- `BlocProvider<SyncBloc>` en `MultiBlocProvider`

---

## Estrategia de Resolución de Conflictos

Documentada en `sync_bloc.dart` líneas 97-145:

1. **Actas nuevas** (`actaId == null`): no hay registro remoto → sin conflicto posible, se crean directamente
2. **Correcciones** (`actaId != null`):
   - Se obtiene el `updated_at` remoto
   - Se compara con `createdAt` local
   - Si **remoto es más reciente**: conflicto. Se guarda en Hive con `syncStatus: 'conflicto'` y detalle con ambas fechas. El usuario debe decidir (descartar local o sobrescribir remoto)
   - Si **local es igual o más reciente**: se procede con last-write-wins (optimistic concurrency)
3. **Resolución manual** (`ResolverConflicto`):
   - `descartarLocal = true`: elimina entrada local, mantiene remoto
   - `descartarLocal = false`: elimina acta remota, re-agrega a cola como pendiente (se recreará en Appwrite)
