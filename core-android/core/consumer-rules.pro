# Public facade only; internals stay obfuscatable.
-keep public class io.mobileshield.MobileShield {
    public *;
}
# JNI entry points are resolved by name.
-keepclasseswithmembernames,includedescriptorclasses class io.mobileshield.** {
    native <methods>;
}
