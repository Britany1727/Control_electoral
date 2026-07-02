# Control Electoral 2026

## Descripción General

Aplicación móvil Flutter (Android) para el sistema de escrutinio electoral en Ecuador. Gestiona el registro y consolidación de actas electorales con tres roles: Coordinador Provincial, Coordinador de Recinto y Veedor. Backend: Appwrite (BaaS). Arquitectura: **Clean Architecture** con Bloc (BLoC) como manejador de estado.

---

## 1. Estructura del Proyecto (`lib/`)

```
lib/
├── core/                        # Capa transversal (compartida)
│   ├── appwrite/
│   │   └── appwrite_client.dart # Singleton Client de Appwrite
│   ├── constants/
│   │   ├── app_constants.dart   # Constantes de config (threshold, sufragantes)
│   │   └── appwrite_constants.dart  # IDs de colecciones, bucket, function
│   ├── deep_links/
│   │   └── deep_link_handler.dart   # Maneja deep links (verificación, recovery)
│   ├── error/
│   │   ├── exceptions.dart      # ServerException, AuthException, etc.
│   │   └── failure.dart         # ServerFailure, AuthFailure, etc. (sealed class)
│   ├── usecase/
│   │   └── usecase.dart         # UseCase abstracto + NoParams
│   └── utils/
│       ├── cedula_validator.dart    # Valida cédula ecuatoriana (algoritmo módulo 10)
│       ├── gps_helper.dart          # Helper para geolocalización (Geolocator)
│       └── image_quality_checker.dart # Evalúa nitidez (Laplacian variance)
│
├── features/
│   ├── auth/                    # Autenticación y usuarios
│   ├── coordinador_provincial/  # Dashboard Provincial
│   ├── coordinador_recinto/     # Dashboard de Recinto
│   └── veedor/                  # Dashboard Veedor (registro/corrección actas + sync offline)
│
├── injection_container.dart     # GetIt DI (singletons, factories)
├── main.dart                    # Entry Point: providers globales + router
└── router/
    └── app_router.dart          # GoRouter con auth redirect por rol
```

---

## 2. Core (`lib/core/`)

### `appwrite_client.dart`
- **`AppwriteClient`**: Singleton que inicializa `Client`, `Account`, `Databases`, `Storage`, `Functions` de Appwrite.

### `constants/appwrite_constants.dart`
- Endpoint, Project ID, Database ID, y todos los IDs de colecciones (`usuarios`, `recintos`, `mesas`, `organizaciones_politicas`, `actas`, `votos_por_organizacion`), bucket `actas_fotos`, y function ID `create-user`.

### `constants/app_constants.dart`
- `defaultPassword` (desde .env), `laplacianThreshold`, `minSufragantes`, `maxSufragantes`.

### `deep_links/deep_link_handler.dart`
- Escucha URLs del esquema `controlelectoral://` para:
  - `verify` (o `verificar`): dispara `ConfirmVerificationRequested` → verificación de correo.
  - `recovery` (o `reset-password`): navega a `/reset-password` con `userId` y `secret`.

### `error/exceptions.dart`
- Clases: `ServerException`, `AuthException`, `NetworkException`, `CacheException`, `ValidationException`, `PermissionException`, `NotFoundException`.

### `error/failure.dart`
- Clases selladas: `ServerFailure`, `AuthFailure`, `NetworkFailure`, `CacheFailure`, `ValidationFailure`, `PermissionFailure`, `ImageQualityFailure`, `GpsFailure`, `NotFoundFailure`.

### `usecase/usecase.dart`
- **`UseCase<Type, Params>`**: abstracto con `Future<Either<Failure, Type>> call(Params params)`.
- **`NoParams`**: params vacío.

### `utils/cedula_validator.dart`
- **`CedulaValidator.isValid(cedula)`**: valida cédula ecuatoriana (10 dígitos, provincia 1-24, dígito 3 < 6, dígito verificador módulo 10).

### `utils/gps_helper.dart`
- **`GpsHelper.isGpsEnabled()`**, `checkPermission()`, `requestPermission()`, `getCurrentPosition()`: wrapper de `Geolocator`.

### `utils/image_quality_checker.dart`
- **`ImageQualityChecker.isSharp(file, threshold)`**: aplica kernel Laplaciano 3×3 sobre la imagen en escala de grises, calcula varianza; si < threshold, la imagen se considera borrosa.

---

## 3. Feature Auth (`lib/features/auth/`)

### Data Layer

#### `data/datasources/auth_remote_datasource.dart`
- **`AuthRemoteDatasource`** (abstracto): define `login`, `logout`, `getCurrentUser`, `createUser`, `changePassword`, `recoverPassword`, `requestPasswordReset`, `completePasswordReset`, `sendEmailVerification`, `confirmEmailVerification`, `sendPasswordRecovery`, `confirmPasswordRecovery`.
- **`AuthRemoteDatasourceImpl`**: implementación con `Account` y `Databases`.
  - `login()`: intenta login con email real; si falla, prueba con `cedula@electoral.ec` (legacy). Actualiza correo en BD si cambió.
  - `getCurrentUser()`: obtiene usuario Auth por ID de sesión, busca documento en `usuarios` por ID. Si falla, busca por cédula (legacy).
  - `createUser()`: crea auth user + documento en `usuarios`. Rollback si falla creación del documento. Envía verificación de correo.
  - `changePassword()`: actualiza contraseña en Auth y `primer_login = false` en BD.
  - `sendEmailVerification()`: llama `account.createVerification()`.
  - `confirmEmailVerification()`: llama `account.updateVerification()`.

#### `data/models/usuario_model.dart`
- **`UsuarioModel`**: extiende `Usuario`. `fromMap()` mapea campos + `emailVerificado` opcional.

#### `data/repositories/auth_repository_impl.dart`
- **`AuthRepositoryImpl`**: implementa `AuthRepository`. Envuelve cada llamada en `try/catch` → `Right`/`Left`.

### Domain Layer

#### `domain/entities/usuario.dart`
- **`Usuario`**: `id`, `cedula`, `nombres`, `apellidos`, `telefono`, `correo`, `rol`, `primerLogin`, `emailVerificado`, `recintoId?`, `creadoPor?`. Getter `nombreCompleto`.

#### `domain/repositories/auth_repository.dart`
- Abstracto: `login`, `logout`, `getCurrentUser`, `createUser`, `changePassword`, `recoverPassword`, `requestPasswordReset`, `completePasswordReset`, `sendEmailVerification`, `confirmEmailVerification`, `sendPasswordRecovery`, `confirmPasswordRecovery`.

#### `domain/usecases/`
- `login_usecase.dart` → `LoginUseCase(LoginParams)`.
- `create_user_usecase.dart` → `CreateUserUseCase(CreateUserParams)`.
- `change_password_usecase.dart`, `logout_usecase.dart`, `send_email_verification_usecase.dart`, `confirm_email_verification_usecase.dart`, `recover_password_usecase.dart`, `request_recovery_usecase.dart`, `complete_recovery_usecase.dart`, `send_password_recovery_usecase.dart`, `confirm_password_recovery_usecase.dart`.

### Presentation Layer

#### `bloc/auth_bloc.dart`
- **Eventos**: `LoginRequested`, `LogoutRequested`, `ChangePasswordRequested`, `RecoverPasswordRequested`, `CheckAuthStatus`, `ResetAuthState`.
- **Estados**: `AuthInitial`, `AuthLoading`, `AuthAuthenticated(usuario)`, `AuthUnauthenticated`, `AuthError(message)`, `AuthRequiresPasswordChange(usuario)`.
- Lógica:
  - `_onLogin`: login → si `primerLogin` emite `AuthRequiresPasswordChange` sino `AuthAuthenticated`.
  - `_onLogout`: cierra sesión.
  - `_onChangePassword`: cambia contraseña → emite `AuthUnauthenticated`.
  - `_onCheckAuthStatus`: verifica sesión actual.

#### `bloc/recovery_bloc.dart`
- Eventos: `SendRecoveryRequested`, `ConfirmRecoveryRequested`, `ResetRecoveryState`.
- Estados: `RecoveryInitial`, `RecoveryLoading`, `RecoveryEmailSent`, `RecoverySuccess`, `RecoveryFailure`.

#### `bloc/verification/verification_bloc.dart`
- Eventos: `SendVerificationRequested`, `ConfirmVerificationRequested`, `ResetVerificationState`.
- Estados: `VerificationInitial`, `VerificationLoading`, `VerificationEmailSent`, `VerificationSuccess`, `VerificationFailure`.

#### `pages/login_page.dart`
- Formulario: cédula, email, rol (dropdown), contraseña. Valida campos, login por Bloc.

#### `pages/change_password_page.dart`
- **`ChangePasswordPage`**: formulario: contraseña actual, nueva, confirmar. Usa `ChangePasswordRequested`.

#### `pages/forgot_password_page.dart`
- **`ForgotPasswordPage`**: ingresa email → `SendRecoveryRequested`.

#### `pages/reset_password_page.dart`
- **`ResetPasswordPage`**: recibe `userId` y `secret` de deep link → `ConfirmRecoveryRequested`.

#### `widgets/email_verification_banner.dart`
- Banner naranja si `emailVerificado == false`. Botón "Reenviar" → `SendVerificationRequested`.

---

## 4. Feature Coordinador Provincial (`lib/features/coordinador_provincial/`)

### Data Layer

#### `data/datasources/provincial_remote_datasource.dart`
- **Métodos**: `getRecintos()`, `getRecintosSinCoordinador()`, `createRecinto()`, `createCoordinadorRecinto()`, `getAvanceRecinto()`, `getResumenGlobal()`, `getActasPorRecinto()`, `getVotosConsolidados()`, `getDetalleActa()`.
- **NOTA**: Todos los filtros por `estado` y `mesa_id` se hacen **en Dart** (`.where()`) porque esas columnas no son atributos del schema en Appwrite.
- `getRecintos()`: lista todos.
- `getRecintosSinCoordinador()`: usa `Query.isNull('coordinador_recinto_id')`.
- `createRecinto()`: crea recinto + `número_jrv` mesas (iteración 1..totalMesas).
- `createCoordinadorRecinto()`: llama **Appwrite Function** `create-user` para crear auth user, luego crea documento en `usuarios`, actualiza recinto con `coordinador_recinto_id`.
- `getAvanceRecinto()`: mesas del recinto → actas filtradas en Dart (mesaId + estado).
- `getResumenGlobal()`: total recintos, total mesas, actas registradas (filtro Dart).
- `getActasPorRecinto()`: mesas → actas filtradas en Dart.
- `getVotosConsolidados()`: organizaciones → mesas (por recinto o todas) → actas registradas → votos → agrupa por dignidad → acumula.
- `getDetalleActa()`: acta por ID + mesa + organizaciones + votos.

#### `data/models/recinto_model.dart`
- **`RecintoModel`**: extiende `Recinto`. `fromMap()`: convierte `numero_jrv` a String (viene como int de Appwrite).

#### `data/repositories/provincial_repository_impl.dart`
- Wrapper try/catch → `Right`/`Left`.

### Domain Layer

#### `domain/entities/`
- **`Recinto`**: `id`, `canton`, `parroquia`, `nombre`, `numeroJrv?`, `coordinadorRecintoId?`.
- **`VotosConsolidados`**: `dignidad`, `resultados: List<ResultadoOrganizacion>`.
- **`ResultadoOrganizacion`**: `organizacionId`, `nombreOrganizacion`, `candidato`, `totalVotos`.
- **`DetalleActaCompleto`**: `acta: Acta`, `mesaNumero`, `votos: List<VotoConOrganizacion>`.
- **`VotoConOrganizacion`**: `organizacionId`, `nombreOrganizacion`, `candidato`, `votos`.

#### `domain/repositories/provincial_repository.dart`
- Abstracto: todos los métodos del datasource.

#### `domain/usecases/`
- `get_recintos_usecase.dart`, `create_recinto_usecase.dart`, `create_coordinador_recinto_usecase.dart`, `get_avance_recinto_usecase.dart`, `get_recintos_sin_coordinador_usecase.dart`, `get_votos_consolidados_usecase.dart`, `get_detalle_acta_usecase.dart`, `get_resumen_global_usecase.dart`, `get_actas_por_recinto_usecase.dart`.

### Presentation Layer

#### `bloc/provincial_bloc.dart`
- 9 handlers: `LoadRecintos`, `CreateRecinto` (droppable), `CreateCoordinadorRecinto` (droppable), `LoadAvanceRecinto`, `LoadRecintosSinCoordinador`, `LoadVotosConsolidados`, `LoadActasPorRecinto`, `LoadDetalleActa`, `LoadResumenGlobal`.
- Estados: `ProvincialInitial`, `ProvincialLoading`, `RecintosLoaded`, `RecintosSinCoordinadorLoaded`, `AvanceRecintoLoaded`, `RecintoCreated`, `CoordinadorRecintoCreated`, `ResumenGlobalLoaded`, `VotosConsolidadosLoaded`, `ActasPorRecintoLoaded`, `DetalleActaLoaded`, `ProvincialError`.

#### `pages/provincial_dashboard_page.dart`
- Menú principal: Gestionar Recintos, Crear Recinto, Crear Coordinador, Votos Consolidados, Informe Electoral. Botón logout. Banner verificación email.

#### `pages/recintos_list_page.dart`
- Lista recintos con indicador de avance. Toca → `AvanceRecintoPage`. Pull-to-refresh. Fallback: re-dispatch `LoadRecintos` con `addPostFrameCallback` para evitar pantalla en blanco al regresar.

#### `pages/avance_recinto_page.dart`
- Círculo de progreso (mesas/actas). Botones: Actualizar, Ver Actas.

#### `pages/actas_por_recinto_page.dart`
- Lista actas del recinto (icono GPS verde si tiene coordenadas). Toca → `DetalleActaPage`.

#### `pages/detalle_acta_page.dart`
- Información completa: mesa, dignidad, estado, sufragantes, válidos, nulos, blancos, fecha. GPS con botón "Ver en Google Maps" (abre `google.com/maps` con `launchUrl` + `LaunchMode.externalApplication`). Lista votos por organización.

#### `pages/create_recinto_page.dart`
- Formulario: cantón, parroquia, nombre, número JRV (opcional → crea mesas).

#### `pages/create_coordinador_page.dart`
- Selecciona recinto sin coordinador → datos persona → contraseña → llama Function Appwrite.

#### `pages/votos_consolidados_page.dart`
- Lista votos agrupados por dignidad, ordenados de mayor a menor.

#### `pages/informe_electoral_page.dart`
- **Flujo encadenado**: `LoadResumenGlobal` → `ResumenGlobalLoaded` dispara `LoadRecintos` → `RecintosLoaded` dispara `LoadVotosConsolidados`.
- Resumen general con progreso (recintos, mesas, actas, pendientes, barra %).
- Filtro por recinto.
- Votos consolidados por dignidad.
- Avance por recinto (lista tocable).

---

## 5. Feature Coordinador de Recinto (`lib/features/coordinador_recinto/`)

### Data Layer

#### `data/datasources/recinto_remote_datasource.dart`
- **Métodos**: `getMesas()`, `createVeedor()`, `asignarVeedor()`, `getOrganizaciones()`, `getActaPorMesa()`, `corregirActa()`, `subirFotoActa()`, `getAvance()`.
- `getMesas()`: lista mesas de recinto + determina `hasActa` iterando actas en Dart.
- `createVeedor()`: crea auth user + documento en `usuarios` + actualiza mesa con `veedor_id`.
- `asignarVeedor()`: busca veedor por cédula, actualiza mesa.
- `getActaPorMesa()`: busca acta por `mesa_id` en Dart (`.where()`).
- `corregirActa()`: actualiza `total_sufragantes`, `votos_nulos`, `votos_blancos` + cada voto por org.
- `subirFotoActa()`: sube a Storage, actualiza `foto_url` en acta.
- `getAvance()`: similar a `getAvanceRecinto` provincial.

#### `data/models/mesa_model.dart`
- **`MesaModel`**: extiende `Mesa`. `fromMap()` incluye `hasActa` opcional.

#### `data/repositories/recinto_repository_impl.dart`
- Wrapper try/catch.

### Domain Layer

#### `domain/entities/mesa.dart`
- **`Mesa`**: `id`, `numeroJrv`, `recintoId`, `veedorId?`, `hasActa`.

#### `domain/repositories/recinto_repository.dart`
- Abstracto.

#### `domain/usecases/`
- `get_mesas_usecase.dart`, `create_veedor_usecase.dart`, `asignar_veedor_usecase.dart`, `corregir_acta_usecase.dart`, `get_acta_por_mesa_usecase.dart`, `get_organizaciones_usecase.dart`, `subir_foto_acta_usecase.dart`, `get_avance_usecase.dart`.

### Presentation Layer

#### `bloc/recinto_bloc.dart`
- 8 handlers: `LoadMesas`, `CreateVeedor`, `AsignarVeedor`, `LoadOrganizaciones`, `LoadActaPorMesa`, `CorregirActa`, `SubirFotoActa`, `LoadAvance`.
- Estados: `RecintoInitial`, `RecintoLoading`, `MesasLoaded`, `VeedorCreated`, `VeedorAsignado`, `OrganizacionesLoaded`, `ActaPorMesaLoaded`, `ActaCorregida`, `FotoSubida`, `AvanceLoaded`, `RecintoError`.

#### `pages/recinto_dashboard_page.dart`
- Menú: Gestionar Mesas, Crear Veedor, Buscar Mesa por JRV. Muestra avance (mesas, actas, pendientes).

#### `pages/mesas_list_page.dart`
- Lista mesas con indicador de acta (check/cancel) y botones: Reasignar Veedor, Ver Detalle.

#### `pages/detalle_mesa_page.dart`
- Información de mesa + acta (si existe) con foto ampliable. Botón "Corregir Acta".

#### `pages/detalle_acta_page.dart` (recinto)
- Formulario de corrección: total sufragantes, nulos, blancos, votos por organización. Subir foto (gallery).

#### `pages/create_veedor_page.dart`
- Formulario: datos del veedor + asignación a mesa (dropdown).

---

## 6. Feature Veedor (`lib/features/veedor/`)

### Data Layer

#### `data/datasources/veedor_remote_datasource.dart`
- **Métodos**: `getMesasVeedor()`, `registrarActa()`, `subirFotoActa()`, `getOrganizaciones()`, `corregirActaVeedor()`, `getActaPorId()`, `eliminarActa()`, `getVotosPorActa()`.
- `getMesasVeedor()`: mesas por `veedor_id` + recinto + actas (filtro Dart). Retorna lista combinada.
- `registrarActa()`: crea documento en `actas` + documentos en `votos_por_organizacion`.
- `subirFotoActa()`: sube a Storage, actualiza `foto_url`.
- `getVotosPorActa()`: lista votos por `acta_id` → retorna `Map<organizacion_id, votos>`.

#### `data/datasources/veedor_local_datasource.dart`
- **Hive**: almacena `ActaPendienteModel` para sync offline.
- Métodos: `guardarPendiente()`, `getPendientes()`, `getPendientesSync()`, `getPorLocalId()`, `actualizarEstado()`, `eliminar()`, `contarPendientes()`, `contarConflictos()`.

#### `data/models/`
- **`ActaModel`**: extiende `Acta`. `fromMap()` mapea campos (incluye `gps_lat`/`gps_lng`).
- **`ActaPendienteModel`**: modelo para offline: `localId`, `actaId?`, `fotoUrl?`, `fotoLocalPath?`, datos del acta, `syncStatus` (pendiente/sincronizado/conflicto), `conflictoDetalle?`.
- **`OrganizacionPoliticaModel`**: extiende `OrganizacionPolitica`. `fromMap()` mapea `nombre`, `dignidad`, `candidato`.
- **`VotoModel`**: extiende `Voto`. Diferencias: en la BD remota la clave puede ser `votos` o `cantidad_votos`.

#### `data/repositories/veedor_repository_impl.dart`
- **`VeedorRepositoryImpl`**: implementa `VeedorRepository`.
- `registrarActa()`: intenta remoto; si falla (offline), guarda localmente con `_generateLocalId()`.
- `subirFotoActa()`: si ID local o falla remoto, guarda ruta local.
- `getVotosPorActa()`: remoto directamente.

### Domain Layer

#### `domain/entities/`
- **`Acta`**: `id`, `mesaId`, `dignidad`, `totalSufragantes`, `votosNulos`, `votosBlancos`, `fotoUrl?`, `gpsLatitud?`, `gpsLongitud?`, `registradoPor`, `estado`, `updatedAt?`. Getter `votosValidos`.
- **`OrganizacionPolitica`**: `id`, `nombre`, `dignidad`, `candidato`.
- **`Voto`**: `id`, `actaId`, `organizacionId`, `votos`.

#### `domain/repositories/veedor_repository.dart`
- Abstracto: `getMesasVeedor`, `registrarActa`, `subirFotoActa`, `getOrganizaciones`, `getVotosPorActa`, `corregirActaVeedor`.

#### `domain/usecases/`
- `get_mesas_veedor_usecase.dart`, `registrar_acta_usecase.dart`, `subir_foto_acta_usecase.dart`, `get_organizaciones_usecase.dart`, `get_votos_por_acta_usecase.dart`, `corregir_acta_veedor_usecase.dart`.

### Presentation Layer

#### `bloc/veedor_bloc.dart`
- 6 handlers: `LoadMesasVeedor`, `LoadOrganizaciones`, `RegistrarActa`, `SubirFotoActa`, `CorregirActaVeedor`, `LoadVotosPorActa`.
- Estados: `VeedorInitial`, `VeedorLoading`, `MesasVeedorLoaded`, `OrganizacionesLoaded`, `ActaRegistrada`, `FotoSubida`, `VotosPorActaLoaded`, `ActaCorregida`, `VeedorError`.

#### `sync/sync_bloc.dart`
- **`SyncBloc`**: maneja sincronización offline de actas pendientes.
- Eventos: `StartSync`, `ConnectivityChanged`, `SyncNext`, `ResolverConflicto`.
- Estados: `SyncInitial`, `SyncIdle(conectado, pendientes, conflictos)`, `SyncInProgress(total, procesados)`, `SyncCompletado(sincronizados, conflictos, errores)`, `ConflictoDetectado(pendiente, remoteUpdatedAt)`, `SyncError`.
- **Estrategia de conflictos**: last-write-wins con detección: compara `updated_at` remoto vs `createdAt` local; si remoto es más reciente → conflicto (usuario decide descartar local o sobrescribir borrando remoto y re-subiendo).
- Auto-sync cuando reconecta (`_sinConexionPrevia`).

#### `pages/veedor_dashboard_page.dart`
- Menú: Mis Mesas, Registrar Acta. Badge de sync (pendientes), indicador cloud.

#### `pages/mis_mesas_page.dart`
- **`MisMesasPage`**: lista mesas asignadas con ExpansionTile. Por acta: botón "Corregir" → `CorregirActaPage`.

#### `pages/registrar_acta_page.dart`
- **Flujo**:
  1. **Step 0**: Seleccionar mesa (de las asignadas). Si mesa tiene ambas dignidades registradas, no se puede seleccionar.
  2. Si ya tiene alcalde registrado → salta a prefecto (step 2). Si no → step 1 (alcalde).
- **Formulario**: tabla con Organización | Candidato | Votos (5 organizaciones). Fila: Nulos | Blancos | Total.
- **Cámara inline**: `ImagePicker` → validación `ImageQualityChecker.isSharp` → alerta "Tomar de nuevo" / "Omitir" si borrosa.
- **GPS**: auto-captura al cargar y al tomar foto.
- **Validación**: ningún org > total; suma org + nulos + blancos == total.
- **Guardado**: `RegistrarActa` → `ActaRegistrada` → `SubirFotoActa` → `FotoSubida` → avanza a siguiente dignidad.
- Al completar ambas dignidades, vuelve atrás con snackbar.

#### `pages/corregir_acta_page.dart`
- Recibe datos del acta + `LoadOrganizaciones` + `LoadVotosPorActa`.
- Campos pre-rellenados: total, nulos, blancos, votos por org.
- Botón "Cambiar foto" → `FotoActaPage`.
- Guarda: `CorregirActaVeedor`.

#### `pages/foto_acta_page.dart`
- Cámara con validación de nitidez. Botón "Subir Foto". Al éxito → `Navigator.pop()` (vuelve a la página que lo llamó).

---

## 7. Inyección de Dependencias (`injection_container.dart`)

**GetIt `sl`** registra:

- **Core**: `Account`, `Databases`, `Storage`, `Functions` (singletons).
- **Auth**: `AuthBloc`, `RecoveryBloc`, `VerificationBloc` (factories) + use cases + repositorio + datasource (lazy singletons).
- **Provincial**: `ProvincialBloc` (factory) + 9 use cases + repositorio + datasource.
- **Recinto**: `RecintoBloc` (factory) + 8 use cases + repositorio + datasource.
- **Veedor**: `VeedorBloc`, `SyncBloc` (factories) + 6 use cases + repositorio + datasource remoto + local + `Connectivity`.

---

## 8. Router (`router/app_router.dart`)

**GoRouter** con:
- `/login`: `LoginPage`.
- `/change-password`: `ChangePasswordPage`.
- `/forgot-password`: `ForgotPasswordPage`.
- `/reset-password`: `ResetPasswordPage`.
- **ShellRoute** (provee `ProvincialBloc`, `RecintoBloc`, `VeedorBloc` a rutas hijas).
  - `/provincial`: `ProvincialDashboardPage`.
  - `/recinto`: `RecintoDashboardPage`.
  - `/veedor`: `VeedorDashboardPage`.

**Auth redirect**: si `AuthUnauthenticated` → `/login`. Si `AuthRequiresPasswordChange` → `/change-password`. Si autenticado y va a `/login` o `/change-password` → redirige según rol.

---

## 9. Appwrite Function: `create-user`

**`appwrite/functions/create-user/src/index.js`**:
1. Recibe `email`, `password`, `name`.
2. Crea auth user con `Account.create()`.
3. Crea sesión temporal con `Account.createEmailPasswordSession()`.
4. Envía verificación de correo con `Account.createVerification()`.
5. Elimina sesión temporal.
6. Retorna `{ success: true, userId }`.

**Importante**: La verificación se envía al **nuevo usuario** (no al coordinador logueado), a diferencia de `account.createVerification()` en Flutter que opera sobre la sesión actual.

---

## 10. Registro de Avance (summary)

### Funcionalidad Implementada

| Funcionalidad | Estado |
|---|---|
| Login con rol (provincial/recinto/veedor) | ✅ |
| Creación de recintos con mesas automáticas | ✅ |
| Creación de coordinadores de recinto (con verificación email) | ✅ |
| Dashboard provincial: resumen global, informe electoral | ✅ |
| Dashboard recinto: gestión mesas, creación veedores | ✅ |
| Dashboard veedor: registro de actas (alcalde + prefecto) | ✅ |
| Cámara inline con validación de nitidez (Laplacian) | ✅ |
| GPS automático al registrar acta | ✅ |
| Sincronización offline de actas (Hive + SyncBloc) | ✅ |
| Corrección de actas (coordinador recinto + veedor) | ✅ |
| Google Maps en detalle de acta (GPS) | ✅ |
| Deep links para verificación y recuperación de contraseña | ✅ |
| Banner verificación de email | ✅ |
| Botón "Corregir" en Mis Mesas (veedor) | ✅ |
| Flujo encadenado en Informe Electoral (sin race conditions) | ✅ |
| Pantalla en blanco al navegar atrás: corregido con `addPostFrameCallback` | ✅ |
| Filtros en Dart (reemplazo de `Query.equal` para `estado`/`mesa_id`) | ✅ |

### Pendiente / Conocido

- Inconsistencia en clave `'votos'` vs `'cantidad_votos'` en `votos_por_organizacion` (provincial lee `cantidad_votos`, veedor escribe `votos`).
- `numero_jrv` en `recintos` se guarda como int en Appwrite → convertido a String en Dart.
- Los nuevos handlers en `ProvincialBloc`/`VeedorBloc` requieren **hot restart** (no hot reload).
- Se necesita probar flujo completo veedor (registro, corrección) y navegación provincial.
