# Consumer Proguard rules for the phone_number Flutter plugin
# Keep the core classes of the libphonenumber library.
-keep class com.google.i18n.phonenumbers.** { *; }

# If the library uses enums extensively and accesses them by name,
# you might want to ensure enums are kept properly.
# This is often covered by general enum rules apps might have, but can be included for safety.
-keepclassmembers enum com.google.i18n.phonenumbers.** {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
