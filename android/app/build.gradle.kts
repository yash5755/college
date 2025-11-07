plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.vvceapp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.vvceapp"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // Optional: JVM toolchain for Kotlin/Java alignment
    kotlin {
        jvmToolchain(17)
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Required for desugaring (Java 8+ APIs)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    // Multidex support for Firebase plugins
    implementation("androidx.multidex:multidex:2.0.1")
}
