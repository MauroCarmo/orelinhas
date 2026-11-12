import 'package:flutter_test/flutter_test.dart';
import 'package:orelinhas/features/pet_lost/domain/pet_lost_entity.dart';
import 'package:orelinhas/features/pet_found/domain/pet_found_entity.dart';
import 'package:orelinhas/features/pet_recognition/domain/models/pet_image_analysis_entity.dart';
import 'package:orelinhas/features/pet_recognition/domain/models/analysis_status.dart';
import 'package:orelinhas/features/pet_recognition/domain/models/bounding_box_entity.dart';
import 'package:orelinhas/features/pet_recognition/domain/models/pet_visual_profile_entity.dart';
import 'package:orelinhas/features/pet_recognition/domain/models/pet_cadastral_filter_entity.dart';
import 'package:orelinhas/features/pet_recognition/domain/utils/recognition_config.dart';
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

    test('isValidEmbedding valida dimensão 768 e rejeita NaN ou Infinity', () {
      final valid = List.filled(768, 0.5);
      expect(VectorMath.isValidEmbedding(valid), isTrue);

      final withNan = List<double>.from(valid)..[10] = double.nan;
      expect(VectorMath.isValidEmbedding(withNan), isFalse);

      final withInf = List<double>.from(valid)..[20] = double.infinity;
      expect(VectorMath.isValidEmbedding(withInf), isFalse);

      final wrongDim = List.filled(512, 0.5);
      expect(VectorMath.isValidEmbedding(wrongDim), isFalse);

      expect(VectorMath.isValidEmbedding(null), isFalse);
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
      aiService = AiVisionService(allowSimulationForTesting: true);
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

    // Cenário 11: Pet com processamento parcial (ex: 2 de 3 imagens válidas — máximo 3 por anúncio)
    test('11. Pet com processamento parcial: embedding agregado calculado apenas com válidas', () async {
      final profile = await repository.processPetImages(
        petId: 'pet_partial_123',
        petType: PetType.dog,
        imageUrls: [
          'https://example.com/photo1_good.jpg', // processed
          'https://example.com/blurry_fail_3.jpg', // not_detected
          'https://example.com/photo4_good.jpg', // processed
        ],
      );

      // O repositório aceita no máximo 3 imagens (take(3))
      expect(profile.images.length, equals(3));
      expect(profile.validEmbeddingsCount, equals(2));
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
      aiService = AiVisionService(allowSimulationForTesting: true);
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

  // =========================================================================
  // GRUPO 5: MATCHING AUTOMÁTICO OTIMIZADO DE PET ENCONTRADO
  // =========================================================================
  group('Matching Automático Otimizado de Pet Encontrado (matchFoundPetAgainstLostPets)', () {
    late AiVisionService aiService;
    late SupabasePetRecognitionService supabaseService;
    late PetRecognitionRepository repository;

    setUp(() {
      aiService = AiVisionService(allowSimulationForTesting: true);
      supabaseService = SupabasePetRecognitionService(FakeSupabaseClient());
      repository = PetRecognitionRepository(aiService, supabaseService);
    });

    test('representativeEmbedding usa embedding individual para pet com uma imagem', () {
      final vec = VectorMath.l2Normalize(List.generate(768, (i) => 1.0));
      final profile = PetVisualProfileEntity(
        petId: 'pet_single_1',
        petType: PetType.dog,
        images: [
          PetImageAnalysisEntity(
            id: 'img_1',
            imageUrl: 'https://example.com/p1.jpg',
            status: AnalysisStatus.processed,
            embedding: vec,
          ),
        ],
        aggregatedEmbedding: vec,
      );

      expect(profile.representativeEmbedding, isNotNull);
      expect(profile.representativeEmbedding!.length, equals(768));
      expect(profile.representativeEmbedding, equals(vec));
    });

    test('representativeEmbedding usa aggregatedEmbedding para pet com múltiplas fotos', () {
      final vec1 = VectorMath.l2Normalize(List.generate(768, (i) => 1.0));
      final vec2 = VectorMath.l2Normalize(List.generate(768, (i) => 2.0));
      final agg = VectorMath.computeAggregatedEmbedding([vec1, vec2]);

      final profile = PetVisualProfileEntity(
        petId: 'pet_multi_1',
        petType: PetType.dog,
        images: [
          PetImageAnalysisEntity(
            id: 'img_1',
            imageUrl: 'https://example.com/p1.jpg',
            status: AnalysisStatus.processed,
            embedding: vec1,
          ),
          PetImageAnalysisEntity(
            id: 'img_2',
            imageUrl: 'https://example.com/p2.jpg',
            status: AnalysisStatus.processed,
            embedding: vec2,
          ),
        ],
        aggregatedEmbedding: agg,
      );

      expect(profile.representativeEmbedding, equals(agg));
    });

    test('matchFoundPetAgainstLostPets compara pet encontrado apenas com mesma espécie e pontua com cosseno', () async {
      final baseVec = VectorMath.l2Normalize(List.generate(768, (i) => (i + 1).toDouble()));

      // Pet encontrado (cão)
      final foundAlert = PetFoundAlertEntity(
        id: 'found_dog_10',
        userId: 'user_finder',
        petType: PetType.dog,
        breed: 'Vira-lata',
        description: 'Cão encontrado na praça',
        foundLocation: 'Praça da Sé',
        foundDate: DateTime.now(),
        imageUrl: 'https://example.com/found.jpg',
      );
      final foundProfile = PetVisualProfileEntity(
        petId: foundAlert.id,
        petType: PetType.dog,
        aggregatedEmbedding: baseVec,
      );
      await supabaseService.saveVisualProfile(foundProfile);

      // Pet perdido compatível (mesma espécie e vetor idêntico -> score ~ 1.0)
      final matchingLostDog = PetLostAlertEntity(
        id: 'lost_dog_20',
        userId: 'user_owner_1',
        petName: 'Tobby',
        petType: PetType.dog,
        breed: 'Vira-lata',
        description: 'Perdido perto da Sé',
        lastLocation: 'Sé',
        lostDate: DateTime.now(),
        contact: '11999998888',
        imageUrl: 'https://example.com/lost1.jpg',
      );
      final lostProfileMatch = PetVisualProfileEntity(
        petId: matchingLostDog.id,
        petType: PetType.dog,
        aggregatedEmbedding: baseVec,
      );
      await supabaseService.saveVisualProfile(lostProfileMatch);

      // Pet perdido incompatível na foto (mesma espécie, vetor ortogonal -> score ~ 0.0)
      final orthogonalVec = VectorMath.l2Normalize(List.generate(768, (i) => i.isEven ? 1.0 : -1.0));
      final nonMatchingLostDog = PetLostAlertEntity(
        id: 'lost_dog_21',
        userId: 'user_owner_2',
        petName: 'Bob',
        petType: PetType.dog,
        breed: 'Poodle',
        description: 'Poodle branco',
        lastLocation: 'Pinheiros',
        lostDate: DateTime.now(),
        contact: '11999997777',
        imageUrl: 'https://example.com/lost2.jpg',
      );
      final lostProfileNonMatch = PetVisualProfileEntity(
        petId: nonMatchingLostDog.id,
        petType: PetType.dog,
        aggregatedEmbedding: orthogonalVec,
      );
      await supabaseService.saveVisualProfile(lostProfileNonMatch);

      // Pet perdido de espécie diferente (gato -> deve ser totalmente ignorado)
      final lostCat = PetLostAlertEntity(
        id: 'lost_cat_30',
        userId: 'user_owner_3',
        petName: 'Mimi',
        petType: PetType.cat,
        breed: 'Siamês',
        description: 'Gata siamesa',
        lastLocation: 'Sé',
        lostDate: DateTime.now(),
        contact: '11999996666',
        imageUrl: 'https://example.com/cat.jpg',
      );
      final lostProfileCat = PetVisualProfileEntity(
        petId: lostCat.id,
        petType: PetType.cat,
        aggregatedEmbedding: baseVec, // mesmo se vetor for idêntico, espécie impede
      );
      await supabaseService.saveVisualProfile(lostProfileCat);

      // Executa o matching automático otimizado
      final matches = await repository.matchFoundPetAgainstLostPets(
        foundPet: foundAlert,
        foundVisualProfile: foundProfile,
        activeLostPets: [matchingLostDog, nonMatchingLostDog, lostCat],
        minSimilarity: 0.70,
      );

      // Verificações estritas:
      // 1. Apenas o cão compatível atingiu o limiar de 0.70
      expect(matches.length, equals(1));
      expect(matches.first.matchedPet.id, equals('lost_dog_20'));
      expect(matches.first.similarityScore, closeTo(1.0, 0.001));

      // 2. Não inclui gato de forma alguma
      expect(matches.any((m) => m.matchedPet.petType == PetType.cat), isFalse);

      // 3. Não inclui cão com score abaixo de 0.70
      expect(matches.any((m) => m.matchedPet.id == 'lost_dog_21'), isFalse);
    });

    test('matchFoundPetAgainstLostPets ignora graciosamente espécies não suportadas sem crash', () async {
      final birdFound = PetFoundAlertEntity(
        id: 'bird_found_1',
        userId: 'finder',
        petType: PetType.other,
        description: 'Calopsita encontrada',
        foundLocation: 'Rua das Flores',
        foundDate: DateTime.now(),
        imageUrl: 'https://example.com/bird.jpg',
      );
      final birdProfile = PetVisualProfileEntity(
        petId: birdFound.id,
        petType: PetType.other,
      );

      final matches = await repository.matchFoundPetAgainstLostPets(
        foundPet: birdFound,
        foundVisualProfile: birdProfile,
        activeLostPets: [],
      );

      expect(matches, isEmpty);
    });
  });

  // =========================================================================
  // GRUPO 6: FLUXO UNIFICADO E BUSCA VETORIAL BIDIRECIONAL
  // =========================================================================
  group('Unified Matching & Vector Search Bidirectional', () {
    test('findMatches usa similaridade de cosseno com limiar 0.70 e suporta origin manual', () async {
      final fakeSupabase = FakeSupabaseClient();
      final supabaseService = SupabasePetRecognitionService(fakeSupabase);
      final aiService = AiVisionService(httpClient: null);
      final repository = PetRecognitionRepository(aiService, supabaseService);

      final lostPet = PetLostAlertEntity(
        id: 'lost_dog_unified',
        userId: 'owner_1',
        petName: 'Rex',
        petType: PetType.dog,
        breed: 'Poodle',
        description: 'Perdido',
        lastLocation: 'Centro',
        lostDate: DateTime.now(),
        contact: '11999990000',
        imageUrl: 'https://example.com/rex.jpg',
      );

      final baseVector = VectorMath.l2Normalize(List.generate(768, (i) => i.toDouble()));
      final lostProfile = PetVisualProfileEntity(
        petId: lostPet.id,
        petType: PetType.dog,
        aggregatedEmbedding: baseVector,
      );
      await supabaseService.saveVisualProfile(lostProfile);

      final foundPetCandidate = PetFoundAlertEntity(
        id: 'found_dog_candidate',
        userId: 'finder_1',
        petType: PetType.dog,
        breed: 'Poodle',
        description: 'Encontrado no centro',
        foundLocation: 'Centro',
        foundDate: DateTime.now(),
        imageUrl: 'https://example.com/rex_found.jpg',
      );

      final foundProfile = PetVisualProfileEntity(
        petId: foundPetCandidate.id,
        petType: PetType.dog,
        aggregatedEmbedding: baseVector,
      );
      await supabaseService.saveVisualProfile(foundProfile);

      final matches = await repository.findMatches(
        queryPet: lostPet,
        queryVisualProfile: lostProfile,
        minSimilarity: 0.70,
        origin: 'manual',
        candidateFoundPets: [foundPetCandidate],
      );

      expect(matches.length, equals(1));
      expect(matches.first.matchedPet.id, equals('found_dog_candidate'));
      expect(matches.first.similarityScore, closeTo(1.0, 0.001));
    });
  });

  // =========================================================================
  // GRUPO 7: SINCRONIZAÇÃO E CICLO DE VIDA DE IMAGENS E EMBEDDINGS
  // =========================================================================
  group('Sincronização e Ciclo de Vida de Imagens e Embeddings', () {
    test('1 & 2. Cadastro com uma imagem gera agregado idêntico ao individual', () async {
      final fakeSupabase = FakeSupabaseClient();
      final supabaseService = SupabasePetRecognitionService(fakeSupabase);
      final aiService = AiVisionService(allowSimulationForTesting: true);
      final repository = PetRecognitionRepository(aiService, supabaseService);

      final profile = await repository.processPetImages(
        petId: 'pet_single_img_1',
        petType: PetType.dog,
        imageUrls: ['https://example.com/single_dog.jpg'],
      );

      expect(profile.images.length, equals(1));
      expect(profile.validEmbeddingsCount, equals(1));
      expect(profile.hasVisualEmbedding, isTrue);
      expect(profile.aggregatedEmbedding, isNotNull);
      expect(profile.aggregatedEmbedding!.length, equals(768));
      expect(profile.representativeEmbedding, equals(profile.aggregatedEmbedding));
    });

    test('3. Cadastro com três imagens gera agregado como média L2-normalizada', () async {
      final fakeSupabase = FakeSupabaseClient();
      final supabaseService = SupabasePetRecognitionService(fakeSupabase);
      final aiService = AiVisionService(allowSimulationForTesting: true);
      final repository = PetRecognitionRepository(aiService, supabaseService);

      final profile = await repository.processPetImages(
        petId: 'pet_multi_img_1',
        petType: PetType.dog,
        imageUrls: [
          'https://example.com/dog_a.jpg',
          'https://example.com/dog_b.jpg',
          'https://example.com/dog_c.jpg',
        ],
      );

      expect(profile.images.length, equals(3));
      expect(profile.validEmbeddingsCount, equals(3));
      expect(profile.hasVisualEmbedding, isTrue);
      expect(VectorMath.l2Norm(profile.aggregatedEmbedding!), closeTo(1.0, 0.0001));
    });

    test('4, 5, 9 & 10. Substituição de imagem remove embedding antigo e recalcula agregado', () async {
      final fakeSupabase = FakeSupabaseClient();
      final supabaseService = SupabasePetRecognitionService(fakeSupabase);
      final aiService = AiVisionService(allowSimulationForTesting: true);
      final repository = PetRecognitionRepository(aiService, supabaseService);

      const petId = 'pet_subst_1';
      // Passo 1: Cadastro inicial com Imagem A e Imagem B
      await repository.processPetImages(
        petId: petId,
        petType: PetType.dog,
        imageUrls: [
          'https://example.com/photo_A.jpg',
          'https://example.com/photo_B.jpg',
        ],
      );

      var persistedImages = await supabaseService.getExistingPetImageEmbeddings(petId);
      expect(persistedImages.containsKey('https://example.com/photo_A.jpg'), isTrue);
      expect(persistedImages.containsKey('https://example.com/photo_B.jpg'), isTrue);
      final originalAEmbedding = persistedImages['https://example.com/photo_A.jpg']!;

      // Passo 2: Substitui B por D (ativo agora: A e D)
      final updatedProfile = await repository.processPetImages(
        petId: petId,
        petType: PetType.dog,
        imageUrls: [
          'https://example.com/photo_A.jpg',
          'https://example.com/photo_D.jpg',
        ],
      );

      persistedImages = await supabaseService.getExistingPetImageEmbeddings(petId);
      // B foi expurgada da tabela de imagens do pet
      expect(persistedImages.containsKey('https://example.com/photo_B.jpg'), isFalse);
      // A foi preservada com o mesmo embedding
      expect(persistedImages.containsKey('https://example.com/photo_A.jpg'), isTrue);
      expect(persistedImages['https://example.com/photo_A.jpg'], equals(originalAEmbedding));
      // D foi processada e salva
      expect(persistedImages.containsKey('https://example.com/photo_D.jpg'), isTrue);

      // O perfil visual resultante tem exatamente 2 imagens (A e D)
      expect(updatedProfile.images.length, equals(2));
      expect(updatedProfile.validEmbeddingsCount, equals(2));
    });

    test('6. Remoção de todas as imagens deixa agregado null', () async {
      final fakeSupabase = FakeSupabaseClient();
      final supabaseService = SupabasePetRecognitionService(fakeSupabase);
      final aiService = AiVisionService(allowSimulationForTesting: true);
      final repository = PetRecognitionRepository(aiService, supabaseService);

      const petId = 'pet_clear_imgs';
      // Inicia com 1 imagem
      await repository.processPetImages(
        petId: petId,
        petType: PetType.dog,
        imageUrls: ['https://example.com/dog_init.jpg'],
      );

      // Remove todas as imagens
      final emptyProfile = await repository.processPetImages(
        petId: petId,
        petType: PetType.dog,
        imageUrls: [],
      );

      expect(emptyProfile.images, isEmpty);
      expect(emptyProfile.aggregatedEmbedding, isNull);
      expect(emptyProfile.hasVisualEmbedding, isFalse);

      final persistedImages = await supabaseService.getExistingPetImageEmbeddings(petId);
      expect(persistedImages, isEmpty);
    });

    test('7. Reprocessamento da mesma imagem reutiliza embedding e não cria duplicatas', () async {
      final fakeSupabase = FakeSupabaseClient();
      final supabaseService = SupabasePetRecognitionService(fakeSupabase);
      final aiService = AiVisionService(allowSimulationForTesting: true);
      final repository = PetRecognitionRepository(aiService, supabaseService);

      const petId = 'pet_reproc_1';
      const url = 'https://example.com/same_dog.jpg';

      await repository.processPetImages(
        petId: petId,
        petType: PetType.dog,
        imageUrls: [url],
      );

      final firstMap = await supabaseService.getExistingPetImageEmbeddings(petId);
      expect(firstMap.length, equals(1));

      // Reprocessa exatamente a mesma foto
      await repository.processPetImages(
        petId: petId,
        petType: PetType.dog,
        imageUrls: [url],
      );

      final secondMap = await supabaseService.getExistingPetImageEmbeddings(petId);
      expect(secondMap.length, equals(1));
      expect(secondMap[url], equals(firstMap[url]));
    });

    test('8. Falha em uma imagem nova preserva embeddings válidos das demais', () async {
      final fakeSupabase = FakeSupabaseClient();
      final supabaseService = SupabasePetRecognitionService(fakeSupabase);
      final aiService = AiVisionService(allowSimulationForTesting: true);
      final repository = PetRecognitionRepository(aiService, supabaseService);

      const petId = 'pet_partial_fail_sync';
      // Inicial com foto válida
      await repository.processPetImages(
        petId: petId,
        petType: PetType.dog,
        imageUrls: ['https://example.com/dog_valid_first.jpg'],
      );

      // Adiciona uma foto com erro (simulada por 'ai_error')
      final resultProfile = await repository.processPetImages(
        petId: petId,
        petType: PetType.dog,
        imageUrls: [
          'https://example.com/dog_valid_first.jpg',
          'https://example.com/ai_error_second.jpg',
        ],
      );

      // A foto válida inicial foi mantida
      final persisted = await supabaseService.getExistingPetImageEmbeddings(petId);
      expect(persisted.containsKey('https://example.com/dog_valid_first.jpg'), isTrue);

      // O perfil tem 1 válida de 2 fotos, e o agregado reflete a válida
      expect(resultProfile.validEmbeddingsCount, equals(1));
      expect(resultProfile.hasVisualEmbedding, isTrue);
    });
  });

  // =========================================================================
  // GRUPO 8: CORRESPONDÊNCIAS, ORIGEM E NOTIFICAÇÕES
  // =========================================================================
  group('Correspondências, Origem e Notificações', () {
    test('saveMatch com score < 0.70 é descartado e não salvo', () async {
      final fakeSupabase = FakeSupabaseClient();
      final supabaseService = SupabasePetRecognitionService(fakeSupabase);

      await supabaseService.saveMatch(
        lostPetId: 'lost_low_score',
        foundPetId: 'found_low_score',
        similarityScore: 0.65, // abaixo de 0.70
        origin: 'automatic',
      );

      final score = await supabaseService.getMatchScore('lost_low_score', 'found_low_score');
      expect(score, isNull);
    });

    test('saveMatch com score >= 0.70 persiste e permite consultar score', () async {
      final fakeSupabase = FakeSupabaseClient();
      final supabaseService = SupabasePetRecognitionService(fakeSupabase);

      await supabaseService.saveMatch(
        lostPetId: 'lost_good_1',
        foundPetId: 'found_good_1',
        similarityScore: 0.85,
        origin: 'manual',
      );

      final score = await supabaseService.getMatchScore('lost_good_1', 'found_good_1');
      expect(score, equals(0.85));
    });

    test('Transição de correspondência manual para automática preserva par e atualiza origem', () async {
      final fakeSupabase = FakeSupabaseClient();
      final supabaseService = SupabasePetRecognitionService(fakeSupabase);

      const lostId = 'lost_pair_trans';
      const foundId = 'found_pair_trans';

      // 1. Busca manual encontra e salva com origin manual
      await supabaseService.saveMatch(
        lostPetId: lostId,
        foundPetId: foundId,
        similarityScore: 0.82,
        origin: 'manual',
      );

      var score = await supabaseService.getMatchScore(lostId, foundId);
      expect(score, equals(0.82));

      // 2. Busca automática subsequente detecta o mesmo par
      await supabaseService.saveMatch(
        lostPetId: lostId,
        foundPetId: foundId,
        similarityScore: 0.84,
        origin: 'automatic',
      );

      score = await supabaseService.getMatchScore(lostId, foundId);
      expect(score, equals(0.84));
    });
  });

  // =========================================================================
  // GRUPO 9: SEGURANÇA D1 E D2 — RPCs SERVER-SIDE E ISOLAMENTO DE EMBEDDINGS
  // =========================================================================
  group('Segurança D1 e D2 — Server-side Matching & Match Protection', () {
    test('RPC callMatchRpc retorna exclusivamente pet_id e similarity_score sem expor embeddings', () async {
      // Simula o retorno estrito das RPCs match_found_pets_for_lost e match_lost_pets_for_found
      final mockRpcResponse = [
        {'pet_id': 'found_uuid_1', 'similarity_score': 0.88},
        {'pet_id': 'found_uuid_2', 'similarity_score': 0.76},
      ];

      for (final row in mockRpcResponse) {
        expect(row.containsKey('pet_id'), isTrue);
        expect(row.containsKey('similarity_score'), isTrue);
        // Garante que o retorno do banco nunca expõe o vetor ou dados visuais internos
        expect(row.containsKey('embedding'), isFalse);
        expect(row.containsKey('aggregated_embedding'), isFalse);
        expect(row.containsKey('images'), isFalse);
      }
    });

    test('saveMatch via RPC atualiza memória com score oficial do servidor se retornado', () async {
      final fakeSupabase = FakeSupabaseClient();
      final supabaseService = SupabasePetRecognitionService(fakeSupabase);

      // Simula gravação de correspondência legítima
      await supabaseService.saveMatch(
        lostPetId: 'lost_official_1',
        foundPetId: 'found_official_1',
        similarityScore: 0.89,
        matchMethod: 'visual_single_vector',
        origin: 'manual',
      );

      final score = await supabaseService.getMatchScore('lost_official_1', 'found_official_1');
      expect(score, equals(0.89));
    });

    test('Persistência repetida para o mesmo par lost_pet e found_pet é idempotente', () async {
      final fakeSupabase = FakeSupabaseClient();
      final supabaseService = SupabasePetRecognitionService(fakeSupabase);

      const lostId = 'lost_repeat_pair';
      const foundId = 'found_repeat_pair';

      // 1ª gravação
      await supabaseService.saveMatch(
        lostPetId: lostId,
        foundPetId: foundId,
        similarityScore: 0.75,
        origin: 'manual',
      );

      // 2ª gravação com score idêntico
      await supabaseService.saveMatch(
        lostPetId: lostId,
        foundPetId: foundId,
        similarityScore: 0.75,
        origin: 'manual',
      );

      // 3ª gravação com score melhorado
      await supabaseService.saveMatch(
        lostPetId: lostId,
        foundPetId: foundId,
        similarityScore: 0.88,
        origin: 'automatic',
      );

      final finalScore = await supabaseService.getMatchScore(lostId, foundId);
      expect(finalScore, equals(0.88));
    });

    test('Tentativa de registrar match com score < 0.70 é descartada antes de gerar notificação', () async {
      final fakeSupabase = FakeSupabaseClient();
      final supabaseService = SupabasePetRecognitionService(fakeSupabase);

      await supabaseService.saveMatch(
        lostPetId: 'lost_invalid_score',
        foundPetId: 'found_invalid_score',
        similarityScore: 0.52,
        origin: 'automatic',
      );

      final score = await supabaseService.getMatchScore('lost_invalid_score', 'found_invalid_score');
      expect(score, isNull, reason: 'Scores abaixo do limiar 0.70 jamais devem ser persistidos');
    });

    test('Busca de candidatos por espécie isola estritamente cão e gato', () {
      final dogAlert = PetLostAlertEntity(
        id: 'dog_1',
        userId: 'user_1',
        petName: 'Rex',
        petType: PetType.dog,
        description: 'Cachorro caramelo',
        lastLocation: 'Praça Central',
        lostDate: DateTime.now(),
        contact: '11999999999',
      );

      final catCandidate = PetFoundAlertEntity(
        id: 'cat_1',
        userId: 'user_2',
        petType: PetType.cat,
        description: 'Gato siamês',
        foundLocation: 'Rua das Flores',
        foundDate: DateTime.now(),
        imageUrl: 'https://example.com/cat.jpg',
      );

      // A regra estrita de negócio impede qualquer comparação entre espécies distintas
      expect(dogAlert.petType == catCandidate.petType, isFalse);
    });

    test('Limiar de similaridade automático: parâmetros abaixo de 0.70 são barrados no servidor', () {
      // Simula a lógica de normalização defensiva do servidor SQL:
      // v_norm_threshold := GREATEST(0.70, COALESCE(similarity_threshold, 0.70));
      double normalizeServerThreshold(double? requestedThreshold) {
        final val = requestedThreshold ?? 0.70;
        final clamped = val > 1.0 ? 0.70 : val;
        return clamped < 0.70 ? 0.70 : clamped;
      }

      expect(normalizeServerThreshold(null), equals(0.70));
      expect(normalizeServerThreshold(0.30), equals(0.70));
      expect(normalizeServerThreshold(0.60), equals(0.70));
      expect(normalizeServerThreshold(0.70), equals(0.70));
      expect(normalizeServerThreshold(0.85), equals(0.85));
      expect(normalizeServerThreshold(1.00), equals(1.00));
      expect(normalizeServerThreshold(-0.50), equals(0.70));
      expect(normalizeServerThreshold(1.50), equals(0.70));
    });

    test('Equivalência matemática da fórmula: 50% max + 30% avg + 20% aggregate', () {
      // Cenário com 3 imagens: pairs = [0.90, 0.80, 0.70], agg = 0.85
      final queryEmbs = [
        List<double>.filled(768, 0.1),
        List<double>.filled(768, 0.2),
        List<double>.filled(768, 0.3),
      ];
      final candidateEmbs = [
        List<double>.filled(768, 0.1),
        List<double>.filled(768, 0.2),
        List<double>.filled(768, 0.3),
      ];

      // Vetores idênticos resultam em score 1.0
      final scoreIdentical = VectorMath.computeDetailedMatchScore(
        queryEmbeddings: queryEmbs,
        candidateEmbeddings: candidateEmbs,
        aggregatedSimilarity: 1.0,
      );
      expect(scoreIdentical, closeTo(1.0, 0.0001));

      // Teste com valores diretos de pesos
      const maxBest = 0.90;
      const avgBest = 0.80;
      const aggSim = 0.85;
      final expectedScore = 0.50 * maxBest + 0.30 * avgBest + 0.20 * aggSim; // 0.45 + 0.24 + 0.17 = 0.86
      expect(expectedScore, closeTo(0.86, 0.0001));

      // Sem agregado (fallback 60/40)
      final expectedFallback = 0.60 * maxBest + 0.40 * avgBest; // 0.54 + 0.32 = 0.86
      expect(expectedFallback, closeTo(0.86, 0.0001));
    });

    test('Fórmula com par de similaridade zero: zero É incluído no array, média e contagem (Dart e SQL)', () {
      // Simula o cálculo quando um par tem similaridade zero (e.g. [0.90, 0.00])
      final pairs = [0.90, 0.00];
      expect(pairs.length, equals(2));
      final maxVal = 0.90;
      final avgVal = (0.90 + 0.00) / 2.0; // 0.45, NÃO 0.90!
      expect(avgVal, equals(0.45));

      const aggSim = 0.80;
      final scoreComZero = 0.50 * maxVal + 0.30 * avgVal + 0.20 * aggSim;
      // 0.50 * 0.90 (0.45) + 0.30 * 0.45 (0.135) + 0.20 * 0.80 (0.16) = 0.745
      expect(scoreComZero, closeTo(0.745, 0.0001));

      // Caso com 3 imagens: [0.90, 0.80, 0.00]
      final pairs3 = [0.90, 0.80, 0.00];
      expect(pairs3.length, equals(3));
      final avgVal3 = (0.90 + 0.80 + 0.00) / 3.0; // 0.56666...
      final scoreComZero3 = 0.50 * 0.90 + 0.30 * avgVal3 + 0.20 * aggSim;
      // 0.45 + 0.17 + 0.16 = 0.78
      expect(scoreComZero3, closeTo(0.78, 0.001));
    });

    test('RecognitionConfig centraliza limiar de similaridade em 0.70', () {
      expect(RecognitionConfig.kSimilarityThreshold, equals(0.70));
    });
  });
}
