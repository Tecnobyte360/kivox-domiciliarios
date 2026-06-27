# 🛵 Kivox Repartidores — App de domiciliarios (Flutter)

App móvil para que el domiciliario **inicie ruta**, **finalice ruta (Entregado)**, vea el **código de entrega**, navegue con **Google Maps** y comparta su **ubicación GPS** — conectada a la plataforma Kivox.

## Pantallas
- **Login** por *código de acceso* (el mismo del enlace web `…/d/TU-CODIGO`).
- **Mis pedidos**: KPIs (pendientes / entregados hoy), lista ordenada por cercanía, botones **Ir / Llamar / Iniciar ruta / Entregado**, código de entrega visible al ir en camino. Refresca solo cada 30s y manda GPS cada 45s.

## Backend (ya desplegado en Kivox)
La app consume `https://admin.kivox.co/api/domiciliario/*` (auth por token del domiciliario):
`POST login`, `GET pedidos`, `POST pedidos/{id}/iniciar`, `POST pedidos/{id}/entregar`, `POST ubicacion`.
> Si usas otro dominio, cambia `baseUrl` en `lib/api.dart`.

---

## Cómo compilar (necesitas Flutter instalado)

1. Instala Flutter: https://docs.flutter.dev/get-started/install (y `flutter doctor`).
2. En esta carpeta, genera las plataformas nativas (android/ios) **sin sobrescribir** lib/ ni pubspec:
   ```bash
   flutter create --project-name kivox_domiciliarios --platforms=android,ios .
   ```
3. Instala dependencias:
   ```bash
   flutter pub get
   ```
4. **Permisos Android** — edita `android/app/src/main/AndroidManifest.xml` y agrega, ANTES de `<application ...>`:
   ```xml
   <uses-permission android:name="android.permission.INTERNET"/>
   <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
   <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
   ```
5. **Permisos iOS** (si compilas para iPhone) — en `ios/Runner/Info.plist` agrega:
   ```xml
   <key>NSLocationWhenInUseUsageDescription</key>
   <string>Usamos tu ubicación para optimizar la ruta de entregas.</string>
   ```
6. Probar en un celular conectado:
   ```bash
   flutter run
   ```
7. Generar el APK para instalar/distribuir:
   ```bash
   flutter build apk --release
   ```
   El APK queda en `build/app/outputs/flutter-apk/app-release.apk`.

---

## Notas
- **Login:** el domiciliario pega su *código de acceso* (la parte final de su enlace `…/d/XXXX`). Lo puedes copiar desde el panel **Domiciliarios** de Kivox.
- Para publicar en **Google Play** hay que firmar el APK/AAB (keystore) y crear la ficha de la tienda — eso es un paso aparte cuando quieras publicarla.
- El ícono y nombre se pueden personalizar con `flutter_launcher_icons` cuando definas el logo final de Kivox Repartidores.
