import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api.dart';

class TelaUsuarios extends StatefulWidget {
  const TelaUsuarios({super.key});

  @override
  State<TelaUsuarios> createState() => _TelaUsuariosState();
}

class _TelaUsuariosState extends State<TelaUsuarios> {
  late Future<List<Usuario>> _futuro;
  final _data = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _futuro = ApiClient.instance.listarUsuarios();
  }

  Future<void> _recarregar() async {
    setState(() => _futuro = ApiClient.instance.listarUsuarios());
    await _futuro;
  }

  Future<void> _abrirCadastro() async {
    final criado = await showDialog<bool>(
      context: context,
      builder: (_) => const _DialogoCadastroUsuario(),
    );
    if (criado == true) {
      await _recarregar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuário cadastrado com perfil operador.')),
        );
      }
    }
  }

  Widget _cartao(Usuario usuario) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          leading: CircleAvatar(
            backgroundColor:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            child: Icon(Icons.person_outline,
                color: Theme.of(context).colorScheme.primary),
          ),
          title: Text(usuario.nome,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('${usuario.email}\nCadastrado em ${_data.format(usuario.dataCriacao.toLocal())}'),
          ),
          isThreeLine: true,
          trailing: Chip(
            label: Text(usuario.perfil == 'administrador' ? 'Administrador' : 'Operador'),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (!ApiClient.instance.isAdmin) {
      return const Center(child: Text('Acesso restrito a administradores.'));
    }
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirCadastro,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Cadastrar usuário'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: FutureBuilder<List<Usuario>>(
            future: _futuro,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off_outlined, size: 48),
                      const SizedBox(height: 12),
                      Text('Não foi possível consultar os usuários: ${snap.error}'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _recarregar,
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                );
              }
              final usuarios = snap.data ?? const <Usuario>[];
              return RefreshIndicator(
                onRefresh: _recarregar,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 96),
                  children: [
                    Text('ADMINISTRAÇÃO',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              letterSpacing: 1.5,
                            )),
                    const SizedBox(height: 6),
                    Text('Usuários',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 6),
                    Text('${usuarios.length} contas cadastradas'),
                    const SizedBox(height: 12),
                    const Text(
                      'As novas contas recebem perfil de operador. O acesso administrativo permanece restrito a contas autorizadas.',
                    ),
                    const SizedBox(height: 20),
                    if (usuarios.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Center(child: Text('Nenhum usuário encontrado.')),
                      )
                    else
                      for (final usuario in usuarios) _cartao(usuario),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DialogoCadastroUsuario extends StatefulWidget {
  const _DialogoCadastroUsuario();

  @override
  State<_DialogoCadastroUsuario> createState() =>
      _DialogoCadastroUsuarioState();
}

class _DialogoCadastroUsuarioState extends State<_DialogoCadastroUsuario> {
  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  bool _salvando = false;
  bool _mostrarSenha = false;
  String? _erro;

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      await ApiClient.instance.cadastrarUsuario(
        nome: _nomeCtrl.text,
        email: _emailCtrl.text,
        senha: _senhaCtrl.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on Exception catch (e) {
      if (mounted) setState(() => _erro = e.toString());
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _emailCtrl.dispose();
    _senhaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Cadastrar usuário'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _nomeCtrl,
                    decoration: const InputDecoration(labelText: 'Nome'),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(labelText: 'E-mail'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      final email = (v ?? '').trim();
                      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                        return 'Informe um e-mail válido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _senhaCtrl,
                    decoration: InputDecoration(
                      labelText: 'Senha inicial',
                      helperText: 'Use pelo menos 8 caracteres',
                      suffixIcon: IconButton(
                        tooltip: _mostrarSenha ? 'Ocultar senha' : 'Mostrar senha',
                        onPressed: () =>
                            setState(() => _mostrarSenha = !_mostrarSenha),
                        icon: Icon(_mostrarSenha
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                      ),
                    ),
                    obscureText: !_mostrarSenha,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: (v) => (v == null || v.length < 8)
                        ? 'A senha deve ter pelo menos 8 caracteres'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Perfil: Operador'),
                  ),
                  if (_erro != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_erro!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
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
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Criar conta'),
          ),
        ],
      );
}
