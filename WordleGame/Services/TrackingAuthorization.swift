//
//  TrackingAuthorization.swift
//  WordleGame
//
//  App Tracking Transparency prompt. `NSUserTrackingUsageDescription` is in
//  Info.plist (localized via InfoPlist.strings).
//
//  The prompt must be requested while the app is in the *active* state, which is
//  why `WordleGameApp` calls this on the first `.active` scene phase rather than
//  from `init`. AdMob reads the resulting status on its next ad request, so no
//  extra wiring into `AdManager` is needed.
//

import AppTrackingTransparency
import Foundation

enum TrackingAuthorization {

    /// Shows the ATT prompt once (no-op if the user has already responded).
    static func requestIfNeeded() {
        #if DEBUG
        if ProcessInfo.processInfo.environment["UITESTS"] == "1" { return }
        #endif
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }

        // Small delay so the system alert doesn't collide with the launch.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            ATTrackingManager.requestTrackingAuthorization { status in
                print("[ATT] Tracking authorization status: \(status.rawValue)")
            }
        }
    }
}
