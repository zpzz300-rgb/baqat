// lib/utils/image_utils.dart
import 'package:image_picker/image_picker.dart';

/// أداة موحَّدة لاختيار الصور مع ضغط تلقائي قبل رفعها
/// على Supabase storage لتقليل استهلاك الباندويث والتخزين.
class ImageUtils {
  static const double _maxDimension = 1600;
  static const int _quality = 70;

  /// التقاط/اختيار صورة مع ضغط تلقائي
  static Future<XFile?> pickCompressed({
    required ImageSource source,
  }) async {
    final picker = ImagePicker();
    return picker.pickImage(
      source: source,
      imageQuality: _quality,
      maxWidth: _maxDimension,
      maxHeight: _maxDimension,
    );
  }
}
