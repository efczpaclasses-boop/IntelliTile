//
//  UpdateController.swift
//  DockTile
//
//  IntelliTile (Intel Mac port): Sparkle is unlinked. The official appcast only offers the
//  arm64-only official build, so auto-update must not run on this port. This is a no-op stub
//  that keeps the API the views use; "Check for Updates" is hidden while `isAvailable` is false.
//  Idea #2 (Phase B) replaces it with a check of the fork's GitHub Releases (no auto-install).
//  Helper bundles must never instantiate this class.
//

import AppKit
import Combine

@MainActor
final class UpdateController: NSObject, ObservableObject {
    /// No update channel in this build: every "Check for Updates" entry point is hidden.
    let isAvailable = false

    /// Kept for the views' existing `.disabled(!canCheckForUpdates)` wiring.
    @Published private(set) var canCheckForUpdates = false

    override init() {
        super.init()
        DiagnosticsLog.shared.log("update", "Updater disabled (IntelliTile: Sparkle removed; update with update.sh)")
    }

    func checkForUpdates() {
        DiagnosticsLog.shared.log("update", "Check for Updates requested, but this build has no update channel")
    }
}

// MARK: - Install while idle (#13)

/// Sparkle installs a silently downloaded update when the app quits, and with the menu bar icon or
/// Dock Lock on Dock Tile rarely quits. So while it stays resident it installs once the user is away
/// (`IdleInstallTests`).
enum IdleInstall {
    nonisolated static let idleThreshold: TimeInterval = 600
    nonisolated static let quietRelaunchWindow: TimeInterval = 120

    /// Never while the window is on screen (a hidden quiet-launch window still exists, so `isVisible`),
    /// never mid-build or mid-Dock-restart, and only after ten minutes without any input.
    nonisolated static func shouldInstall(windowVisible: Bool, secondsSinceInput: TimeInterval, dockBusy: Bool) -> Bool {
        !windowVisible && !dockBusy && secondsSinceInput >= idleThreshold
    }

    /// The relaunch after an idle install starts quietly only if the flag was written moments ago.
    nonisolated static func isQuietRelaunch(flaggedAt: Date, now: Date) -> Bool {
        let age = now.timeIntervalSince(flaggedAt)
        return age >= 0 && age < quietRelaunchWindow
    }
}

/// Holds Sparkle's install handler and checks every 60 s, only while one is held. Holding it stalls
/// Sparkle's update cycle until it runs or the app quits.
@MainActor
final class IdleInstaller {
    static let shared = IdleInstaller()
    private var install: (() -> Void)?
    private var timer: Timer?

    func hold(_ install: @escaping () -> Void, version: String) {
        self.install = install
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            MainActor.assumeIsolated { IdleInstaller.shared.check() }
        }
        DiagnosticsLog.shared.log("update", "Update \(version) waits for an idle moment to install")
    }

    private func check() {
        guard let install else { return }
        // Any input event (kCGAnyInputEventType); `.null` is event 0 and reads far older.
        let idle = CGEventType(rawValue: ~0).map {
            CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0)
        } ?? 0
        let windowVisible = NSApp.windows.contains {
            // A minimised window is in use too: the quiet relaunch would not bring it back.
            $0.identifier?.rawValue == AppDelegate.configurationWindowID && ($0.isVisible || $0.isMiniaturized)
        }
        let dockBusy = HelperBundleManager.shared.isAnyDockOperationInFlight
        guard IdleInstall.shouldInstall(windowVisible: windowVisible, secondsSinceInput: idle, dockBusy: dockBusy) else {
            DiagnosticsLog.shared.log("update", "Idle check: \(Int(idle)) s idle, window \(windowVisible), Dock busy \(dockBusy)", verbose: true)
            return
        }
        timer?.invalidate()
        timer = nil
        self.install = nil
        UserDefaults.standard.set(Date(), forKey: UserDefaultsKeys.relaunchQuietlyAt)
        DiagnosticsLog.shared.log("update", "Installing while idle after \(Int(idle)) s")
        install()
    }
}
