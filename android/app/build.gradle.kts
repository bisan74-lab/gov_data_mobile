plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.golfwindy.golf_windy"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.golfwindy.golf_windy"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // **Google Mobile Ads SDK가 API 23 이상을 요구한다.** Flutter 기본값
        // (21)을 그대로 두면 매니페스트 병합 단계에서 빌드가 깨진다
        // (`uses-sdk:minSdkVersion 21 cannot be smaller than version 23
        // declared in library [:google_mobile_ads]`). Flutter가 기본값을
        // 올리더라도 낮아지지 않도록 maxOf로 둔다.
        minSdk = maxOf(23, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // AndroidManifest의 AdMob 앱 ID. 기본값은 구글 공식 **테스트** 앱
        // ID이므로, 아무 설정 없이 빌드해도 실 수익 계정에 무효 트래픽이
        // 잡히지 않는다. 스토어 배포 빌드는 반드시 실제 값을 넘겨야 한다.
        // `flutter build`는 임의의 Gradle -P 인자를 넘겨주지 않으므로
        // 환경변수를 먼저 본다:
        //   ADMOB_APP_ID=ca-app-pub-XXXX~YYYY flutter build appbundle
        manifestPlaceholders["admobAppId"] =
            System.getenv("ADMOB_APP_ID")
                ?: (project.findProperty("admob_app_id") as String?)
                ?: "ca-app-pub-3940256099942544~3347511713"
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
