import Foundation
import Testing
@testable import Dock_Tile

/// IntelliTile idea #2: "Check for Updates" compares the fork's latest GitHub Release tag with the
/// installed version (plus the release tag CI stamps into Info.plist) and only ever offers this
/// fork's own Releases page. No network in these tests.
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
        #expect(ForkReleaseCheck.isNewer("v2.8.2-intel.1", than: "2.8.1"))
        #expect(!ForkReleaseCheck.isNewer("v2.8.1", than: "2.8.1"))
        #expect(!ForkReleaseCheck.isNewer("v2.8", than: "2.8.0"))
        #expect(!ForkReleaseCheck.isNewer("v2.7.9", than: "2.8.1"))
        #expect(!ForkReleaseCheck.isNewer("nightly", than: "2.8.1"))
    }

    private func stamped(_ tag: String) -> ForkReleaseCheck.Version {
        ForkReleaseCheck.localVersion(marketing: "2.8.1", stamp: tag)!
    }

    private var unstamped: ForkReleaseCheck.Version {
        ForkReleaseCheck.localVersion(marketing: "2.8.1", stamp: "")!
    }

    @Test("Intel build numbers parse")
    func intelParsing() {
        #expect(ForkReleaseCheck.parse("v2.8.1-intel.2") == .init(core: [2, 8, 1], intel: 2))
        #expect(ForkReleaseCheck.parse("v2.8.2") == .init(core: [2, 8, 2], intel: nil))
        #expect(ForkReleaseCheck.parse("v2.8.1-intel.0") == nil)
        #expect(ForkReleaseCheck.parse("v2.8.1-intel.x") == nil)
        #expect(ForkReleaseCheck.parse("v2.8.1-intel.2")?.label == "2.8.1-intel.2")
    }

    @Test("Stamped release builds: 2.8.1-intel.1 < 2.8.1-intel.2 < 2.8.2")
    func intelOrdering() {
        let i1 = stamped("v2.8.1-intel.1")
        let i2 = stamped("v2.8.1-intel.2")
        #expect(i1 == .init(core: [2, 8, 1], intel: 1))
        #expect(ForkReleaseCheck.isNewer(ForkReleaseCheck.parse("v2.8.1-intel.2")!, than: i1))
        #expect(ForkReleaseCheck.isNewer(ForkReleaseCheck.parse("v2.8.2")!, than: i2))
        #expect(ForkReleaseCheck.isNewer(ForkReleaseCheck.parse("v2.8.2")!, than: i1))
        #expect(ForkReleaseCheck.isNewer(ForkReleaseCheck.parse("v2.8.2-intel.1")!, than: i2))
        #expect(!ForkReleaseCheck.isNewer(ForkReleaseCheck.parse("v2.8.1-intel.1")!, than: i1))
        #expect(!ForkReleaseCheck.isNewer(ForkReleaseCheck.parse("v2.8.1-intel.1")!, than: i2))
        #expect(!ForkReleaseCheck.isNewer(ForkReleaseCheck.parse("v2.8.1")!, than: i1))
    }

    @Test("A dev build with no stamp is offered only a newer X.Y.Z")
    func unstampedDevBuild() {
        let dev = unstamped
        #expect(dev == .init(core: [2, 8, 1], intel: nil))
        #expect(ForkReleaseCheck.localVersion(marketing: "2.8.1", stamp: nil) == dev)
        #expect(!ForkReleaseCheck.isNewer(ForkReleaseCheck.parse("v2.8.1-intel.1")!, than: dev))
        #expect(!ForkReleaseCheck.isNewer(ForkReleaseCheck.parse("v2.8.1-intel.9")!, than: dev))
        #expect(ForkReleaseCheck.isNewer(ForkReleaseCheck.parse("v2.8.2")!, than: dev))
        #expect(ForkReleaseCheck.outcome(statusCode: 200, data: json(["tag_name": "v2.8.1-intel.2"]),
                                         local: dev) == .upToDate(version: "2.8.1"))
    }

    @Test("A stamp that is malformed or names another X.Y.Z is ignored")
    func badStamp() {
        #expect(ForkReleaseCheck.localVersion(marketing: "2.8.1", stamp: "v2.9.0-intel.3") == unstamped)
        #expect(ForkReleaseCheck.localVersion(marketing: "2.8.1", stamp: "nightly") == unstamped)
        #expect(ForkReleaseCheck.localVersion(marketing: "unknown", stamp: "v2.8.1-intel.1") == nil)
    }

    @Test("A newer Intel build of the same version offers its page")
    func newerIntelRelease() {
        let page = "https://github.com/efczpaclasses-boop/IntelliTile/releases/tag/v2.8.1-intel.2"
        let result = ForkReleaseCheck.outcome(statusCode: 200,
            data: json(["tag_name": "v2.8.1-intel.2", "html_url": page]), local: stamped("v2.8.1-intel.1"))
        #expect(result == .newer(version: "2.8.1-intel.2", page: URL(string: page)!))
        #expect(ForkReleaseCheck.outcome(statusCode: 200, data: json(["tag_name": "v2.8.1-intel.1"]),
                                         local: stamped("v2.8.1-intel.1")) == .upToDate(version: "2.8.1-intel.1"))
    }

    @Test("A newer release offers its own page on this fork")
    func newerRelease() {
        let page = "https://github.com/efczpaclasses-boop/IntelliTile/releases/tag/v2.8.2"
        let result = ForkReleaseCheck.outcome(statusCode: 200,
            data: json(["tag_name": "v2.8.2", "html_url": page]), local: unstamped)
        #expect(result == .newer(version: "2.8.2", page: URL(string: page)!))
    }

    @Test("A page outside this fork's releases is never opened")
    func foreignPageIgnored() {
        for bad in ["https://github.com/k97/dock-tile/releases/tag/v9.0.0",
                    "http://github.com/efczpaclasses-boop/IntelliTile/releases/tag/v9.0.0",
                    "https://example.com/efczpaclasses-boop/IntelliTile/releases/tag/v9.0.0"] {
            let result = ForkReleaseCheck.outcome(statusCode: 200,
                data: json(["tag_name": "v9.0.0", "html_url": bad]), local: unstamped)
            #expect(result == .newer(version: "9.0.0", page: ForkReleaseCheck.releasesPage))
        }
    }

    @Test("Same version, no releases, and errors")
    func otherOutcomes() {
        #expect(ForkReleaseCheck.outcome(statusCode: 200, data: json(["tag_name": "v2.8.1"]),
                                         local: unstamped) == .upToDate(version: "2.8.1"))
        #expect(ForkReleaseCheck.outcome(statusCode: 404, data: Data(), local: unstamped) == .noReleases)
        #expect(ForkReleaseCheck.outcome(statusCode: 403, data: Data(), local: unstamped) == .failed)
        #expect(ForkReleaseCheck.outcome(statusCode: 200, data: Data("x".utf8), local: unstamped) == .failed)
        #expect(ForkReleaseCheck.outcome(statusCode: 200, data: json(["tag_name": "latest"]),
                                         local: unstamped) == .failed)
    }

    @Test("The check only talks to this fork")
    func endpoints() {
        #expect(ForkReleaseCheck.latestReleaseAPI.absoluteString
                == "https://api.github.com/repos/efczpaclasses-boop/IntelliTile/releases/latest")
        #expect(ForkReleaseCheck.releasesPage.absoluteString
                == "https://github.com/efczpaclasses-boop/IntelliTile/releases")
    }
}
