import 'package:flutter/foundation.dart';

/// URL del backend Spring Boot alojado en Render.
/// Puedes sobreescribirla al compilar con: flutter run --dart-define=API_URL=https://tu-app.onrender.com
String get baseUrl {
  const env = String.fromEnvironment('API_URL');
  if (env.isNotEmpty) return env;
  
  // URL de producción en Render (cambia esta dirección por la tuya exacta)
  return 'https://cabeza-de-algodon-backend.onrender.com';
}