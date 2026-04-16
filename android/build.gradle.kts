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

    // FORZADO DE SDK PARA PLUGINS (Resuelve el error lStar)
    project.afterEvaluate {
        val android = project.extensions.findByName("android")
        if (android is com.android.build.gradle.BaseExtension) {
            android.compileSdkVersion(36)
            android.defaultConfig.targetSdkVersion(34)
        }
    }

    // Parche específico para flutter_bluetooth_serial
    if (project.name == "flutter_bluetooth_serial") {
        project.afterEvaluate {
            val android = project.extensions.findByName("android")
            if (android != null) {
                // 1. Forzamos el namespace
                try {
                    val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                    setNamespace.invoke(android, "io.github.edufolly.flutter_bluetooth_serial")
                } catch (e: Exception) {
                    // Ignorar
                }

                // 2. Limpiamos el AndroidManifest.xml del plugin
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
