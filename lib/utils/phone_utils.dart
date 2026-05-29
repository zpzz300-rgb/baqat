// lib/utils/phone_utils.dart
import 'package:flutter/services.dart';

/// Converts Arabic/Eastern-Arabic digits to Western digits
String arabicToEnglish(String s) {
  const arabic  = ['٠','١','٢','٣','٤','٥','٦','٧','٨','٩'];
  const eastern = ['۰','۱','۲','۳','۴','۵','۶','۷','۸','۹'];
  for (int i = 0; i < 10; i++) {
    s = s.replaceAll(arabic[i],  i.toString());
    s = s.replaceAll(eastern[i], i.toString());
  }
  return s;
}

/// Input formatter: converts Arabic digits → English digits, keeps only digits + leading +
class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final converted = arabicToEnglish(newValue.text)
        .replaceAll(RegExp(r'[^\d+]'), '');
    return newValue.copyWith(
      text: converted,
      selection: TextSelection.collapsed(offset: converted.length),
    );
  }
}

String normalizeEgyptPhone(String raw) {
  var digits = arabicToEnglish(raw).replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  while (digits.startsWith('00')) {
    digits = digits.substring(2);
  }
  if (digits.startsWith('20')) {
    digits = digits.substring(2);
  }
  if (!digits.startsWith('0')) {
    digits = '0$digits';
  }
  return digits;
}

/// Input formatter for national ID — digits only, max 14
class NatIdInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = arabicToEnglish(newValue.text).replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 14 ? digits.substring(0, 14) : digits;
    return newValue.copyWith(
      text: limited,
      selection: TextSelection.collapsed(offset: limited.length),
    );
  }
}

/// Returns null if valid, or an error message string
String? validatePhone(String phone) {
  if (phone.isEmpty) return null; // optional fields pass
  // Egyptian mobile: 01[0-9]{9}
  if (RegExp(r'^01[0-9]{9}$').hasMatch(phone)) return null;
  // Egyptian landline: 0[2-9][0-9]{6,8}
  if (RegExp(r'^0[2-9][0-9]{6,8}$').hasMatch(phone)) return null;
  return 'رقم غير صحيح (موبايل: 01xxxxxxxxx / أرضي: 0xxxxxxxx)';
}

/// Check if phone exists in the system
String? checkDuplicate(String phone, List<String> existingPhones, {String? excludeId}) {
  if (phone.isEmpty) return null;
  if (existingPhones.contains(phone)) {
    return 'هذا الرقم موجود بالفعل في النظام ❌';
  }
  return null;
}
