import java.util.Properties

// Release signing. The keystore never enters the repository: locally it is
// named by android/key.properties, in CI it is written from a secret. Both
// are gitignored.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasReleaseKeystore = keystoreProperties.containsKey("storeFile")

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "dev.ben.nemo"
    // Ahead of Flutter's own default (36), because flutter_secure_storage 11
    // is built against 37 and refuses to link into an app compiled against
    // less. AGP 9.1 only "recommends" at most 36 and compiles this happily.
    // Put it back to flutter.compileSdkVersion once Flutter's default has
    // caught up, so there is one place deciding this again.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications needs java.time on older devices.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.ben.nemo"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Notifications with channels and boot receivers; 26 = Android 8.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Falls back to the debug key when no keystore is configured, so
            // `flutter run --release` still works on a fresh clone. Anything
            // published has to carry the real key: the debug one ships with
            // every Android SDK, so a build signed with it can be replaced in
            // place by anyone.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// Flutter's tooling looks for build/app/outputs/flutter-apk/app-<abi>-release.apk
// by that exact name, so those keep it. These copies say which app and which
// version they are, which is what matters once a file leaves the machine.
// A Sync rather than a Copy, so the folder mirrors the last build instead of
// collecting APKs from every build that came before.
val namedReleaseApks =
    tasks.register<Sync>("namedReleaseApks") {
        description = "Copies the release APKs under a name carrying the app and version."
        val version = "${flutter.versionName}+${flutter.versionCode}"
        from(layout.buildDirectory.dir("outputs/flutter-apk")) { include("*-release.apk") }
        into(layout.buildDirectory.dir("outputs/release"))
        rename { original ->
            val abi = Regex("^app-(.+)-release\\.apk$").find(original)?.groupValues?.get(1)
            "nemo-$version-${abi ?: "universal"}.apk"
        }
        doLast {
            logger.lifecycle("named APKs in ${destinationDir}")
        }
    }

tasks.matching { it.name == "assembleRelease" }.configureEach {
    finalizedBy(namedReleaseApks)
}
