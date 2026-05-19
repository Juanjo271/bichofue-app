import 'package:flutter/material.dart';
import '../main.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import 'attraction_detail_screen.dart';

/// Vista secundaria: Lista tradicional de atractivos.
/// Se accede desde el mapa o desde la navegación.
class AttractionsListScreen extends StatefulWidget {
  const AttractionsListScreen({super.key});

  @override
  State<AttractionsListScreen> createState() => _AttractionsListScreenState();
}

class _AttractionsListScreenState extends State<AttractionsListScreen> {
  List<dynamic> _atractivos = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAtractivos();
  }

  Future<void> _loadAtractivos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final online = await ApiService.getAtractivos();
      if (online.isNotEmpty) {
        setState(() {
          _atractivos = online;
          _isLoading = false;
        });
        return;
      }
    } catch (_) {}

    try {
      final offline = await DatabaseService.getAtractivos();
      setState(() {
        _atractivos = offline;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de Lugares'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAtractivos,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: BichofueColors.cafe),
            const SizedBox(height: 16),
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAtractivos,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_atractivos.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.place, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No hay lugares disponibles'),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _atractivos.length,
      itemBuilder: (ctx, index) {
        final atr = _atractivos[index];
        final isEmblematico = atr['es_emblematico'] == 1 || atr['es_emblematico'] == true;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          elevation: isEmblematico ? 2 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: isEmblematico
                ? const BorderSide(color: BichofueColors.amarillo, width: 2)
                : BorderSide.none,
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isEmblematico ? BichofueColors.amarillo : BichofueColors.verde,
              child: Icon(
                isEmblematico ? Icons.camera_alt : Icons.place,
                color: BichofueColors.blanco,
              ),
            ),
            title: Text(
              atr['nombre'] ?? 'Sin nombre',
              style: TextStyle(
                fontWeight: isEmblematico ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Text(
              atr['componente'] ?? atr['grupo'] ?? 'Atractivo turístico',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AttractionDetailScreen(atraction: atr),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
