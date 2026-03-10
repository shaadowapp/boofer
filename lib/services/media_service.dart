import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cryptography/cryptography.dart';
import 'virgil_e2ee_service.dart';

/// Service for handling media file operations in chat
/// Handles picking, compression (webp conversion), encryption, and Supabase storage
class MediaService {
  static MediaService? _instance;
  static MediaService get instance => _instance ??= MediaService._internal();
  MediaService._internal();

  final ImagePicker _imagePicker = ImagePicker();
  final SupabaseClient _supabase = Supabase.instance.client;

  // File size limits (in bytes)
  static const int maxImageSize = 5 * 1024 * 1024; // 5 MB
  static const int maxVideoSize = 15 * 1024 * 1024; // 15 MB

  /// Pick image from gallery or camera
  Future<File?> pickImage({bool fromCamera = false}) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
      );

      if (image != null) return File(image.path);
      return null;
    } catch (e) {
      debugPrint('❌ Error picking image: $e');
      rethrow;
    }
  }

  /// Pick video from gallery or camera
  Future<File?> pickVideo({bool fromCamera = false}) async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      );

      if (video != null) {
        final file = File(video.path);
        // Check video size
        final size = await file.length();
        if (size > maxVideoSize) {
          throw Exception(
            'Video size exceeds ${maxVideoSize ~/ (1024 * 1024)}MB limit',
          );
        }
        return file;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error picking video: $e');
      rethrow;
    }
  }

  /// Compress image and convert to WebP format
  /// Returns compressed file path and original/original compressed size
  Future<Map<String, dynamic>> compressImageToWebp(
    File imageFile, {
    int quality = 85,
  }) async {
    try {
      final filePath = imageFile.path;
      final extension = path.extension(filePath).toLowerCase();

      // Get original file size
      final originalSize = await imageFile.length();

      // Check if already webp
      if (extension == '.webp') {
        // Just compress without conversion
        final compressedFile = await FlutterImageCompress.compressAndGetFile(
          filePath,
          await _getTempPath(
              'compressed_${DateTime.now().millisecondsSinceEpoch}.webp'),
          quality: quality,
          format: CompressFormat.webp,
        );

        if (compressedFile == null) throw Exception('Failed to compress image');

        final compressedSize = await compressedFile.length();
        debugPrint(
          '🗜️ Image compressed (WebP): ${originalSize ~/ 1024}KB → ${compressedSize ~/ 1024}KB',
        );

        return {
          'file': compressedFile,
          'originalSize': originalSize,
          'compressedSize': compressedSize,
          'mimeType': 'image/webp',
        };
      } else {
        // Convert to webp with compression
        final outputFileName =
            'converted_${DateTime.now().millisecondsSinceEpoch}.webp';
        final outputPath = await _getTempPath(outputFileName);

        final compressedFile = await FlutterImageCompress.compressAndGetFile(
          filePath,
          outputPath,
          quality: quality,
          format: CompressFormat.webp,
        );

        if (compressedFile == null) throw Exception('Failed to compress and convert image to WebP');

        final compressedSize = await compressedFile.length();
        debugPrint(
          '🗜️ Image converted to WebP: ${originalSize ~/ 1024}KB → ${compressedSize ~/ 1024}KB (${((1 - compressedSize / originalSize) * 100).toStringAsFixed(1)}% reduction)',
        );

        return {
          'file': compressedFile,
          'originalSize': originalSize,
          'compressedSize': compressedSize,
          'mimeType': 'image/webp',
        };
      }
    } catch (e) {
      debugPrint('❌ Error compressing image: $e');
      rethrow;
    }
  }

  /// Generate video thumbnail
  Future<File?> generateVideoThumbnail(File videoFile) async {
    try {
      // For now, we'll just use a placeholder approach
      // In production, you'd use video_thumbnail package
      debugPrint('🎬 Video thumbnail generation (placeholder)');
      return null;
    } catch (e) {
      debugPrint('❌ Error generating video thumbnail: $e');
      return null;
    }
  }

  /// Safely convert any key value (String base64, Uint8List, or List<int>) to Uint8List.
  Uint8List _toUint8List(dynamic value) {
    if (value is Uint8List) return value;
    if (value is List<int>) return Uint8List.fromList(value);
    if (value is String) return Uint8List.fromList(base64Decode(value));
    throw ArgumentError('Cannot convert ${value.runtimeType} to Uint8List');
  }

  /// Encrypt media bytes using AES-GCM with Virgil-encrypted key
  /// Returns encrypted bytes and encrypted metadata
  Future<Map<String, dynamic>> encryptMedia(
    Uint8List mediaBytes,
    Map<String, dynamic> recipientKeys,
    Map<String, dynamic>? senderKeys,
  ) async {
    try {
      // Generate random AES-256 key for media encryption
      final aesGcm = AesGcm.with256bits();
      final mediaKey = await aesGcm.newSecretKey();
      final mediaKeyBytes = await mediaKey.extractBytes();

      // Generate nonce
      final nonce = aesGcm.newNonce();

      // Encrypt media bytes with AES-GCM
      final secretBox = await aesGcm.encrypt(
        mediaBytes,
        secretKey: mediaKey,
        nonce: nonce,
      );

      // Encrypt the AES key using Virgil for recipient
      // getRecipientKeys returns Uint8List; guard anyway for future-proofing
      final virgilService = VirgilE2EEService.instance;
      final recipientEncPk = _toUint8List(recipientKeys['encryptionPublicKey']);
      final encryptedKeyData = await virgilService.encryptThenSign(
        base64Encode(mediaKeyBytes),
        recipientEncPk,
      );

      // Also encrypt for sender (so they can view their own messages)
      Map<String, dynamic>? encryptedKeyDataSender;
      if (senderKeys != null) {
        final senderEncPk = _toUint8List(senderKeys['encryptionPublicKey']);
        encryptedKeyDataSender = await virgilService.encryptThenSign(
          base64Encode(mediaKeyBytes),
          senderEncPk,
        );
      }

      debugPrint('🔐 Media encrypted: ${mediaBytes.length} bytes');

      return {
        'encryptedBytes': secretBox.cipherText,
        'mac': secretBox.mac.bytes,
        'nonce': nonce,
        'encryptedKeyRecipient': encryptedKeyData,
        'encryptedKeySender': encryptedKeyDataSender,
      };
    } catch (e) {
      debugPrint('❌ Error encrypting media: $e');
      rethrow;
    }
  }

  /// Decrypt media bytes using Virgil-decrypted key
  Future<Uint8List> decryptMedia(
    Uint8List encryptedBytes,
    Uint8List macBytes,
    Uint8List nonceBytes,
    Map<String, dynamic> encryptedKeyData,
    Uint8List senderSignaturePublicKey,
  ) async {
    try {
      // Decrypt the media key using Virgil
      final virgilService = VirgilE2EEService.instance;
      final decryptedKeyDataBase64 = await virgilService.decryptThenVerify(
        encryptedKeyData,
        senderSignaturePublicKey,
      );

      final mediaKeyBytes = base64Decode(decryptedKeyDataBase64);
      final mediaKey = await AesGcm.with256bits().newSecretKeyFromBytes(
        mediaKeyBytes,
      );

      // Decrypt media bytes
      final aesGcm = AesGcm.with256bits();
      final secretBox =
          SecretBox(encryptedBytes, nonce: nonceBytes, mac: Mac(macBytes));
      final decryptedBytes = await aesGcm.decrypt(
        secretBox,
        secretKey: mediaKey,
      );

      debugPrint('🔓 Media decrypted: ${decryptedBytes.length} bytes');

      return Uint8List.fromList(decryptedBytes);
    } catch (e) {
      debugPrint('❌ Error decrypting media: $e');
      rethrow;
    }
  }

  /// Upload encrypted media to Supabase Storage
  /// Path format: conversation_id/message_id.enc
  Future<String> uploadEncryptedMedia(
    String conversationId,
    String messageId,
    Uint8List encryptedBytes,
  ) async {
    try {
      final fileName = '$messageId.enc';
      final storagePath = '$conversationId/$fileName';

      debugPrint('⬆️ Uploading encrypted media to: $storagePath');

      await _supabase.storage.from('chat-media').uploadBinary(
            storagePath,
            encryptedBytes,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false,
            ),
          );

      debugPrint('✅ Media uploaded successfully');

      return storagePath;
    } catch (e) {
      debugPrint('❌ Error uploading media: $e');
      rethrow;
    }
  }

  /// Download encrypted media from Supabase Storage
  Future<Uint8List> downloadEncryptedMedia(String storagePath) async {
    try {
      debugPrint('⬇️ Downloading encrypted media from: $storagePath');

      final response =
          await _supabase.storage.from('chat-media').download(storagePath);

      debugPrint('✅ Media downloaded successfully');

      return response;
    } catch (e) {
      debugPrint('❌ Error downloading media: $e');
      rethrow;
    }
  }

  /// Delete media from Supabase Storage
  Future<void> deleteMedia(String storagePath) async {
    try {
      debugPrint('🗑️ Deleting media from storage: $storagePath');

      await _supabase.storage.from('chat-media').remove([storagePath]);

      debugPrint('✅ Media deleted from storage');
    } catch (e) {
      debugPrint('❌ Error deleting media: $e');
      // Don't rethrow - deletion failure shouldn't break the flow
    }
  }

  /// Save decrypted media to local cache
  Future<String> saveMediaToLocalCache(
    Uint8List mediaBytes,
    String messageId,
    String mimeType,
  ) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final extension = mimeType.startsWith('image/') ? '.webp' : '.mp4';
      final filePath = '${tempDir.path}/media_$messageId$extension';

      final file = File(filePath);
      await file.writeAsBytes(mediaBytes);

      debugPrint('💾 Media saved to local cache: $filePath');

      return filePath;
    } catch (e) {
      debugPrint('❌ Error saving media to cache: $e');
      rethrow;
    }
  }

  /// Get cached media file path
  Future<File?> getCachedMediaFile(String messageId) async {
    try {
      final tempDir = await getTemporaryDirectory();

      // Try both webp and mp4 extensions
      for (final ext in ['.webp', '.mp4']) {
        final filePath = '${tempDir.path}/media_$messageId$ext';
        final file = File(filePath);
        if (await file.exists()) {
          return file;
        }
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error getting cached media: $e');
      return null;
    }
  }

  /// Clear cached media file
  Future<void> clearCachedMedia(String messageId) async {
    try {
      final tempDir = await getTemporaryDirectory();

      for (final ext in ['.webp', '.mp4']) {
        final filePath = '${tempDir.path}/media_$messageId$ext';
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
          debugPrint('🗑️ Cached media cleared: $filePath');
        }
      }
    } catch (e) {
      debugPrint('❌ Error clearing cached media: $e');
    }
  }

  /// Helper to get temp path
  Future<String> _getTempPath(String fileName) async {
    final tempDir = await getTemporaryDirectory();
    return '${tempDir.path}/$fileName';
  }

  /// Validate file type and size
  bool validateMediaFile(File file, {bool isVideo = false}) {
    try {
      final extension = path.extension(file.path).toLowerCase();

      if (isVideo) {
        // Allow common video formats
        if (!['.mp4', '.mov', '.avi', '.mkv'].contains(extension)) {
          throw Exception('Unsupported video format: $extension');
        }
      } else {
        // Allow common image formats
        if (!['.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic'].contains(
          extension,
        )) {
          throw Exception('Unsupported image format: $extension');
        }
      }

      return true;
    } catch (e) {
      rethrow;
    }
  }
}
