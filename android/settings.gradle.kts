pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // **AGP는 대상 API 수준(`playTargetSdk`)을 지원하는 버전이어야 한다.**
    // 8.7.3은 API 35까지만 검증돼 있어 compileSdk 36에서 경고·실패가 난다.
    // `playTargetSdk`를 올릴 때 이 버전도 함께 확인한다.
    // (Gradle 래퍼가 8.12라 AGP 8.9.x의 요구치는 이미 넘는다.)
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

include(":app")
