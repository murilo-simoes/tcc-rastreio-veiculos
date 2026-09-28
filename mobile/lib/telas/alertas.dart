import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api.dart';
import 'detalhe_veiculo.dart';

/// Alertas consultados periodicamente enquanto a tela estiver aberta.
class TelaAlertas extends StatefulWidget {
  const TelaAlertas({super.key});

  @override
  State<TelaAlertas> createState() => _TelaAlertasState();
}

class _TelaAlertasState extends State<TelaAlertas> {
  List<Alerta>? _alertas;
  String? _erro;
  Timer? _timer;
  bool _atualizando = false;
  bool _somenteNovos = false;
  int? _confirmandoId;
  final _fmt = DateFormat('dd/MM/yyyy, HH:mm');

  @override
  void initState() {
    super.initState();
    _carregar();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _carregar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _carregar() async {
    if (_atualizando) return;
    setState(() => _atualizando = true);
    try {
      final alertas = await ApiClient.instance.listarAlertas();
      if (!mounted) return;
      setState(() {
        _alertas = alertas;
        _erro = null;
      });
    } catch (e) {
      if (mounted) setState(() => _erro = e.toString());
    } finally {
      if (mounted) setState(() => _atualizando = false);
    }
  }

  Future<void> _visualizar(Alerta alerta) async {
    if (_confirmandoId != null) return;
    setState(() => _confirmandoId = alerta.id);
    try {
      await ApiClient.instance.marcarAlertaVisualizado(alerta.id);
      await _carregar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível confirmar o alerta: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _confirmandoId = null);
    }
  }

  Widget _indicador(String rotulo, String valor, IconData icone, Color cor) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icone, color: cor, size: 25),
              const SizedBox(height: 8),
              Text(valor, style: Theme.of(context).textTheme.headlineSmall),
              Text(rotulo, maxLines: 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _info(IconData icone, String texto) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icone, size: 17, color: Colors.blueGrey.shade600),
        const SizedBox(width: 5),
        Flexible(child: Text(texto)),
      ],
    );
  }

  Widget _cartaoAlerta(Alerta alerta, bool compacto) {
    final novo = alerta.status != 'visualizado';
    final cor = novo ? const Color(0xFFB42318) : const Color(0xFF20815A);
    final camera = alerta.camera;
    final carro = alerta.veiculo;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: cor, width: 5)),
        ),
        child: Padding(
          padding: EdgeInsets.all(compacto ? 16 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                      carro?.placa ??
                          'Veículo #${alerta.avistamento.idVeiculo}',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              )),
                  Chip(
                    avatar: Icon(
                        novo
                            ? Icons.notification_important_outlined
                            : Icons.check_circle_outline,
                        size: 18,
                        color: cor),
                    label: Text(novo ? 'Novo avistamento' : 'Visualizado'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(carro?.descricao ?? 'Dados do veículo indisponíveis',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 14),
              Wrap(
                spacing: 20,
                runSpacing: 10,
                children: [
                  _info(
                      Icons.videocam_outlined,
                      camera?.descricao ??
                          'Câmera ${alerta.avistamento.idCamera}'),
                  _info(
                      Icons.schedule, _fmt.format(alerta.avistamento.dataHora)),
                  _info(Icons.fact_check_outlined,
                      'Leitura ${alerta.avistamento.confianca.toStringAsFixed(0)}%'),
                ],
              ),
              if (camera?.endereco?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                _info(Icons.location_on_outlined, camera!.endereco!),
              ],
              const Divider(height: 28),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: carro == null
                        ? null
                        : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    TelaDetalheVeiculo(veiculo: carro),
                              ),
                            ),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Ver veículo'),
                  ),
                  if (novo)
                    FilledButton.tonalIcon(
                      onPressed: _confirmandoId == null
                          ? () => _visualizar(alerta)
                          : null,
                      icon: _confirmandoId == alerta.id
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.done, size: 18),
                      label: const Text('Marcar como visualizado'),
                    ),
                  Text('Alerta #${alerta.id}',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final compacto = constraints.maxWidth < 650;
      final alertas = _alertas;
      if (alertas == null && _erro == null) {
        return const Center(child: CircularProgressIndicator());
      }
      if (alertas == null) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 48),
              const SizedBox(height: 12),
              Text(_erro ?? 'Não foi possível carregar os alertas.'),
              const SizedBox(height: 12),
              FilledButton(
                  onPressed: _carregar, child: const Text('Tentar novamente')),
            ],
          ),
        );
      }
      final novos = alertas.where((a) => a.status != 'visualizado').length;
      final visiveis = _somenteNovos
          ? alertas.where((a) => a.status != 'visualizado').toList()
          : alertas;
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: RefreshIndicator(
            onRefresh: _carregar,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(compacto ? 12 : 24),
              itemCount: visiveis.length + 1,
              itemBuilder: (context, index) {
                if (index > 0) {
                  return _cartaoAlerta(visiveis[index - 1], compacto);
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MONITORAMENTO',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  letterSpacing: 1.5,
                                )),
                    const SizedBox(height: 6),
                    Text('Alertas de detecção',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 6),
                    const Text(
                        'Veículos identificados pelas câmeras cadastradas.'),
                    const SizedBox(height: 16),
                    Row(children: [
                      _indicador(
                          'Total',
                          '${alertas.length}',
                          Icons.notifications_outlined,
                          const Color(0xFF1A3A6B)),
                      _indicador(
                          'Não visualizados',
                          '$novos',
                          Icons.warning_amber_outlined,
                          const Color(0xFFB42318)),
                    ]),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ChoiceChip(
                          label: Text('Todos (${alertas.length})'),
                          selected: !_somenteNovos,
                          onSelected: (_) =>
                              setState(() => _somenteNovos = false),
                        ),
                        ChoiceChip(
                          label: Text('Não visualizados ($novos)'),
                          selected: _somenteNovos,
                          onSelected: (_) =>
                              setState(() => _somenteNovos = true),
                        ),
                        IconButton(
                          onPressed: _atualizando ? null : _carregar,
                          tooltip: 'Atualizar alertas',
                          icon: _atualizando
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                    if (_erro != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('Falha na atualização: $_erro',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                      ),
                    const SizedBox(height: 12),
                    if (visiveis.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Center(
                          child: Text(_somenteNovos
                              ? 'Nenhum alerta aguardando visualização.'
                              : 'Nenhum alerta registrado.'),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    });
  }
}
