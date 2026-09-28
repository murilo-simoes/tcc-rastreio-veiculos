import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rastreio_veiculos/api.dart';

void main() {
  final veiculoJson = <String, dynamic>{
    'id_veiculo': 7,
    'placa': 'ABC1D23',
    'marca': 'Volkswagen',
    'modelo': 'Gol',
    'cor': 'Prata',
    'ano': 2019,
    'data_furto': '2026-06-15',
    'num_boletim_ocorrencia': 'BO-TESTE',
    'status': 'ativo',
  };
  final cameraJson = <String, dynamic>{
    'id_camera': 3,
    'descricao': 'Câmera da Avenida Paulista',
    'endereco': 'Avenida Paulista, 1500',
  };
  final avistamento = <String, dynamic>{
    'id_avistamento': 10,
    'id_veiculo': 7,
    'id_camera': 3,
    'data_hora': '2026-09-28T19:20:00',
    'confianca_leitura': '91.50',
  };

  Map<String, dynamic> alerta(Map<String, dynamic> dadosAvistamento) => {
        'id_alerta': 4,
        'status': 'enviado',
        'data_envio': '2026-09-28T19:20:02',
        'avistamento': dadosAvistamento,
      };

  test('aceita veículo e câmera aninhados na API nova', () {
    final dados = {
      ...avistamento,
      'veiculo': veiculoJson,
      'camera': cameraJson
    };
    final resultado = Alerta.fromJson(alerta(dados));
    expect(resultado.veiculo?.placa, 'ABC1D23');
    expect(resultado.camera?.descricao, 'Câmera da Avenida Paulista');
  });

  test('completa IDs do contrato antigo com cadastros separados', () {
    final resultado = Alerta.fromJson(
      alerta(avistamento),
      veiculosPorId: {7: Veiculo.fromJson(veiculoJson)},
      camerasPorId: {3: CameraInfo.fromJson(cameraJson)},
    );
    expect(resultado.veiculo?.placa, 'ABC1D23');
    expect(resultado.camera?.endereco, 'Avenida Paulista, 1500');
  });

  test('contrato antigo sem cadastro disponível mantém o alerta', () {
    final resultado = Alerta.fromJson(alerta(avistamento));
    expect(resultado.avistamento.idVeiculo, 7);
    expect(resultado.avistamento.idCamera, 3);
    expect(resultado.veiculo, isNull);
    expect(resultado.camera, isNull);
  });

  test('consulta API antiga e resolve veículo e câmera pelos IDs', () async {
    final chamadas = <String, int>{};
    final client = MockClient((request) async {
      final caminho = request.url.path;
      chamadas[caminho] = (chamadas[caminho] ?? 0) + 1;
      final Object dados;
      switch (caminho) {
        case '/auth/login':
          dados = {'access_token': 'token-teste'};
        case '/auth/me':
          dados = {'perfil': 'administrador'};
        case '/alertas':
          dados = [alerta(avistamento)];
        case '/veiculos-furtados':
          dados = [veiculoJson];
        case '/cameras':
          dados = [cameraJson];
        default:
          throw StateError('Rota inesperada: $caminho');
      }
      return http.Response(jsonEncode(dados), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });
    final api = ApiClient(client: client);
    await api.login('teste@exemplo.com', 'senha');
    final alertas = await api.listarAlertas();
    expect(alertas.single.veiculo?.placa, 'ABC1D23');
    expect(alertas.single.camera?.descricao, 'Câmera da Avenida Paulista');
    await api.listarAlertas();
    expect(chamadas['/veiculos-furtados'], 1);
    expect(chamadas['/cameras'], 1);
    client.close();
  });
}
