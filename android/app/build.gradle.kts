import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) load(f.inputStream())
}

android {
    configurations.all {
        resolutionStrategy {
            force("androidx.core:core-ktx:1.13.1")
        }
    }

    namespace = "com.example.drunken_sailor"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        create("release") {
            keyAlias = keyProps["keyAlias"] as String
            keyPassword = keyProps["keyPassword"] as String
            storeFile = file(keyProps["storeFile"] as String)
            storePassword = keyProps["storePassword"] as String
        }
    }

    defaultConfig {
        applicationId = "com.example.drunken_sailor"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
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
