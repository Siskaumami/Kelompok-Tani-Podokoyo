import java.net.URI
import java.util.Base64

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val uploadValues = listOf("TANI_KEYSTORE_PATH", "TANI_KEYSTORE_PASSWORD", "TANI_KEY_ALIAS", "TANI_KEY_PASSWORD")
    .associateWith { System.getenv(it).orEmpty() }
val uploadConfigured = uploadValues.values.all { it.isNotBlank() }

android {
    namespace = "id.podokoyo.tanidesa"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    defaultConfig {
        applicationId = "id.podokoyo.tanidesa"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    signingConfigs {
        if (uploadConfigured) {
            create("upload") {
                storeFile = file(uploadValues.getValue("TANI_KEYSTORE_PATH"))
                storePassword = uploadValues.getValue("TANI_KEYSTORE_PASSWORD")
                keyAlias = uploadValues.getValue("TANI_KEY_ALIAS")
                keyPassword = uploadValues.getValue("TANI_KEY_PASSWORD")
            }
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("upload")
            isMinifyEnabled = true
            isShrinkResources = true
        }
    }
}

val verifyReleaseConfiguration = tasks.register("verifyReleaseConfiguration") {
    doLast {
        val defines = project.findProperty("dart-defines")?.toString().orEmpty().split(",")
            .filter { it.isNotEmpty() }
            .map { String(Base64.getDecoder().decode(it), Charsets.UTF_8) }
            .associate { it.substringBefore("=") to it.substringAfter("=", "") }
        val api = defines["API_BASE_URL"].orEmpty()
        val uri = runCatching { URI(api) }.getOrNull()
        require(uri != null && uri.scheme == "https" && !uri.host.isNullOrBlank() &&
            uri.rawUserInfo == null && uri.rawQuery == null && uri.rawFragment == null &&
            uri.path in listOf("", "/", "/api/v1", "/api/v1/")) {
            "Release requires --dart-define=API_BASE_URL=https://your-service-origin"
        }
        val origin = defines["APP_ORIGIN"].orEmpty()
        if (origin.isNotBlank()) {
            val app = URI(origin)
            require(app.scheme == "https" && !app.host.isNullOrBlank() && app.rawUserInfo == null &&
                app.rawQuery == null && app.rawFragment == null && app.path in listOf("", "/")) {
                "APP_ORIGIN must be the HTTPS APP_URL origin."
            }
        }
        require(uploadConfigured) { "Configure all four TANI_KEYSTORE_* / TANI_KEY_* environment values before a release." }
    }
}
tasks.configureEach {
    if (name == "preReleaseBuild") dependsOn(verifyReleaseConfiguration)
}

kotlin {
    compilerOptions { jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17 }
}
flutter { source = "../.." }
