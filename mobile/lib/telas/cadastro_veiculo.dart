import 'package:flutter/material.dart';

import '../api.dart';

/// Exibe o modal de cadastro de veículo furtado.
///
/// Retorna `true` se o veículo foi cadastrado com sucesso (para o chamador
/// saber que precisa recarregar a lista), ou `null`/`false` se cancelado.
Future<bool?> mostrarCadastroVeiculo(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (_) => const _DialogoCadastroVeiculo(),
  );
}

final _padraoPlaca = RegExp(r'^[A-Z]{3}[0-9][A-Z0-9][0-9]{2}$');

class _DialogoCadastroVeiculo extends StatefulWidget {
  const _DialogoCadastroVeiculo();

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
  bool _salvando = false;
  String? _erro;

  Future<void> _escolherData() async {
    final agora = DateTime.now();
    final data = await showDatePicker(
      context: context,
      initialDate: agora,
      firstDate: DateTime(2000),
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
      await ApiClient.instance.cadastrarVeiculo(
        placa: _placaCtrl.text.trim().toUpperCase(),
        marca: _marcaCtrl.text.trim(),
        modelo: _modeloCtrl.text.trim(),
        cor: _corCtrl.text.trim(),
        ano: int.parse(_anoCtrl.text.trim()),
        dataFurto: _dataFurto!,
        boletim: _boletimCtrl.text.trim(),
      );
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
      title: const Text('Cadastrar veículo furtado'),
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
                  title: Text(
                      _dataFurto == null ? 'Data do furto' : 'Furtado em $_dataFormatada'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: _escolherData,
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
              : const Text('Salvar'),
        ),
      ],
    );
  }
}
