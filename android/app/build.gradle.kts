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

// Keep the historical production applicationId so signed APKs can update
// existing Hiraukan installations. CI may override it only for standalone
// validation builds that intentionally coexist with production.
val productionApplicationId = "com.meteor.kikoeruflutter"
val applicationIdOverride = System.getenv("HIRAUAKAN_APPLICATION_ID")
    ?.trim()
    ?.takeIf { it.isNotEmpty() }
val resolvedApplicationId = applicationIdOverride ?: productionApplicationId
val isStandaloneValidationBuild =
    resolvedApplicationId != productionApplicationId

android {
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
        applicationId = resolvedApplicationId
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
        manifestPlaceholders["appLabel"] = "Hiraukan"
    }

    signingConfigs {
        create("release") {
            if (hasReleaseKeystore && releaseKeystoreFile != null) {
                storeFile = releaseKeystoreFile
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = when {
                hasReleaseKeystore -> signingConfigs.getByName("release")
                isStandaloneValidationBuild -> signingConfigs.getByName("debug")
                else -> throw GradleException(
                    "Production release build requires the historical Hiraukan signing keystore. " +
                        "Refusing to create com.meteor.kikoeruflutter with a debug certificate."
                )
            }
        }
        debug {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // flutter_local_notifications and related Java APIs require desugaring.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // local_auth requires a FragmentActivity/AppCompat-compatible host.
    implementation("androidx.appcompat:appcompat:1.8.0")

    // Keep Media3 aligned for just_audio and the 32-bit FLAC extractor fix.
    val media3Version = "1.6.1"
    implementation("androidx.media3:media3-exoplayer:$media3Version")
    implementation("androidx.media3:media3-exoplayer-dash:$media3Version")
    implementation("androidx.media3:media3-exoplayer-hls:$media3Version")
    implementation("androidx.media3:media3-exoplayer-smoothstreaming:$media3Version")
}
