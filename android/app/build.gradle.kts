// Kotlin DSL icinde `java` Gradle'in kendi eklentisine cozuluyor ve
// `java.util` paketini golgeliyor; bu yuzden acikca import ediliyor.
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.rpgproje.dm_table"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.rpgproje.dm_table"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Kendi imzalama anahtarin varsa `android/key.properties` dosyasina
        // storeFile / storePassword / keyAlias / keyPassword yazman yeterli;
        // asagidaki blok onu kendiliginden kullanir.
        val keyProperties = Properties()
        val keyPropertiesFile = rootProject.file("key.properties")
        if (keyPropertiesFile.exists()) {
            keyPropertiesFile.inputStream().use { keyProperties.load(it) }
            create("release") {
                storeFile = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Kendi anahtarin yoksa debug anahtariyla imzalaniyor. Kisisel
            // kurulum (sideload) icin bu yeterli; yalnizca Play Store'a
            // yuklemek gerekirse gercek bir anahtar sart.
            //
            // DIKKAT: imzalama anahtari degisirse Android uygulamayi ayri bir
            // uygulama sayar -- guncelleme yerine once kaldirmak gerekir ve
            // cihazdaki kampanya verisi silinir. Once yedek al.
            signingConfig = if (signingConfigs.findByName("release") != null) {
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
