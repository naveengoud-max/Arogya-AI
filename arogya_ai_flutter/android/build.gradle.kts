allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Redirect build directory to bypass Chinese character path in CMake / Ninja
rootProject.layout.buildDirectory.set(file("C:/Users/knave/arogya_build"))

subprojects {
    project.layout.buildDirectory.set(file("C:/Users/knave/arogya_build/${project.name}"))
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
