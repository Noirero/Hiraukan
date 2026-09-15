import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}
val releaseKeystoreFile = keystoreProperties.getProperty("storeFile")?.let(rootProject::file)
val hasReleaseKeystore = releaseKeystoreFile?.exists() == true
val testKeystoreFile = rootProject.file("hiraukan-test-key.jks")

android {
    // Keep the Kotlin/Java namespace stable for now so native channel classes do not need to move.
    // Android install identity is controlled by applicationId below.
    namespace = "com.meteor.kikoeruflutter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // Hiraukan owns a distinct Android identity instead of reusing KikoFlu's package.
        applicationId = "com.noirero.hiraukan"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
        manifestPlaceholders["appLabel"] = "Hiraukan"
    }

    signingConfigs {
        create("hiraukanTest") {
            storeFile = testKeystoreFile
            storePassword = "hiraukan-test-only-2026"
            keyAlias = "hiraukan-test"
            keyPassword = "hiraukan-test-only-2026"
        }
        create("release") {
            if (hasReleaseKeystore && releaseKeystoreFile != null) {
                storeFile = releaseKeystoreFile
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    flavorDimensions += "distribution"
    productFlavors {
        // AGP reserves flavor names beginning with "test". Keep the user-facing
        // identity as Hiraukan Test while using a neutral internal flavor name.
        create("qa") {
            dimension = "distribution"
            applicationIdSuffix = ".test"
            versionNameSuffix = "-test"
            manifestPlaceholders["appLabel"] = "Hiraukan Test"
            signingConfig = signingConfigs.getByName("hiraukanTest")
        }
        create("prod") {
            dimension = "distribution"
            manifestPlaceholders["appLabel"] = "Hiraukan"
            if (hasReleaseKeystore) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }

    buildTypes {
        release {
            // Signing is selected by flavor. QA uses the committed test-only key;
            // prod is signed only when the permanent release key is provided.
        }
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// just_audio 0.9.44 is compiled against Media3 1.4.1. Keep all Media3
// artifacts aligned on 1.6.1, which contains the 32-bit FLAC extractor fix,
// while retaining Android's native AudioTrack playback backend.
dependencies {
    // flutter_local_notifications 10+ requires core library desugaring on
    // Android even when scheduled notifications are not used.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // local_auth's biometric prompt requires an AppCompat-compatible Activity
    // theme. Declare it explicitly instead of relying on a transitive AndroidX
    // dependency so the theme resources stay deterministic across plugin updates.
    implementation("androidx.appcompat:appcompat:1.8.0")

    val media3Version = "1.6.1"
    implementation("androidx.media3:media3-exoplayer:$media3Version")
    implementation("androidx.media3:media3-exoplayer-dash:$media3Version")
    implementation("androidx.media3:media3-exoplayer-hls:$media3Version")
    implementation("androidx.media3:media3-exoplayer-smoothstreaming:$media3Version")
}
