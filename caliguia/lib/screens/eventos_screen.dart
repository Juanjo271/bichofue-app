import 'package:flutter/material.dart';
import '../main.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';

class EventosScreen extends StatefulWidget {
  const EventosScreen({super.key});

  @override
  State<EventosScreen> createState() => _EventosScreenState();
}

class _EventosScreenState extends State<EventosScreen> {
  List<dynamic> _eventos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEventos();
  }

  Future<void> _loadEventos() async {
    setState(() => _isLoading = true);
    
    try {
      final eventos = await ApiService.getEventos();
      if (eventos.isNotEmpty) {
        setState(() {
          _eventos = eventos;
          _isLoading = false;
        });
        return;
      }
    } catch (_) {}

    try {
      final offline = await DatabaseService.getEventos();
      setState(() {
        _eventos = offline;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BichofueColors.beige,
      appBar: AppBar(
        title: const Text('Eventos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEventos,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _eventos.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_busy, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No hay eventos disponibles'),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _eventos.length,
                  itemBuilder: (ctx, index) {
                    final ev = _eventos[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: BichofueColors.cafe,
                          child: Icon(Icons.event, color: BichofueColors.blanco),
                        ),
                        title: Text(ev['nombre'] ?? 'Evento'),
                        subtitle: Text(ev['fecha_texto'] ?? 'Fecha por definir'),
                        trailing: Chip(
                          label: Text(ev['escala'] ?? 'Evento'),
                          backgroundColor: BichofueColors.amarillo.withOpacity(0.2),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
