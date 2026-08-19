import com.android.build.gradle.BaseExtension

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

// evaluationDependsOn(":app") kaldırıldı: afterEvaluate ile çakışıyordu ve
// eklenti compileSdk override'ını engelliyordu.

subprojects {
    val bumpSdk = {
        extensions.findByType(BaseExtension::class.java)?.apply {
            compileSdkVersion(36)
        }
    }
    if (state.executed) {
        bumpSdk()
    } else {
        afterEvaluate { bumpSdk() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
