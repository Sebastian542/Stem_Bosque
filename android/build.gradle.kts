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
    // Resolución de dependencias para evitar lStar
    configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "androidx.core") {
                useVersion("1.13.1")
            }
        }
    }

    // Parche para bluetooth_serial sin afterEvaluate si es posible
    if (project.name == "flutter_bluetooth_serial") {
        // Solo aplicar si el proyecto aún no está evaluado
        if (!project.state.executed) {
            project.afterEvaluate {
                val android = project.extensions.findByName("android")
                if (android != null) {
                    try {
                        val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                        setNamespace.invoke(android, "io.github.edufolly.flutter_bluetooth_serial")
                    } catch (e: Exception) { }
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
