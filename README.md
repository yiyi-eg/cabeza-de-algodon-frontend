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
- `core/roles.dart`: matriz de permisos. `state/`: sesión, listas, tiempo real. `ui/`: pantallas.

## Supuestos
- Los catálogos (estados, tipos, roles, género) coinciden con los CHECK de la base de datos `mydb`. Si cambias un CHECK, actualiza `schema.dart`.
- "Por cobrar" y "Cobrado" solo cuentan INGRESO_CUOTA y DONACION; EGRESO_GASTO y PAGO_FUNDACION no se suman como ingresos.
- DPI validado con 13 dígitos. Moneda en quetzales (Q).

## Observaciones del backend (recomendadas)
1. `SecurityConfig` permite `/ws/**` pero el endpoint es `/ws-asilo`: cambia a `/ws-asilo/**` o el tiempo real no conecta.
2. El backend no valida roles (solo token). Agrega `requestMatchers(...).hasRole(...)` o `@PreAuthorize`.
3. `/api/auth/register` es público: cualquiera puede crear un ADMIN.
4. `GET /api/usuarios` devuelve el hash de la contraseña: usa `@JsonIgnore` o un DTO.
5. `JwtService` usa una clave fija en código (ignora `JWT_SECRET`) y el token no trae rol/id; la app los obtiene de `/api/usuarios`.
6. `fichas`/`transacciones` usan `@ManyToOne(LAZY)`: si falla la serialización JSON, agrega `@JsonIgnoreProperties({"hibernateLazyInitializer","handler"})` o DTOs.
7. `FichaMedicaHistorial` y `TransaccionFinanciera` no tienen `@PrePersist`: la app envía `creadoEn`.
