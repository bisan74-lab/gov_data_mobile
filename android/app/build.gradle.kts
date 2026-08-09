import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 릴리스 서명 정보. `android/key.properties`(gitignore됨)가 있을 때만 읽어
// 실제 업로드 키로 서명하고, 없으면 아래에서 debug 키로 폴백한다.
// **이 폴백을 없애면 키가 없는 CI(테스트 APK 빌드)나 새로 클론한 환경에서
// 빌드가 깨진다.**
// 파일 형식:
//   storeFile=/절대/경로/upload-keystore.jks
//   storePassword=...
//   keyAlias=golfwindy
//   keyPassword=...
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val hasReleaseKeystore = keystoreProperties.getProperty("storeFile") != null

// Play Console이 요구하는 대상 API 수준.
//
// **Flutter의 기본값(`flutter.targetSdkVersion`)을 그대로 쓰면 안 된다** —
// Flutter 3.32.5의 기본값은 35(Android 15)인데, Google Play는 2026-08-31부터
// **최신 Android 출시로부터 1년 이내**(현재 36 = Android 16)를 요구하고,
// 그보다 낮으면 **앱 업데이트 제출 자체가 막힌다.** Flutter를 올리지 않고도
// 대응할 수 있도록 여기서 명시적으로 고정한다.
//
// Play가 요구 수준을 올리면(매년 8월경) 이 값을 올리고, AGP가 그 API를
// 지원하는 버전인지 `settings.gradle.kts`에서 함께 확인한다. 릴리스·CI
// 워크플로도 `sdkmanager`로 해당 플랫폼을 미리 설치해야 한다 — 없으면
// "failed to find target with hash string android-NN"으로 깨진다.
val playTargetSdk = 36

android {
    namespace = "com.golfwindy.golf_windy"
    // compileSdk는 targetSdk 이상이어야 한다.
    compileSdk = maxOf(playTargetSdk, flutter.compileSdkVersion)
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
        targetSdk = playTargetSdk
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // AndroidManifest의 AdMob 앱 ID. 기본값은 구글 공식 **테스트** 앱
        // ID이므로, 아무 설정 없이 빌드해도 실 수익 계정에 무효 트래픽이
        // 잡히지 않는다. 스토어 배포 빌드는 반드시 실제 값을 넘겨야 한다.
        // `flutter build`는 임의의 Gradle -P 인자를 넘겨주지 않으므로
        // 환경변수를 먼저 본다:
        //   ADMOB_APP_ID=ca-app-pub-XXXX~YYYY flutter build appbundle
        //
        // **빈 문자열은 "없음"으로 친다**(`takeIf { it.isNotBlank() }`).
        // 환경변수를 빈 값으로 넘기는 일이 흔한데(워크플로가 조건부로
        // 주입할 때), Kotlin `?:`는 null에서만 폴백하므로 그대로 두면
        // 매니페스트에 `android:value=""`가 박힌다. 그러면 앱이 켜지자마자
        // 광고 SDK 초기화에서 죽는다("initialized without an application ID").
        manifestPlaceholders["admobAppId"] =
            System.getenv("ADMOB_APP_ID")?.takeIf { it.isNotBlank() }
                ?: (project.findProperty("admob_app_id") as String?)
                    ?.takeIf { it.isNotBlank() }
                ?: "ca-app-pub-3940256099942544~3347511713"
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // 업로드 키가 준비된 환경에서만 실제 서명한다. 없으면 debug 키로
            // 서명해 `flutter build apk --release`(테스트 배포)가 계속 된다 —
            // 단, **debug 키로 서명된 빌드는 Play Store에 올릴 수 없다.**
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
