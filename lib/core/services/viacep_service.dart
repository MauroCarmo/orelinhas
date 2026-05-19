import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../exceptions/app_exceptions.dart';
import '../logger/app_logger.dart';
import '../validation/sanitizers.dart';

final viaCepServiceProvider = Provider<ViaCepService>((ref) {
  return ViaCepService();
});

class ViaCepService {
  final _logger = AppLogger.category('ViaCepService');
  final HttpClient _httpClient;

  ViaCepService({HttpClient? httpClient}) : _httpClient = httpClient ?? HttpClient();

  /// Realiza a consulta assíncrona ao ViaCEP para um CEP específico.
  /// Retorna um mapa contendo os campos de endereço correspondentes ou lança uma AppException estruturada.
  Future<Map<String, String>> fetchAddress(String cep) async {
    final cleanCep = AppSanitizers.digitsOnly(cep);

    if (cleanCep.length != 8) {
      _logger.w('Tentativa de busca com CEP de tamanho inválido.', context: {'cep': cep});
      throw const ValidationException('O CEP deve conter exatamente 8 dígitos.');
    }

    final uri = Uri.parse('https://viacep.com.br/ws/$cleanCep/json/');
    _logger.i('Iniciando busca de CEP no ViaCEP.', context: {'cep': cleanCep});

    try {
      final request = await _httpClient.getUrl(uri).timeout(const Duration(seconds: 10));
      final response = await request.close().timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        _logger.e('ViaCEP retornou código HTTP inesperado.', context: {'statusCode': response.statusCode});
        throw const NetworkException('Não foi possível obter dados do endereço. Servidor indisponível.');
      }

      final responseBody = await response.transform(utf8.decoder).join();
      final data = json.decode(responseBody) as Map<String, dynamic>;

      if (data['erro'] == true || data['erro'] == 'true') {
        _logger.w('CEP inexistente na base do ViaCEP.', context: {'cep': cleanCep});
        throw const ValidationException('CEP não encontrado na base de dados.');
      }

      // Mapeia o retorno da API para os campos da nossa AddressEntity
      return {
        'street': data['logradouro'] as String? ?? '',
        'district': data['bairro'] as String? ?? '',
        'city': data['localidade'] as String? ?? '',
        'state': data['uf'] as String? ?? '',
      };
    } on SocketException catch (e, st) {
      _logger.e('Erro de conexão ao buscar CEP.', error: e, stackTrace: st, context: {'cep': cleanCep});
      throw const NetworkException('Falha de conexão. Verifique sua internet.');
    } on TimeoutException catch (e, st) {
      _logger.e('Tempo limite de resposta excedido ao buscar CEP.', error: e, stackTrace: st, context: {'cep': cleanCep});
      throw const NetworkException('Tempo de resposta excedido. O serviço do ViaCEP demorou demais.');
    } on HttpException catch (e, st) {
      _logger.e('Erro HTTP ao buscar CEP.', error: e, stackTrace: st, context: {'cep': cleanCep});
      throw const NetworkException('Falha ao obter dados do endereço. Erro no servidor de CEP.');
    } on FormatException catch (e, st) {
      _logger.e('Erro de formatação de JSON retornado pelo ViaCEP.', error: e, stackTrace: st, context: {'cep': cleanCep});
      throw const UnknownException('Resposta inválida do servidor de CEP.');
    } catch (e, st) {
      if (e is AppException) rethrow;
      _logger.e('Erro desconhecido durante busca de CEP.', error: e, stackTrace: st, context: {'cep': cleanCep});
      throw UnknownException('Erro inesperado ao consultar o CEP: $e');
    }
  }
}
