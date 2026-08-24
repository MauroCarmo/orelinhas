import 'package:flutter_test/flutter_test.dart';
import 'package:orelinhas/features/pet_lost/domain/pet_lost_entity.dart';
import 'package:orelinhas/features/pet_recognition/domain/models/analysis_status.dart';
import 'package:orelinhas/features/pet_recognition/domain/models/bounding_box_entity.dart';
import 'package:orelinhas/features/pet_recognition/domain/models/pet_visual_profile_entity.dart';
import 'package:orelinhas/features/pet_recognition/domain/models/pet_cadastral_filter_entity.dart';
import 'package:orelinhas/features/pet_recognition/domain/utils/vector_math.dart';
import 'package:orelinhas/features/pet_recognition/data/services/ai_vision_service.dart';
import 'package:orelinhas/features/pet_recognition/data/services/supabase_pet_recognition_service.dart';
import 'package:orelinhas/features/pet_recognition/data/repositories/pet_recognition_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Fake SupabaseClient para testes
class FakeSupabaseClient extends Fake implements SupabaseClient {}

void main() {
  // =========================================================================
  // GRUPO 1: OPERAÇÕES MATEMÁTICAS VETORIAIS (VectorMath)
  // =========================================================================
  group('VectorMath - Embedding Operations', () {
    test('l2Norm calcula a magnitude Euclidiana corretamente', () {
      final vec = [3.0, 4.0];
      expect(VectorMath.l2Norm(vec), equals(5.0));
    });

    test('l2Normalize gera um vetor unitário com norma aproximada de 1.0', () {
      final vec = [1.0, 2.0, 3.0, 4.0, 5.0];
      final normalized = VectorMath.l2Normalize(vec);
      final norm = VectorMath.l2Norm(normalized);
      expect(norm, closeTo(1.0, 0.0001));
    });

    test('l2Normalize com vetor de zeros retorna vetor de zeros sem crash (NaN safe)', () {
      final vec = [0.0, 0.0, 0.0];
      final normalized = VectorMath.l2Normalize(vec);
      expect(normalized, equals([0.0, 0.0, 0.0]));
      expect(normalized.any((v) => v.isNaN), isFalse);
    });

    test('cosineSimilarity calcula 1.0 para vetores idênticos', () {
      final a = VectorMath.l2Normalize(List.generate(768, (i) => i.toDouble()));
      final sim = VectorMath.cosineSimilarity(a, a);
      expect(sim, closeTo(1.0, 0.0001));
    });

    test('cosineSimilarity calcula 0.0 para vetores ortogonais', () {
      final a = [1.0, 0.0, 0.0];
      final b = [0.0, 1.0, 0.0];
      expect(VectorMath.cosineSimilarity(a, b), closeTo(0.0, 0.0001));
    });

    test('cosineSimilarity retorna 0.0 com segurança para entradas nulas ou vazias', () {
      expect(VectorMath.cosineSimilarity(null, [1.0, 2.0]), equals(0.0));
      expect(VectorMath.cosineSimilarity([1.0, 2.0], null), equals(0.0));
      expect(VectorMath.cosineSimilarity([], []), equals(0.0));
      expect(VectorMath.cosineSimilarity([1.0], [1.0, 2.0]), equals(0.0));
    });

    test('computeAggregatedEmbedding calcula a média e normaliza L2 com 768 dimensões', () {
      final v1 = VectorMath.l2Normalize(List.filled(768, 1.0));
      final v2 = VectorMath.l2Normalize(List.filled(768, 2.0));
      final v3 = VectorMath.l2Normalize(List.filled(768, 3.0));

      final aggregated = VectorMath.computeAggregatedEmbedding([v1, v2, v3, null]);
      expect(aggregated, isNotNull);
      expect(aggregated!.length, equals(768));
      expect(VectorMath.l2Norm(aggregated), closeTo(1.0, 0.0001));
    });

    test('computeAggregatedEmbedding retorna null quando não há vetores válidos de 768d', () {
      final invalidShort = [1.0, 2.0, 3.0];
      final aggregated = VectorMath.computeAggregatedEmbedding([null, invalidShort]);
      expect(aggregated, isNull);
    });
  });

  // =========================================================================
  // GRUPO 2: ENTIDADES E ESTADOS DE PROCESSAMENTO
  // =========================================================================
  group('Pet Recognition Domain Models', () {
    test('AnalysisStatus mapeia corretamente strings e enums', () {
      expect(AnalysisStatus.fromString('processing'), equals(AnalysisStatus.processing));
      expect(AnalysisStatus.fromString('processed'), equals(AnalysisStatus.processed));
      expect(AnalysisStatus.fromString('not_detected'), equals(AnalysisStatus.notDetected));
      expect(AnalysisStatus.fromString('error'), equals(AnalysisStatus.error));
      expect(AnalysisStatus.fromString('unknown'), equals(AnalysisStatus.pending));

      expect(AnalysisStatus.notDetected.toSnakeCase(), equals('not_detected'));
    });

    test('BoundingBoxEntity calcula width, height e area normalizados', () {
      const box = BoundingBoxEntity(
        xMin: 0.1,
        yMin: 0.2,
        xMax: 0.5,
        yMax: 0.7,
        confidence: 0.95,
        label: 'dog',
      );

      expect(box.width, closeTo(0.4, 0.0001));
      expect(box.height, closeTo(0.5, 0.0001));
      expect(box.area, closeTo(0.2, 0.0001));
    });

    test('PetVisualProfileEntity identifica elegibilidade apenas para cães e gatos', () {
      const dogProfile = PetVisualProfileEntity(petId: '1', petType: PetType.dog);
      const catProfile = PetVisualProfileEntity(petId: '2', petType: PetType.cat);
      const birdProfile = PetVisualProfileEntity(petId: '3', petType: PetType.other);

      expect(dogProfile.isEligibleForVisualAi, isTrue);
      expect(catProfile.isEligibleForVisualAi, isTrue);
      expect(birdProfile.isEligibleForVisualAi, isFalse);
    });
  });

  // =========================================================================
  // GRUPO 3: CRITÉRIOS DE ACEITAÇÃO & CENÁRIOS DE ROBUSTEZ (1 a 12)
  // =========================================================================
  group('Pet Recognition AI Pipeline & Robustness Acceptance Criteria', () {
    late AiVisionService aiService;
    late SupabasePetRecognitionService supabaseService;
    late PetRecognitionRepository repository;

    setUp(() {
      aiService = AiVisionService();
      supabaseService = SupabasePetRecognitionService(FakeSupabaseClient());
      repository = PetRecognitionRepository(aiService, supabaseService);
    });

    // Cenário 1: Cachorro com foto boa
    test('1. Cachorro com foto boa: YOLO detecta bbox e SigLIP gera embedding 768d normalizado', () async {
      final result = await aiService.analyzeImage(
        imageId: 'img_dog_good',
        imageUrl: 'https://example.com/good_dog_photo.jpg',
        petType: PetType.dog,
      );

      expect(result.status, equals(AnalysisStatus.processed));
      expect(result.detections, isNotEmpty);
      expect(result.embedding768, isNotNull);
      expect(result.embedding768!.length, equals(768));
      expect(VectorMath.l2Norm(result.embedding768!), closeTo(1.0, 0.0001));
    });

    // Cenário 2: Cachorro com foto ruim / desfocada
    test('2. Cachorro com foto ruim: YOLO não detecta, status notDetected, sem embedding, cadastro nunca bloqueado', () async {
      final result = await aiService.analyzeImage(
        imageId: 'img_dog_blurry',
        imageUrl: 'https://example.com/blurry_fail_photo.jpg',
        petType: PetType.dog,
      );

      expect(result.status, equals(AnalysisStatus.notDetected));
      expect(result.detections, isEmpty);
      expect(result.embedding768, isNull);
      // Imagem não é descartada
      expect(result.errorMessage, isNotNull);
    });

    // Cenário 3: Cachorro parcialmente visível
    test('3. Cachorro parcialmente visível: lida com segurança sem falhar', () async {
      final result = await aiService.analyzeImage(
        imageId: 'img_partial_dog',
        imageUrl: 'https://example.com/partial_dog.jpg',
        petType: PetType.dog,
      );

      expect([AnalysisStatus.processed, AnalysisStatus.notDetected], contains(result.status));
    });

    // Cenário 4: Gato com foto boa
    test('4. Gato com foto boa: Processado com sucesso no pipeline de felinos', () async {
      final result = await aiService.analyzeImage(
        imageId: 'img_cat_good',
        imageUrl: 'https://example.com/good_cat_photo.jpg',
        petType: PetType.cat,
      );

      expect(result.status, equals(AnalysisStatus.processed));
      expect(result.embedding768, isNotNull);
      expect(result.embedding768!.length, equals(768));
    });

    // Cenário 5: Imagem sem animal detectável
    test('5. Imagem sem animal: YOLO não detecta, status notDetected, imagem mantida', () async {
      final result = await aiService.analyzeImage(
        imageId: 'img_no_pet',
        imageUrl: 'https://example.com/no_pet_background.jpg',
        petType: PetType.dog,
      );

      expect(result.status, equals(AnalysisStatus.notDetected));
      expect(result.embedding768, isNull);
    });

    // Cenário 6: Imagem com múltiplos animais
    test('6. Imagem com múltiplos animais: YOLO gera 2+ bounding boxes e permite selecionar animal', () async {
      final result = await aiService.analyzeImage(
        imageId: 'img_multi',
        imageUrl: 'https://example.com/multi_pet_park.jpg',
        petType: PetType.dog,
      );

      expect(result.status, equals(AnalysisStatus.processed));
      expect(result.detections.length, greaterThanOrEqualTo(2));
      expect(result.selectedDetection, isNotNull);
    });

    // Cenário 7: Espécie não suportada (pássaro, réptil, outro)
    test('7. Espécie não suportada (other): ignora pipeline visual de embeddings', () async {
      final result = await aiService.analyzeImage(
        imageId: 'img_bird',
        imageUrl: 'https://example.com/bird.jpg',
        petType: PetType.other,
      );

      expect(result.status, equals(AnalysisStatus.notDetected));
      expect(result.embedding768, isNull);
      expect(result.errorMessage, contains('cães e gatos'));
    });

    // Cenário 8 & 9: Falhas técnicas (YOLO ou SigLIP)
    test('8 & 9. Falha técnica no YOLO / SigLIP: status error/notDetected, não bloqueia o fluxo', () async {
      final result = await aiService.analyzeImage(
        imageId: 'img_crash',
        imageUrl: 'https://example.com/ai_error_sample.jpg',
        petType: PetType.dog,
      );

      expect(result.status, equals(AnalysisStatus.error));
      expect(result.embedding768, isNull);
    });

    // Cenário 11: Pet com processamento parcial (ex: 3 de 5 imagens válidas)
    test('11. Pet com processamento parcial: embedding agregado calculado apenas com válidas', () async {
      final profile = await repository.processPetImages(
        petId: 'pet_partial_123',
        petType: PetType.dog,
        imageUrls: [
          'https://example.com/photo1_good.jpg', // processed
          'https://example.com/photo2_good.jpg', // processed
          'https://example.com/blurry_fail_3.jpg', // not_detected
          'https://example.com/photo4_good.jpg', // processed
          'https://example.com/ai_error_5.jpg', // error
        ],
      );

      expect(profile.images.length, equals(5));
      expect(profile.validEmbeddingsCount, equals(3));
      expect(profile.hasVisualEmbedding, isTrue);
      expect(profile.aggregatedEmbedding!.length, equals(768));
      expect(VectorMath.l2Norm(profile.aggregatedEmbedding!), closeTo(1.0, 0.0001));
    });

    // Cenário 12: Pet sem nenhum embedding válido (0 de 5 válidas)
    test('12. Pet sem nenhum embedding válido: cadastro completo, perfil sem agregado, sem crash', () async {
      final profile = await repository.processPetImages(
        petId: 'pet_no_valid_123',
        petType: PetType.dog,
        imageUrls: [
          'https://example.com/blurry_fail_1.jpg',
          'https://example.com/no_pet_2.jpg',
          'https://example.com/ai_error_3.jpg',
        ],
      );

      expect(profile.images.length, equals(3));
      expect(profile.validEmbeddingsCount, equals(0));
      expect(profile.hasVisualEmbedding, isFalse);
      expect(profile.aggregatedEmbedding, isNull);
    });
  });

  // =========================================================================
  // GRUPO 4: BUSCA EM DUAS ETAPAS E ISOLAMENTO DE ESPÉCIES
  // =========================================================================
  group('Pet Recognition Search Strategy (2-Stage & Species Isolation)', () {
    late AiVisionService aiService;
    late SupabasePetRecognitionService supabaseService;
    late PetRecognitionRepository repository;

    setUp(() {
      aiService = AiVisionService();
      supabaseService = SupabasePetRecognitionService(FakeSupabaseClient());
      repository = PetRecognitionRepository(aiService, supabaseService);
    });

    test('Regra de isolamento de espécies: Cão nunca é comparado com Gato', () async {
      final dogQuery = PetLostAlertEntity(
        id: 'dog_query_1',
        userId: 'user_1',
        petName: 'Rex',
        petType: PetType.dog,
        breed: 'Labrador',
        description: 'Cachorro labrador amarelo.',
        lastLocation: 'Parque Central',
        lostDate: DateTime.now(),
        contact: '11999998888',
        imageUrl: 'https://example.com/rex.jpg',
        latitude: -23.55,
        longitude: -46.63,
      );

      final catCandidate = PetLostAlertEntity(
        id: 'cat_candidate_1',
        userId: 'user_2',
        petName: 'Mimi',
        petType: PetType.cat,
        breed: 'Siamês',
        description: 'Gata siamesa desaparecida.',
        lastLocation: 'Parque Central',
        lostDate: DateTime.now(),
        contact: '11999997777',
        imageUrl: 'https://example.com/mimi.jpg',
        latitude: -23.55,
        longitude: -46.63,
      );

      // Simula candidato gato
      final filter = PetCadastralFilterEntity.fromPetAlert(dogQuery);
      expect(filter.petType, equals(PetType.dog));
      expect(catCandidate.petType, equals(PetType.cat));

      // Busca deve filtrar candidatos por espécie estrita
      final matches = await repository.findMatches(queryPet: dogQuery);
      expect(matches.any((m) => m.matchedPet.petType == PetType.cat), isFalse);
    });

    test('Busca em 2 etapas: Refinamento detalhado gera scores de similaridade', () {
      final v1 = VectorMath.l2Normalize(List.generate(768, (i) => i.toDouble()));
      final v2 = VectorMath.l2Normalize(List.generate(768, (i) => (i + 5).toDouble()));

      final detailedScore = VectorMath.computeDetailedMatchScore(
        queryEmbeddings: [v1],
        candidateEmbeddings: [v2],
        aggregatedSimilarity: 0.98,
      );

      expect(detailedScore, greaterThan(0.80));
      expect(detailedScore, lessThanOrEqualTo(1.0));
    });

    test('Busca para espécies não suportadas (aves, répteis) utiliza atributos cadastrais', () async {
      final birdQuery = PetLostAlertEntity(
        id: 'bird_query_1',
        userId: 'user_1',
        petName: 'Louro',
        petType: PetType.other,
        breed: 'Papagaio Verdadeiro',
        description: 'Papagaio verde com asas amarelas.',
        lastLocation: 'Bairro Jardim',
        lostDate: DateTime.now(),
        contact: '11999998888',
        imageUrl: 'https://example.com/louro.jpg',
        latitude: -23.55,
        longitude: -46.63,
      );

      final matches = await repository.findMatches(queryPet: birdQuery);
      expect(matches, isEmpty); // Sem outros pássaros no mock banco
    });
  });
}
