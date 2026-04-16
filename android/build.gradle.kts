import java.io.File

allprojects {
    repositories {
        google()
        mavenCentral()
    }

    // Estrategia de resolución global para evitar el error lStar
    configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "androidx.core") {
                useVersion("1.13.1")
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
    // Forzamos compileSdkVersion en plugins problemáticos
    afterEvaluate {
        val android = project.extensions.findByName("android")
        if (android is com.android.build.gradle.BaseExtension) {
            // Si el SDK es menor a 33, lo subimos a 34 para que reconozca lStar
            if (android.compileSdkVersion != null && 
                (android.compileSdkVersion!!.startsWith("android-") && 
                 android.compileSdkVersion!!.substringAfter("android-").toInt() < 33)) {
                android.compileSdkVersion(34)
            }
        }
    }

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
