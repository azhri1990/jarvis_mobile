import 'dart:async';
import 'dart:convert';
import 'dart:io';

class GatewayResult {
  const GatewayResult({required this.ok, required this.message, this.payload});

  final bool ok;
  final String message;
  final Map<String, dynamic>? payload;
}

class JarvisGateway {
  JarvisGateway({this.baseUrl = 'http://127.0.0.1:5000', this.token = ''});

  final String baseUrl;
  final String token;

  Uri _uri(String path) {
    final normalized = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return Uri.parse('$normalized$path');
  }

  Future<GatewayResult> health() => _request('GET', '/health');

  Future<GatewayResult> command(String command, {bool confirmation = false}) =>
      _request('POST', '/command', body: {
        'command': command,
        if (confirmation) 'confirmation': true,
      });

  Future<GatewayResult> skills() => _request('GET', '/skills');

  Future<GatewayResult> _request(String method, String path, {Map<String, dynamic>? body}) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    try {
      final request = await client.openUrl(method, _uri(path));
      request.headers.contentType = ContentType.json;
      if (token.trim().isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${token.trim()}');
      }
      if (body != null) request.write(jsonEncode(body));
      final response = await request.close().timeout(const Duration(seconds: 8));
      final text = await response.transform(utf8.decoder).join();
      Map<String, dynamic>? payload;
      if (text.isNotEmpty) {
        final decoded = jsonDecode(text);
        if (decoded is Map<String, dynamic>) payload = decoded;
      }
      return GatewayResult(
        ok: response.statusCode >= 200 && response.statusCode < 300,
        message: payload?['error']?.toString() ??
            payload?['status']?.toString() ?? 'HTTP ${response.statusCode}',
        payload: payload,
      );
    } on TimeoutException {
      return const GatewayResult(ok: false, message: 'Gateway timeout');
    } on SocketException catch (error) {
      return GatewayResult(ok: false, message: 'Gateway unavailable: ${error.message}');
    } on FormatException {
      return const GatewayResult(ok: false, message: 'Gateway returned invalid JSON');
    } catch (error) {
      return GatewayResult(ok: false, message: 'Gateway error: $error');
    } finally {
      client.close(force: true);
    }
  }
}
