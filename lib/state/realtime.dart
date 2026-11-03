import 'package:flutter/material.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../core/config.dart';
import 'stores.dart';

/// Escucha los canales STOMP del backend (/ws-asilo) y refresca las listas.
class Realtime {
  final Stores stores;
  final GlobalKey<ScaffoldMessengerState> messenger;
  Realtime(this.stores, this.messenger);

  StompClient? _c;
  static const _topics = {
    'internos': 'internos',
    'solicitudes': 'solicitudes',
    'visitas': 'visitas',
    'finanzas': 'transacciones',
    'alertas-medicas': 'fichas',
  };

  void start(String token) {
    stop();
    final c = StompClient(
      config: StompConfig.sockJS(
        url: '$baseUrl/ws-asilo',
        reconnectDelay: const Duration(seconds: 8),
        stompConnectHeaders: {'Authorization': 'Bearer $token'},
        webSocketConnectHeaders: {'Authorization': 'Bearer $token'},
        onConnect: (frame) {
          _topics.forEach((topic, storeKey) {
            _c?.subscribe(
              destination: '/topic/$topic',
              callback: (f) {
                stores.of(storeKey).load(silent: true);
                if (topic == 'alertas-medicas') {
                  messenger.currentState?.showSnackBar(
                      const SnackBar(content: Text('Nueva ficha médica registrada')));
                }
              },
            );
          });
        },
        onWebSocketError: (_) {},
        onStompError: (_) {},
      ),
    );
    _c = c;
    c.activate();
  }

  void stop() {
    _c?.deactivate();
    _c = null;
  }
}
