import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:orelinhas/features/pet_lost/domain/pet_lost_entity.dart';
import 'package:orelinhas/features/pet_recognition/data/services/ai_vision_service.dart';
import 'package:orelinhas/features/pet_recognition/domain/models/analysis_status.dart';
import 'package:orelinhas/features/pet_recognition/domain/utils/vector_math.dart';

void main() {
  group('AiVisionService - Remote Contract & Robustness Tests', () {
    test('Sucesso na inferência remota: interpreta detecções e normaliza embedding 768d', () async {
      final mockEmbedding = List<double>.generate(768, (i) => (i + 1) * 0.01);
      final mockClient = MockClient((request) async {
        expect(request.url.path, equals('/analyze'));
        expect(request.method, equals('POST'));
        expect(request.headers['Authorization'], equals('Bearer test_token'));

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['pet_type'], equals('dog'));

        return http.Response(
          jsonEncode({
            'detections': [
              {
                'x_min': 0.1,
                'y_min': 0.1,
                'x_max': 0.8,
                'y_max': 0.9,
                'confidence': 0.95,
                'label': 'dog',
              }
            ],
            'embedding': mockEmbedding,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = AiVisionService(
        httpClient: mockClient,
        apiEndpoint: 'http://127.0.0.1:8000',
        authToken: 'test_token',
      );

      final result = await service.analyzeImage(
        imageId: 'img_test_1',
        imageUrl: 'https://example.com/dog.jpg',
        petType: PetType.dog,
      );

      expect(result.status, equals(AnalysisStatus.processed));
      expect(result.detections.length, equals(1));
      expect(result.detections.first.label, equals('dog'));
      expect(result.detections.first.confidence, equals(0.95));
      expect(result.embedding768, isNotNull);
      expect(result.embedding768!.length, equals(768));
      // Verifica se a normalização L2 foi aplicada
      expect(VectorMath.l2Norm(result.embedding768!), closeTo(1.0, 0.0001));
    });

    test('Remoto retorna sem detecções: status notDetected e sem embedding', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'detections': [], 'embedding': null}),
          200,
        );
      });

      final service = AiVisionService(
        httpClient: mockClient,
        apiEndpoint: 'http://127.0.0.1:8000',
      );

      final result = await service.analyzeImage(
        imageId: 'img_test_2',
        imageUrl: 'https://example.com/no_pet.jpg',
        petType: PetType.dog,
      );

      expect(result.status, equals(AnalysisStatus.notDetected));
      expect(result.detections, isEmpty);
      expect(result.embedding768, isNull);
    });

    test('Falha HTTP 500 do backend: status error, não lança exceção (tolerância a falhas)', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final service = AiVisionService(
        httpClient: mockClient,
        apiEndpoint: 'http://127.0.0.1:8000',
      );

      final result = await service.analyzeImage(
        imageId: 'img_test_3',
        imageUrl: 'https://example.com/crash.jpg',
        petType: PetType.dog,
      );

      expect(result.status, equals(AnalysisStatus.error));
      expect(result.errorMessage, contains('500'));
    });

    test('Embedding com dimensão incorreta (ex: 512 em vez de 768): descartado com segurança', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'detections': [
              {'x_min': 0.1, 'y_min': 0.1, 'x_max': 0.8, 'y_max': 0.8, 'confidence': 0.9, 'label': 'dog'}
            ],
            'embedding': List<double>.filled(512, 0.5), // Dimensão errada
          }),
          200,
        );
      });

      final service = AiVisionService(
        httpClient: mockClient,
        apiEndpoint: 'http://127.0.0.1:8000',
      );

      final result = await service.analyzeImage(
        imageId: 'img_test_4',
        imageUrl: 'https://example.com/invalid_dim.jpg',
        petType: PetType.dog,
      );

      // Como o embedding não tem 768, não considera processado
      expect(result.embedding768, isNull);
      expect(result.status, equals(AnalysisStatus.notDetected));
    });

    test('AI_VISION_ENDPOINT ausente ou vazio: retorna erro explícito sem simulação', () async {
      final service = AiVisionService(
        apiEndpoint: null, // Sem endpoint configurado e sem flag de teste
      );

      final result = await service.analyzeImage(
        imageId: 'img_no_endpoint',
        imageUrl: 'https://example.com/good_dog.jpg',
        petType: PetType.dog,
      );

      // Deve retornar erro explícito e nenhum embedding
      expect(result.status, equals(AnalysisStatus.error));
      expect(result.embedding768, isNull);
      expect(result.errorMessage, contains('AI_VISION_ENDPOINT ausente'));
    });

    test('Simulador só executa quando explicitamente permitido para teste isolado', () async {
      final service = AiVisionService(
        apiEndpoint: null,
        allowSimulationForTesting: true,
      );

      final result = await service.analyzeImage(
        imageId: 'img_simulated',
        imageUrl: 'https://example.com/good_dog.jpg',
        petType: PetType.dog,
      );

      expect(result.status, equals(AnalysisStatus.processed));
      expect(result.detections, isNotEmpty);
      expect(result.embedding768!.length, equals(768));
    });
  });
}
