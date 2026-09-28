import 'package:flutter/material.dart';

import '../api.dart';
import 'inicio.dart';

class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key});

  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  bool _carregando = false;
  String? _erro;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _senhaCtrl.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      await ApiClient.instance.login(_emailCtrl.text.trim(), _senhaCtrl.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const TelaInicio()),
      );
    } on Exception catch (e) {
      if (mounted) setState(() => _erro = e.toString());
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Widget _formulario() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Acessar painel',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                const Text(
                    'Entre com sua conta para consultar veículos e alertas.'),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  autofillHints: const [AutofillHints.username],
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'Informe um e-mail válido'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _senhaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Senha',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  autofillHints: const [AutofillHints.password],
                  obscureText: true,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Informe a senha' : null,
                  onFieldSubmitted: (_) => _entrar(),
                ),
                if (_erro != null) ...[
                  const SizedBox(height: 16),
                  Text(_erro!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _carregando ? null : _entrar,
                    child: _carregando
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Entrar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _marca() {
    return Container(
      color: const Color(0xFF1A3A6B),
      padding: const EdgeInsets.all(48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.local_police_outlined,
                  size: 72, color: Colors.white),
              const SizedBox(height: 24),
              Text('Rastreio de veículos',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      )),
              const SizedBox(height: 16),
              const Text(
                'Consulte veículos monitorados e acompanhe os avistamentos registrados pelas câmeras.',
                style:
                    TextStyle(color: Colors.white70, fontSize: 18, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(builder: (context, constraints) {
        final amplo = constraints.maxWidth >= 900;
        if (amplo) {
          return Row(
            children: [
              Expanded(child: _marca()),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: _formulario(),
                  ),
                ),
              ),
            ],
          );
        }
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _formulario(),
          ),
        );
      }),
    );
  }
}
