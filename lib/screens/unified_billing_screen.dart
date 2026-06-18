// lib/screens/unified_billing_screen.dart
// 🧾 القسم الموحّد للفواتير: فواتير الخطوط + مراجعة الفواتير + الخطوط الرئيسية
// مجمّعة في مكان واحد بتبويبات، وكل تبويب يحتفظ بكل الفلاتر الخاصة به.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/app_theme.dart';
import 'bills_screen.dart';
import 'company_invoices_screen.dart';
import 'main_lines_screen.dart';

class UnifiedBillingScreen extends StatelessWidget {
  const UnifiedBillingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Material(
            color: AppColors.blue2,
            child: SafeArea(
              bottom: false,
              child: TabBar(
                isScrollable: true,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                labelStyle:
                    GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 13),
                unselectedLabelStyle:
                    GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 13),
                tabs: const [
                  Tab(text: '📋 فواتير الخطوط'),
                  Tab(text: '🧾 مراجعة الفواتير'),
                  Tab(text: '📡 خطوط رئيسية'),
                ],
              ),
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                BillsScreen(),
                CompanyInvoicesScreen(),
                MainLinesScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
