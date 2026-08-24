import 'dart:math' as math;

/// Utilitários matemáticos para operações com vetores de embeddings (ex: 768 dimensões).
class VectorMath {
  /// Converte com segurança dados de embedding vindos do Supabase/PostgREST.
  /// Suporta tanto List<dynamic> quanto String no formato pgvector (ex: "[0.12, -0.34, ...]").
  static List<double>? parseEmbedding(dynamic raw) {
    if (raw == null) return null;
    if (raw is List) {
      return raw.map((e) => (e as num).toDouble()).toList();
    }
    if (raw is String) {
      final clean = raw.replaceAll('[', '').replaceAll(']', '').trim();
      if (clean.isEmpty) return null;
      return clean
          .split(',')
          .map((s) => double.tryParse(s.trim()))
          .whereType<double>()
          .toList();
    }
    return null;
  }

  /// Calcula a norma L2 (magnitude Euclidiana) de um vetor.
  static double l2Norm(List<double> vector) {
    if (vector.isEmpty) return 0.0;
    double sumSq = 0.0;
    for (final val in vector) {
      sumSq += val * val;
    }
    return math.sqrt(sumSq);
  }

  /// Normaliza um vetor usando norma L2 (vetor unitário).
  /// Se o vetor for nulo ou tiver norma zero, retorna uma cópia com zeros.
  static List<double> l2Normalize(List<double> vector) {
    if (vector.isEmpty) return [];
    final norm = l2Norm(vector);
    if (norm == 0.0 || norm.isNaN) {
      return List<double>.filled(vector.length, 0.0);
    }
    return vector.map((v) => v / norm).toList();
  }

  /// Calcula o produto escalar (dot product) entre dois vetores de mesmo tamanho.
  static double dotProduct(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return 0.0;
    double sum = 0.0;
    for (int i = 0; i < a.length; i++) {
      sum += a[i] * b[i];
    }
    return sum;
  }

  /// Calcula a similaridade de cosseno entre dois vetores de embeddings.
  /// Retorna um valor entre -1.0 e 1.0 (ou 0.0 a 1.0 na prática de embeddings).
  static double cosineSimilarity(List<double>? a, List<double>? b) {
    if (a == null || b == null || a.isEmpty || b.isEmpty || a.length != b.length) {
      return 0.0;
    }

    final normA = l2Norm(a);
    final normB = l2Norm(b);

    if (normA == 0.0 || normB == 0.0) return 0.0;

    final dot = dotProduct(a, b);
    final sim = dot / (normA * normB);
    return sim.clamp(-1.0, 1.0);
  }

  /// Calcula o embedding agregado a partir de múltiplos vetores individuais válidos.
  /// 1. Filtra vetores nulos ou de tamanho incorreto (ex: diferente de 768).
  /// 2. Calcula a média aritmética dos componentes.
  /// 3. Aplica normalização L2 sobre o vetor resultante.
  static List<double>? computeAggregatedEmbedding(
    List<List<double>?> validEmbeddings, {
    int expectedDimension = 768,
  }) {
    final nonNullVectors = validEmbeddings
        .whereType<List<double>>()
        .where((v) => v.length == expectedDimension)
        .toList();

    if (nonNullVectors.isEmpty) return null;

    final length = expectedDimension;
    final count = nonNullVectors.length;
    final sumVector = List<double>.filled(length, 0.0);

    for (final vec in nonNullVectors) {
      for (int i = 0; i < length; i++) {
        sumVector[i] += vec[i];
      }
    }

    // Calcula a média
    final meanVector = sumVector.map((v) => v / count).toList();

    // Normaliza com L2
    return l2Normalize(meanVector);
  }

  /// Compara dois conjuntos de embeddings individuais (Refinamento da Etapa 2).
  /// Combina a similaridade máxima entre as fotos e a média das melhores correspondências.
  static double computeDetailedMatchScore({
    required List<List<double>> queryEmbeddings,
    required List<List<double>> candidateEmbeddings,
    double? aggregatedSimilarity,
  }) {
    if (queryEmbeddings.isEmpty || candidateEmbeddings.isEmpty) {
      return aggregatedSimilarity ?? 0.0;
    }

    final List<double> pairSimilarities = [];

    for (final q in queryEmbeddings) {
      double bestForQ = 0.0;
      for (final c in candidateEmbeddings) {
        final sim = cosineSimilarity(q, c);
        if (sim > bestForQ) {
          bestForQ = sim;
        }
      }
      pairSimilarities.add(bestForQ);
    }

    if (pairSimilarities.isEmpty) return aggregatedSimilarity ?? 0.0;

    // Calcula a média das melhores similaridades por foto
    final avgBest = pairSimilarities.reduce((a, b) => a + b) / pairSimilarities.length;
    final maxBest = pairSimilarities.reduce(math.max);

    // Score multi-sinal balanceado:
    // 50% max score individual + 30% média dos melhores pares + 20% similaridade agregada
    if (aggregatedSimilarity != null && aggregatedSimilarity > 0) {
      return (maxBest * 0.50 + avgBest * 0.30 + aggregatedSimilarity * 0.20)
          .clamp(0.0, 1.0);
    }

    return (maxBest * 0.60 + avgBest * 0.40).clamp(0.0, 1.0);
  }
}
