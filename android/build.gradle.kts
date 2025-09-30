
val ffmpegGitHubUser: String? = (findProperty("gpr.user") as String?) ?: System.getenv("GPR_USER")
val ffmpegGitHubToken: String? = (findProperty("gpr.key") as String?) ?: System.getenv("GPR_KEY")
allprojects {
    repositories {
        google()
        mavenCentral()
        maven {
            url = uri("https://maven.pkg.github.com/arthenica/ffmpeg-kit")
            credentials {
                username = ffmpegGitHubUser ?: ""
                password = ffmpegGitHubToken ?: ""
            }
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
