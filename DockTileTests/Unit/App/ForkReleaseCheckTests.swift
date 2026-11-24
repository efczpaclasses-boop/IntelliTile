import Foundation
import Testing
@testable import Dock_Tile

/// IntelliTile idea #2: "Check for Updates" compares the fork's latest GitHub Release tag with the
/// installed version and only ever offers this fork's own Releases page. No network in these tests.
@Suite("Fork release check")
struct ForkReleaseCheckTests {

    private func json(_ object: [String: Any]) -> Data {
        (try? JSONSerialization.data(withJSONObject: object)) ?? Data()
    }

    @Test("Tags parse with or without v and with a suffix")
    func parsing() {
        #expect(ForkReleaseCheck.versionComponents("v2.8.1") == [2, 8, 1])
        #expect(ForkReleaseCheck.versionComponents("2.8.1") == [2, 8, 1])
        #expect(ForkReleaseCheck.versionComponents("v2.9.0-intel.1") == [2, 9, 0])
        #expect(ForkReleaseCheck.versionComponents("latest") == nil)
        #expect(ForkReleaseCheck.versionComponents("2..1") == nil)
        #expect(ForkReleaseCheck.versionComponents("") == nil)
    }

    @Test("Only a strictly greater version is newer")
    func comparison() {
        #expect(ForkReleaseCheck.isNewer("v2.8.2", than: "2.8.1"))
        #expect(ForkReleaseCheck.isNewer("v2.10.0", than: "2.9.9"))
        #expect(ForkReleaseCheck.isNewer("v2.8.1.1", than: "2.8.1"))
        #expect(!ForkReleaseCheck.isNewer("v2.8.1", than: "2.8.1"))
        #expect(!ForkReleaseCheck.isNewer("v2.8", than: "2.8.0"))
        #expect(!ForkReleaseCheck.isNewer("v2.7.9", than: "2.8.1"))
        #expect(!ForkReleaseCheck.isNewer("nightly", than: "2.8.1"))
    }

    @Test("A newer release offers its own page on this fork")
    func newerRelease() {
        let page = "https://github.com/efczpaclasses-boop/IntelliTile/releases/tag/v2.8.2"
        let result = ForkReleaseCheck.outcome(statusCode: 200,
            data: json(["tag_name": "v2.8.2", "html_url": page]), localVersion: "2.8.1")
        #expect(result == .newer(version: "2.8.2", page: URL(string: page)!))
    }

    @Test("A page outside this fork's releases is never opened")
    func foreignPageIgnored() {
        for bad in ["https://github.com/k97/dock-tile/releases/tag/v9.0.0",
                    "http://github.com/efczpaclasses-boop/IntelliTile/releases/tag/v9.0.0",
                    "https://example.com/efczpaclasses-boop/IntelliTile/releases/tag/v9.0.0"] {
            let result = ForkReleaseCheck.outcome(statusCode: 200,
                data: json(["tag_name": "v9.0.0", "html_url": bad]), localVersion: "2.8.1")
            #expect(result == .newer(version: "9.0.0", page: ForkReleaseCheck.releasesPage))
        }
    }

    @Test("Same version, no releases, and errors")
    func otherOutcomes() {
        #expect(ForkReleaseCheck.outcome(statusCode: 200, data: json(["tag_name": "v2.8.1"]),
                                         localVersion: "2.8.1") == .upToDate(version: "2.8.1"))
        #expect(ForkReleaseCheck.outcome(statusCode: 404, data: Data(), localVersion: "2.8.1") == .noReleases)
        #expect(ForkReleaseCheck.outcome(statusCode: 403, data: Data(), localVersion: "2.8.1") == .failed)
        #expect(ForkReleaseCheck.outcome(statusCode: 200, data: Data("x".utf8), localVersion: "2.8.1") == .failed)
        #expect(ForkReleaseCheck.outcome(statusCode: 200, data: json(["tag_name": "latest"]),
                                         localVersion: "2.8.1") == .failed)
    }

    @Test("The check only talks to this fork")
    func endpoints() {
        #expect(ForkReleaseCheck.latestReleaseAPI.absoluteString
                == "https://api.github.com/repos/efczpaclasses-boop/IntelliTile/releases/latest")
        #expect(ForkReleaseCheck.releasesPage.absoluteString
                == "https://github.com/efczpaclasses-boop/IntelliTile/releases")
    }
}
