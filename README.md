# Cabeza de Algodón – App Flutter

Cliente para el backend Spring Boot (`/api/*`, JWT, WebSocket `/ws-asilo`). Material 3, claro/oscuro, vistas por rol.

## Ejecutar
```bash
cd asilo_cabeza_de_algodon
flutter create . --platforms=android,ios,web,windows   # genera carpetas de plataforma (no pisa lib/ ni pubspec)
flutter pub get
flutter run                                            # backend en localhost:8081
# dispositivo físico:  flutter run --dart-define=API_URL=http://192.168.1.50:8081
```
Android con HTTP: en `AndroidManifest.xml` agrega `<uses-permission android:name="android.permission.INTERNET"/>` y `android:usesCleartextTraffic="true"` en `<application>`.

## Roles y módulos (editable en `lib/core/roles.dart`)
| Módulo | ADMIN | RECEPCION | MEDICO | ENFERMERO | FINANCIERO |
|---|---|---|---|---|---|
| Internos | ver/crear/editar/eliminar | ver/crear/editar | ver | ver | ver |
| Solicitudes | todo | ver/crear/editar | – | – | – |
| Responsables y asignaciones | ver/crear/(quitar) | ver/crear/(quitar) | ver | ver | ver |
| Visitantes | todo | todo | – | ver | – |
| Visitas (+salida) | ver/crear | ver/crear | ver | ver | – |
| Fichas médicas | ver/crear | – | ver/crear | ver/crear | – |
| Finanzas | ver/crear/editar | – | – | – | ver/crear/editar |
| Usuarios | ver/crear | – | – | – | – |

Las funciones disponibles también están limitadas por lo que el backend expone (p. ej. fichas y visitas no tienen PUT/DELETE).

## Estructura
- `core/schema.dart`: UNA definición por entidad (campos, tipos, validaciones, relaciones). La UI se genera de aquí.
- `core/roles.dart`: matriz de permisos. `state/`: sesión, listas, tiempo real. `ui/`: pantallas
