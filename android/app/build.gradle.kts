plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

// The word bank lives at the repo root (shared/words) and is shared with the
// iOS app. It is packaged as assets/words/*.txt — never copy it into android/.
val sharedDir = rootProject.file("../shared")

// AdMob IDs. Debug builds always use Google's test IDs. Release builds read the
// real ones from Gradle properties (~/.gradle/gradle.properties or -P…) and fall
// back to the test IDs, which show test ads and earn nothing.
object TestAdIds {
    const val APP = "ca-app-pub-3940256099942544~3347511713"
    const val BANNER = "ca-app-pub-3940256099942544/9214589741"
    const val INTERSTITIAL = "ca-app-pub-3940256099942544/1033173712"
    const val REWARDED = "ca-app-pub-3940256099942544/5224354917"
}
fun adProp(name: String, fallback: String) = (findProperty("wordle.admob.$name") as String?) ?: fallback

android {
    namespace = "com.sargisgevorgyan.wordlegame"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.sargisgevorgyan.wordlegame"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"

        manifestPlaceholders["admobAppId"] = adProp("appId", TestAdIds.APP)
        buildConfigField("String", "ADMOB_BANNER_ID", "\"${adProp("bannerId", TestAdIds.BANNER)}\"")
        buildConfigField("String", "ADMOB_INTERSTITIAL_ID", "\"${adProp("interstitialId", TestAdIds.INTERSTITIAL)}\"")
        buildConfigField("String", "ADMOB_REWARDED_ID", "\"${adProp("rewardedId", TestAdIds.REWARDED)}\"")
    }

    sourceSets["main"].assets.srcDir(sharedDir)

    buildTypes {
        debug {
            manifestPlaceholders["admobAppId"] = TestAdIds.APP
            buildConfigField("String", "ADMOB_BANNER_ID", "\"${TestAdIds.BANNER}\"")
            buildConfigField("String", "ADMOB_INTERSTITIAL_ID", "\"${TestAdIds.INTERSTITIAL}\"")
            buildConfigField("String", "ADMOB_REWARDED_ID", "\"${TestAdIds.REWARDED}\"")
        }
        release {
            isMinifyEnabled = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
    buildFeatures {
        compose = true
        buildConfig = true
    }
    testOptions {
        unitTests.all {
            it.systemProperty("sharedWordsDir", File(sharedDir, "words").absolutePath)
        }
    }
}

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2024.12.01")
    implementation(composeBom)
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.core:core-splashscreen:1.0.1")
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-core")
    implementation("androidx.compose.ui:ui-tooling-preview")
    debugImplementation("androidx.compose.ui:ui-tooling")

    // Monetization: Play Billing (Remove Ads, hint packs, Pro), AdMob, UMP consent.
    implementation("com.android.billingclient:billing-ktx:7.1.1")
    implementation("com.google.android.gms:play-services-ads:23.6.0")
    implementation("com.google.android.ump:user-messaging-platform:3.1.0")

    testImplementation("junit:junit:4.13.2")
}
