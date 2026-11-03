import 'package:flutter/material.dart';

const roles = ['ADMIN', 'MEDICO', 'ENFERMERO', 'RECEPCION', 'FINANCIERO'];

const roleLabels = {
  'ADMIN': 'Administrador',
  'MEDICO': 'Médico',
  'ENFERMERO': 'Enfermería',
  'RECEPCION': 'Recepción',
  'FINANCIERO': 'Finanzas',
};
const roleColors = {
  'ADMIN': Color(0xFF6D4AFF),
  'MEDICO': Color(0xFF0E7C86),
  'ENFERMERO': Color(0xFF2F80ED),
  'RECEPCION': Color(0xFFF2994A),
  'FINANCIERO': Color(0xFF27AE60),
};
const roleTaglines = {
  'ADMIN': 'Control total del sistema',
  'MEDICO': 'Seguimiento clínico de los internos',
  'ENFERMERO': 'Cuidado diario y observaciones',
  'RECEPCION': 'Admisiones, solicitudes y visitas',
  'FINANCIERO': 'Pagos y estado de cuenta',
};

/// Permisos por módulo y rol: r=ver, c=crear, u=editar, d=eliminar.
/// El backend actual NO valida roles (solo exige token), por lo que esta
/// matriz es la que gobierna lo que cada rol ve y puede hacer en la app.
const Map<String, Map<String, String>> _perm = {
  'internos': {'ADMIN': 'rcud', 'RECEPCION': 'rcu', 'MEDICO': 'r', 'ENFERMERO': 'r', 'FINANCIERO': 'r'},
  'solicitudes': {'ADMIN': 'rcud', 'RECEPCION': 'rcu'},
  'responsables': {'ADMIN': 'rc', 'RECEPCION': 'rc', 'MEDICO': 'r', 'ENFERMERO': 'r', 'FINANCIERO': 'r'},
  'asignaciones': {'ADMIN': 'rcd', 'RECEPCION': 'rcd', 'MEDICO': 'r', 'ENFERMERO': 'r', 'FINANCIERO': 'r'},
  'visitantes': {'ADMIN': 'rcud', 'RECEPCION': 'rcud', 'ENFERMERO': 'r'},
  'visitas': {'ADMIN': 'rc', 'RECEPCION': 'rc', 'ENFERMERO': 'r', 'MEDICO': 'r'},
  'fichas': {'ADMIN': 'rc', 'MEDICO': 'rc', 'ENFERMERO': 'rc'},
  'transacciones': {'ADMIN': 'rcu', 'FINANCIERO': 'rcu'},
  'usuarios': {'ADMIN': 'rc'},
};

bool can(String? rol, String schema, String perm) =>
    (_perm[schema]?[rol] ?? '').contains(perm);

/// Orden del menú lateral.
const navOrder = [
  'internos', 'solicitudes', 'visitas', 'visitantes',
  'responsables', 'fichas', 'transacciones', 'usuarios',
];
