// lib/services/gemini_ai.dart
// Google Gemini API integration (Google AI Studio)
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import 'local_ai.dart';

class GeminiAI {
  static const _model = 'gemini-2.0-flash';
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  /// Returns a Gemini response if [apiKey] is set, otherwise falls back to [LocalAI].
  static Future<String> respond({
    required String question,
    required AppDB db,
    required String apiKey,
  }) async {
    if (apiKey.trim().isEmpty) {
      return LocalAI.respond(question, db);
    }

    final localContext = LocalAI.respond('ملخص', db);
    final systemPrompt =
        'أنت مساعد ذكي لتطبيق إدارة باقات الاتصالات باللغة العربية. '
        'رد على سؤال المستخدم بشكل واضح ومختصر بالاعتماد على البيانات أدناه. '
        'استخدم الإيموجي والتنسيق المرتب.\n\n'
        'بيانات المستخدم الحالية:\n$localContext';

    final body = {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': '$systemPrompt\n\nالسؤال: $question'}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 1024,
      },
    };

    try {
      final res = await http
          .post(
            Uri.parse('$_endpoint?key=$apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (res.statusCode != 200) {
        final err = jsonDecode(res.body);
        final msg = err['error']?['message'] ?? 'خطأ ${res.statusCode}';
        return '❌ فشل الاتصال بـ Gemini:\n$msg\n\n— رجوع للمساعد المحلي —\n\n${LocalAI.respond(question, db)}';
      }

      final data = jsonDecode(utf8.decode(res.bodyBytes));
      final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
      if (text is String && text.trim().isNotEmpty) return text.trim();
      return LocalAI.respond(question, db);
    } catch (e) {
      return '⚠️ تعذّر الاتصال بـ Gemini (تحقق من الإنترنت).\n\n${LocalAI.respond(question, db)}';
    }
  }
}
