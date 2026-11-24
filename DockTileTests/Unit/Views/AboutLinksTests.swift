//
//  AboutLinksTests.swift
//  DockTileTests
//
//  Guards the About pane's "Send Feedback…" destination. `AboutLinks.feedback` reads the address
//  from Info.plist `DTFeedbackEmail` and silently falls back to the website when the key is absent
//  or the URL cannot be built — a fallback that looks identical to the Website row in the UI while
//  the copy still promises the message reaches the developer. These pin the key's presence in the
//  shipped bundle (the test host IS the dev app) and the exact mailto the button opens.
//

import Foundation
import Testing
@testable import Dock_Tile

@Suite("About pane links")
struct AboutLinksTests {

    /// IntelliTile (Intel Mac port): no feedback e-mail ships, so Send Feedback opens the fork's
    /// GitHub Issues page, never the original project's address.
    @Test("Send Feedback opens the fork's Issues page")
    func feedbackOpensForkIssues() {
        #expect(Bundle.main.object(forInfoDictionaryKey: "DTFeedbackEmail") == nil)
        #expect(AboutLinks.feedback.absoluteString == "https://github.com/efczpaclasses-boop/IntelliTile/issues")
        #expect(AboutLinks.feedback != AboutLinks.website)
    }

    @Test("The review-sheet link opens the language's sheet on GitHub")
    func translationSheetLink() {
        #expect(AboutLinks.translationSheet(localization: "zh-Hans").absoluteString
                == "https://github.com/efczpaclasses-boop/IntelliTile/blob/intel-x86_64/docs/l10n/zh-Hans.md")
    }
}
