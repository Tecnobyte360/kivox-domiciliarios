import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import 'login_screen.dart';
import 'chat_list_screen.dart';
import 'pedidos_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _nombre = '';
  String _negocio = '';
  bool _permChat = false;
  bool _esDomi = false;
  String _movilToken = '';
  String _domiToken = '';
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _nombre = p.getString('user_nombre') ?? '';
      _negocio = p.getString('user_negocio') ?? '';
      _permChat = p.getBool('perm_chat') ?? false;
      _esDomi = p.getBool('es_domiciliario') ?? false;
      _movilToken = p.getString('movil_token') ?? '';
      _domiToken = p.getString('domiciliario_token') ?? '';
      _cargando = false;
    });
  }

  Future<void> _salir() async {
    final p = await SharedPreferences.getInstance();
    await p.clear();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final modulos = <Widget>[];
    if (_permChat) {
      modulos.add(_card(
        icon: Icons.chat,
        titulo: 'Chat de WhatsApp',
        sub: 'Conversaciones de clientes',
        color: kBrand,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatListScreen(token: _movilToken))),
      ));
    }
    if (_esDomi && _domiToken.isNotEmpty) {
      modulos.add(_card(
        icon: Icons.motorcycle,
        titulo: 'Mis entregas',
        sub: 'Pedidos asignados y ruta',
        color: const Color(0xFF3B82F6),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PedidosScreen(token: _domiToken))),
      ));
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
            child: Image.asset('assets/logo.png', height: 26),
          ),
          const SizedBox(width: 8),
          const Text('Kivox'),
        ]),
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: _salir)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Hola, $_nombre 👋', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          if (_negocio.isNotEmpty) Text(_negocio, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 16),
          if (modulos.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: Text('Tu usuario no tiene módulos habilitados.', style: TextStyle(color: Colors.black54))),
            ),
          ...modulos,
        ],
      ),
    );
  }

  Widget _card({required IconData icon, required String titulo, required String sub, required Color color, required VoidCallback onTap}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: Container(
          width: 52, height: 52,
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(sub),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
