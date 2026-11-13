import 'package:flutter/material.dart';

import '../api.dart';

/// Exibe o modal de cadastro ou edição de veículo furtado.
///
/// Retorna `true` se o veículo foi cadastrado com sucesso (para o chamador
/// saber que precisa recarregar a lista), ou `null`/`false` se cancelado.
Future<bool?> mostrarCadastroVeiculo(
  BuildContext context, {
  Veiculo? veiculo,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _DialogoCadastroVeiculo(veiculo: veiculo),
  );
}

final _padraoPlaca = RegExp(r'^[A-Z]{3}[0-9][A-Z0-9][0-9]{2}$');

class _DialogoCadastroVeiculo extends StatefulWidget {
  const _DialogoCadastroVeiculo({this.veiculo});

  final Veiculo? veiculo;

  @override
  State<_DialogoCadastroVeiculo> createState() =>
      _DialogoCadastroVeiculoState();
}

class _DialogoCadastroVeiculoState extends State<_DialogoCadastroVeiculo> {
  final _formKey = GlobalKey<FormState>();
  final _placaCtrl = TextEditingController();
  final _marcaCtrl = TextEditingController();
  final _modeloCtrl = TextEditingController();
  final _corCtrl = TextEditingController();
  final _anoCtrl = TextEditingController();
  final _boletimCtrl = TextEditingController();
  DateTime? _dataFurto;
  String _status = 'ativo';
  bool _salvando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    final veiculo = widget.veiculo;
    if (veiculo == null) return;
    _placaCtrl.text = veiculo.placa;
    _marcaCtrl.text = veiculo.marca;
    _modeloCtrl.text = veiculo.modelo;
    _corCtrl.text = veiculo.cor;
    _anoCtrl.text = veiculo.ano.toString();
    _boletimCtrl.text = veiculo.boletim;
    _dataFurto = DateTime.tryParse(veiculo.dataFurto);
    _status = veiculo.status;
  }

  Future<void> _escolherData() async {
    final agora = DateTime.now();
    final dataInicial = _dataFurto == null || _dataFurto!.isAfter(agora)
        ? agora
        : _dataFurto!;
    final data = await showDatePicker(
      context: context,
      initialDate: dataInicial,
      firstDate: DateTime(1950),
      lastDate: agora,
    );
    if (data != null) setState(() => _dataFurto = data);
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dataFurto == null) {
      setState(() => _erro = 'Informe a data do furto');
      return;
    }
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      final veiculo = widget.veiculo;
      final placa = _placaCtrl.text.trim().toUpperCase();
      final marca = _marcaCtrl.text.trim();
      final modelo = _modeloCtrl.text.trim();
      final cor = _corCtrl.text.trim();
      final ano = int.parse(_anoCtrl.text.trim());
      final dataFurto = _dataFurto!;
      final boletim = _boletimCtrl.text.trim();
      if (veiculo == null) {
        await ApiClient.instance.cadastrarVeiculo(
          placa: placa,
          marca: marca,
          modelo: modelo,
          cor: cor,
          ano: ano,
          dataFurto: dataFurto,
          boletim: boletim,
        );
      } else {
        await ApiClient.instance.atualizarVeiculo(
          id: veiculo.id,
          placa: placa,
          marca: marca,
          modelo: modelo,
          cor: cor,
          ano: ano,
          dataFurto: dataFurto,
          boletim: boletim,
          status: _status,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on Exception catch (e) {
      setState(() => _erro = e.toString());
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  void dispose() {
    _placaCtrl.dispose();
    _marcaCtrl.dispose();
    _modeloCtrl.dispose();
    _corCtrl.dispose();
    _anoCtrl.dispose();
    _boletimCtrl.dispose();
    super.dispose();
  }

  String get _dataFormatada {
    final d = _dataFurto!;
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.veiculo == null
          ? 'Cadastrar veículo furtado'
          : 'Editar veículo monitorado'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _placaCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Placa (ex: ABC1D23)'),
                  textCapitalization: TextCapitalization.characters,
                  validator: (v) {
                    final placa = (v ?? '').trim().toUpperCase();
                    if (!_padraoPlaca.hasMatch(placa)) {
                      return 'Placa inválida';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _marcaCtrl,
                  decoration: const InputDecoration(labelText: 'Marca'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _modeloCtrl,
                  decoration: const InputDecoration(labelText: 'Modelo'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _corCtrl,
                  decoration: const InputDecoration(labelText: 'Cor'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _anoCtrl,
                  decoration: const InputDecoration(labelText: 'Ano'),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final ano = int.tryParse(v ?? '');
                    if (ano == null || ano < 1950) return 'Ano inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _boletimCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Nº do boletim de ocorrência'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_dataFurto == null
                      ? 'Data do furto'
                      : 'Furtado em $_dataFormatada'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: _escolherData,
                ),
                DropdownButtonFormField<String>(
                  value: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'ativo', child: Text('Monitorando')),
                    DropdownMenuItem(
                        value: 'recuperado', child: Text('Recuperado')),
                    DropdownMenuItem(
                        value: 'cancelado', child: Text('Encerrado')),
                  ],
                  onChanged: (valor) {
                    if (valor != null) setState(() => _status = valor);
                  },
                ),
                if (_erro != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_erro!,
                        style: const TextStyle(color: Colors.red)),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _salvando ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _salvando ? null : _salvar,
          child: _salvando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(widget.veiculo == null
                  ? 'Cadastrar'
                  : 'Salvar alterações'),
        ),
      ],
    );
  }
}
