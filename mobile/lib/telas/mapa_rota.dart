import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../api.dart';

/// Mapa (OpenStreetMap) com a rota probabilística do veículo (RF10).
///
/// Exibe as três camadas do modelo probabilístico descrito no trabalho:
/// o trajeto percorrido (Cadeia de Markov + roteamento viário OSRM),
/// a posição futura estimada (Filtro de Kalman, com raio de incerteza)
/// e as zonas com maior probabilidade de novo avistamento (KDE).

class _ItemLegenda extends StatelessWidget {
  const _ItemLegenda({required this.cor, required this.texto});
  final Color cor;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12,
            decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(texto, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
class TelaMapaRota extends StatefulWidget {
  const TelaMapaRota({super.key, required this.rota});
  final Rota rota;

  @override
  State<TelaMapaRota> createState() => _TelaMapaRotaState();
}

class _TelaMapaRotaState extends State<TelaMapaRota> {
  List<LatLng>? _tracado;

  /// Pontos das câmeras sem repetições consecutivas (avistamentos seguidos
  /// na mesma câmera não alteram o trajeto).
  List<LatLng> get _paradas {
    final pontos = <LatLng>[];
    for (final p in widget.rota.pontos) {
      final atual = LatLng(p.latitude, p.longitude);
      if (pontos.isEmpty || pontos.last != atual) pontos.add(atual);
    }
    return pontos;
  }

  @override
  void initState() {
    super.initState();
    _buscarTracado();
  }

  Future<void> _buscarTracado() async {
    final paradas = _paradas;
    if (paradas.length < 2) {
      setState(() => _tracado = paradas);
      return;
    }
    try {
      final coords = paradas
          .map((p) => '${p.longitude},${p.latitude}')
          .join(';');
      final resp = await http
          .get(Uri.parse(
              'https://router.project-osrm.org/route/v1/driving/$coords'
              '?overview=full&geometries=geojson'))
          .timeout(const Duration(seconds: 8));
      final geometria = jsonDecode(resp.body)['routes'][0]['geometry']
          ['coordinates'] as List;
      setState(() => _tracado = geometria
          .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList());
    } catch (_) {
      // OSRM indisponível: liga as câmeras por retas
      setState(() => _tracado = paradas);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rota = widget.rota;
    final fmt = DateFormat('dd/MM HH:mm');
    final paradas = _paradas;

    final opcoes = paradas.length > 1
        ? MapOptions(
            initialCameraFit: CameraFit.coordinates(
              coordinates: paradas,
              padding: const EdgeInsets.all(60),
              maxZoom: 16,
            ),
          )
        : MapOptions(initialCenter: paradas.first, initialZoom: 15);

    return Scaffold(
      appBar: AppBar(
        title: Text('Rota provável — ${rota.placa}'),
        backgroundColor: const Color(0xFF1A3A6B),
        foregroundColor: Colors.white,
      ),
      body: FlutterMap(
        options: opcoes,
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'br.edu.tcc.rastreio_veiculos',
          ),
          // Zonas KDE: regiões com maior probabilidade de novo avistamento
          CircleLayer(
            circles: [
              for (final z in rota.zonasKde)
                if (z.densidade > 0.05)
                  CircleMarker(
                    point: LatLng(z.latitude, z.longitude),
                    radius: 400 + 500 * z.densidade,
                    useRadiusInMeter: true,
                    color: Colors.orange.withValues(alpha: 0.12 + 0.18 * z.densidade),
                    borderColor: Colors.orange.withValues(alpha: 0.5),
                    borderStrokeWidth: 1,
                  ),
              // Área de incerteza da predição de Kalman
              if (rota.predicaoKalman != null)
                CircleMarker(
                  point: LatLng(rota.predicaoKalman!.latitude,
                      rota.predicaoKalman!.longitude),
                  radius: rota.predicaoKalman!.raioIncertezaM,
                  useRadiusInMeter: true,
                  color: Colors.purple.withValues(alpha: 0.10),
                  borderColor: Colors.purple.withValues(alpha: 0.6),
                  borderStrokeWidth: 2,
                ),
            ],
          ),
          if (_tracado == null)
            const Center(child: CircularProgressIndicator())
          else
            PolylineLayer(
              polylines: [
                Polyline(
                  points: _tracado!,
                  strokeWidth: 4,
                  color: Colors.red.withValues(alpha: 0.8),
                ),
                // Ligação tracejada até a posição futura prevista (Kalman)
                if (rota.predicaoKalman != null)
                  Polyline(
                    points: [
                      LatLng(rota.pontos.last.latitude,
                          rota.pontos.last.longitude),
                      LatLng(rota.predicaoKalman!.latitude,
                          rota.predicaoKalman!.longitude),
                    ],
                    strokeWidth: 3,
                    color: Colors.purple.withValues(alpha: 0.7),
                    pattern: const StrokePattern.dotted(),
                  ),
              ],
            ),
          MarkerLayer(
            markers: [
              // Posição futura estimada pelo Filtro de Kalman
              if (rota.predicaoKalman != null)
                Marker(
                  point: LatLng(rota.predicaoKalman!.latitude,
                      rota.predicaoKalman!.longitude),
                  width: 46,
                  height: 46,
                  child: Tooltip(
                    message: 'Posição futura estimada (Kalman)\n'
                        'Incerteza: ±${(rota.predicaoKalman!.raioIncertezaM / 1000).toStringAsFixed(1)} km',
                    child: const CircleAvatar(
                      backgroundColor: Colors.purple,
                      child: Icon(Icons.question_mark,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ),
              for (final p in rota.pontos)
                Marker(
                  point: LatLng(p.latitude, p.longitude),
                  width: 46,
                  height: 46,
                  child: Tooltip(
                    message: '${p.ordem}. ${p.camera}\n'
                        '${fmt.format(p.dataHora)} — '
                        '${p.probabilidade.toStringAsFixed(0)}%',
                    child: CircleAvatar(
                      backgroundColor:
                          p.ordem == rota.pontos.length
                              ? Colors.red
                              : const Color(0xFF1A3A6B),
                      child: Text('${p.ordem}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Último avistamento: ${rota.pontos.last.camera} '
                'às ${fmt.format(rota.pontos.last.dataHora)}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Wrap(
                spacing: 16,
                alignment: WrapAlignment.center,
                children: [
                  _ItemLegenda(cor: Colors.red, texto: 'Trajeto percorrido'),
                  _ItemLegenda(
                      cor: Colors.purple,
                      texto: 'Posição futura (Kalman)'),
                  _ItemLegenda(
                      cor: Colors.orange, texto: 'Zona provável (KDE)'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
