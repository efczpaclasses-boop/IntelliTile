import AppKit
import Testing
@testable import Dock_Tile

/// IntelliTile idea #5: Desktop, Documents and Downloads get the generic folder icon, so drawing a
/// tile never triggers the macOS folder-access prompt (k97/dock-tile#36, option 1).
@Suite("Protected folder icons")
struct ProtectedFolderIconTests {
    private let home = "/Users/probe"

    @Test("The three protected folders match, however the path is written")
    func protectedFoldersMatch() {
        for path in ["/Users/probe/Desktop", "/Users/probe/Documents", "/Users/probe/Downloads",
                     "/Users/probe/Downloads/"] {
            #expect(AppIconLoader.isProtectedFolder(path, home: home), "\(path)")
        }
    }

    @Test("Other folders keep their real icon")
    func otherFoldersDoNotMatch() {
        for path in ["/Users/probe/Music", "/Users/probe/Downloads/Work", "/Users/probe/Documents copy",
                     "/Users/other/Downloads", "/Applications", "/Users/probe"] {
            #expect(!AppIconLoader.isProtectedFolder(path, home: home), "\(path)")
        }
    }

    @Test("The real home's Downloads matches, also when written with ~")
    func realHomeDownloads() {
        let downloads = (NSHomeDirectory() as NSString).appendingPathComponent("Downloads")
        #expect(AppIconLoader.isProtectedFolder(downloads))
        #expect(AppIconLoader.isProtectedFolder("~/Downloads"))
    }
}
