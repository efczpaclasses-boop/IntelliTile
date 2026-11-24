# IntelliTile test log

Every result says where it came from. Nothing here has been run on macOS yet.

## 24 Nov 2026, Phase A — from the Linux box (Debian 13, x86_64), not macOS

No repository build scripts or app code were executed. Tools: ShellCheck 0.10.0 (Debian package),
actionlint 1.7.12 (official release binary, checksum verified), xcodeproj gem 1.28.1 (rubygems.org),
Python 3 `plistlib`/`json`, Swift 6.4.3-RELEASE for Debian 13 from download.swift.org (GPG signature
verified against swift.org's release keys).

| Check | Result |
|---|---|
| `shellcheck install.sh update.sh Scripts/intel-port/ci-inspect.sh` | pass, 0 findings |
| `shellcheck -s sh` on the "Bundle Icon Compiler" run script (extracted from the pbxproj) | pass, 0 findings |
| `actionlint .github/workflows/intel-macos.yml` | pass, 0 findings |
| `actionlint` upstream `ci.yml` + `release.yml` | 29 shellcheck "info" notes, all pre-existing (same count on upstream main); only the `on:` blocks were edited |
| `plistlib` / JSON parse: `Info.plist`, both launcher plists, entitlements, both `.xcstrings`, both `icon.json`, `Package.resolved` | pass |
| `project.pbxproj` parses with the xcodeproj gem (objectVersion 77), no gem warnings, no duplicate or dangling object IDs, all 74 file references exist on disk | pass |
| String catalog: every key used in `AppStrings.swift` exists with all 8 languages; `%@` preserved in the new credit string; no "Dock Tile" / "Happy Machines" / "Spades" values left | pass |
| `swiftc -parse` (syntax only, Linux toolchain, no SDK) on all 23 Swift files changed on this branch | pass, 23/23 |
| `install.sh --help`; refuses on non-macOS; `--uninstall --yes` in a fake HOME removes only `~/IntelPorts/dock-tile` and `~/Applications/IntelliTile.app` (a sibling app and the tile folder were untouched); answering anything but `yes` removes nothing; unknown option exits 2 | pass |
| `version_ge` helper (15.8.4≥15.6, 15.5.1<15.6, 15.10≥15.6, 26.2≥26.0) | pass |
| `update.sh` against a local bare clone: wrong option exits 2; Xcode-rewritten `Package.resolved` alone is reset; any other local edit stops it | pass |

Not possible on Linux (needs macOS): type-checking against the macOS SDK, the Xcode build, Firebase
x86_64 linking, the `.icon` compile, unit tests, and any runtime behaviour.

## GitHub Intel runner (macos-15-intel, Xcode 26.3) — 24 Nov 2026, NOT green yet

Workflow `.github/workflows/intel-macos.yml`. Runs: 45334786071 (398f95c), 45338378534 (bf3c1ca),
45340729892 (1a60eca), https://github.com/efczpaclasses-boop/IntelliTile/actions

| Step | Result (source: Intel runner) |
|---|---|
| Release build, x86_64, ad-hoc, no Rust | pass (all 3 runs) |
| Binary report | `Mach-O 64-bit executable x86_64`; `lipo`: non-fat x86_64; main executable minos 15.0; bundled Firebase frameworks x86_64, minos 10.15; RESULT PASS |
| Headless smoke test | PASS: IDs, URL scheme `intellitile`, LSMinimumSystemVersion 15.0, Firebase/Crashlytics off, no SU* keys or Sparkle, no GoogleService-Info.plist, Assets.car present, no original-brand strings, `codesign --verify --deep --strict` OK, Signature=adhoc |
| Unit tests (DockTileTests, Debug, x86_64) | FAIL: 760 passed, 177 failed, 13 skipped (same in all 3 runs) |

Unit-test failures:
- Run 1: 5 stale-name assertions (fixed in bf3c1ca) and the brand-glyph size test (fixed in 4e2fbca; not yet confirmed, because that test was among the crashed ones in run 3).
- 177 cases end as "crashed with signal abrt". One crash of the test host (`IntelliTile Dev`) stops every test still running. Crash report (run 3): EXC_CRASH SIGABRT on thread `com.apple.RenderBox.Encoder`. The stack runs `MTLReportFailure` < `+[MTLLoader sliceIDForDevice:…]` < `-[_MTLBinaryArchive loadFromURL:error:]` < `RB::load_library_archive` < `RB::RenderFrame::encode` < `RB::ImageProvider::render_device`. That is a Metal assertion inside Apple's SwiftUI renderer while it draws for a test. It happens on the runner's virtual GPU and not in IntelliTile code. Not tested on a real Intel GPU yet.
- Launch smoke: skipped (it runs after the tests).

## Faraz's Mac (MacBookPro15,2, macOS 15.8.4)

Not run yet. Nothing in this branch is claimed to work on his Mac until he confirms.
