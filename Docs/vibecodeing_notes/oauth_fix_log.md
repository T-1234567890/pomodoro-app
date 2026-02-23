# OAuth Fix Log

## Phase 1 — Project facts
- Target: Pomodoro (product type: macOS app, AppKit/SwiftUI hybrid)
- Deployment target: macOS 14.6
- Swift version: 5.0 (build settings)
- Lifecycle: SwiftUI App with NSApplicationDelegate (AppDelegate) — AppKit

## Phase 2 — Cloud file inputs
- Confirmed Cloud files existed on disk under `macos/Pomodoro/Pomodoro/Cloud` after relocation.
- PBX project already referenced `path = Cloud` under the Pomodoro group; ensured files are present at that path.
- Target membership: files listed in Sources build phase.
- Action: moved Cloud files into `macos/Pomodoro/Pomodoro/Cloud` to match PBX references (resolved “build input files not found”).

## Phase 3 — GoogleSignIn SPM state
- Package reference in project: `https://github.com/google/GoogleSignIn-iOS.git` (Up to Next Major from 7.0.0).
- Product dependency linked to Pomodoro target.
- Next steps to resolve locally: Xcode → File → Packages → Reset Package Caches, then Resolve Package Versions; clean build folder if needed.

## Phase 4 — Code safety
- Added `#if canImport(GoogleSignIn)` guards and a mock sign-in fallback to keep builds working if the package is unavailable or unresolved.
- Sign-in wiring placeholder; no secrets added.

## Phase 5 — Remaining checks
- Pending local actions: re-resolve SPM, rebuild. If module header error persists, consider package clean + derived data purge.

## Update — Combine/import and build fixes (latest)
- Added `import Combine` to AuthManager and CloudSettingsSection to satisfy @Published / property wrapper requirements.
- Made AuthManager non-actor, with @MainActor on signIn/signOut; added logout alias for existing callers.
- Conditional `canImport(GoogleSignIn)` retained; mock fallback remains for build stability.

## Update — AppDelegate guard
- Wrapped GoogleSignIn usage in AppDelegate with `#if canImport(GoogleSignIn)` and added the import guard to resolve missing `GIDSignIn` when the package is absent.

## Update — FeatureGate Combine import
- Added `import Combine` to FeatureGate to satisfy ObservableObject/@Published requirements.

## Update — Real Google sign-in wiring
- AuthSession now stores idToken (optional) alongside accessToken.
- AuthManager now imports GoogleSignIn directly, keeps a reusable configuration with the provided client ID, and performs real `signIn(withPresenting:)` using the main window. It stores email + idToken + accessToken, saves via AuthStore, and logs success/failure. Mock fallback removed.
- CloudSettingsSection now previews the idToken (falls back to access token) after sign-in.
