import 'package:flutter/material.dart';
import '../main.dart';
import '../models/stamp_model.dart';
import '../services/api_service.dart';
import '../services/stamp_service.dart';
import '../widgets/bichofue_avatar.dart';

/// Pantalla de colección de estampas caleñas
/// Muestra grid con estampas obtenidas y bloqueadas
class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  List<StampModel> _stamps = [];
  bool _isLoading = true;
  String _filter = 'todas'; // todas, desbloqueadas, bloqueadas

  @override
  void initState() {
    super.initState();
    _loadStamps();
  }

  Future<void> _loadStamps() async {
    setState(() => _isLoading = true);
    final stamps = await StampService.getUserStamps();
    setState(() {
      _stamps = stamps;
      _isLoading = false;
    });
  }

  List<StampModel> get _filteredStamps {
    switch (_filter) {
      case 'desbloqueadas':
        return _stamps.where((s) => s.unlocked).toList();
      case 'bloqueadas':
        return _stamps.where((s) => !s.unlocked).toList();
      default:
        return _stamps;
    }
  }

  @override
  Widget build(BuildContext context) {
    final desbloqueadas = _stamps.where((s) => s.unlocked).length;
    final total = _stamps.length;
    final progreso = total > 0 ? desbloqueadas / total : 0.0;

    return Scaffold(
      backgroundColor: BichofueColors.beige,
      appBar: AppBar(
        title: const Text('Mi Colección'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadStamps,
        color: BichofueColors.amarillo,
        backgroundColor: BichofueColors.verde,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : CustomScrollView(
                slivers: [
                  // Header con progreso
                  SliverToBoxAdapter(
                    child: _buildProgressHeader(desbloqueadas, total, progreso),
                  ),

                  // Filtros
                  SliverToBoxAdapter(
                    child: _buildFilterChips(),
                  ),

                  // Grid de estampas
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: _stamps.isEmpty
                        ? SliverToBoxAdapter(
                            child: _buildEmptyState(),
                          )
                        : SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.75,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final stamp = _filteredStamps[index];
                                return _buildStampCard(stamp);
                              },
                              childCount: _filteredStamps.length,
                            ),
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildProgressHeader(int desbloqueadas, int total, double progreso) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [BichofueColors.verde, Color(0xFF1B5E20)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          // Círculo de progreso
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: progreso,
                  strokeWidth: 8,
                  backgroundColor: BichofueColors.blanco.withOpacity(0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    BichofueColors.amarillo,
                  ),
                ),
                Center(
                  child: Text(
                    '${(progreso * 100).toInt()}%',
                    style: const TextStyle(
                      color: BichofueColors.blanco,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Colección Caleña',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: BichofueColors.blanco,
                        fontSize: 20,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$desbloqueadas de $total estampas',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: BichofueColors.beige,
                      ),
                ),
                const SizedBox(height: 8),
                if (desbloqueadas == total && total > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: BichofueColors.amarillo.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.emoji_events,
                            size: 14, color: BichofueColors.amarillo),
                        SizedBox(width: 4),
                        Text(
                          '¡Colección completa!',
                          style: TextStyle(
                            color: BichofueColors.amarillo,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      {'key': 'todas', 'label': 'Todas'},
      {'key': 'desbloqueadas', 'label': 'Obtenidas'},
      {'key': 'bloqueadas', 'label': 'Por descubrir'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        children: filters.map((f) {
          final isSelected = _filter == f['key'];
          return ChoiceChip(
            label: Text(f['label']!),
            selected: isSelected,
            onSelected: (_) => setState(() => _filter = f['key']!),
            selectedColor: BichofueColors.amarillo,
            backgroundColor: BichofueColors.blanco,
            labelStyle: TextStyle(
              color: isSelected ? BichofueColors.negro : BichofueColors.cafe,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStampCard(StampModel stamp) {
    final isUnlocked = stamp.unlocked;

    return Card(
      elevation: isUnlocked ? 4 : 0,
      color: isUnlocked ? BichofueColors.blanco : BichofueColors.grisClaro,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Imagen o placeholder
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: isUnlocked
                    ? BichofueColors.verde.withOpacity(0.1)
                    : BichofueColors.gris.withOpacity(0.2),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Center(
                child: isUnlocked
                    ? (stamp.imagenUrl != null
                        ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(20)),
                            child: Image.network(
                              '${ApiService.baseUrl}${stamp.imagenUrl}',
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (_, __, ___) =>
                                  _buildStampPlaceholder(stamp, isUnlocked),
                            ),
                          )
                        : _buildStampPlaceholder(stamp, isUnlocked))
                    : Icon(
                        Icons.lock,
                        size: 40,
                        color: BichofueColors.gris,
                      ),
              ),
            ),
          ),

          // Info
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isUnlocked)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _parseColor(stamp.rarezaColor).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        stamp.rareza.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: _parseColor(stamp.rarezaColor),
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: BichofueColors.gris.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'BLOQUEADA',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: BichofueColors.gris,
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    stamp.nombre,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isUnlocked
                          ? BichofueColors.negro
                          : BichofueColors.gris,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isUnlocked) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          size: 12,
                          color: BichofueColors.amarillo,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${stamp.puntos} pts',
                          style: const TextStyle(
                            fontSize: 11,
                            color: BichofueColors.cafe,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStampPlaceholder(StampModel stamp, bool isUnlocked) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          stamp.categoriaIcon,
          style: const TextStyle(fontSize: 40),
        ),
        const SizedBox(height: 4),
        Icon(
          Icons.location_on,
          size: 20,
          color: isUnlocked
              ? BichofueColors.verde
              : BichofueColors.gris,
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            const BichofueAvatar(size: 80, state: BichofueAvatarState.idle),
            const SizedBox(height: 20),
            Text(
              '¡Oís, ve!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Todavía no tenés estampas. Identificá monumentos con la cámara para empezar tu colección.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: BichofueColors.cafe,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return BichofueColors.verde;
    }
  }
}
