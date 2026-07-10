/// Cliente da API REST do sistema de rastreio.
///
/// Em desenvolvimento aponta para o backend local. No emulador Android,
/// use 10.0.2.2 no lugar de 127.0.0.1.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const String baseUrl =
      String.fromEnvironment('API_URL', defaultValue: 'http://127.0.0.1:8000');

  String? _token;
  bool get autenticado => _token != null;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<void> login(String email, String senha) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: _headers,
      body: jsonEncode({'email': email, 'senha': senha}),
    );
    if (resp.statusCode != 200) {
      throw ApiException('E-mail ou senha inválidos');
    }
    _token = jsonDecode(utf8.decode(resp.bodyBytes))['access_token'];
  }

  void logout() => _token = null;

  Future<List<dynamic>> _getLista(String caminho) async {
    final resp =
        await http.get(Uri.parse('$baseUrl$caminho'), headers: _headers);
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

  Future<List<Alerta>> listarAlertas() async =>
      (await _getLista('/alertas')).map((j) => Alerta.fromJson(j)).toList();

  Future<Rota> gerarRota(int idVeiculo) async {
    final resp = await http.post(
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
    await http.patch(
      Uri.parse('$baseUrl/alertas/$idAlerta/visualizar'),
      headers: _headers,
    );
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

class Avistamento {
  Avistamento.fromJson(Map<String, dynamic> j)
      : id = j['id_avistamento'],
        idCamera = j['id_camera'],
        dataHora = DateTime.parse(j['data_hora']),
        // A API serializa valores DECIMAL como string (ex.: "91.40")
        confianca = double.parse(j['confianca_leitura'].toString());

  final int id, idCamera;
  final DateTime dataHora;
  final double confianca;
}

class Alerta {
  Alerta.fromJson(Map<String, dynamic> j)
      : id = j['id_alerta'],
        status = j['status'],
        dataEnvio =
            j['data_envio'] != null ? DateTime.parse(j['data_envio']) : null,
        avistamento = Avistamento.fromJson(j['avistamento']);

  final int id;
  final String status;
  final DateTime? dataEnvio;
  final Avistamento avistamento;
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
        pontos = (j['pontos'] as List)
            .map((p) => PontoRota.fromJson(p))
            .toList(),
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
