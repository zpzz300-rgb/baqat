// lib/widgets/ai_modal.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
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

  // تحليلات فورية محلية — تشتغل من غير نت ومن غير API key، بأرقام حقيقية
  final List<Map<String, String>> _insightBtns = [
    {'label': '🧠 ملخص فوري', 'k': 'summary'},
    {'label': '🏆 أعلى الخطوط ربحاً', 'k': 'top'},
    {'label': '🔴 خطوط خاسرة', 'k': 'loss'},
    {'label': '💸 أعلى المديونين', 'k': 'debt'},
    {'label': '📦 توزيع الباقات', 'k': 'packages'},
    {'label': '💳 انتظام الدفع', 'k': 'regularity'},
    {'label': '📈 رفع الأسعار', 'k': 'priceup'},
    {'label': '⚪ خطوط بدون فاتورة', 'k': 'nobill'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
          // Instant local insights (no API needed)
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              itemCount: _insightBtns.length,
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => _showInsight(_insightBtns[i]['k']!),
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2F1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF80CBC4)),
                  ),
                  child: Center(
                    child: Text(_insightBtns[i]['label']!,
                        style: GoogleFonts.cairo(
                            color: const Color(0xFF00695C),
                            fontWeight: FontWeight.w700,
                            fontSize: 11)),
                  ),
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
            decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
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

  // ── تحليلات فورية محلية (بدون نت / بدون API) ──────────────────
  void _showInsight(String kind) {
    final db = context.read<AppProvider>().db;
    String report;
    switch (kind) {
      case 'summary':     report = _insightSummary(db); break;
      case 'top':         report = _insightTop(db); break;
      case 'loss':        report = _insightLoss(db); break;
      case 'debt':        report = _insightDebt(db); break;
      case 'packages':    report = _insightPackages(db); break;
      case 'regularity':  report = _insightRegularity(db); break;
      case 'priceup':     report = _insightPriceUp(db); break;
      case 'nobill':      report = _insightNoBill(db); break;
      default:            report = 'مفيش تحليل متاح.';
    }
    setState(() => _messages.add({'role': 'assistant', 'content': report}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  double _bill(Group g) =>
      g.fixedBillAmount > 0 ? g.fixedBillAmount : (g.actualBillAmount ?? 0);
  String _gName(Group g) =>
      g.ownerName?.isNotEmpty == true ? g.ownerName! : g.phone;

  String _insightSummary(AppDB db) {
    final income = db.members.fold<double>(0, (s, m) => s + m.price);
    final profit = db.groups.fold<double>(0, (s, g) => s + db.groupProfit(g.id));
    final debt = db.totalDebt;
    final debtors = db.members.where((m) => m.balance < 0).length;
    return '🧠 ملخص فوري\n\n'
        '📡 الخطوط: ${db.groups.length}\n'
        '👥 العملاء: ${db.members.length}\n'
        '📥 الدخل الشهري: ${income.toStringAsFixed(0)} ج\n'
        '💰 صافي ربح الفواتير: ${profit.toStringAsFixed(0)} ج\n'
        '📋 إجمالي الديون: ${debt.toStringAsFixed(0)} ج (على $debtors عميل)\n\n'
        '${profit < 0 ? "⚠️ في خطوط بتخسر — بُص على «خطوط خاسرة»." : "✅ الوضع العام إيجابي."}';
  }

  String _insightTop(AppDB db) {
    final ranked = db.groups
        .map((g) => (g, db.groupProfit(g.id)))
        .where((e) => _bill(e.$1) > 0)
        .toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    if (ranked.isEmpty) return '🏆 مفيش خطوط بفاتورة محددة لحساب الربح.';
    final top = ranked.take(5).toList();
    final b = StringBuffer('🏆 أعلى 5 خطوط ربحاً\n\n');
    for (var i = 0; i < top.length; i++) {
      b.writeln('${i + 1}. ${_gName(top[i].$1)} — ${top[i].$2.toStringAsFixed(0)} ج');
    }
    return b.toString().trim();
  }

  String _insightLoss(AppDB db) {
    final losers = db.groups
        .where((g) => _bill(g) > 0 && db.groupProfit(g.id) < 0)
        .map((g) => (g, db.groupProfit(g.id)))
        .toList()
      ..sort((a, b) => a.$2.compareTo(b.$2));
    if (losers.isEmpty) return '✅ مفيش خطوط خاسرة — كل خط بيغطّي فاتورته.';
    final b = StringBuffer('🔴 خطوط خاسرة (دخلها أقل من فاتورتها)\n\n');
    for (final e in losers) {
      b.writeln('• ${_gName(e.$1)} — خسارة ${e.$2.abs().toStringAsFixed(0)} ج');
    }
    b.writeln('\n💡 ارفع أسعار عملاء الخطوط دي أو راجع الفاتورة الثابتة.');
    return b.toString().trim();
  }

  String _insightDebt(AppDB db) {
    final debtors = db.members.where((m) => m.balance < 0).toList()
      ..sort((a, b) => a.balance.compareTo(b.balance));
    if (debtors.isEmpty) return '🎉 مفيش مديونيات — كله سداد!';
    final top = debtors.take(8).toList();
    final b = StringBuffer('💸 أعلى المديونين\n\n');
    for (final m in top) {
      b.writeln('• ${m.name} — ${(-m.balance).toStringAsFixed(0)} ج');
    }
    final total = debtors.fold<double>(0, (s, m) => s + (-m.balance));
    b.writeln('\nإجمالي الديون: ${total.toStringAsFixed(0)} ج على ${debtors.length} عميل.');
    return b.toString().trim();
  }

  String _insightPackages(AppDB db) {
    final byGb = <int, int>{};
    for (final m in db.members) {
      if (m.type != 'regular') continue;
      byGb[m.gb] = (byGb[m.gb] ?? 0) + 1;
    }
    if (byGb.isEmpty) return '📦 مفيش عملاء باقات لعرضهم.';
    final keys = byGb.keys.toList()..sort();
    final b = StringBuffer('📦 توزيع العملاء حسب حجم الباقة\n\n');
    for (final gb in keys) {
      b.writeln('• $gb جيجا → ${byGb[gb]} عميل');
    }
    return b.toString().trim();
  }

  String _insightRegularity(AppDB db) {
    int green = 0, yellow = 0, red = 0, none = 0;
    for (final m in db.members) {
      switch (m.paymentFlag) {
        case 'green': green++; break;
        case 'yellow': yellow++; break;
        case 'red': red++; break;
        default: none++;
      }
    }
    return '💳 انتظام الدفع\n\n'
        '🟢 منتظم: $green عميل\n'
        '🟡 متذبذب: $yellow عميل\n'
        '🔴 متعثّر: $red عميل\n'
        '⚪ غير مصنّف: $none عميل\n\n'
        '${red > 0 ? "💡 ركّز على المتعثرين دول الأول في التحصيل." : "✅ مفيش متعثرين مصنّفين."}';
  }

  String _insightPriceUp(AppDB db) {
    // الخطوط اللي ربحها ضعيف أو سالب — مرشحة لرفع السعر
    final candidates = db.groups
        .where((g) => _bill(g) > 0)
        .map((g) => (g, db.groupProfit(g.id)))
        .where((e) => e.$2 < 50)
        .toList()
      ..sort((a, b) => a.$2.compareTo(b.$2));
    if (candidates.isEmpty) {
      return '📈 كل خطوطك ربحها كويس (فوق 50 ج). مفيش حاجة محتاجة رفع عاجل.';
    }
    final b = StringBuffer('📈 خطوط مرشّحة لرفع السعر (ربحها ضعيف أو سالب)\n\n');
    for (final e in candidates.take(8)) {
      b.writeln('• ${_gName(e.$1)} — ربح ${e.$2.toStringAsFixed(0)} ج');
    }
    b.writeln('\n💡 استخدم «رفع أسعار الاشتراكات» من تجديد الاشتراكات لرفعهم دفعة واحدة.');
    return b.toString().trim();
  }

  String _insightNoBill(AppDB db) {
    final noBill = db.groups.where((g) => _bill(g) <= 0 && g.type != 'manual').toList();
    if (noBill.isEmpty) return '✅ كل الخطوط متحدد لها فاتورة ثابتة — الربح بيتحسب صح.';
    final b = StringBuffer('⚪ خطوط بدون فاتورة ثابتة (ربحها مش بيتحسب)\n\n');
    for (final g in noBill) {
      b.writeln('• ${_gName(g)}');
    }
    b.writeln('\n💡 افتح إعدادات كل خط وحط «المبلغ الثابت للفاتورة» عشان الربح يظهر.');
    return b.toString().trim();
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
