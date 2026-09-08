# Engineering Standards

## Architecture pattern
MVVM with a Repository boundary between Presentation and Data:
- **Views** are dumb — SwiftUI structs, no business logic, bind to `@Published` state.
- **ViewModels** own presentation state and orchestrate calls to a
  `ListingRepositoryProtocol` — never touch Core Data or `URLSession` directly.
- **Repository** (`ListingRepository`) is the single source of truth for
  listing data; owns the decision of when to read local vs. trigger remote
  refresh vs. queue for sync.
- **Domain models** (`Listing`, `PendingChange`, `SyncStatus`) are plain
  Swift structs with no framework imports (`Domain/` has zero `import
  UIKit`/`CoreData`/etc.) — they can be reasoned about and unit tested with
  no persistence or networking in the picture at all.

## Dependency injection
Constructor injection via `AppContainer` (`App/AppContainer.swift`) — every
dependency is expressed as a protocol (`NetworkServiceProtocol`,
`ListingRepositoryProtocol`, `KeychainServiceProtocol`). `AppContainer.shared`
is the one singleton in the app, and it exists purely to wire the object
graph once at launch — no other type reaches for a singleton directly. Tests
substitute `FakeListingRepository` at the ViewModel boundary instead of
mocking Core Data or the network.

## Reactive patterns (Combine)
- `Reachability` exposes a `CurrentValueSubject<Bool, Never>` rather than
  `@Published`. `@Published` publishes on `willSet` — before the property is
  actually updated — so a subscriber reading the property synchronously
  inside its own handler can see the old value. `CurrentValueSubject.send()`
  updates `.value` first, which matters because `SyncEngine` reads
  `reachability.isConnected` synchronously within the same call chain that
  reacts to the publisher.
- `SyncEngine` subscribes to the reachability publisher with
  `.receive(on: DispatchQueue.main)` for thread safety with UIKit
  notifications (the foreground trigger) on the same call path.
- A 10-second `Timer.publish` probe (`recheckConnectivity()`) works around a
  real iOS Simulator behavior where `NWPathMonitor`'s long-lived monitor
  doesn't reliably fire a reconnect event — confirmed via direct testing,
  not assumed.

## Concurrency
Swift Concurrency (`async`/`await`) throughout — no completion-handler
pyramids. `ImageCacheService` is an `actor` so concurrent image requests
from scrolling grid cells can't race on the in-flight-task dictionary or
`NSCache`. Core Data writes go through a single serial `backgroundContext`
(`context.perform { }`), keeping write ordering deterministic — important
for sync correctness, since a favorite-toggle write and a sync-result write
must never interleave unpredictably.

## Error handling
- Network errors are typed (`NetworkError`) rather than passed through as
  opaque `Error`, so the UI can distinguish offline, decoding failure, and
  server error and react appropriately.
- A failed background refresh never wipes local data — `ListingRepository`
  only overwrites Core Data on a *successful* fetch; a failed one silently
  leaves the last-known-good local state on screen.
- Sync failures are recorded per `PendingChangeEntity` (`retryCount`,
  `lastError`) rather than discarded — an offline edit is never silently
  lost.
- Core Data fetches use `try? ... ?? []` at the read boundary so a
  transient fetch error degrades to an empty result rather than crashing —
  but this pattern has a real cost worth naming honestly: it will also
  swallow a genuine misconfiguration (e.g. a Core Data model name mismatch)
  without surfacing it, which is exactly the kind of bug that's fast to
  introduce and slow to notice without checking the actual on-device data.

## Testing
- `ConflictResolverTests` — pure-logic tests; the highest-value tests in
  the app since this is exactly the kind of subtle logic that's easy to get
  wrong and hard to catch by eyeballing the UI.
- `CreateListingValidationTests` — boundary cases for title/price/description
  validation.
- `ListingsViewModelTests` — filtering and favorite-forwarding behavior,
  using `FakeListingRepository` (no Core Data or network in the test
  target). Assertions that depend on the repository's Combine publisher
  delivering a value await that delivery explicitly rather than asserting
  synchronously right after triggering the async load — asserting
  immediately after `onAppear()` is a real race, not a hypothetical one.
- Run via **Cmd+U** in Xcode, or `xcodebuild test -scheme PocketMarket
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'` from the
  command line/CI.

## Security
- No auth token exists in this mock API, but `KeychainService` wraps the
  Keychain APIs (`kSecAttrAccessibleAfterFirstUnlock`) so any future token
  storage has a ready, tested home rather than landing in `UserDefaults`.
- User-entered fields (title, description, price) are validated and
  trimmed before ever reaching persistence or network layers
  (`CreateListingViewModel.validate()`).
- Photo picking uses `PHPickerViewController`, which runs out-of-process
  and requires no Photos-library permission grant at all — a smaller trust
  surface than the legacy `UIImagePickerController` library API (the camera
  path still uses `UIImagePickerController`, since `PHPicker` doesn't cover
  camera capture).

## Code style
- One type per file, file name matches the primary type (e.g. the original
  combined `ImagePickerView.swift` was split into `CameraCaptureView.swift`
  and `PhotoLibraryPickerView.swift` to keep this consistent).
- Every non-obvious design decision is a `//` comment at the point of the
  decision (see `ImageCacheService`, `ConflictResolver`, `Reachability`)
  rather than only living in this document — the code should explain *why*,
  not just *what*.
- No force-unwraps in code paths that touch user or network input; optional
  binding / nil-coalescing with sane defaults instead (see
  `ListingDTO.toDomain()`).

## A real bug worth documenting honestly
Early in this build, `PersistenceController` initialized
`NSPersistentContainer(name: "OfflineMarketplace")` — a leftover string
from an earlier reference project — while the actual model file was
`PocketMarket.xcdatamodeld`. Core Data logged `Failed to load model named
OfflineMarketplace` and fell back to an empty model with zero entities.
Because every fetch in the app used `try? ... ?? []`, this failure was
completely silent: the app built, ran, and showed a normal UI with an
empty grid — no crash, no visible error. It was only found by checking the
actual on-device Core Data store (no `.sqlite` file existed at all) and
reading the unified system log directly, rather than by reading the Swift
source, which looked entirely correct. The fix was a one-line container
name change; the lesson worth keeping is that a broad `try?` at a
persistence boundary trades crash-safety for error-visibility, and that
trade needs to be a conscious one, not a default.
