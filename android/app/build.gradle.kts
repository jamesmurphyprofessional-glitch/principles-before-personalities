plugins {
    id("com.android.application")
}

android {
    namespace = "com.jamesmurphy.principlesbeforepersonalities"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.jamesmurphy.principlesbeforepersonalities"
        minSdk = 24
        targetSdk = 35
        versionCode = 2
        versionName = "1.0.1"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            // Sideload build: signed with the local debug key so it installs without a Play Store listing.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}
