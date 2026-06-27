import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() => runApp(const KivoxApp());

// Colores de marca Kivox (verde del logo)
const kBrand = Color(0xFF2E9E5B);
const kBrandDark = Color(0xFF1B7A44);

class KivoxApp extends StatelessWidget {
  const KivoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kivox',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: kBrand,
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
        appBarTheme: const AppBarTheme(
          backgroundColor: kBrand,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
      ),
      home: const _Arranque(),
    );
  }
}

class _Arranque extends StatefulWidget {
  const _Arranque();
  @override
  State<_Arranque> createState() => _ArranqueState();
}

class _ArranqueState extends State<_Arranque> {
  bool _cargando = true;
  bool _logueado = false;

  @override
  void initState() {
    super.initState();
    _revisar();
  }

  Future<void> _revisar() async {
    final prefs = await SharedPreferences.getInstance();
    final t = prefs.getString('movil_token');
    setState(() {
      _logueado = t != null && t.isNotEmpty;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _logueado ? const HomeScreen() : const LoginScreen();
  }
}
