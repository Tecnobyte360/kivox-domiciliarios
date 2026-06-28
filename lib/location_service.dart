import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'api.dart';

/// Rastreo de ubicación en segundo plano para el domiciliario.
///
/// Usa un *foreground service* de geolocator: mientras hay una notificación
/// fija ("Kivox en ruta"), Android permite seguir recibiendo la ubicación
/// aunque la app esté en segundo plano o con la pantalla apagada.
class LocationService {
  static StreamSubscription<Position>? _sub;
  static bool get activo => _sub != null;

  static Future<bool> _permiso() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    return !(p == LocationPermission.denied || p == LocationPermission.deniedForever);
  }

  /// Inicia el rastreo (idempotente). [token] = token del domiciliario.
  static Future<void> iniciar(String token) async {
    if (_sub != null || token.isEmpty) return;
    if (!await _permiso()) return;

    final api = KivoxApi(token);

    // Envío inmediato al arrancar
    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 12));
      await api.enviarUbicacion(pos.latitude, pos.longitude);
    } catch (_) {}

    final settings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
      intervalDuration: const Duration(seconds: 20),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'Kivox en ruta',
        notificationText: 'Compartiendo tu ubicación con la central',
        enableWakeLock: true,
      ),
    );

    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
      (pos) => api.enviarUbicacion(pos.latitude, pos.longitude),
      onError: (_) {},
    );
  }

  static Future<void> detener() async {
    await _sub?.cancel();
    _sub = null;
  }
}
