import org.gradle.api.GradleException

pluginManagement {
    val flutterSdkPath =
        run {
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
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        google()
        mavenCentral()
        maven {
            url = uri("https://maven.pkg.github.com/arthenica/ffmpeg-kit")
            credentials {
                // gradle.properties 또는 환경 변수에서 읽기
                val gprUser = (providers.gradleProperty("gpr.user").orNull
                    ?: System.getenv("GPR_USER"))
                    ?.takeIf { it.isNotBlank() }
                    ?: throw GradleException(
                        "GitHub Packages username is missing. " +
                            "Set gpr.user in ~/.gradle/gradle.properties or export GPR_USER."
                    )
                val gprKey = (providers.gradleProperty("gpr.key").orNull
                    ?: System.getenv("GPR_KEY"))
                    ?.takeIf { it.isNotBlank() }
                    ?: throw GradleException(
                        "GitHub Packages token is missing. " +
                            "Set gpr.key in ~/.gradle/gradle.properties or export GPR_KEY."
                    )

                username = gprUser
                password = gprKey
            }
        }
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false
    // START: FlutterFire Configuration
    id("com.google.gms.google-services") version("4.3.15") apply false
    // END: FlutterFire Configuration
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

include(":app")
