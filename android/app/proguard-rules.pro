# Project-specific R8 rules. The Flutter Gradle plugin adds its own
# flutter_proguard_rules.pro on top of these.

# The Flutter engine references Play Core classes for deferred components.
# They are compile-only and not used by this app (it has no Play Store
# dependency, which keeps it F-Droid clean), so let R8 strip the references
# instead of failing on the missing classes.
-dontwarn com.google.android.play.core.**
