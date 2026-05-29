// lib/widgets/ai_modal.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_provider.dart';
import '../services/app_theme.dart';
import '../services/gemini_ai.dart';

class AiModal extends StatefulWidget {
  const AiModal({super.key});
  @override
  State<AiModal> createState() => _AiModalState();
}

class _AiModalState extends State<AiModal> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _loading = false;

  final List<Map<String, String>> _quickBtns = [
    {'label': '📊 حلل بياناتي', 'q': 'حلل بياناتي واعطني ملخص شامل'},
    {'label': '💸 أكبر المديونين', 'q': 'من أكبر المديونين وكيف أتعامل معهم؟'},
    {'label': '💬 رسالة تذكير', 'q': 'اكتب رسالة واتساب لتذكير العملاء بالسداد'},
    {'label': '📈 توقعات الربح', 'q': 'ما توقعات الربح الشهر القادم؟'},
    {'label': '💡 اقتراحات', 'q': 'إيه اقتراحاتك لتحسين عملي؟'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6a1b9a), Color(0xFFab47bc)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const Text('🤖', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('مساعد الذكاء الاصطناعي', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                    Text(_loading ? '⏳ يفكر...' : '✨ جاهز', style: GoogleFonts.cairo(color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),

          // Quick buttons
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              itemCount: _quickBtns.length,
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => _sendMsg(_quickBtns[i]['q']!),
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFf3e5f5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_quickBtns[i]['label']!, style: GoogleFonts.cairo(color: const Color(0xFF6a1b9a), fontWeight: FontWeight.w700, fontSize: 11)),
                ),
              ),
            ),
          ),
          const Divider(height: 1),

          // Messages
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🤖', style: TextStyle(fontSize: 36)),
                        const SizedBox(height: 8),
                        Text('مرحباً! أنا مساعدك الذكي', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 14)),
                        Text('اسألني عن عملاءك أو بياناتك', style: GoogleFonts.cairo(color: AppColors.muted, fontSize: 12)),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final msg = _messages[i];
                      final isUser = msg['role'] == 'user';
                      return Align(
                        alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          decoration: BoxDecoration(
                            color: isUser ? AppColors.blueLight : const Color(0xFFf3e5f5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            msg['content'] ?? '',
                            style: GoogleFonts.cairo(fontSize: 13, color: isUser ? AppColors.blue2 : const Color(0xFF4a148c)),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Input
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    decoration: InputDecoration(
                      hintText: 'اسألني أي حاجة...',
                      hintStyle: GoogleFonts.cairo(fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFFf5f5f5),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (v) => _sendMsg(v),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _sendMsg(_inputCtrl.text),
                  child: Container(
                    width: 42, height: 42,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0xFF6a1b9a), Color(0xFFab47bc)]),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMsg(String text) async {
    if (text.trim().isEmpty || _loading) return;
    final prov = context.read<AppProvider>();
    _inputCtrl.clear();

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _loading = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });

    final reply = await GeminiAI.respond(
      question: text,
      db: prov.db,
      apiKey: prov.apiKey,
    );

    setState(() {
      _messages.add({'role': 'assistant', 'content': reply});
      _loading = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }
}
