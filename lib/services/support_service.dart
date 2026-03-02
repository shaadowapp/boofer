import 'dart:math';
import 'package:flutter/foundation.dart';
import '../services/supabase_service.dart';

class SupportService {
  static final SupportService instance = SupportService._();
  SupportService._();

  final SupabaseService _supabase = SupabaseService.instance;
  Stream<List<Map<String, dynamic>>> getSupportMessagesStream(String userId) {
    return _supabase.client
        .from('support_messages')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('timestamp', ascending: true);
  }

  Future<List<Map<String, dynamic>>> fetchSupportMessages(String userId) async {
    try {
      final response = await _supabase.client
          .from('support_messages')
          .select('*')
          .eq('user_id', userId)
          .order('timestamp', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching support messages: $e');
      return [];
    }
  }

  Future<void> sendSupportMessage({
    required String userId,
    required String text,
    bool isFromAdmin = false,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final payload = {
        'user_id': userId,
        'text': text,
        'is_from_admin': isFromAdmin,
        'metadata': metadata ?? {},
      };
      debugPrint('🚀 [SUPPORT_SVC] Inserting message: $payload');
      await _supabase.client.from('support_messages').insert(payload);
      // Refresh list
      await fetchSupportMessages(userId);
    } catch (e) {
      debugPrint('Error sending support message: $e');
    }
  }

  Future<void> clearMessages(String userId) async {
    try {
      await _supabase.client
          .from('support_messages')
          .delete()
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('Error clearing support messages: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchTickets(String userId) async {
    try {
      final response = await _supabase.client
          .from('support_tickets')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching support tickets: $e');
      return [];
    }
  }

  // Removed manual listener in favor of .stream() constructor
  void listenToSupportMessages(String userId) {
    // No longer used, but kept for compatibility in case of calls
    debugPrint('Native Supabase Stream handles real-time for $userId');
  }

  static String generateShortId() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random();
    return List.generate(5, (index) => chars[rand.nextInt(chars.length)])
        .join();
  }

  Future<void> createTicket({
    required String userId,
    required String title,
    required String description,
    String? ticketNumber,
  }) async {
    try {
      await _supabase.client.from('support_tickets').insert({
        'user_id': userId,
        'title': title,
        'description': description,
        'status': 'open',
        'created_at': DateTime.now().toIso8601String(),
        'ticket_number': ticketNumber ?? generateShortId(),
      });
    } catch (e) {
      debugPrint('Error creating support ticket: $e');
      rethrow;
    }
  }

  Future<void> reportBug({
    required String userId,
    required String title,
    required String description,
    String? steps,
    String? expected,
    String? actual,
    String? severity,
    String? deviceInfo,
    String? bugNumber,
  }) async {
    try {
      await _supabase.client.from('bug_reports').insert({
        'user_id': userId,
        'title': title,
        'description': description,
        'steps_to_reproduce': steps,
        'expected_behavior': expected,
        'actual_behavior': actual,
        'severity': severity ?? 'medium',
        'device_info': deviceInfo,
        'status': 'open',
        'bug_number': bugNumber ?? generateShortId(),
      });
    } catch (e) {
      debugPrint('Error reporting bug: $e');
      rethrow;
    }
  }

  Future<void> sendFeedback({
    required String userId,
    required String type,
    required String message,
    String? email,
  }) async {
    try {
      await _supabase.client.from('feedback').insert({
        'user_id': userId,
        'type': type,
        'message': message,
        'email': email,
        'short_id': generateShortId(),
      });
    } catch (e) {
      debugPrint('Error sending feedback: $e');
      rethrow;
    }
  }

  Future<String> createLiveChatRequest({
    required String userId,
  }) async {
    try {
      final response = await _supabase.client
          .from('live_chat_requests')
          .insert({
            'user_id': userId,
            'status': 'pending',
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();
      
      return response['id'].toString();
    } catch (e) {
      debugPrint('Error creating live chat request: $e');
      rethrow;
    }
  }

  Stream<Map<String, dynamic>> listenToLiveChatRequest(String requestId) {
    return _supabase.client
        .from('live_chat_requests')
        .stream(primaryKey: ['id'])
        .eq('id', requestId)
        .map((list) => list.isNotEmpty ? list.first : {});
  }

  Future<void> updateLiveChatRequestStatus({
    required String requestId,
    required String status,
  }) async {
    try {
      await _supabase.client
          .from('live_chat_requests')
          .update({
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);
    } catch (e) {
      debugPrint('Error updating live chat request status: $e');
      rethrow;
    }
  }
}

