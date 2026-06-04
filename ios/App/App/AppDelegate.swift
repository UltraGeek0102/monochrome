import UIKit
import AVFoundation
import Capacitor

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        configureAudioSession()
        return true
    }

    // MARK: - Inject Appwrite config once the webview has fully loaded
    // We hook into applicationDidBecomeActive (fires after the webview is ready)
    // and use a one-shot flag so we only inject once on first launch.
    private var hasInjectedAppwriteConfig = false

    func applicationDidBecomeActive(_ application: UIApplication) {
        guard !hasInjectedAppwriteConfig else { return }
        hasInjectedAppwriteConfig = true

        // Give the page JS a moment to finish initialising before we inject
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard let bridge = (self.window?.rootViewController as? CAPBridgeViewController)?.bridge else { return }
            let js = """
                window.__APPWRITE_ENDPOINT__ = 'https://auth.monochrome.tf/v1';
                window.__APPWRITE_PROJECT_ID__ = 'auth-for-monochrome';
                window.__CAPACITOR_APP__ = true;
                console.log('[Monochrome] Appwrite config injected');
            """
            bridge.webView?.evaluateJavaScript(js) { _, error in
                if let error = error {
                    print("[AppDelegate] Appwrite injection failed: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Handle OAuth callback (appwrite-callback-auth-for-monochrome://)
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
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

    // MARK: - Audio Session

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
            break
        case .ended:
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
            do {
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("[AudioSession] Failed to reactivate after route change: \(error.localizedDescription)")
            }
        }
    }

    func applicationWillResignActive(_ application: UIApplication) {}
    func applicationDidEnterBackground(_ application: UIApplication) {}
    func applicationWillEnterForeground(_ application: UIApplication) {}
    func applicationWillTerminate(_ application: UIApplication) {}

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        return ApplicationDelegateProxy.shared.application(application, continue: userActivity, restorationHandler: restorationHandler)
    }
}
