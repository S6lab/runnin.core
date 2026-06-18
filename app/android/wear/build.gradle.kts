import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.s6lab.runnin.wear"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.s6lab.runnin"
        // Wear OS 3+ exige minSdk 30; Galaxy Watch 4+ roda Wear 3.x/4.x/5.x.
        // health-services 1.1.x já requer 30 também — alinhado.
        minSdk = 30
        targetSdk = 34
        // Track Wear OS dedicada tem série de versionCode INDEPENDENTE do
        // phone. Code 1 queimou em tentativa anterior de upload (Play Console
        // marca como usado mesmo se a release foi rejeitada). Bumpando pra 11
        // — fix de logo cortada em display redondo + safe padding 14→20dp.
        versionCode = 11
        versionName = "1.0.1"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    buildFeatures {
        compose = true
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    lint {
        // ComponentActivity das versões novas de activity-compose já implementa
        // o contrato de ActivityResult corretamente, mas o lint dispara
        // InvalidFragmentVersionForActivityResult porque vê apenas a versão
        // legacy do fragment. Não usamos Fragment no app Wear (Compose-only).
        disable += "InvalidFragmentVersionForActivityResult"
        abortOnError = false
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            // Reusa o mesmo keystore do app phone — Wearable Data Layer exige
            // que watch e phone usem a MESMA chave de assinatura, senão o
            // pareamento por capability falha em runtime ("Two apps with the
            // same package must be signed by the same key").
            if (rootProject.file("key.properties").exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
        debug {
            // Debug usa o keystore default do Android Studio (~/.android/debug.keystore)
            // tanto no phone quanto no watch — pareamento funciona em dev.
        }
    }
}

dependencies {
    implementation(platform("androidx.compose:compose-bom:2025.01.00"))
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.7")

    // Compose runtime + UI
    implementation("androidx.compose.runtime:runtime")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.foundation:foundation")
    debugImplementation("androidx.compose.ui:ui-tooling")

    // Wear Compose (Material2 estável — Material3 do Wear ainda em alpha).
    // Material2 do Wear tem Text, Button, MaterialTheme com Wear specifics
    // (round display, swipe to dismiss). API similar pro que precisamos.
    implementation("androidx.wear.compose:compose-material:1.4.1")
    implementation("androidx.wear.compose:compose-foundation:1.4.1")
    implementation("androidx.wear.compose:compose-navigation:1.4.1")

    // Material icons extended pro ChevronRight / Pause usados nos componentes.
    implementation("androidx.compose.material:material-icons-extended")

    // Wear OS runtime + tiles/complications (base — não usamos tiles ainda)
    implementation("androidx.wear:wear:1.3.0")

    // Health Services — ExerciseClient (HKWorkoutSession equivalente)
    // 1.1.0-rc02 já está na app phone; mesma versão pra evitar drift.
    implementation("androidx.health:health-services-client:1.1.0-rc02")
    implementation("com.google.guava:guava:33.4.0-android")

    // Wearable Data Layer (MessageClient + DataClient + CapabilityClient).
    // Equivalente Android do WatchConnectivity (WCSession sendMessage +
    // updateApplicationContext) do iOS. Roda em phone E em watch.
    implementation("com.google.android.gms:play-services-wearable:19.0.0")

    // Coroutines pra bridging do Futures→suspend e callbacks→Flow
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.9.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-guava:1.9.0")

    // JSON (já vem com kotlinx-serialization; reusa org.json builtin pra
    // simplificar — payloads são pequenos)
}
