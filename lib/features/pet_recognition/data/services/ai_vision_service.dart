import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../../core/env/env.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../pet_lost/domain/pet_lost_entity.dart';
import '../../domain/models/analysis_status.dart';
import '../../domain/models/bounding_box_entity.dart';
import '../../domain/utils/vector_math.dart';

final aiVisionServiceProvider = Provider<AiVisionService>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final accessToken = supabase.auth.currentSession?.accessToken;
  return AiVisionService(authToken: accessToken, apiEndpoint: Env.aiVisionEndpoint);
});

/// Resultado da execução do pipeline de IA para uma imagem.
class VisionAnalysisResult {
  final AnalysisStatus status;
  final List<BoundingBoxEntity> detections;
  final BoundingBoxEntity? selectedDetection;
  final List<double>? embedding768;
  final String? errorMessage;

  const VisionAnalysisResult({
    required this.status,
    this.detections = const [],
    this.selectedDetection,
    this.embedding768,
    this.errorMessage,
  });
}

/// Serviço responsável por orquestrar a detecção com YOLOv8n e geração de embeddings com SigLIP.
class AiVisionService {
  final http.Client _httpClient;
  final _logger = AppLogger.category('AiVisionService');

  // Configurações do serviço de IA (podem ser substituídas por endpoints reais de Edge Function / Cloud)
  final String? _apiEndpoint;
  final String? _authToken;
  final Duration _timeout;

  AiVisionService({
    http.Client? httpClient,
    String? apiEndpoint,
    String? authToken,
    Duration timeout = const Duration(seconds: 15),
  })  : _httpClient = httpClient ?? http.Client(),
        _apiEndpoint = apiEndpoint,
        _authToken = authToken,
        _timeout = timeout;

  /// Analisa uma imagem de pet através do pipeline:
  /// 1. Verificação de elegibilidade da espécie (somente cães e gatos).
  /// 2. Detecção com YOLOv8n (identificação de animais e bounding boxes).
  /// 3. Se houver múltiplos animais e nenhum especificado, prepara lista para seleção.
  /// 4. Recorte e extração de embedding 768d com SigLIP normalizado com L2.
  /// 5. Falhas técnicas NUNCA lançam exceções não tratadas que quebrem o app.
  Future<VisionAnalysisResult> analyzeImage({
    required String imageId,
    required String imageUrl,
    required PetType petType,
    Uint8List? imageBytes,
    BoundingBoxEntity? userSelectedBox,
  }) async {
    _logger.i('Iniciando análise de imagem.', context: {
      'imageId': imageId,
      'petType': petType.name,
      'imageUrl': imageUrl,
    });

    // 1. Verificação de espécie
    if (petType != PetType.dog && petType != PetType.cat) {
      _logger.i('Espécie não elegível para reconhecimento visual de embeddings.', context: {
        'petType': petType.name,
      });
      return const VisionAnalysisResult(
        status: AnalysisStatus.notDetected,
        errorMessage: 'Reconhecimento visual automático disponível apenas para cães e gatos.',
      );
    }

    try {
      // 2. Se houver endpoint remoto configurado, faz chamada HTTP
      final endpoint = _apiEndpoint;
      if (endpoint != null && endpoint.isNotEmpty) {
        return await _callRemoteAiPipeline(
          imageUrl: imageUrl,
          imageBytes: imageBytes,
          petType: petType,
          selectedBox: userSelectedBox,
        );
      }

      // 3. Quando AI_VISION_ENDPOINT estiver ausente ou vazio,
      // retorna erro explícito de configuração.
      _logger.e('AI_VISION_ENDPOINT não configurado no .env.');
      return const VisionAnalysisResult(
        status: AnalysisStatus.error,
        errorMessage: 'Serviço de reconhecimento de IA não configurado (AI_VISION_ENDPOINT ausente).',
      );
    } on TimeoutException catch (e, st) {
      _logger.w('Timeout na análise de visão computacional.', error: e, stackTrace: st);
      return const VisionAnalysisResult(
        status: AnalysisStatus.error,
        errorMessage: 'Tempo limite esgotado ao analisar a imagem.',
      );
    } catch (e, st) {
      _logger.e('Erro inesperado no pipeline de visão computacional.', error: e, stackTrace: st);
      return VisionAnalysisResult(
        status: AnalysisStatus.error,
        errorMessage: 'Falha técnica temporária na análise de imagem.',
      );
    }
  }

  /// Chamada à API remota (ex: Supabase Edge Function ou serviço YOLO+SigLIP)
  Future<VisionAnalysisResult> _callRemoteAiPipeline({
    required String imageUrl,
    required Uint8List? imageBytes,
    required PetType petType,
    required BoundingBoxEntity? selectedBox,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    // Adiciona headers de autenticação quando disponíveis
    final token = _authToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
      headers['apikey'] = token;
    }

    final bodyMap = <String, dynamic>{
      'image_url': imageUrl,
      'pet_type': petType.name,
      'selected_box': selectedBox?.toJson(),
    };

    // Inclui os bytes da imagem como base64 quando disponíveis (útil para URLs privadas)
    if (imageBytes != null && imageBytes.isNotEmpty) {
      bodyMap['image_base64'] = base64Encode(imageBytes);
    }

    final response = await _httpClient
        .post(
          Uri.parse('$_apiEndpoint/analyze'),
          headers: headers,
          body: jsonEncode(bodyMap),
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final detectionsJson = data['detections'] as List<dynamic>?;
      final detections = detectionsJson != null
          ? detectionsJson
              .map((d) => BoundingBoxEntity.fromJson(d as Map<String, dynamic>))
              .toList()
          : <BoundingBoxEntity>[];

      if (detections.isEmpty) {
        return const VisionAnalysisResult(
          status: AnalysisStatus.notDetected,
          errorMessage: 'Nenhum animal detectado na imagem.',
        );
      }

      final embeddingRaw = data['embedding'] as List<dynamic>?;
      List<double>? embedding;
      if (embeddingRaw != null && embeddingRaw.length == 768) {
        final rawDoubles = embeddingRaw.map((e) => (e as num).toDouble()).toList();
        if (rawDoubles.every((v) => v.isFinite)) {
          embedding = VectorMath.l2Normalize(rawDoubles);
        }
      }

      final chosenBox = selectedBox ?? (detections.isNotEmpty ? detections.first : null);

      return VisionAnalysisResult(
        status: embedding != null ? AnalysisStatus.processed : AnalysisStatus.notDetected,
        detections: detections,
        selectedDetection: chosenBox,
        embedding768: embedding,
      );
    } else {
      return VisionAnalysisResult(
        status: AnalysisStatus.error,
        errorMessage: 'Serviço de IA retornou status ${response.statusCode}',
      );
    }
  }
}
