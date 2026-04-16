import java.io.File

allprojects {
    repositories {
        google()
        mavenCentral()
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

    // Forzado de SDK para plugins sin usar afterEvaluate
    project.plugins.withType<com.android.build.gradle.api.AndroidBasePlugin> {
        project.extensions.configure<com.android.build.gradle.BaseExtension> {
            compileSdkVersion(36)
            defaultConfig {
                targetSdkVersion(34)
            }
        }
    }

    // Parche específico para flutter_bluetooth_serial
    if (project.name == "flutter_bluetooth_serial") {
        project.afterEvaluate {
            val android = project.extensions.findByName("android")
            if (android != null) {
                try {
                    val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                    setNamespace.invoke(android, "io.github.edufolly.flutter_bluetooth_serial")
                } catch (e: Exception) { }

                val manifestFile = project.file("src/main/AndroidManifest.xml")
                if (manifestFile.exists()) {
                    val content = manifestFile.readText()
                    if (content.contains("package=")) {
                        val updatedContent = content.replace(Regex("package=\"[^\"]*\""), "")
                        manifestFile.writeText(updatedContent)
                    }
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
