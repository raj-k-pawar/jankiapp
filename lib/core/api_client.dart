import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'config.dart';

/// A failed call, with a message that is safe to show to staff.
class ApiException implements Exception {
  ApiException(this.message, {this.data = const {}, this.unauthorized = false});

  final String message;
  final Map<String, dynamic> data;
  final bool unauthorized;

  @override
  String toString() => message;
}

/// Thin wrapper around the website's staff API (/api/app/v1).
class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const Duration _timeout = Duration(seconds: 25);

  /// Staff login token; sent as a Bearer header when set.
  String? token;

  /// Called when the website says the login is no longer valid.
  void Function()? onUnauthorized;

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> get(String path, [Map<String, String>? query]) {
    return _send(() => _client.get(AppEnv.endpoint(path, query), headers: _headers), path);
  }

  /// Posts form fields — the same encoding the website's own pages use.
  Future<Map<String, dynamic>> post(String path, [Map<String, String> fields = const {}]) {
    return _send(() => _client.post(AppEnv.endpoint(path), headers: _headers, body: fields), path);
  }

  Future<Map<String, dynamic>> _send(Future<http.Response> Function() call, String path) async {
    final problem = AppEnv.problem;
    if (problem != null) throw ApiException(problem);

    final http.Response res;
    try {
      res = await call().timeout(_timeout);
    } on TimeoutException {
      throw ApiException('The website took too long to respond. Please try again.');
    } on SocketException {
      throw ApiException('No internet connection. Please check your network and try again.');
    } on HandshakeException {
      throw ApiException('Could not make a secure connection to the website.');
    } on http.ClientException {
      throw ApiException('Could not reach the website. Please check your network and try again.');
    }

    Map<String, dynamic> body = const {};
    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is Map<String, dynamic>) body = decoded;
    } on FormatException {
      // not JSON — handled by the status checks below
    }
    final message = body['message'] is String ? body['message'] as String : '';

    if (res.statusCode == 401 && path != 'login') {
      onUnauthorized?.call();
      throw ApiException(message.isNotEmpty ? message : 'Session expired. Please log in again.', unauthorized: true);
    }
    if (res.statusCode == 429 && path != 'login') {
      throw ApiException('Too many requests. Please wait a moment and try again.');
    }
    if (body['success'] == true) return body;
    if (message.isNotEmpty) throw ApiException(message, data: body);
    if (res.statusCode == 429) throw ApiException('Too many attempts. Please wait a minute and try again.');
    if (res.statusCode == 403) throw ApiException('You do not have permission to do that.');
    throw ApiException('Something went wrong (code ${res.statusCode}). Please try again.');
  }
}
