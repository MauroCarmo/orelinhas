/// Representa o estado do ciclo de vida de análise de uma imagem de pet no pipeline de IA.
enum AnalysisStatus {
  /// Imagem recebida, aguardando envio/processamento.
  pending,

  /// Imagem em processamento pela pipeline (YOLOv8n / SigLIP).
  processing,

  /// Imagem processada com sucesso e embedding de 768 dimensões gerado.
  processed,

  /// Imagem analisada, mas nenhum cão/gato foi detectado com confiança suficiente.
  /// Não invalida nem bloqueia o cadastro do pet.
  notDetected,

  /// Ocorreu uma falha técnica durante o processamento (ex: timeout, erro de rede, etc.).
  /// A imagem é preservada e o cadastro do pet permanece válido.
  error;

  /// Retorna o enum a partir de string serializada.
  static AnalysisStatus fromString(String? value) {
    switch (value) {
      case 'processing':
        return AnalysisStatus.processing;
      case 'processed':
        return AnalysisStatus.processed;
      case 'not_detected':
      case 'notDetected':
        return AnalysisStatus.notDetected;
      case 'error':
        return AnalysisStatus.error;
      case 'pending':
      default:
        return AnalysisStatus.pending;
    }
  }

  /// Retorna a representação snake_case para persistência e API.
  String toSnakeCase() {
    switch (this) {
      case AnalysisStatus.pending:
        return 'pending';
      case AnalysisStatus.processing:
        return 'processing';
      case AnalysisStatus.processed:
        return 'processed';
      case AnalysisStatus.notDetected:
        return 'not_detected';
      case AnalysisStatus.error:
        return 'error';
    }
  }

  /// Rótulo amigável em português para a interface do usuário.
  String get userFriendlyLabel {
    switch (this) {
      case AnalysisStatus.pending:
        return 'Aguardando análise';
      case AnalysisStatus.processing:
        return 'Analisando imagem...';
      case AnalysisStatus.processed:
        return 'Foto analisada com sucesso';
      case AnalysisStatus.notDetected:
        return 'Não foi possível analisar esta foto automaticamente';
      case AnalysisStatus.error:
        return 'Análise temporariamente indisponível para esta foto';
    }
  }
}
