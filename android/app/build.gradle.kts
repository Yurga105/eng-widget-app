import java.io.FileInputStream
import java.util.Properties

// Release-подпись (план публикации в Google Play, фаза 0): путь к
// upload-keystore и пароли живут в android/key.properties — файл и сам
// keystore в git не попадают (.gitignore). Файла нет — release-сборка
// роняется гардом внизу файла, debug-сборки не затронуты.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.english.widget.eng_widget_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications требует core library desugaring
        // (java.time и др. на старых устройствах) — README плагина.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.english.widget.eng_widget_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = requireNotNull(keystoreProperties.getProperty("keyAlias")) {
                    "android/key.properties: нет keyAlias"
                }
                keyPassword = requireNotNull(keystoreProperties.getProperty("keyPassword")) {
                    "android/key.properties: нет keyPassword"
                }
                storeFile = file(
                    requireNotNull(keystoreProperties.getProperty("storeFile")) {
                        "android/key.properties: нет storeFile"
                    },
                )
                storePassword = requireNotNull(keystoreProperties.getProperty("storePassword")) {
                    "android/key.properties: нет storePassword"
                }
            }
        }
    }

    buildTypes {
        release {
            // Upload-ключ из key.properties; debug-подпись ниже — заглушка
            // конфигурации: релиз без key.properties роняет гард внизу файла
            // (в debug-подписи релиз не собирается — фаза 0 плана публикации).
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

dependencies {
    // Нужен для isCoreLibraryDesugaringEnabled (требование
    // flutter_local_notifications).
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")

    // Этап 5: JVM-тесты WordOfDayCalculator (паритет формулы с Dart,
    // риск №4 в PLAN.md §9). junit — раннер; org.json — рабочая реализация
    // для десктопа (в android.jar классы org.json — заглушки «not mocked»).
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20240303")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

// Релиз без upload-ключа не собираем: конфигурация выше подставляет
// debug-подпись как заглушку, а этот гард роняет сборку с понятной
// ошибкой до выполнения задач (план публикации в Google Play, фаза 0).
gradle.taskGraph.whenReady {
    if (hasReleaseSigning) {
        return@whenReady
    }
    val releaseTasks = allTasks.filter { it.name.contains("Release") }
    if (releaseTasks.isNotEmpty()) {
        throw GradleException(
            "Release-сборка требует android/key.properties с upload-ключом " +
                "(план публикации в Google Play, фаза 0). Создайте keystore и " +
                "key.properties — debug-сборкам файл не нужен. Задачи: " +
                releaseTasks.take(3).joinToString(", ") { it.name } +
                " … (всего ${releaseTasks.size})",
        )
    }
}
