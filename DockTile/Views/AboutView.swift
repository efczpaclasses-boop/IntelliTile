//
//  AboutView.swift
//  DockTile
//
//  The About pane (v2): lives in the sidebar under the app name — the only home of Software Update.
//  Swift 6 - Strict Concurrency
//

import SwiftUI

/// Links the pane opens. IntelliTile (Intel Mac port): every link points to the fork; the original
/// project is credited as plain text only (TRADEMARKS.md). `feedback` comes from Info.plist
/// `DTFeedbackEmail` (mailto:) when set, otherwise the fork's GitHub Issues page.
enum AboutLinks {
    static let website = URL(string: "https://github.com/efczpaclasses-boop/IntelliTile")!
    static let repository = website
    static let issues = URL(string: "https://github.com/efczpaclasses-boop/IntelliTile/issues")!
    /// The language's review sheet in the fork (same docs/l10n layout as the original).
    static func translationSheet(localization: String) -> URL {
        URL(string: "https://github.com/efczpaclasses-boop/IntelliTile/blob/intel-x86_64/docs/l10n/\(localization).md") ?? repository
    }
    /// What the rows show — the bare address.
    static let websiteDisplay = "github.com/efczpaclasses-boop/IntelliTile"
    /// The original project, credited as plain text (not a link).
    static let originalProjectDisplay = "github.com/k97/dock-tile"
    static var feedback: URL {
        guard let email = Bundle.main.object(forInfoDictionaryKey: "DTFeedbackEmail") as? String,
              !email.isEmpty else { return issues }
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = email
        components.queryItems = [URLQueryItem(name: "subject", value: "IntelliTile feedback")]
        return components.url ?? issues
    }
}

struct AboutPaneView: View {
    @EnvironmentObject private var configManager: ConfigurationManager
    @EnvironmentObject private var updateController: UpdateController
    @Environment(\.colorScheme) private var colorScheme

    private var copyright: String {
        Bundle.main.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String ?? ""
    }

    // One grouped Form (a Form is List-backed and will not size itself inside a ScrollView): the hero
    // rides as a full-bleed, clear-background first row.
    var body: some View {
        Form {
                    Section {
                        hero
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                    Section {
                        LabeledContent {
                            // IntelliTile: hidden until an update channel exists (idea #2, Phase B).
                            if updateController.isAvailable {
                                Button(AppStrings.Button.checkForUpdates) {
                                    DiagnosticsLog.shared.ui("About → Check for Updates")
                                    updateController.checkForUpdates()
                                }
                                .disabled(!updateController.canCheckForUpdates)
                            }
                        } label: {
                            Text(AppStrings.appName)
                            Text(AppStrings.About.version(AppEnvironment.appVersion))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        LabeledContent(AppStrings.About.website) {
                            Link(AboutLinks.websiteDisplay, destination: AboutLinks.website)
                        }
                    }
                    // Support actions as ordinary settings rows — label and description leading, a
                    // single button trailing — so they read like the Check for Updates row above
                    // rather than a card with two stretched buttons under it.
                    Section {
                        LabeledContent {
                            Button(AppStrings.About.sendFeedback) {
                                DiagnosticsLog.shared.ui("About → Send Feedback")
                                NSWorkspace.shared.open(AboutLinks.feedback)
                            }
                        } label: {
                            Text(AppStrings.About.feedbackTitle)
                            Text(AppStrings.About.feedbackRowBody)
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        LabeledContent {
                            // "Copy", not "Copy Diagnostics" — the row label already says which.
                            Button(AppStrings.Button.copy) {
                                DiagnosticsLog.shared.ui("About → Copy Diagnostics")
                                DiagnosticsLog.shared.copyToPasteboard(configurations: configManager.configurations)
                            }
                            .accessibilityLabel(AppStrings.Menu.copyDiagnostics)
                        } label: {
                            Text(AppStrings.About.diagnosticsTitle)
                            Text(AppStrings.About.diagnosticsBody)
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if let localization = TranslationInvite.runningLocalization,
                       TranslationInvite.showsTranslationRow(localization: localization) {
                        Section {
                            LabeledContent {
                                Button(AppStrings.Translation.helpImprove) {
                                    DiagnosticsLog.shared.ui("About → Help Improve translation")
                                    AnalyticsService.shared.log(.translationHelpTapped,
                                                                ["source": "about", "ui_language": localization])
                                    NSWorkspace.shared.open(AboutLinks.translationSheet(localization: localization))
                                }
                            } label: {
                                Text(AppStrings.Translation.title)
                                Text(AppStrings.Translation.reviewLine)
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    Section {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(AppStrings.About.portTitle)
                            Text(AppStrings.About.portCredit(AboutLinks.originalProjectDisplay))
                                .font(.caption).foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    } header: {
                        Text(AppStrings.About.creditsHeader)
                    } footer: {
                        Text(copyright)
                            .font(.caption).foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity)
                    }
        }
        .formStyle(.grouped)
        .paneScrollEdgeEffect()
        .paneTitleBand(AppStrings.About.title)
    }

    /// The product in context: Finder beside Dock Tile's own icon on a Dock strip (the reference
    /// pairing — the app that lives next to yours in the Dock, not a synthetic tile row).
    private var hero: some View {
        let dockShape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        return HStack(spacing: 12) {
            Image(nsImage: VendorMark.finderIcon).resizable().frame(width: 64, height: 64)
            Image(nsImage: VendorMark.appIcon).resizable().frame(width: 64, height: 64)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background {
            // In dark mode the bare material sinks into the studio canvas behind it — lift the
            // strip with a faint white wash and a hairline edge so it reads as the Dock's shelf.
            dockShape.fill(.regularMaterial)
                .overlay(dockShape.fill(Color.white.opacity(colorScheme == .dark ? 0.07 : 0)))
        }
        .overlay(dockShape.strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.16 : 0.05), lineWidth: 0.5))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(StudioCanvasBackgroundView())
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AppStrings.appName)
    }
}

// MARK: - Vendor marks

/// IntelliTile (Intel Mac port): the Happy Machines and Spades marks are removed (TRADEMARKS.md);
/// only the two system-rendered icons for the About hero remain.
enum VendorMark {
    /// Finder and the app's own icon in the About hero, resolved once. Both via
    /// `NSWorkspace.icon(forFile:)`, so each is exactly what the Dock renders.
    static let finderIcon: NSImage = NSWorkspace.shared.icon(forFile: "/System/Library/CoreServices/Finder.app")
    static let appIcon: NSImage = NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
}
