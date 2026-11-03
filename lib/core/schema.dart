import 'package:flutter/material.dart';
import 'format.dart';

typedef Item = Map<String, dynamic>;
typedef Lk = String Function(String entity, dynamic id);

/// Devuelve el id de una relación, sea objeto anidado {"idX": 1} o valor plano.
Object? idOf(dynamic raw, String key) => raw is Map ? raw[key] : raw;

enum FT { text, multiline, integer, money, date, dateTime, select, relation, flag, password, dpi, phone }

/// Campos que el cliente completa solo (el backend no los llena).
enum Auto { none, nowOnCreate, nowOnSave, currentUser }

class Rel {
  final String entity;
  final String? nestedIdKey; // si el backend espera {"interno": {"idInterno": 1}}
  final bool Function(Item)? filter; // limita las opciones del desplegable
  const Rel(this.entity, {this.nestedIdKey, this.filter});
}


class Field {
  final String key, label;
  final FT type;
  final bool required, createOnly, inForm, inCard, full;
  final int? max, min;
  final List<String> options;
  final Rel? rel;
  final IconData icon;
  final Object? initial; // 'now' para fechas
  final Auto auto;
  final List<String> alt; // nombres alternativos de la clave en el JSON del backend
  const Field(this.key, this.label, this.type,
      {this.required = true,
      this.createOnly = false,
      this.inForm = true,
      this.inCard = false,
      this.full = false,
      this.max,
      this.min,
      this.options = const [],
      this.rel,
      this.icon = Icons.edit_outlined,
      this.initial,
      this.auto = Auto.none,
      this.alt = const []});
}

class RowAction {
  final String label, method, perm;
  final IconData icon;
  final String Function(Item) path;
  final bool Function(Item) visible;
  const RowAction(this.label, this.icon, this.path, this.visible,
      {this.method = 'PUT', this.perm = 'c'});
}

class Schema {
  final String key, title, singular, newLabel, path, idKey;
  final IconData icon;
  final Color color;
  final List<Field> fields;
  final bool apiCreate, apiUpdate, apiDelete;
  final String? createPath;
  final String Function(Item, Lk) titleOf;
  final String Function(Item, Lk)? subtitleOf;
  final String? Function(Item)? badgeOf;
  final String? Function(Item)? trailingOf;
  final List<RowAction> actions;

  const Schema({
    required this.key,
    required this.title,
    required this.singular,
    required this.newLabel,
    required this.path,
    required this.idKey,
    required this.icon,
    required this.color,
    required this.fields,
    required this.titleOf,
    this.subtitleOf,
    this.badgeOf,
    this.trailingOf,
    this.apiCreate = false,
    this.apiUpdate = false,
    this.apiDelete = false,
    this.createPath,
    this.actions = const [],
  });

  Set<String> get relatedKeys => {for (final f in fields) if (f.rel != null) f.rel!.entity};
}

// ---- Catálogos: coinciden con los CHECK de la base de datos (mydb) ----
const _generos = ['Masculino', 'Femenino'];
const _sangre = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
const _estadosInterno = ['ACTIVO', 'HOSPITALIZADO', 'EN_ENFERMERIA', 'EGRESADO', 'FALLECIDO'];
const _estadosSolicitud = ['PENDIENTE', 'APROBADA', 'RECHAZADA'];
const _tiposTransaccion = ['INGRESO_CUOTA', 'DONACION', 'EGRESO_GASTO', 'PAGO_FUNDACION'];
const _estadosPago = ['PENDIENTE', 'PAGADO', 'VENCIDO'];
const _roles = ['ADMIN', 'MEDICO', 'ENFERMERO', 'RECEPCION', 'FINANCIERO'];

String _nm(Item i) => '${i['nombre'] ?? ''} ${i['apellido'] ?? ''}'.trim();

final List<Schema> schemas = [
  Schema(
    key: 'internos', title: 'Internos', singular: 'interno', newLabel: 'Nuevo interno',
    path: '/api/internos', idKey: 'idInterno', icon: Icons.elderly, color: const Color(0xFF0E7C86),
    apiCreate: true, apiUpdate: true, apiDelete: true,
    titleOf: (i, lk) => _nm(i),
    subtitleOf: (i, lk) => 'Hab. ${i['numeroHabitacion'] ?? '—'} · Cama ${i['numeroCama'] ?? '—'}',
    badgeOf: (i) => i['estado']?.toString(),
    fields: const [
      Field('solicitudReferenciaId', 'Solicitud de referencia', FT.relation,
          rel: Rel('solicitudes'), createOnly: true, full: true, icon: Icons.assignment_ind_outlined),
      Field('nombre', 'Nombre', FT.text, max: 50, icon: Icons.person_outline),
      Field('apellido', 'Apellido', FT.text, max: 50, icon: Icons.person_outline),
      Field('dpi', 'DPI', FT.dpi, icon: Icons.badge_outlined),
      Field('fechaNacimiento', 'Fecha de nacimiento', FT.date, icon: Icons.cake_outlined),
      Field('genero', 'Género', FT.select, options: _generos, icon: Icons.wc_outlined),
      Field('tipoSangre', 'Tipo de sangre', FT.select, options: _sangre, inCard: true, icon: Icons.bloodtype_outlined),
      Field('numeroHabitacion', 'Habitación', FT.text, max: 45, icon: Icons.meeting_room_outlined),
      Field('numeroCama', 'Cama', FT.text, max: 45, icon: Icons.bed_outlined),
      Field('fechaIngreso', 'Fecha de ingreso', FT.date, initial: 'now', inCard: true, icon: Icons.login),
      Field('estado', 'Estado', FT.select, options: _estadosInterno, initial: 'ACTIVO', icon: Icons.flag_outlined),
      Field('alergias', 'Alergias', FT.multiline, full: true, icon: Icons.warning_amber_outlined),
      Field('condicionesCronicas', 'Condiciones crónicas', FT.multiline, full: true, icon: Icons.monitor_heart_outlined),
      Field('creadoEn', 'Creado', FT.dateTime, inForm: false, required: false),
      Field('actualizadoEn', 'Actualizado', FT.dateTime, inForm: false, required: false),
    ],
  ),
  Schema(
    key: 'solicitudes', title: 'Solicitudes de referencia', singular: 'solicitud', newLabel: 'Nueva solicitud',
    path: '/api/solicitudes', idKey: 'idSolicitudReferencia', icon: Icons.assignment_ind_outlined,
    color: const Color(0xFFF2994A), apiCreate: true, apiUpdate: true, apiDelete: true,
    titleOf: (i, lk) => '${i['nombreAspirante'] ?? '—'}',
    subtitleOf: (i, lk) => 'Solicitante: ${i['nombreSolicitante'] ?? '—'} · ${i['parentesco'] ?? ''}',
    badgeOf: (i) => i['estadoSolicitud']?.toString(),
    fields: const [
      Field('nombreAspirante', 'Nombre del aspirante', FT.text, max: 150, icon: Icons.person_outline),
      Field('dpiAspirante', 'DPI del aspirante', FT.dpi, icon: Icons.badge_outlined),
      Field('edadAspirante', 'Edad del aspirante', FT.integer, min: 0, max: 120, icon: Icons.cake_outlined),
      Field('nombreSolicitante', 'Nombre del solicitante', FT.text, max: 150, icon: Icons.person_pin_outlined),
      Field('parentesco', 'Parentesco', FT.text, max: 50, icon: Icons.family_restroom),
      Field('telefono', 'Teléfono', FT.phone, max: 20, inCard: true, icon: Icons.phone_outlined),
      Field('motivoIngreso', 'Motivo de ingreso', FT.multiline, full: true, icon: Icons.notes),
      Field('estadoSolicitud', 'Estado', FT.select, options: _estadosSolicitud, initial: 'PENDIENTE', icon: Icons.flag_outlined),
      Field('fechaSolicitud', 'Fecha de solicitud', FT.date, initial: 'now', inCard: true, icon: Icons.event_outlined),
      Field('creadoEn', 'Creado', FT.dateTime, inForm: false, required: false),
      Field('actualizadoEn', 'Actualizado', FT.dateTime, inForm: false, required: false),
    ],
  ),
  Schema(
    key: 'responsables', title: 'Responsables', singular: 'responsable', newLabel: 'Nuevo responsable',
    path: '/api/responsables', idKey: 'idResponsable', icon: Icons.family_restroom,
    color: const Color(0xFF9B51E0), apiCreate: true,
    titleOf: (i, lk) => _nm(i),
    subtitleOf: (i, lk) => '${i['telefono'] ?? ''}',
    fields: const [
      Field('nombre', 'Nombre', FT.text, max: 50, icon: Icons.person_outline),
      Field('apellido', 'Apellido', FT.text, max: 50, icon: Icons.person_outline),
      Field('dpi', 'DPI', FT.dpi, inCard: true, icon: Icons.badge_outlined),
      Field('telefono', 'Teléfono', FT.phone, max: 20, icon: Icons.phone_outlined),
      Field('direccion', 'Dirección', FT.text, max: 255, full: true, inCard: true, icon: Icons.home_outlined),
    ],
  ),
  Schema(
    key: 'asignaciones', title: 'Responsables del interno', singular: 'asignación', newLabel: 'Asignar responsable',
    path: '/api/internos-responsables', idKey: 'idInternosResponsables', icon: Icons.link,
    color: const Color(0xFF9B51E0), apiCreate: true, apiDelete: true,
    titleOf: (i, lk) => lk('responsables', i['responsableId']),
    subtitleOf: (i, lk) => '${i['parentesco'] ?? ''} de ${lk('internos', i['internoId'])}',
    badgeOf: (i) => i['esContactoPrincipal'] == true ? 'PRINCIPAL' : null,
    fields: const [
      Field('internoId', 'Interno', FT.relation, rel: Rel('internos'), icon: Icons.elderly),
      Field('responsableId', 'Responsable', FT.relation, rel: Rel('responsables'), icon: Icons.family_restroom),
      Field('parentesco', 'Parentesco', FT.text, max: 50, icon: Icons.favorite_border),
      Field('esContactoPrincipal', 'Contacto principal', FT.flag, required: false, initial: false),
    ],
  ),
  Schema(
    key: 'visitantes', title: 'Visitantes', singular: 'visitante', newLabel: 'Nuevo visitante',
    path: '/api/visitantes', idKey: 'idVisitante', icon: Icons.people_alt_outlined,
    color: const Color(0xFF2D9CDB), apiCreate: true, apiUpdate: true, apiDelete: true,
    titleOf: (i, lk) => _nm(i),
    subtitleOf: (i, lk) => '${i['telefono'] ?? ''}',
    fields: const [
      Field('nombre', 'Nombre', FT.text, max: 50, icon: Icons.person_outline),
      Field('apellido', 'Apellido', FT.text, max: 50, icon: Icons.person_outline),
      Field('dpi', 'DPI', FT.dpi, inCard: true, icon: Icons.badge_outlined),
      Field('telefono', 'Teléfono', FT.phone, max: 25, icon: Icons.phone_outlined),
      Field('creadoEn', 'Registrado', FT.dateTime, inForm: false, required: false),
    ],
  ),
  Schema(
    key: 'visitas', title: 'Visitas', singular: 'visita', newLabel: 'Registrar visita',
    path: '/api/visitas', idKey: 'idVisita', icon: Icons.how_to_reg_outlined,
    color: const Color(0xFF2D9CDB), apiCreate: true,
    titleOf: (i, lk) => lk('visitantes', i['visitanteId']),
    subtitleOf: (i, lk) => 'Visita a ${lk('internos', i['internoId'])}',
    badgeOf: (i) => i['fechaHoraSalida'] == null ? 'EN CURSO' : 'FINALIZADA',
    actions: [
      RowAction('Registrar salida', Icons.logout, (i) => '/api/visitas/${i['idVisita']}/salida',
          (i) => i['fechaHoraSalida'] == null),
    ],
    fields: const [
      Field('internoId', 'Interno visitado', FT.relation, rel: Rel('internos'), full: true, icon: Icons.elderly),
      Field('visitanteId', 'Visitante', FT.relation, rel: Rel('visitantes'), full: true, icon: Icons.people_alt_outlined),
      Field('parentesco', 'Parentesco', FT.text, max: 50, icon: Icons.family_restroom),
      Field('fechaHoraEntrada', 'Entrada', FT.dateTime, initial: 'now', inCard: true, icon: Icons.login),
      Field('fechaHoraSalida', 'Salida', FT.dateTime, inForm: false, required: false, inCard: true),
      Field('creadoEn', 'Registrado', FT.dateTime, inForm: false, required: false),
    ],
  ),
  Schema(
    key: 'fichas', title: 'Fichas médicas', singular: 'ficha médica', newLabel: 'Nueva ficha médica',
    path: '/api/fichas-medicas', idKey: 'idFichaMedicaHistorial', icon: Icons.medical_services_outlined,
    color: const Color(0xFFEB5757), apiCreate: true,
    titleOf: (i, lk) => lk('internos', idOf(i['interno'], 'idInterno')),
    subtitleOf: (i, lk) => '${i['diagnostico'] ?? ''}'.split('\n').first,
    fields: const [
      Field('interno', 'Interno', FT.relation, rel: Rel('internos', nestedIdKey: 'idInterno'), full: true, icon: Icons.elderly),
      Field('diagnostico', 'Diagnóstico', FT.multiline, full: true, icon: Icons.healing),
      Field('tratamientoRecetado', 'Tratamiento recetado', FT.multiline, full: true, icon: Icons.medication_outlined),
      Field('observacionesEnfermeria', 'Observaciones de enfermería', FT.multiline, full: true, icon: Icons.notes),
      Field('fechaRegistro', 'Fecha de registro', FT.dateTime, initial: 'now', inCard: true, icon: Icons.event_outlined),
      Field('usuario', 'Registrado por', FT.relation, rel: Rel('usuarios', nestedIdKey: 'idUsuario'),
          alt: ['medicoResponsable', 'medico'], inForm: false, inCard: true, auto: Auto.currentUser,
          icon: Icons.person_outline),
      Field('creadoEn', 'Creado', FT.dateTime, inForm: false, required: false, auto: Auto.nowOnCreate),
    ],
  ),
  Schema(
    key: 'transacciones', title: 'Finanzas', singular: 'transacción', newLabel: 'Nueva transacción',
    path: '/api/transacciones', idKey: 'idTransaccionFinanciera', icon: Icons.payments_outlined,
    color: const Color(0xFF27AE60), apiCreate: true, apiUpdate: true,
    titleOf: (i, lk) => '${i['descripcion'] ?? '—'}',
    subtitleOf: (i, lk) => '${lk('internos', idOf(i['interno'], 'idInterno'))} · ${i['tipo'] ?? ''}',
    badgeOf: (i) => i['estadoPago']?.toString(),
    trailingOf: (i) => money(i['monto']),
    fields: const [
      Field('interno', 'Interno', FT.relation, rel: Rel('internos', nestedIdKey: 'idInterno'),
          createOnly: true, full: true, icon: Icons.elderly),
      Field('tipo', 'Tipo', FT.select, options: _tiposTransaccion, inCard: true, icon: Icons.category_outlined),
      Field('monto', 'Monto (Q)', FT.money, icon: Icons.attach_money),
      Field('descripcion', 'Descripción', FT.text, max: 255, full: true, icon: Icons.notes),
      Field('fechaTransaccion', 'Fecha', FT.date, initial: 'now', inCard: true, icon: Icons.event_outlined),
      Field('estadoPago', 'Estado de pago', FT.select, options: _estadosPago, initial: 'PENDIENTE', icon: Icons.flag_outlined),
      Field('registradoPor', 'Registrado por', FT.relation, rel: Rel('usuarios', nestedIdKey: 'idUsuario'), alt: ['usuario'],
          inForm: false, auto: Auto.currentUser, icon: Icons.person_outline),
      Field('creadoEn', 'Creado', FT.dateTime, inForm: false, required: false, auto: Auto.nowOnCreate),
      Field('actualizadoEn', 'Actualizado', FT.dateTime, inForm: false, required: false, auto: Auto.nowOnSave),
    ],
  ),
  Schema(
    key: 'usuarios', title: 'Usuarios', singular: 'usuario', newLabel: 'Nuevo usuario',
    path: '/api/usuarios', createPath: '/api/auth/register', idKey: 'idUsuario',
    icon: Icons.admin_panel_settings_outlined, color: const Color(0xFF6D4AFF), apiCreate: true,
    titleOf: (i, lk) => '${i['username'] ?? '—'}',
    subtitleOf: (i, lk) => '${i['rol'] ?? ''}',
    badgeOf: (i) => i['rol']?.toString(),
    fields: const [
      Field('username', 'Usuario', FT.text, max: 50, icon: Icons.person_outline),
      Field('password', 'Contraseña', FT.password, icon: Icons.lock_outline),
      Field('rol', 'Rol', FT.select, options: _roles, initial: 'ENFERMERO', icon: Icons.shield_outlined),
      Field('creadoEn', 'Creado', FT.dateTime, inForm: false, required: false, inCard: true),
      Field('actualizadoEn', 'Actualizado', FT.dateTime, inForm: false, required: false),
    ],
  ),
];

Schema schemaOf(String key) => schemas.firstWhere((s) => s.key == key);
