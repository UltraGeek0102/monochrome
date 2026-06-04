import UIKit
import AVFoundation
import Capacitor

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        configureAudioSession()
        injectAppwriteConfig()  // <-- ADDED
        return true
    }

    // MARK: - ADDED: Inject Appwrite config so OAuth redirects back to the app
    // instead of opening monochrome.tf in Safari
    private func injectAppwriteConfig() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard let bridge = (self.window?.rootViewController as? CAPBridgeViewController)?.bridge else { return }
            let js = """
                window.__APPWRITE_ENDPOINT__ = 'https://auth.monochrome.tf/v1';
                window.__APPWRITE_PROJECT_ID__ = 'auth-for-monochrome';
                window.__CAPACITOR_APP__ = true;
            """
            bridge.webView?.evaluateJavaScript(js, completionHandler: nil)
        }
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            // .playback keeps audio alive when the app is backgrounded or the screen locks
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("[AudioSession] Failed to configure: \(error.localizedDescription)")
        }

        // Handle audio interruptions (phone calls, Siri, alarms, etc.)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioInterruption),
            name: AVAudioSession.interruptionNotification,
            object: session
        )

        // Handle route changes (headphones unplugged, Bluetooth disconnect, etc.)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: session
        )
    }

    @objc private func handleAudioInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            // Interruption began - system pauses audio automatically
            break
        case .ended:
            // Interruption ended - reactivate session so playback can resume
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    do {
                        try AVAudioSession.sharedInstance().setActive(true)
                    } catch {
                        print("[AudioSession] Failed to reactivate after interruption: \(error.localizedDescription)")
                    }
                }
            }
        @unknown default:
            break
        }
    }

    @objc private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        if reason == .oldDeviceUnavailable {
            // Headphones/Bluetooth disconnected - reactivate session to keep background alive
            do {
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("[AudioSession] Failed to reactivate after route change: \(error.localizedDescription)")
            }
        }
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate.
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        // ADDED: intercept Appwrite OAuth callback before passing to Capacitor
        if url.scheme == "appwrite-callback-auth-for-monochrome" {
            DispatchQueue.main.async {
                guard let bridge = (self.window?.rootViewController as? CAPBridgeViewController)?.bridge else { return }
                let escaped = url.absoluteString.replacingOccurrences(of: "'", with: "\\'")
                let js = "window.dispatchEvent(new CustomEvent('appwrite-oauth-callback', { detail: '\(escaped)' }));"
                bridge.webView?.evaluateJavaScript(js, completionHandler: nil)
            }
            return true
        }
        return ApplicationDelegateProxy.shared.application(app, open: url, options: options)
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        return ApplicationDelegateProxy.shared.application(application, continue: userActivity, restorationHandler: restorationHandler)
    }

}
