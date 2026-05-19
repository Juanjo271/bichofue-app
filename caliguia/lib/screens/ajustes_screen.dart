import 'package:flutter/material.dart';
import '../main.dart';
import '../services/api_service.dart';
import '../services/discovery_service.dart';
import '../services/websocket_service.dart';

class AjustesScreen extends StatefulWidget {
  const AjustesScreen({super.key});

  @override
  State<AjustesScreen> createState() => _AjustesScreenState();
}

class _AjustesScreenState extends State<AjustesScreen> {
  bool _isOnline = false;
  String _backendUrl = '';

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    final url = await DiscoveryService.getSavedUrl();
    if (url != null) {
      ApiService.setBaseUrl(url);
      final online = await ApiService.isOnline();
      if (mounted) {
        setState(() {
          _isOnline = online;
          _backendUrl = url;
        });
      }
    }
  }

  /// Obtiene el texto inicial para el campo de IP (última guardada o vacío)
  Future<String> _getInitialIpText() async {
    final saved = await DiscoveryService.getSavedUrl();
    if (saved != null) {
      return saved.replaceFirst('http://', '');
    }
    return '';
  }

  Future<void> _manualConnect() async {
    final initialText = await _getInitialIpText();
    final controller = TextEditingController(text: initialText);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Conectar al Backend'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'IP:Puerto del backend',
            hintText: 'ej: 192.168.1.9:5000',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Conectar'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _tryConnect(result);
    }
  }

  Future<void> _tryConnect(String ipPort) async {
    final url = ipPort.startsWith('http') ? ipPort : 'http://$ipPort';
    ApiService.setBaseUrl(url);
    final online = await ApiService.isOnline();
    if (online) {
      await DiscoveryService.saveBackendUrl(url);
      await WebSocketService.connect(url: url);
      if (mounted) {
        setState(() {
          _isOnline = true;
          _backendUrl = url;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Conectado a $url')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No se pudo conectar. Verifica la IP y que el servidor esté corriendo.'),
                  backgroundColor: BichofueColors.cafe,
                ),
        );
      }
    }
  }

  Future<void> _rescanNetwork() async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Buscando backend en la red...')),
      );
    }

    final url = await DiscoveryService.discoverBackend();
    if (url != null) {
      ApiService.setBaseUrl(url);
      final online = await ApiService.isOnline();
      if (online) {
        await WebSocketService.connect(url: url);
        if (mounted) {
          setState(() {
            _isOnline = true;
            _backendUrl = url;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Backend encontrado: $url')),
          );
        }
        return;
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se encontró el backend. Intenta ingresar la IP manualmente.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BichofueColors.beige,
      appBar: AppBar(
        title: const Text('Ajustes'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: Icon(
                _isOnline ? Icons.cloud_done : Icons.cloud_off,
                color: _isOnline ? Colors.green : Colors.orange,
              ),
              title: const Text('Estado de conexión'),
              subtitle: Text(_isOnline
                  ? 'Conectado a: $_backendUrl'
                  : 'Sin conexión al backend'),
              trailing: Switch(
                value: _isOnline,
                onChanged: (val) {
                  if (!val) {
                    WebSocketService.disconnect();
                    setState(() => _isOnline = false);
                  } else {
                    _manualConnect();
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _rescanNetwork,
            icon: const Icon(Icons.wifi_find),
            label: const Text('Re-escanear red'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.info),
                  title: Text('Acerca de Bichofué'),
                ),
                const Divider(),
                const ListTile(
                  title: Text('Versión'),
                  trailing: Text('1.0.0'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
