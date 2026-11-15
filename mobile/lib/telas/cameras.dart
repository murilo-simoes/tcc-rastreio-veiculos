import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../api.dart';

class TelaCameras extends StatefulWidget {
  const TelaCameras({super.key});

  @override
  State<TelaCameras> createState() => _TelaCamerasState();
}

class _TelaCamerasState extends State<TelaCameras> {
  List<CameraInfo> _cameras = [];
  final Map<int, Uint8List> _quadros = {};
  final Map<int, String> _status = {};
  Timer? _timer;
  bool _carregando = true;
  bool _atualizando = false;

  @override
  void initState() {
    super.initState();
    _carregarCameras();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _atualizar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _carregarCameras() async {
    try {
      final cameras = await ApiClient.instance.listarCameras();
      if (!mounted) return;
      setState(() {
        _cameras = cameras;
        _carregando = false;
      });
      await _atualizar();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status[-1] = e.toString();
        _carregando = false;
      });
    }
  }

  Future<void> _atualizar() async {
    if (_atualizando || _cameras.isEmpty) return;
    _atualizando = true;
    await Future.wait(_cameras.map((camera) async {
      try {
        final bytes = await ApiClient.instance.buscarPreviaCamera(camera.id);
        if (mounted) {
          setState(() {
            _quadros[camera.id] = bytes;
            _status.remove(camera.id);
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _status[camera.id] = e.toString());
        }
      }
    }));
    _atualizando = false;
  }

  Widget _cartao(CameraInfo camera) {
    final quadro = _quadros[camera.id];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: quadro == null
                ? ColoredBox(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.videocam_off_outlined, size: 36),
                          const SizedBox(height: 8),
                          Text(_status[camera.id] ?? 'Aguardando sinal do Pi'),
                        ],
                      ),
                    ),
                  )
                : Image.memory(quadro, fit: BoxFit.cover, gaplessPlayback: true),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(camera.descricao,
                    style: Theme.of(context).textTheme.titleMedium),
                if (camera.endereco != null) ...[
                  const SizedBox(height: 4),
                  Text(camera.endereco!),
                ],
                const SizedBox(height: 6),
                Text(quadro == null
                    ? (_status[camera.id] ?? 'Conectando…')
                    : 'Imagem recebida do Pi'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) return const Center(child: CircularProgressIndicator());
    if (_cameras.isEmpty) {
      return Center(child: Text(_status[-1] ?? 'Nenhuma câmera cadastrada'));
    }
    return LayoutBuilder(builder: (context, constraints) {
      final colunas = constraints.maxWidth >= 1100
          ? 3
          : constraints.maxWidth >= 650
              ? 2
              : 1;
      return RefreshIndicator(
        onRefresh: _atualizar,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Prévia para testes. As imagens são atualizadas pelo Pi em intervalos de alguns segundos e não ficam armazenadas.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Atualizar agora',
                      onPressed: _atualizar,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: colunas,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: colunas == 1 ? 1.35 : 0.95,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: _cameras.map(_cartao).toList(),
            ),
          ],
        ),
      );
    });
  }
}
