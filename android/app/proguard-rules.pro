# قواعد الضغط (R8) للنسخة النهائية
#
# 🐛 المشكلة اللي القواعد دي بتحلّها:
# لما بنبني release، R8 بيصغّر الكود وبيشيل معلومات «النوع العام» (Signature).
# مكتبة الإشعارات بتستخدم Gson علشان تقرا الإشعارات المحفوظة، وGson محتاج
# المعلومة دي بالظبط، فكان بيرمي:
#     java.lang.RuntimeException: Missing type parameter.
# وده كان بيوقّع تنبيهات مواعيد الفواتير كلها.
#
# ⚠️ الملف ده **بيزوّد** بس، ما بيلغيش قواعد فلاتر الافتراضية.

# ── Gson: سيب معلومات النوع العام والملاحظات ──────────────────────
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

-dontwarn sun.misc.**

# الكلاسات اللي Gson بيبنيها بنفسه لازم تفضل بأسماء حقولها
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken

-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# ── مكتبة الإشعارات المحلية ────────────────────────────────────────
# موصّى بيها في توثيق المكتبة نفسها — بتقرا كلاساتها بالاسم وقت التشغيل.
-keep class com.dexterous.** { *; }
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }
