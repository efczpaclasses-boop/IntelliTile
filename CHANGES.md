# IntelliTile — changes from k97/dock-tile (Intel Mac port)

Branch `intel-x86_64`, based on upstream `main` at `1b6d2e6` (v2.8.1). `main` stays identical to
upstream. Each entry: change → files → why (Intel blocker / licence) → effect on features and speed.
Analysis references (B1–B5, inventory #n) are to the port's feasibility report.

## Phase A — Intel port core

### 1. Rename to IntelliTile (TRADEMARKS.md)
- **Files:** `DockTile/Config/{Base,Dev,Release}.xcconfig` (PRODUCT_NAME IntelliTile / IntelliTile Dev),
  `DockTile.xcodeproj/project.pbxproj` (product reference, TEST_HOST_APP_NAME), both schemes,
  `DockTile/Resources/Localizable.xcstrings` (all 8 languages), `InfoPlist.xcstrings`, `Info.plist`,
  login-item launcher plists (executable path), Swift string literals in 12 files,
  `DockTile/Views/AboutView.swift`, `DockTile/Constants/AppStrings.swift`, `README.md`, tests
  (`AboutLinksTests`, `AppStringsTests`). Removed `HappyMachinesLogo.svg`, `SpadesIcon{Light,Dark}.png`.
- **Why:** MIT covers the code, not the Dock Tile name/logo/icon or the Happy Machines / Spades marks;
  "forks must ship under a different name and icon". The fork is public.
- **What changed for the user:** every visible "Dock Tile" is "IntelliTile" (menus, alerts, settings,
  About, diagnostics header, default helper name). About pane: Website row → the fork on GitHub; the
  "Also from Happy Machines" section (studio + Spades rows) is replaced by a **Credits** row ("Unofficial
  Intel Mac port … based on the open-source project github.com/k97/dock-tile by k97, under the MIT
  licence…", plain text, new strings translated for de/fr/ja/ru/zh-Hans and marked needs_review);
  Send Feedback opens the fork's GitHub Issues (the original developer's e-mail `DTFeedbackEmail` was
  removed); translation "Help improve" opens the fork's `docs/l10n` page. Copyright line:
  "Copyright © 2026 k97 and contributors. MIT licence."
- **Kept:** internal Swift type, file, target, scheme and module names (`DockTile*`, `Dock_Tile`),
  LICENSE, TRADEMARKS.md, the vendored actool licence notice, all credits.
- **website/ and docs/ (decision):** left unchanged. They are the original project's own marketing and
  documentation, describe the original app, are not built into IntelliTile and are not deployed by
  this fork; the README says so. That is the minimum TRADEMARKS.md needs (the marks are not used to
  identify *our* software). Upstream release tooling (`Scripts/build-release.sh`, `create-dmg.sh`,
  `notarize.sh`, `generate-appcast-entry.sh`, `Scripts/l10n/*`), `CLAUDE.md` and `.claude/` also
  still say "Dock Tile"; they are not used by this port.
- **Speed:** none.

### 2. New bundle IDs, ad-hoc signing
- **Files:** `Release.xcconfig`, `Dev.xcconfig`, `project.pbxproj`, `Info.plist`, launcher plists
  (renamed), `App/Environment.swift`, `App/AppDelegate.swift`, `App/HelperAppDelegate.swift`,
  `Constants/UserDefaultsKeys.swift`, `Managers/SmartAddEngine.swift`, `Views/DockTileDetailView.swift`,
  tests (`HelperDetectionTests`, `LoginLauncherBundleTests`).
- **IDs:**

  | Item | Release | Dev |
  |---|---|---|
  | Main app | `io.github.efczpaclasses-boop.IntelliTile` | `io.github.efczpaclasses-boop.IntelliTile.dev` |
  | Tile helpers | `…IntelliTile.tile.<UUID>` | `…IntelliTile.dev.tile.<UUID>` |
  | Login item (SMAppService agent) | `…IntelliTile.tilelauncher` | `…IntelliTile.dev.tilelauncher` |
  | URL scheme | `intellitile://` | same |
  | Shared defaults suite | `…IntelliTile.shared` | same |
  | Tile list JSON | `~/Library/Preferences/…IntelliTile.configs.json` | `…IntelliTile.dev.configs.json` |
  | Smart Add log | `~/Library/Preferences/…IntelliTile.smartadd.json` | `…dev.smartadd.json` |
  | Helpers + diagnostics.log | `~/Library/Application Support/IntelliTile/` | `…/IntelliTile-Dev/` |
  | Tests | `…IntelliTileTests`, `…IntelliTileUITests` | |

  No App Group or keychain identifiers exist in the entitlements or source.
- **Signing:** upstream `DEVELOPMENT_TEAM` (R68RHN3HF5) cleared on every target; `CODE_SIGN_STYLE =
  Manual`, `CODE_SIGN_IDENTITY = "-"` (ad-hoc), so it builds with no Apple team. Idea #3 (Phase B)
  adds the optional personal-team signing.
- **Why:** must not collide with the official app's IDs, data files or deep links; no paid Developer ID.
- **Not renamed (internal, merge-friendly):** in-process/distributed notification names
  `com.docktile.tileRebuild`, `com.docktile.analyticsConsentChanged`, `com.docktile.dockDidRestart`,
  window IDs `com.docktile.configuration/about`, log subsystem `com.docktile.diagnostics`, pasteboard
  `com.docktile.getinfo`, symbol key `docktile.logo`, resource names `DockTileGlyph`, `docktile-actool`.
  These could only cross-talk with the official app running on the same Mac, which cannot happen on
  Intel.
- **Effect:** none on features; deep links use `intellitile://configure?…`. Speed: none.

### 3. New original app icon
- **Files:** `Scripts/intel-port/make_icon.py` (generator), `DockTile/Resources/AppIcon.icon/`,
  `AppIcon-Dev.icon/` (art replaced, same icon.json shape), `DockTile/Resources/DockTileGlyph.png`,
  `appicon/intellitile/` (1024 master + full `AppIcon.iconset` 16–1024). Removed `appicon/1.0.0`, `1.0.1`.
- **Design:** 2×2 rounded tiles (teal / indigo / sky) with an outlined "chip" tile; Dev icon in slate /
  amber. Nothing like the original orange ring with half-sun and horizon lines.
- **Why:** TRADEMARKS.md (new icon required). The project has no `.appiconset`; Xcode 26 compiles the
  `.icon` bundle and also renders the flattened icon used on Sequoia from it, so replacing the art
  inside the `.icon` replaces the Sequoia icon at every size without touching the build.
- **Effect:** new look only. The symbol picker's brand glyph is now the IntelliTile mark.

### 4. Sparkle unlinked
- **Files:** `project.pbxproj` (package reference, product dependency, Frameworks build file),
  `Package.resolved` (sparkle pin), `Info.plist` (SUFeedURL, SUPublicEDKey, SUEnableAutomaticChecks,
  SUScheduledCheckInterval, SUAutomaticallyUpdate), `App/UpdateController.swift` (stub),
  `App/DockTileApp.swift`, `Views/AboutView.swift`; deleted `DockTileTests/Unit/App/UpdateAnalyticsTests.swift`.
- **Why (B3):** the official appcast offers the arm64-only build; auto-install would break the app on
  Intel. Lead approved full unlinking.
- **Effect:** inventory #29 Software Update is **gone for now**: Check for Updates is hidden in the app
  menu and About pane (`UpdateController.isAvailable == false`). Update with `./update.sh`. Idea #2
  (Phase B) adds a fork-Releases check. No Sparkle framework or XPC services in the app or in any tile
  helper (each helper is a copy of the app), so the app and every helper are smaller. Speed: slightly
  faster launch (no updater start-up), less disk per tile.
- **Note:** `Package.resolved`'s `originHash` is now stale; Xcode rewrites it on the first resolve
  (harmless; `update.sh` resets that one file if it is the only change).

### 5. Firebase off (still linked)
- **Files:** `Info.plist` (`FIREBASE_ANALYTICS_COLLECTION_DEACTIVATED = true`,
  `FirebaseCrashlyticsCollectionEnabled = false`), removed `DockTile/Resources/GoogleService-Info.plist`
  (repo + Resources phase; also git-ignored), `Managers/AnalyticsService.swift`
  (`resolveConsent(nil) == false`), `Views/GeneralSettingsView.swift` (toggle default off),
  `AnalyticsServiceTests`.
- **Why:** plan (analytics off); upstream's Firebase project must not receive data from this fork.
- **Effect:** inventory #27 Share Analytics shows **off** by default; with no project config,
  `FirebaseApp.configure()` is never called (the existing guard logs and returns, no crash), so nothing
  is sent even if switched on. No Crashlytics upload-symbols run script exists in the project; the
  upstream release workflow's dSYM upload is disabled (see 8). If the Firebase x86_64 slices fail to
  link on the Mac, the fallback is to remove the two Firebase products (not done; not needed so far).
- **Speed:** none measurable.

### 6. Idea #1 (approved 24 Nov 2026) — build without the Rust icon compiler
- **Files:** `project.pbxproj` ("Bundle Icon Compiler" run script; DockTile target
  `ENABLE_USER_SCRIPT_SANDBOXING = NO`).
- **What:** if `Vendor/actool/target/release/docktile-actool` is missing, the script prints a warning
  and exits 0 instead of failing. The binary was removed from the phase's `inputPaths` (a missing
  declared input is itself a build error) and the phase is `alwaysOutOfDate`; user-script sandboxing is
  off for the app target only so the script may still read the optional binary when it exists.
- **Why (B5):** no rustup needed on an 8 GB Intel Mac. The compiler is only used on macOS 26+
  (`IconPipeline.isDeclarative`); Sequoia tiles use the legacy `.icns` path.
- **Effect:** no feature lost on Sequoia; macOS 26 declarative tile icons are unavailable in a build
  without the compiler (irrelevant: the Mac's ceiling is Sequoia). Vendored source and MIT notice kept.
  Speed: faster first setup (no Rust install or cargo build).

### 7. install.sh / update.sh
- **Files:** `install.sh`, `update.sh` (repo root).
- **install.sh:** no sudo; checks Intel x86_64 (refuses Rosetta), macOS ≥ 15.6 (Xcode 26 floor),
  ≥ 8 GiB free; finds a **Universal** Xcode 26.2/26.3 in `/Applications` or `~/Applications`
  (or `INTELLITILE_XCODE`) and uses it via `DEVELOPER_DIR`; stops with a clear message if the Xcode
  licence or first-launch setup is pending (approval steps); builds Release x86_64 ad-hoc with
  `-derivedDataPath ~/IntelPorts/dock-tile/DerivedData`, `-clonedSourcePackagesDirPath
  ~/IntelPorts/dock-tile/SourcePackages`, `-jobs 2` (8 GB RAM; `INTELLITILE_JOBS` to change), index
  store off; logs to `~/IntelPorts/dock-tile/logs/`; checks arch, bundle ID, no Sparkle, codesign;
  installs `~/Applications/IntelliTile.app` via a staged copy; refuses while the app is running.
  `--uninstall` (typed `yes` confirmation, or `--uninstall --yes`) removes only
  `~/IntelPorts/dock-tile` and `~/Applications/IntelliTile.app`, tells the user to delete tiles in the
  app first, and lists where tiles and settings remain.
- **update.sh:** checks origin is the fork, branch is `intel-x86_64`, no local edits (resets an
  Xcode-rewritten `Package.resolved`); `git fetch` + `git merge --ff-only origin/intel-x86_64`; then
  runs `install.sh`.
- **Effect:** one-command install/update. Build time on the i5/8 GB is unmeasured (first build also
  downloads the Firebase Swift packages).

### 8. CI on GitHub's Intel runner
- **Files:** `.github/workflows/intel-macos.yml`, `Scripts/intel-port/ci-inspect.sh`,
  `.github/workflows/ci.yml` and `release.yml` (triggers only).
- **Runner choice:** `macos-15-intel`. actions/runner-images `images/macos/macos-15-Readme.md`
  (checked 24 Nov 2026; file last updated 28 Aug 2026) lists Xcode **26.3 (17C529)** and **26.2
  (17C52)** with the **macOS 26.2 SDK** on macOS 15.7.9 x64, which is what the project needs and is the
  closest match to the target Mac (Sequoia 15.8.4, Xcode 26.3). `macos-26-intel` is not needed.
  Xcode 26.3 is selected with `DEVELOPER_DIR`.
- **Job:** resolve packages (retries, cache) → Release x86_64 build, ad-hoc, **no Rust** (exercises
  idea #1) → binary report (`file`, `lipo -info`, minos via `vtool`/`otool` for every Mach-O; fails on
  a missing x86_64 slice or minos > 15.8) → headless smoke test (IDs, URL scheme, helper prefix, data
  names, launcher plist/label/executable, Firebase kill switches, no SU* keys, no Sparkle files or
  linkage, no GoogleService-Info.plist, Assets.car present, no original-brand strings in raw bytes or
  decoded .strings/.plist, codesign verify) → `DockTileTests` on x86_64 → non-blocking launch check
  (app stays running 20 s; diagnostics log saved). Artifacts: reports, logs, xcresult, ad-hoc app zip.
  Actions pinned by commit SHA: checkout v7.0.1, cache v6.1.0, upload-artifact v7.0.2.
- **Upstream workflows:** `ci.yml` runs on Apple-silicon `macos-26` and `release.yml` needs the original
  team's signing/notarisation secrets and uploads Crashlytics dSYMs; on this branch both are
  `workflow_dispatch` only (job bodies unchanged, because `MacOSFloorGuardTests` reads `ci.yml`).
- **Note:** the workflow has **not run yet**: no write path to the fork has been approved.

### 9. Docs
- `CHANGES.md` (this file), `TESTLOG.md` (results and where they came from), README "Intel Mac port
  (unofficial)" section.

## Feature inventory status (Phase A, expected; not yet verified on an Intel Mac)
- Kept: #1–#26, #28 (links changed), #30–#32. #1/#2: installs to `~/Applications`, which the app
  already treats as installed (no relocation prompt).
- Degraded: #27 Share Analytics (default off, never sends: no Firebase project); #28 About
  (fork links, credits instead of studio/Spades rows); #31 URL scheme is `intellitile://`.
- Lost for now: #29 Software Update (Phase B idea #2 replaces it).
- Not available on this Mac: #33 macOS 26 icon styles / Liquid Glass (Tahoe only).

## Not addressed in Phase A
- Security AMBER items (disable-library-validation, unsigned-executable-memory, ad-hoc helpers):
  unchanged; idea #3 (Phase B) works on these.
- Picked ideas #2, #3, #4, #5 and R5: Phase B.

## CI fix loop (24 Nov 2026, Intel runner)
- **bc08927, 1a60eca: CI diagnostics.** Files: `.github/workflows/intel-macos.yml`, `Scripts/intel-port/crash-summary.py`. Why: the xcodebuild log does not say why a Swift Testing case failed, and crash reasons were missing. When the tests fail, CI now prints the failures from `TestResults.xcresult` and the crashed thread of recent `.ips` crash reports. Effect: CI only; the app is unchanged.
- **bf3c1ca: tests expect the IntelliTile names.** Files: 4 test files. Why: five assertions still expected `com.docktile.*`, "Dock Tile" and "DockTile". Effect: none on the app.
- **4e2fbca: full-bleed brand glyph.** Files: `DockTile/Resources/DockTileGlyph.png`, `Scripts/intel-port/make_icon.py`. Why: the app sizes the brand glyph as a full-bleed image, as the original one is. The new glyph had padding and an empty middle row, so it drew too small (the test measured -0.999 against an expected ~0.55). Effect: the brand symbol in the symbol picker is the right size, and it now has a bar through its middle gap.
- **f34e32d: CI-only skip of three SwiftUI-rendering suites** (Lead decision, option A). Files: `.github/workflows/intel-macos.yml`, `Scripts/intel-port/crash-summary.py`.
  - Skipped: `IconPreviewGeometryTests`, `AppsFacePreviewTests`, `AppsBackgroundTests`.
  - Why: on the runner's virtual GPU, Apple's SwiftUI renderer aborts in Metal (RenderBox.Encoder → MTLBinaryArchive → MTLReportFailure). The crash report is from run 45340729892; the same crash happened in runs 45334786071 and 45338378534. The crash killed the test host and failed 177 cases.
  - Effect: the app is unchanged, and every other test gates CI. They stay unverified on real hardware (no Xcode on Faraz's Mac; the optional real-GPU step was dropped).
  - Port-only build green: f34e32d, run 45342814528.

## Release route (24 Nov 2026; plan change: no Xcode on Faraz's Mac)
- **Ideas #2 and #4 paused.** Both were green (runs 45345167714, 45346937881) and are reverted here so the release is port-only; the code is kept on branch `idea2-4-parked` for re-scoping.
- **CI release workflow.** File: `.github/workflows/intel-release.yml` (manual `workflow_dispatch`: a full commit SHA on `intel-x86_64` and a tag). Builds the x86_64 Release app on `macos-15-intel`, ad-hoc signed; zips it with `ditto -c -k --keepParent`, writes a SHA-256 file, unpacks the zip and re-checks `codesign --verify --deep --strict` and the architecture. A separate job with `contents: write` (only there) publishes a GitHub Release on this fork with the `gh` CLI and `GITHUB_TOKEN`, then downloads the assets back and checks the SHA. A last job runs `update.sh` on an Intel runner twice (install, then no-op) and launches the app. Effect: Faraz installs a CI-built app without Xcode.
- **update.sh: release route.** Default: read the newest fork release (`releases/latest`, curl, no auth), download the zip and checksum from this fork only, check SHA-256, signature, x86_64 and bundle ID, then replace only `~/Applications/IntelliTile.app` (staged swap; refuses while the app runs; no sudo; no-op if that release is installed). `--from-source` keeps the old pull-and-build route (needs Xcode).
- README: install section rewritten for the release route; `install.sh` is the optional build-from-source route.

## Idea #4 (approved 24 Nov 2026): Start at Login is opt-in; honest Dock-restart wording
- Re-applied after the release route (Lead, 24 Nov 2026) from ba78d9b on `idea2-4-parked` as f7f1b4f; green in runs 45346937881 (original) and 45353427108.
- Start at Login:
  - Files: `DockTile/Managers/LoginItemManager.swift`, `DockTile/Constants/UserDefaultsKeys.swift`, `DockTileTests/Unit/Managers/LoginItemReconcileTests.swift`, README.
  - Change: a new `startAtLoginOptedIn` flag, set only by turning the Settings switch ON. `reconcileOnLaunch` and the switch's initial state now need that flag, so a new install registers no login item. The design is unchanged: one SMAppService launcher agent, and for a user who opted in, the agent is still re-asserted after a rebuild.
  - Tests: one new parameterised test (not opted in → never registers); the existing tests now pass `userOptedIn: true`.
- Dock-restart wording:
  - Files: `alert.restartDock.message` in `AppStrings.swift` and `Localizable.xcstrings`. English is final; de/fr/ja/ru/zh-Hans are marked `needs_review`.
  - New text says the Dock is force-quit and reopens straight away, existing items stay, and an icon dragged a moment ago may be lost.
  - The force-quit itself (`killall -KILL Dock`) and the one-time consent are unchanged.
- One-time migration (approved by Lead 24 Nov 2026 as part of idea #4):
  - Files: `DockTile/Managers/LoginItemManager.swift` (`shouldAdoptExistingRegistration`, `migrateOptInOnce`, called first in `reconcileOnLaunch`), `DockTile/Constants/UserDefaultsKeys.swift` (`startAtLoginOptInMigrated`), `DockTileTests/Unit/Managers/LoginItemReconcileTests.swift` (3 new tests, 5 cases).
  - Why: builds before #4 (v2.8.1-intel.1) register the login item by themselves and store no opt-in. After updating, the stored choice said OFF while the item was registered: the switch opened OFF for a moment, and a later bundle replacement would not re-assert the agent.
  - What: on the first launch of a build with #4, if no choice is recorded and the agent is registered (enabled or awaiting approval), that is recorded as ON. Runs once per install; never registers or unregisters anything; never overrides an explicit opt-out. Turning it off stays one click in Settings.
  - Commit dac50f7; CI green in run 45360572451. The real upgrade path (intel.1 → a #4 build) is only testable on the Mac (MAC_TEST_PLAN.after-intel2.md U5).
- Why: a privileged Dock utility should not register a login helper until asked, and the consent text should match what happens (IDEAS.md #4; ANALYSIS.md §7). Effect: no feature lost; Start at Login (#25) is OFF until turned on.

## Idea #5 (approved 24 Nov 2026): generic folder icon for Desktop, Documents and Downloads
- Files: `DockTile/Utilities/AppIconLoader.swift` (new `isProtectedFolder` and one branch in `icon(for:)`), plus the new `DockTileTests/Unit/Utilities/ProtectedFolderIconTests.swift`.
- What: if a tile item is exactly `~/Desktop`, `~/Documents` or `~/Downloads`, the popover, the tile face and the cache draw `NSWorkspace.icon(for: .folder)` instead of reading that folder's real icon. Every other folder keeps its real icon; subfolders such as `~/Downloads/Work` are not covered, as IDEAS.md describes.
- Why: reading the real icon is what triggers the macOS folder-access prompt (k97/dock-tile#36, option 1). Opening the folder still works as before (#20).
- Effect: those three folders show a plain folder picture. That is not tested on Sequoia yet; the Mac test plan covers it.
- Commit bc4a2cb; CI green in run 45355961621.

## Idea #2 (approved 24 Nov 2026): Check for Updates against the fork's GitHub Releases
- Re-applied from 2b0131d (`idea2-4-parked`, green in run 45345167714) and changed for the release route (Lead, 24 Nov 2026): Intel build numbers.
- Files:
  - `DockTile/App/UpdateController.swift`: `ForkReleaseCheck` (versions, comparison, response handling) plus the alert.
  - `DockTile/Resources/Info.plist` (new `ITReleaseTag` = `$(INTELLITILE_RELEASE_TAG)`), `DockTile/Config/Base.xcconfig` (`INTELLITILE_RELEASE_TAG =`, empty), `DockTile/App/Environment.swift` (`AppEnvironment.releaseTag`), `DockTile/Managers/DiagnosticsLog.swift` (a `Release:` line in Copy Diagnostics).
  - `.github/workflows/intel-release.yml`: passes `INTELLITILE_RELEASE_TAG="$TAG"` to xcodebuild, and checks the packaged app's `ITReleaseTag` equals the tag and the tag's X.Y.Z equals `CFBundleShortVersionString`.
  - `DockTile/Constants/AppStrings.swift` and `Localizable.xcstrings`: 9 `update.*` strings. English is final; de/fr/ja/ru/zh-Hans are marked `needs_review`.
  - Comments in `DockTileApp.swift` and `AboutView.swift`; README.
  - `DockTileTests/Unit/App/ForkReleaseCheckTests.swift`: the earlier tests plus Intel-build parsing, 2.8.1-intel.1 < 2.8.1-intel.2 < 2.8.2, an unstamped dev build, and a malformed or mismatched stamp.
- What it does:
  - **Check for Updates** shows again, in the app menu and the About pane. Manual only; no background check.
  - One unauthenticated HTTPS GET to `api.github.com/repos/efczpaclasses-boop/IntelliTile/releases/latest` (ephemeral session, 15 s timeout).
  - Installed version = `CFBundleShortVersionString` plus the stamped tag's Intel build. A newer X.Y.Z always wins; with the same X.Y.Z a stamped build compares `-intel.N` (a plain `vX.Y.Z` counts as 0). An unstamped build (from source, or a stamp that does not parse or names another X.Y.Z) is offered only a newer X.Y.Z.
  - If newer, an alert offers that release's page; only `https://github.com/efczpaclasses-boop/IntelliTile/releases/…` is opened, otherwise the Releases page. Other alerts: up to date, no releases yet, couldn't check.
  - **No download and no install.**
- Why: inventory #29 (Software Update) was lost when Sparkle was unlinked (blocker B3).
- Commit 45ac702; CI green in run 45357675658.
- Effect: v2.8.1-intel.1 (built before this) has no stamp and no Check for Updates; the first release with it is v2.8.1-intel.2.

## Fix: translocated app already in an Applications folder (24 Nov 2026; result from Faraz's Mac)
- Found on Faraz's Mac (v2.8.1-intel.1): the app was in `~/Applications` but the "Move IntelliTile to Applications?" prompt appeared. His Copy Diagnostics showed `[relocation] App running from translocated – nudging to relocate`: the download still had Chrome's quarantine mark and was put in place with Terminal `mv` (test-plan step 7), so macOS ran it from a randomised read-only App Translocation copy. Upstream classifies any translocated app as "move it", without looking at where the original is.
- Files: `DockTile/Managers/AppRelocation.swift`, `DockTile/Constants/AppStrings.swift`, `Localizable.xcstrings` (2 strings; English final, de/fr/ja/ru/zh-Hans `needs_review`), `DockTileTests/Unit/Managers/AppRelocationTests.swift` (4 new tests, 12 cases), README.
- What: when translocated, the original path is read with upstream's existing `SecTranslocateCreateOriginalPathForURL` lookup (Security.framework). If it is inside `/Applications` or `~/Applications` (upstream's path matching, unchanged), the new location `translocatedInApplications` shows a plain-English notice instead of the move prompt: macOS is running a protected read-only copy because the download is still marked as from the internet; reinstall with update.sh, or drag the app out of its Applications folder and back with Finder. Buttons: Show in Finder, Done (plus upstream's "Don't ask again" on the launch notice). Nothing is changed on disk; the app never removes its own quarantine mark. Helper generation stays blocked while translocated, as upstream.
- Unchanged: the upstream move prompt for genuinely uninstalled locations (Downloads, a disk image, translocated with an unknown original). The `~/Applications` path check was already correct (upstream tests), so it is not changed.
- README: install with Finder or update.sh; update.sh avoids translocation (curl adds no quarantine mark).
