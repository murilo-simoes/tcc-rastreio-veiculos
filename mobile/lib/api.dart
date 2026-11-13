/// Cliente da API REST do sistema de rastreio.
///
/// Em desenvolvimento aponta para o backend local. No emulador Android,
/// use 10.0.2.2 no lugar de 127.0.0.1.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();
  static final ApiClient instance = ApiClient();

  final http.Client _client;

  static const String baseUrl =
      String.fromEnvironment('API_URL', defaultValue: 'http://127.0.0.1:8000');

  String? _token;
  String? _perfil;
  final _veiculosPorId = <int, Veiculo>{};
  final _camerasPorId = <int, CameraInfo>{};
  DateTime? _veiculosCarregadosEm;
  DateTime? _camerasCarregadasEm;

  bool _cacheAtual(DateTime? instante) =>
      instante != null &&
      DateTime.now().difference(instante) < const Duration(minutes: 1);
  bool get autenticado => _token != null;
  bool get isAdmin => _perfil == 'administrador';

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<void> login(String email, String senha) async {
    final resp = await _client.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: _headers,
      body: jsonEncode({'email': email, 'senha': senha}),
    );
    if (resp.statusCode != 200) {
      throw ApiException('E-mail ou senha inválidos');
    }
    _token = jsonDecode(utf8.decode(resp.bodyBytes))['access_token'];

    final perfilResp =
        await _client.get(Uri.parse('$baseUrl/auth/me'), headers: _headers);
    if (perfilResp.statusCode == 200) {
      _perfil = jsonDecode(utf8.decode(perfilResp.bodyBytes))['perfil'];
    }
  }

  void logout() {
    _token = null;
    _perfil = null;
    _veiculosPorId.clear();
    _camerasPorId.clear();
    _veiculosCarregadosEm = null;
    _camerasCarregadasEm = null;
  }

  Future<Veiculo> cadastrarVeiculo({
    required String placa,
    required String marca,
    required String modelo,
    required String cor,
    required int ano,
    required DateTime dataFurto,
    required String boletim,
  }) async {
    final resp = await _client.post(
      Uri.parse('$baseUrl/veiculos-furtados'),
      headers: _headers,
      body: jsonEncode({
        'placa': placa.toUpperCase(),
        'marca': marca,
        'modelo': modelo,
        'cor': cor,
        'ano': ano,
        'data_furto': dataFurto.toIso8601String().split('T').first,
        'num_boletim_ocorrencia': boletim,
      }),
    );
    if (resp.statusCode == 201) {
      return Veiculo.fromJson(jsonDecode(utf8.decode(resp.bodyBytes)));
    }
    if (resp.statusCode == 409) {
      throw ApiException('A placa ou o número do boletim já está cadastrado');
    }
    if (resp.statusCode == 403) {
      throw ApiException('Apenas administradores podem cadastrar veículos');
    }
    throw ApiException('Erro ${resp.statusCode} ao cadastrar veículo');
  }

  Future<Veiculo> atualizarVeiculo({
    required int id,
    required String placa,
    required String marca,
    required String modelo,
    required String cor,
    required int ano,
    required DateTime dataFurto,
    required String boletim,
    required String status,
  }) async {
    final resp = await _client.patch(
      Uri.parse('$baseUrl/veiculos-furtados/$id'),
      headers: _headers,
      body: jsonEncode({
        'placa': placa.trim().toUpperCase(),
        'marca': marca.trim(),
        'modelo': modelo.trim(),
        'cor': cor.trim(),
        'ano': ano,
        'data_furto': dataFurto.toIso8601String().split('T').first,
        'num_boletim_ocorrencia': boletim.trim(),
        'status': status,
      }),
    );
    if (resp.statusCode == 200) {
      return Veiculo.fromJson(jsonDecode(utf8.decode(resp.bodyBytes)));
    }
    if (resp.statusCode == 409) {
      throw ApiException('A placa ou o número do boletim já está cadastrado');
    }
    if (resp.statusCode == 403) {
      throw ApiException('Apenas administradores podem editar veículos');
    }
    throw ApiException('Erro ${resp.statusCode} ao editar veículo');
  }

  Future<void> encerrarMonitoramento(int id) async {
    final resp = await _client.delete(
      Uri.parse('$baseUrl/veiculos-furtados/$id'),
      headers: _headers,
    );
    if (resp.statusCode == 204) return;
    if (resp.statusCode == 403) {
      throw ApiException('Apenas administradores podem encerrar o monitoramento');
    }
    throw ApiException('Erro ${resp.statusCode} ao encerrar monitoramento');
  }

  Future<List<Usuario>> listarUsuarios() async =>
      (await _getLista('/auth/usuarios'))
          .map((j) => Usuario.fromJson(j))
          .toList();

  Future<Usuario> cadastrarUsuario({
    required String nome,
    required String email,
    required String senha,
  }) async {
    final resp = await _client.post(
      Uri.parse('$baseUrl/auth/usuarios'),
      headers: _headers,
      body: jsonEncode({
        'nome': nome.trim(),
        'email': email.trim().toLowerCase(),
        'senha': senha,
        'perfil': 'operador',
      }),
    );
    if (resp.statusCode == 201) {
      return Usuario.fromJson(jsonDecode(utf8.decode(resp.bodyBytes)));
    }
    if (resp.statusCode == 409) {
      throw ApiException('Este e-mail já está cadastrado');
    }
    if (resp.statusCode == 403) {
      throw ApiException('Apenas administradores podem cadastrar usuários');
    }
    if (resp.statusCode == 422) {
      throw ApiException('Confira o e-mail e use uma senha com pelo menos 8 caracteres');
    }
    throw ApiException('Erro ${resp.statusCode} ao cadastrar usuário');
  }

  Future<List<dynamic>> _getLista(String caminho) async {
    final resp =
        await _client.get(Uri.parse('$baseUrl$caminho'), headers: _headers);
    if (resp.statusCode != 200) {
      throw ApiException('Erro ${resp.statusCode} ao consultar $caminho');
    }
    return jsonDecode(utf8.decode(resp.bodyBytes)) as List<dynamic>;
  }

  Future<List<Veiculo>> listarVeiculos() async =>
      (await _getLista('/veiculos-furtados'))
          .map((j) => Veiculo.fromJson(j))
          .toList();

  Future<List<Avistamento>> listarAvistamentos(int idVeiculo) async =>
      (await _getLista('/avistamentos?id_veiculo=$idVeiculo'))
          .map((j) => Avistamento.fromJson(j))
          .toList();

  Future<List<CameraInfo>> listarCameras() async =>
      (await _getLista('/cameras')).map((j) => CameraInfo.fromJson(j)).toList();

  Future<List<Alerta>> listarAlertas() async {
    final dados = await _getLista('/alertas');
    // O servidor pode ainda usar o contrato antigo, com apenas os IDs.
    if (dados.any((j) => j['avistamento']['veiculo'] == null) &&
        !_cacheAtual(_veiculosCarregadosEm)) {
      try {
        for (final veiculo in await listarVeiculos()) {
          _veiculosPorId[veiculo.id] = veiculo;
        }
      } catch (_) {
        // Exibe o alerta pelo ID quando o cadastro não estiver disponível.
      } finally {
        _veiculosCarregadosEm = DateTime.now();
      }
    }
    if (dados.any((j) => j['avistamento']['camera'] == null) &&
        !_cacheAtual(_camerasCarregadasEm)) {
      try {
        for (final camera in await listarCameras()) {
          _camerasPorId[camera.id] = camera;
        }
      } catch (_) {
        // Mantém a lista de alertas mesmo se a consulta de câmeras falhar.
      } finally {
        _camerasCarregadasEm = DateTime.now();
      }
    }
    return dados
        .map((j) => Alerta.fromJson(
              j,
              veiculosPorId: _veiculosPorId,
              camerasPorId: _camerasPorId,
            ))
        .toList();
  }

  Future<Rota> gerarRota(int idVeiculo) async {
    final resp = await _client.post(
      Uri.parse('$baseUrl/rotas/$idVeiculo/gerar'),
      headers: _headers,
    );
    if (resp.statusCode == 422) {
      throw ApiException(
          'São necessários pelo menos 2 avistamentos para gerar a rota');
    }
    if (resp.statusCode != 201) {
      throw ApiException('Erro ${resp.statusCode} ao gerar rota');
    }
    return Rota.fromJson(jsonDecode(utf8.decode(resp.bodyBytes)));
  }

  Future<void> marcarAlertaVisualizado(int idAlerta) async {
    final resp = await _client.patch(
      Uri.parse('$baseUrl/alertas/$idAlerta/visualizar'),
      headers: _headers,
    );
    if (resp.statusCode != 200) {
      throw ApiException('Erro ${resp.statusCode} ao confirmar alerta');
    }
  }
}

class ApiException implements Exception {
  ApiException(this.mensagem);
  final String mensagem;
  @override
  String toString() => mensagem;
}

// ── Modelos ──────────────────────────────────────────────────────────────────

class Veiculo {
  Veiculo.fromJson(Map<String, dynamic> j)
      : id = j['id_veiculo'],
        placa = j['placa'],
        marca = j['marca'],
        modelo = j['modelo'],
        cor = j['cor'],
        ano = j['ano'],
        dataFurto = j['data_furto'],
        boletim = j['num_boletim_ocorrencia'],
        status = j['status'];

  final int id;
  final String placa, marca, modelo, cor, dataFurto, boletim, status;
  final int ano;

  String get descricao => '$marca $modelo $ano — $cor';
}

class Usuario {
  Usuario.fromJson(Map<String, dynamic> j)
      : id = j['id_usuario'],
        nome = j['nome'],
        email = j['email'],
        perfil = j['perfil'],
        dataCriacao = DateTime.parse(j['data_criacao']);

  final int id;
  final String nome, email, perfil;
  final DateTime dataCriacao;
}

class Avistamento {
  Avistamento.fromJson(Map<String, dynamic> j)
      : id = j['id_avistamento'],
        idVeiculo = j['id_veiculo'],
        idCamera = j['id_camera'],
        dataHora = DateTime.parse(j['data_hora']),
        // A API serializa valores DECIMAL como string (ex.: "91.40")
        confianca = double.parse(j['confianca_leitura'].toString());

  final int id, idVeiculo, idCamera;
  final DateTime dataHora;
  final double confianca;
}

class CameraInfo {
  CameraInfo.fromJson(Map<String, dynamic> j)
      : id = j['id_camera'],
        descricao = j['descricao'],
        endereco = j['endereco'];

  final int id;
  final String descricao;
  final String? endereco;
}

class Alerta {
  Alerta.fromJson(
    Map<String, dynamic> j, {
    Map<int, Veiculo> veiculosPorId = const {},
    Map<int, CameraInfo> camerasPorId = const {},
  })  : id = j['id_alerta'],
        status = j['status'],
        dataEnvio =
            j['data_envio'] != null ? DateTime.parse(j['data_envio']) : null,
        avistamento = Avistamento.fromJson(j['avistamento']),
        veiculo = j['avistamento']['veiculo'] != null
            ? Veiculo.fromJson(j['avistamento']['veiculo'])
            : veiculosPorId[j['avistamento']['id_veiculo']],
        camera = j['avistamento']['camera'] != null
            ? CameraInfo.fromJson(j['avistamento']['camera'])
            : camerasPorId[j['avistamento']['id_camera']];

  final int id;
  final String status;
  final DateTime? dataEnvio;
  final Avistamento avistamento;
  final Veiculo? veiculo;
  final CameraInfo? camera;
}

class PontoRota {
  PontoRota.fromJson(Map<String, dynamic> j)
      : ordem = j['ordem'],
        probabilidade = double.parse(j['probabilidade'].toString()),
        latitude = double.parse(j['latitude'].toString()),
        longitude = double.parse(j['longitude'].toString()),
        camera = j['descricao_camera'],
        dataHora = DateTime.parse(j['data_hora']);

  final int ordem;
  final double probabilidade, latitude, longitude;
  final String camera;
  final DateTime dataHora;
}

class PredicaoKalman {
  PredicaoKalman.fromJson(Map<String, dynamic> j)
      : latitude = (j['latitude'] as num).toDouble(),
        longitude = (j['longitude'] as num).toDouble(),
        raioIncertezaM = (j['raio_incerteza_m'] as num).toDouble();

  final double latitude, longitude, raioIncertezaM;
}

class ZonaKde {
  ZonaKde.fromJson(Map<String, dynamic> j)
      : idCamera = j['id_camera'],
        descricao = j['descricao'],
        latitude = (j['latitude'] as num).toDouble(),
        longitude = (j['longitude'] as num).toDouble(),
        densidade = (j['densidade'] as num).toDouble();

  final int idCamera;
  final String descricao;
  final double latitude, longitude, densidade;
}

class Rota {
  Rota.fromJson(Map<String, dynamic> j)
      : placa = j['placa'],
        pontos =
            (j['pontos'] as List).map((p) => PontoRota.fromJson(p)).toList(),
        predicaoKalman = j['predicao_kalman'] != null
            ? PredicaoKalman.fromJson(j['predicao_kalman'])
            : null,
        zonasKde = ((j['zonas_kde'] ?? []) as List)
            .map((z) => ZonaKde.fromJson(z))
            .toList();

  final String placa;
  final List<PontoRota> pontos;
  final PredicaoKalman? predicaoKalman;
  final List<ZonaKde> zonasKde;
}
