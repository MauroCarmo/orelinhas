import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mime/mime.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/exceptions/error_mapper.dart';
import '../../../core/logger/app_logger.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  final supabase = ref.read(supabaseClientProvider);
  return StorageService(supabase);
});

class StorageService {
  final SupabaseClient _supabase;
  final _logger = AppLogger.category('StorageService');

  StorageService(this._supabase);

  static const _maxFileSize = 5 * 1024 * 1024; // 5 MB
  static const _allowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];

  /// Faz upload de uma imagem a partir de bytes.
  /// [bytes] são os bytes do arquivo de imagem.
  /// [fileName] é o nome do arquivo (usado para determinar extensão).
  /// [bucket] é o nome do bucket no Supabase Storage.
  /// [folder] é o prefixo opcional (ex.: id do usuário) para organizar.
  /// Retorna a URL pública da imagem.
  Future<String> uploadImage({
    required Uint8List bytes,
    required String fileName,
    required String bucket,
    String? folder,
  }) async {
    _logger.i(
      'Iniciando upload de imagem',
      context: {'fileName': fileName, 'bucket': bucket},
    );

    // Verifica tamanho
    if (bytes.length > _maxFileSize) {
      _logger.w(
        'Arquivo excede tamanho máximo',
        context: {'size': bytes.length, 'max': _maxFileSize},
      );
      throw ValidationException('A imagem deve ter no máximo 5 MB.');
    }

    // Verifica extensão
    final extension = fileName.split('.').last.toLowerCase();
    final mimeType = lookupMimeType(fileName, headerBytes: bytes);
    if (!_allowedExtensions.contains(extension) ||
        (mimeType != null && !mimeType.startsWith('image/'))) {
      _logger.w(
        'Formato de arquivo não permitido',
        context: {'extension': extension, 'mime': mimeType},
      );
      throw ValidationException(
        'Formato de imagem inválido. Use JPEG, PNG ou WebP.',
      );
    }

    // Define nome final
    final finalFileName = '${DateTime.now().millisecondsSinceEpoch}.$extension';
    final storagePath = folder != null
        ? '$folder/$finalFileName'
        : finalFileName;

    try {
      await _supabase.storage
          .from(bucket)
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final publicUrl = _supabase.storage
          .from(bucket)
          .getPublicUrl(storagePath);

      _logger.i('Upload concluído com sucesso', context: {'url': publicUrl});
      return publicUrl;
    } on StorageException catch (e) {
      _logger.e('Erro no upload para Supabase Storage', error: e);
      throw AppErrorMapper.map(e, StackTrace.current);
    } catch (e, st) {
      _logger.e('Erro inesperado no upload', error: e, stackTrace: st);
      throw AppErrorMapper.map(e, st);
    }
  }

  /// Remove uma imagem do bucket, se existir.
  Future<void> deleteImage(String bucket, String path) async {
    try {
      await _supabase.storage.from(bucket).remove([path]);
      _logger.i('Imagem removida', context: {'bucket': bucket, 'path': path});
    } catch (e, st) {
      _logger.e('Erro ao remover imagem', error: e, stackTrace: st);
    }
  }
}
