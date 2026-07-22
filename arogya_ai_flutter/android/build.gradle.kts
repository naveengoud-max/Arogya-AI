allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Redirect build directory to bypass Chinese character path in CMake / Ninja if on Windows local host
val isWindows = System.getProperty("os.name").lowercase().contains("win")
val customBuildDir = file("C:/Users/knave/arogya_build")

if (isWindows && customBuildDir.parentFile?.exists() == true) {
    rootProject.layout.buildDirectory.set(customBuildDir)
    subprojects {
        project.layout.buildDirectory.set(file("C:/Users/knave/arogya_build/${project.name}"))
    }
}

subprojects {
    project.evaluationDependsOn(":app")
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            freeCompilerArgs.add("-Xskip-metadata-version-check")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
