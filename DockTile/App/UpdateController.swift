//
//  UpdateController.swift
//  DockTile
//
//  IntelliTile (Intel Mac port): Sparkle is unlinked, because the official appcast only offers the
//  arm64-only official build. Idea #2 (approved 24 Nov 2026): "Check for Updates" asks the fork's
//  public GitHub Releases for the latest release, compares versions and, if a newer one exists,
//  offers to open the Releases page in the browser. Nothing is downloaded or installed.
//  Fork releases must be tagged vX.Y.Z (e.g. v2.8.2) to be compared with CFBundleShortVersionString.
//  Helper bundles must never instantiate this class.
//

import AppKit
import Combine

/// Pure parts of the fork Releases check (unit-tested; no network here).
enum ForkReleaseCheck {
    nonisolated static let latestReleaseAPI = URL(string: "https://api.github.com/repos/efczpaclasses-boop/IntelliTile/releases/latest")!
    nonisolated static let releasesPage = URL(string: "https://github.com/efczpaclasses-boop/IntelliTile/releases")!

    enum Outcome: Equatable {
        case newer(version: String, page: URL)
        case upToDate(version: String)
        case noReleases
        case failed
    }

    /// "v2.8.1", "2.8.1", "2.8.1-intel.1" → [2, 8, 1]. Nil unless it starts with dot-separated integers.
    nonisolated static func versionComponents(_ raw: String) -> [Int]? {
        var s = raw.trimmingCharacters(in: .whitespaces)
        if s.first == "v" || s.first == "V" { s.removeFirst() }
        let core = s.split(whereSeparator: { $0 == "-" || $0 == "+" || $0 == " " }).first.map(String.init) ?? ""
        let parts = core.split(separator: ".", omittingEmptySubsequences: false)
        guard !parts.isEmpty else { return nil }
        var out: [Int] = []
        for p in parts {
            guard let n = Int(p), n >= 0 else { return nil }
            out.append(n)
        }
        return out
    }

    /// True only when both versions parse and `remote` is strictly greater (missing parts count as 0).
    nonisolated static func isNewer(_ remote: String, than local: String) -> Bool {
        guard let r = versionComponents(remote), let l = versionComponents(local) else { return false }
        for i in 0..<max(r.count, l.count) {
            let a = i < r.count ? r[i] : 0, b = i < l.count ? l[i] : 0
            if a != b { return a > b }
        }
        return false
    }

    /// Interpret the `releases/latest` response. Only a github.com page of THIS fork is ever opened.
    nonisolated static func outcome(statusCode: Int, data: Data, localVersion: String) -> Outcome {
        if statusCode == 404 { return .noReleases }
        guard statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String,
              versionComponents(tag) != nil else { return .failed }
        guard isNewer(tag, than: localVersion) else { return .upToDate(version: localVersion) }
        var page = releasesPage
        if let html = json["html_url"] as? String, let url = URL(string: html),
           url.scheme == "https", url.host == "github.com",
           url.path.hasPrefix("/efczpaclasses-boop/IntelliTile/releases/") {
            page = url
        }
        let shown = tag.hasPrefix("v") || tag.hasPrefix("V") ? String(tag.dropFirst()) : tag
        return .newer(version: shown, page: page)
    }

    /// One unauthenticated GET (no cookies, 15 s timeout). Never downloads a build.
    static func fetchLatest(localVersion: String) async -> Outcome {
        var request = URLRequest(url: latestReleaseAPI, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("IntelliTile/\(localVersion)", forHTTPHeaderField: "User-Agent")
        let session = URLSession(configuration: .ephemeral)
        defer { session.finishTasksAndInvalidate() }
        do {
            let (data, response) = try await session.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            return outcome(statusCode: code, data: data, localVersion: localVersion)
        } catch {
            return .failed
        }
    }
}

@MainActor
final class UpdateController: NSObject, ObservableObject {
    /// The fork Releases check is the update channel (idea #2).
    let isAvailable = true

    /// False while a check is running, so the button cannot start a second one.
    @Published private(set) var canCheckForUpdates = true

    override init() {
        super.init()
        DiagnosticsLog.shared.log("update", "Updater: manual check of the fork's GitHub Releases (no auto-install)")
    }

    func checkForUpdates() {
        guard canCheckForUpdates else { return }
        canCheckForUpdates = false
        let local = AppEnvironment.appVersion
        DiagnosticsLog.shared.log("update", "Checking fork Releases (current \(local))")
        Task { @MainActor in
            let result = await ForkReleaseCheck.fetchLatest(localVersion: local)
            self.canCheckForUpdates = true
            DiagnosticsLog.shared.log("update", "Release check result: \(result)")
            self.present(result, local: local)
        }
    }

    private func present(_ result: ForkReleaseCheck.Outcome, local: String) {
        let alert = NSAlert()
        var openPage: URL?
        switch result {
        case .newer(let version, let page):
            alert.messageText = AppStrings.Update.availableTitle
            alert.informativeText = AppStrings.Update.availableMessage(version, local)
            openPage = page
        case .upToDate:
            alert.messageText = AppStrings.Update.upToDateTitle
            alert.informativeText = AppStrings.Update.upToDateMessage(local)
        case .noReleases:
            alert.messageText = AppStrings.Update.upToDateTitle
            alert.informativeText = AppStrings.Update.noReleasesMessage
        case .failed:
            alert.alertStyle = .warning
            alert.messageText = AppStrings.Update.failedTitle
            alert.informativeText = AppStrings.Update.failedMessage
            openPage = ForkReleaseCheck.releasesPage
        }
        if let openPage {
            alert.addButton(withTitle: AppStrings.Update.openReleases)
            alert.addButton(withTitle: AppStrings.Update.later)
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(openPage)
            }
        } else {
            alert.addButton(withTitle: AppStrings.Button.done)
            alert.runModal()
        }
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
