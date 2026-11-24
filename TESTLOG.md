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

## GitHub Intel runner (macos-15-intel, Xcode 26.3)

### GREEN, port-only build: f34e32d, run 45342814528 (24 Nov 2026)
https://github.com/efczpaclasses-boop/IntelliTile/actions/runs/45342814528 (source: Intel runner)

| Step | Result |
|---|---|
| Release build, x86_64, ad-hoc, no Rust | pass |
| Binary report | main executable `Mach-O 64-bit executable x86_64`; `lipo`: non-fat, x86_64; **minos 15.0**; bundled Firebase frameworks x86_64 only, minos 10.15; RESULT PASS. Tile helpers are runtime copies of the main executable. |
| Headless smoke test | PASS: IDs, URL scheme `intellitile`, LSMinimumSystemVersion 15.0, Firebase/Crashlytics off, no SU* keys or Sparkle, no GoogleService-Info.plist, Assets.car present, no original-brand strings, `codesign --verify --deep --strict` OK, Signature=adhoc |
| Unit tests, DockTileTests (Debug, x86_64) | `** TEST SUCCEEDED **`: 1077 test-case results passed (parameterised cases count once per argument), 0 failed, 12 skipped by upstream (local-only/actool) |
| Launch smoke | `launch: running after 20 s`; diagnostics log shows a normal start (menu bar item added, login item reconciled) |

**Suites skipped on CI only** (`-skip-testing` in `intel-macos.yml`; the app is unchanged):
- `IconPreviewGeometryTests` (6 tests)
- `AppsFacePreviewTests` (6 tests)
- `AppsBackgroundTests` (10 tests)

Why these are skipped:
- **Evidence:** the crash report from run 45340729892 (same crash in runs 45334786071 and 45338378534) shows SIGABRT on `com.apple.RenderBox.Encoder`. The stack goes `RB::ImageProvider::render_device` → `RB::load_library_archive` → `-[_MTLBinaryArchive loadFromURL:error:]` → `+[MTLLoader sliceIDForDevice:…]` → `MTLReportFailure` → `abort`. It is a Metal shader-archive assertion inside Apple's SwiftUI renderer, on the runner's virtual GPU.
- **Why these three:** they are the only test suites that render SwiftUI views (`ImageRenderer` / `NSHostingView.cacheDisplay`). That crash report did not name the test in flight, so the list was chosen from the code. Run 45342814528 confirms it: with only these three skipped, there was no crash and every other test passed.
- **Unverified on real hardware:** these three suites have not run on a real Intel GPU, and they will not: Faraz's Mac has no Xcode, so the optional real-GPU test step was dropped (Lead, 24 Nov 2026). What they cover (icon preview geometry, Apps face preview, Apps background rendering) is only checked by eye in MAC_TEST_PLAN.md's feature steps.

### Release v2.8.1-intel.1 (24 Nov 2026)
- Branch tip 7121ce4 (port-only app code = f34e32d, plus the release workflow and update.sh): intel-macos run 45349716311 green (same three suites skipped).
- Release run 45351636763 (tag push, macos-15-intel + ubuntu): build, ditto zip, unpacked copy `codesign --verify --deep --strict` OK, `Signature=adhoc`, x86_64 only, minos 15.0; published; assets downloaded back and SHA matched.
- `IntelliTile-2.8.1-intel.1-x86_64.zip` (5,308,284 bytes), SHA-256 `4ea553d1340fb2c590c310be4f20587d66ae731660bc195e8ec4abfa83b84564`. Re-downloaded from the Linux box with unauthenticated curl: `sha256sum -c` OK.
- update.sh on the Intel runner (macOS 15.7, not Faraz's Mac): first run installed v2.8.1-intel.1 (SHA OK), second run "Already installed"; the curl-installed app had **no** `com.apple.quarantine` attribute; `spctl --assess` said `rejected` (not notarized), yet `open` launched it (running after 20 s).

### Ideas after the release route (24 Nov 2026; Intel runner, macos-15-intel, Xcode 26.3; same three suites skipped)
| Idea | Commit | Run | Result |
|---|---|---|---|
| #4 Start at Login opt-in, Dock-restart wording | f7f1b4f | 45353427108 | green: build, binary report, smoke, `** TEST SUCCEEDED **` (1080 passed, 0 failed, 12 skipped; LoginItemReconcileTests 12/12), launch running after 20 s |
| #5 generic icon for Desktop/Documents/Downloads | bc4a2cb | 45355961621 | green: 1083 passed, 0 failed, 12 skipped (ProtectedFolderIconTests 3/3), launch running after 20 s |
| #2 Check for Updates, intel.N aware | 45ac702 | 45357675658 | green: 1095 passed, 0 failed, 12 skipped (ForkReleaseCheckTests 11/11), launch running after 20 s |
| #4 one-time Start at Login migration | dac50f7 | 45360572451 | green: 1099 passed, 0 failed, 12 skipped (LoginItemReconcileTests 17/17, 5 new migration cases), launch running after 20 s |
| Fix: translocated app already in an Applications folder | 1fc6baa | 45363455629 | green: 1108 passed, 0 failed, 12 skipped (new AppRelocationTranslocatedInstalledTests 9/9), launch running after 20 s |
| update.sh / uninstall handle /Applications or ~/Applications | 798d2f3 | 45366051587 | green: 1109 passed, 0 failed, 12 skipped; new end-to-end step against the published v2.8.1-intel.1 passed all 7 scenarios (fresh install to ~/Applications; no-op; copy in /Applications replaced in place with no ~/Applications copy; two copies refused; unwritable folder refused with the no-sudo message; install.sh refused a second copy before building; uninstall removed the /Applications copy and ~/IntelPorts/dock-tile). Runner: `/Applications` is `drwxrwxr-x root admin`, runner user is an admin |
- CI builds have no release stamp (`ITReleaseTag` empty), so they run as "built from source". The stamped path is covered by unit tests only until a release build exists (v2.8.1-intel.2 is not published).
- The comparison logic was also compiled and run on the Linux box (Swift 6.4.3) with the same cases: all passed. That is not a macOS result.

### Ideas #2 and #4 (paused, then re-applied above)
- 2b0131d Idea #2, run 45345167714: green. ba78d9b Idea #4, run 45346937881: green.
- Both reverted on the branch when the plan changed to CI-built releases; kept on branch `idea2-4-parked`.

### Earlier runs (not green)
- 45334786071 (398f95c), 45338378534 (bf3c1ca): build, binary report and smoke passed. Unit tests: 5 stale-name assertions (fixed in bf3c1ca), the brand-glyph size test (fixed in 4e2fbca) and the renderer crash above.
- 45340729892 (1a60eca): the same renderer crash; the crash report was captured.

## Faraz's Mac (MacBookPro15,2, macOS 15.8.4)

Results relayed by Port Lead. Only these items are confirmed on his Mac.

### v2.8.1-intel.1, MAC_TEST_PLAN steps 1–15 (24 Nov 2026, ~13:10 GST)
- Download with Chrome; the app carried Chrome's `com.apple.quarantine` mark; `spctl -a` said rejected.
- **Step 10: no Gatekeeper dialog.** The app launched without "Not Opened" and without Open Anyway (steps 11–12 not needed). Why Gatekeeper did not ask is not known (unverified).
- **Step 13: BUG.** "Move IntelliTile to Applications?" appeared although the app was in `~/Applications`. His Copy Diagnostics (pid 71561, 09:09Z = 13:09 GST): `[relocation] App running from translocated – nudging to relocate`, then `Attempting move to /Applications`. Cause: App Translocation. The quarantined app had been put in `~/Applications` with Terminal `mv` (plan step 7), which does not lift translocation, so macOS ran a randomised read-only copy; upstream treats every translocated app as "move it". Faraz clicked Move: the app is now `/Applications/IntelliTile.app`, no quarantine mark, `~/Applications` copy gone, relaunched fine. Fixed for later builds in 1fc6baa (explanation instead of the move prompt); intel.1 keeps the bug.
- Installing with update.sh (curl, no quarantine mark) avoids translocation altogether (Intel runner: no mark, launched normally; run 45351636763).
- `[login] Reconciled on launch → enabled`: intel.1 registered the login item by itself (upstream default), as expected; this is the case the idea #4 migration (dac50f7) adopts as ON.
- **Step 15: PASS.**
