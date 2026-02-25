import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../error/error_handler.dart';
import '../models/app_error.dart';

/// Professional API client with proper error handling and retry logic
class ApiClient {
  static ApiClient? _instance;
  static ApiClient get instance => _instance ??= ApiClient._internal();
  
  factory ApiClient() => instance;
  ApiClient._internal();

  final ErrorHandler _errorHandler = ErrorHandler();
  final http.Client _httpClient = http.Client();
  
  String? _baseUrl;
  Map<String, String> _defaultHeaders = {};
  
  static const Duration _defaultTimeout = Duration(seconds: 30);
  static const int _maxRetries = 3;

  /// Initialize API client
  void initialize({
    required String baseUrl,
    String? apiKey,
    Map<String, String>? defaultHeaders,
  }) {
    _baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    _defaultHeaders = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (apiKey != null) 'Authorization': 'Bearer $apiKey',
      ...?defaultHeaders,
    };
  }

  /// GET request with error handling and retry logic
  Future<ApiResponse<T>> get<T>(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    Duration? timeout,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    return _executeWithRetry(() => _get<T>(
      endpoint,
      headers: headers,
      queryParameters: queryParameters,
      timeout: timeout,
      fromJson: fromJson,
    ));
  }

  /// POST request with error handling and retry logic
  Future<ApiResponse<T>> post<T>(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    Duration? timeout,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    return _executeWithRetry(() => _post<T>(
      endpoint,
      body: body,
      headers: headers,
      timeout: timeout,
      fromJson: fromJson,
    ));
  }

  /// PUT request with error handling and retry logic
  Future<ApiResponse<T>> put<T>(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    Duration? timeout,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    return _executeWithRetry(() => _put<T>(
      endpoint,
      body: body,
      headers: headers,
      timeout: timeout,
      fromJson: fromJson,
    ));
  }

  /// PATCH request with error handling and retry logic
  Future<ApiResponse<T>> patch<T>(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    Duration? timeout,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    return _executeWithRetry(() => _patch<T>(
      endpoint,
      body: body,
      headers: headers,
      timeout: timeout,
      fromJson: fromJson,
    ));
  }

  /// DELETE request with error handling and retry logic
  Future<ApiResponse<T>> delete<T>(
    String endpoint, {
    Map<String, String>? headers,
    Duration? timeout,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    return _executeWithRetry(() => _delete<T>(
      endpoint,
      headers: headers,
      timeout: timeout,
      fromJson: fromJson,
    ));
  }

  /// Execute request with retry logic
  Future<ApiResponse<T>> _executeWithRetry<T>(
    Future<ApiResponse<T>> Function() request,
  ) async {
    int attempts = 0;
    
    while (attempts < _maxRetries) {
      try {
        final response = await request();
        if (response.isSuccess || !_shouldRetry(response.statusCode)) {
          return response;
        }
      } catch (e) {
        if (attempts == _maxRetries - 1 || !_shouldRetryException(e)) {
          rethrow;
        }
      }
      
      attempts++;
      if (attempts < _maxRetries) {
        await Future.delayed(Duration(seconds: attempts * 2)); // Exponential backoff
      }
    }
    
    throw Exception('Max retries exceeded');
  }

  /// Internal GET implementation
  Future<ApiResponse<T>> _get<T>(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    Duration? timeout,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    final uri = _buildUri(endpoint, queryParameters);
    final requestHeaders = {..._defaultHeaders, ...?headers};
    
    try {
      final response = await _httpClient
          .get(uri, headers: requestHeaders)
          .timeout(timeout ?? _defaultTimeout);
      
      return _handleResponse<T>(response, fromJson);
    } catch (e, stackTrace) {
      return _handleError<T>(e, stackTrace, 'GET', endpoint);
    }
  }

  /// Internal POST implementation
  Future<ApiResponse<T>> _post<T>(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    Duration? timeout,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    final uri = _buildUri(endpoint);
    final requestHeaders = {..._defaultHeaders, ...?headers};
    final requestBody = body != null ? jsonEncode(body) : null;
    
    try {
      final response = await _httpClient
          .post(uri, headers: requestHeaders, body: requestBody)
          .timeout(timeout ?? _defaultTimeout);
      
      return _handleResponse<T>(response, fromJson);
    } catch (e, stackTrace) {
      return _handleError<T>(e, stackTrace, 'POST', endpoint);
    }
  }

  /// Internal PUT implementation
  Future<ApiResponse<T>> _put<T>(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    Duration? timeout,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    final uri = _buildUri(endpoint);
    final requestHeaders = {..._defaultHeaders, ...?headers};
    final requestBody = body != null ? jsonEncode(body) : null;
    
    try {
      final response = await _httpClient
          .put(uri, headers: requestHeaders, body: requestBody)
          .timeout(timeout ?? _defaultTimeout);
      
      return _handleResponse<T>(response, fromJson);
    } catch (e, stackTrace) {
      return _handleError<T>(e, stackTrace, 'PUT', endpoint);
    }
  }

  /// Internal PATCH implementation
  Future<ApiResponse<T>> _patch<T>(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    Duration? timeout,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    final uri = _buildUri(endpoint);
    final requestHeaders = {..._defaultHeaders, ...?headers};
    final requestBody = body != null ? jsonEncode(body) : null;
    
    try {
      final response = await _httpClient
          .patch(uri, headers: requestHeaders, body: requestBody)
          .timeout(timeout ?? _defaultTimeout);
      
      return _handleResponse<T>(response, fromJson);
    } catch (e, stackTrace) {
      return _handleError<T>(e, stackTrace, 'PATCH', endpoint);
    }
  }

  /// Internal DELETE implementation
  Future<ApiResponse<T>> _delete<T>(
    String endpoint, {
    Map<String, String>? headers,
    Duration? timeout,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    final uri = _buildUri(endpoint);
    final requestHeaders = {..._defaultHeaders, ...?headers};
    
    try {
      final response = await _httpClient
          .delete(uri, headers: requestHeaders)
          .timeout(timeout ?? _defaultTimeout);
      
      return _handleResponse<T>(response, fromJson);
    } catch (e, stackTrace) {
      return _handleError<T>(e, stackTrace, 'DELETE', endpoint);
    }
  }

  /// Build URI with query parameters
  Uri _buildUri(String endpoint, [Map<String, dynamic>? queryParameters]) {
    if (_baseUrl == null) {
      throw Exception('API client not initialized. Call initialize() first.');
    }
    
    final url = '$_baseUrl$endpoint';
    final uri = Uri.parse(url);
    
    if (queryParameters != null && queryParameters.isNotEmpty) {
      return uri.replace(queryParameters: queryParameters.map(
        (key, value) => MapEntry(key, value.toString()),
      ));
    }
    
    return uri;
  }

  /// Handle HTTP response
  ApiResponse<T> _handleResponse<T>(
    http.Response response,
    T Function(Map<String, dynamic>)? fromJson,
  ) {
    final statusCode = response.statusCode;
    
    try {
      final responseBody = response.body.isNotEmpty 
          ? jsonDecode(response.body) as Map<String, dynamic>
          : <String, dynamic>{};
      
      if (statusCode >= 200 && statusCode < 300) {
        T? data;
        if (fromJson != null && responseBody.isNotEmpty) {
          data = fromJson(responseBody);
        }
        
        return ApiResponse<T>.success(
          data: data,
          statusCode: statusCode,
          message: responseBody['message'] as String?,
        );
      } else {
        final errorMessage = responseBody['message'] as String? ?? 
                           responseBody['error'] as String? ?? 
                           'Request failed';
        
        return ApiResponse<T>.error(
          message: errorMessage,
          statusCode: statusCode,
          errorCode: responseBody['code'] as String?,
        );
      }
    } catch (e, stackTrace) {
      _errorHandler.handleError(AppError.network(
        message: 'Failed to parse response: $e',
        stackTrace: stackTrace,
        context: {'statusCode': statusCode, 'body': response.body},
        originalException: e is Exception ? e : Exception(e.toString()),
      ));
      
      return ApiResponse<T>.error(
        message: 'Failed to parse response',
        statusCode: statusCode,
      );
    }
  }

  /// Handle request errors
  ApiResponse<T> _handleError<T>(
    dynamic error,
    StackTrace stackTrace,
    String method,
    String endpoint,
  ) {
    String message;
    int? statusCode;
    
    if (error is SocketException) {
      message = 'No internet connection';
      statusCode = 0;
    } else if (error is TimeoutException) {
      message = 'Request timeout';
      statusCode = 408;
    } else if (error is HttpException) {
      message = 'HTTP error: ${error.message}';
    } else {
      message = 'Network error: $error';
    }
    
    _errorHandler.handleError(AppError.network(
      message: '$method $endpoint failed: $message',
      stackTrace: stackTrace,
      context: {'method': method, 'endpoint': endpoint},
      originalException: error is Exception ? error : Exception(error.toString()),
    ));
    
    return ApiResponse<T>.error(
      message: message,
      statusCode: statusCode,
    );
  }

  /// Check if request should be retried based on status code
  bool _shouldRetry(int? statusCode) {
    if (statusCode == null) return true;
    return statusCode >= 500 || statusCode == 408 || statusCode == 429;
  }

  /// Check if request should be retried based on exception
  bool _shouldRetryException(dynamic exception) {
    return exception is SocketException || 
           exception is TimeoutException ||
           exception is HttpException;
  }

  /// Update authorization header
  void updateAuthToken(String token) {
    _defaultHeaders['Authorization'] = 'Bearer $token';
  }

  /// Remove authorization header
  void clearAuthToken() {
    _defaultHeaders.remove('Authorization');
  }

  /// Dispose resources
  void dispose() {
    _httpClient.close();
  }
}

/// API response wrapper
class ApiResponse<T> {
  final T? data;
  final String? message;
  final int? statusCode;
  final String? errorCode;
  final bool isSuccess;

  ApiResponse._({
    this.data,
    this.message,
    this.statusCode,
    this.errorCode,
    required this.isSuccess,
  });

  factory ApiResponse.success({
    T? data,
    String? message,
    int? statusCode,
  }) {
    return ApiResponse._(
      data: data,
      message: message,
      statusCode: statusCode,
      isSuccess: true,
    );
  }

  factory ApiResponse.error({
    required String message,
    int? statusCode,
    String? errorCode,
  }) {
    return ApiResponse._(
      message: message,
      statusCode: statusCode,
      errorCode: errorCode,
      isSuccess: false,
    );
  }

  bool get isError => !isSuccess;
}