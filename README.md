# SwiftRepos: Callbacks & Observation vs. Combine

This is a version of the SwiftRepos lab exercise, but refactored to use Combine.  What follows are some notes comparing two versions of the SwiftRepos app:

- **`SwiftRepos/`**: an Alamofire request with a **completion handler**, an **`@Observable`** view model, and a **computed property** for search filtering.
- **`SwiftReposCombine/`**: the same app with the data flow rewritten in **Combine**. The parser returns a **publisher**, and a **pipeline** keeps the filtered list up to date.

The two projects are a controlled comparison. They share the same Xcode project settings (iOS 17, Swift 6 concurrency defaults), the same Alamofire version, the same models, the same rows, the same `WebView`, the same navigation, and the same four tests. 

**Only these things differ between the two apps:**

| File | What changes |
|---|---|
| `Models/Parser.swift` | Completion handler → returns `AnyPublisher` |
| `ViewModels/RepositoryViewModel.swift` | `@Observable` + computed property → `ObservableObject` + `@Published` + one pipeline |
| `Views/ContentView.swift` | 2 lines: `@State` → `@StateObject`, and `Bindable(viewModel).searchText` → `$viewModel.searchText` |
| `SwiftReposTests/RepositoryViewModelTests.swift` | Same four tests; three become `async` and wait for the debounce |
| Bundle ID | `net.cmuis.SwiftReposCombine`, so both apps can be installed side by side |

We will break down each of these 4 changes in detail in section 2 below, giving you some key ideas on the impact of each change. I have some other teaching notes here and also in comments in the app itself to help you understand what is happening. (*The comments are all "TA Notes" that I had in the original lab to help TAs answer questions I thought might come up. I left them all in here, but modified the ones related to Combine; the entire set could be instructive.*)

---

## 1. The "Big Idea"

There are two jobs in this app, and each version handles them differently:

| Job | `SwiftRepos` | `SwiftReposCombine` |
|---|---|---|
| **Fetch** the repos (one async event) | Call a function and pass a closure to run when the data arrives | Get back a **publisher**; subscribing to it starts the request |
| **Filter** as the user types (an ongoing stream of changes) | A computed property that SwiftUI re-reads whenever its inputs change | A pipeline that *pushes* a new array into a stored property whenever its inputs change |

### The Big Idea in 2 Sentences:
What I want you to take away is this: **in modern SwiftUI, Observation already makes the screen reflect the current state** without Combine. Combine earns its place when the logic involves **time** (debounce, throttle, retry) or **combining several streams** of events.

---

## 2. Layer by Layer

### 2.1 Networking: `Parser.swift`

```swift
// SwiftRepos — completion handler
func fetchRepositories(completion: @escaping ([Repository]) -> Void) {
  AF.request(url)
    .validate()
    .responseDecodable(of: Repositories.self) { response in
      switch response.result {
      case .success(let container):
        completion(container.items)
      case .failure(let error):
        print("Error fetching repositories: \(error.localizedDescription)")
        completion([])
      }
    }
}
```

```swift
// SwiftReposCombine — returns a publisher
func fetchRepositories() -> AnyPublisher<[Repository], Never> {
  AF.request(url)
    .validate()
    .publishDecodable(type: Repositories.self)
    .value()
    .map(\.items)
    .catch { error -> Just<[Repository]> in
      print("Error fetching repositories: \(error.localizedDescription)")
      return Just([])
    }
    .eraseToAnyPublisher()
}
```

Some key points for you (the student) to note:

- **Same request, same `.validate()`, same decoding.** Only the way the result is delivered changes. `publishDecodable(type:)` is Alamofire's Combine version of `responseDecodable(of:)`.
- **Calling the function doesn't make the request.** The Combine version returns a *description* of the request. Nothing goes over the network until something subscribes, which here is `loadRepositories()`.
- **`switch response.result` becomes operators.** The `.success` branch becomes `.map(\.items)`. The `.failure` branch becomes `.catch { ... Just([]) }`.
- **`.value()`** turns Alamofire's full `DataResponse` into a plain stream of decoded values that fails with `AFError`.
- **`Just`** is a publisher that emits one value and finishes. `.catch` swaps the failed stream for `Just([])`.
- **`Never` in the return type.** `.catch` handles every error, so the publisher can't fail, and the type says so: `AnyPublisher<[Repository], Never>`. What would the return type be if we removed `.catch`? Answer: `AnyPublisher<[Repository], AFError>`. The caller would then *have to* handle failure, because `sink` without `receiveCompletion:` and `assign(to:)` only work when the failure type is `Never`.
- **`eraseToAnyPublisher()`** hides a type like `Publishers.Catch<Publishers.Map<AnyPublisher<Repositories, AFError>, [Repository]>, Just<[Repository]>>`. Show the full type once; students will see why erasure exists.
- **Threading:** Alamofire delivers both the completion handler and the publisher's values on the main queue by default, so neither version needs `.receive(on:)`. If you use `URLSession.dataTaskPublisher` instead you *will* need it.

### 2.2 View Model: `RepositoryViewModel.swift`

```swift
// SwiftRepos
@Observable
class RepositoryViewModel {
  var repos: [Repository] = []
  var searchText: String = ""

  var filteredRepos: [Repository] {
    guard !searchText.isEmpty else { return repos }
    return repos.filter { repo in
      repo.name.localizedCaseInsensitiveContains(searchText)
    }
  }

  @ObservationIgnored private let parser = Parser()

  func loadRepositories() {
    parser.fetchRepositories { [weak self] repos in
      self?.repos = repos
    }
  }
}
```

```swift
// SwiftReposCombine
class RepositoryViewModel: ObservableObject {
  @Published var repos: [Repository] = []
  @Published var searchText: String = ""
  @Published private(set) var filteredRepos: [Repository] = []

  private let parser = Parser()

  init() {
    $repos
      .combineLatest(
        $searchText
          .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
          .removeDuplicates()
      )
      .map { repos, searchText in
        guard !searchText.isEmpty else { return repos }
        return repos.filter { repo in
          repo.name.localizedCaseInsensitiveContains(searchText)
        }
      }
      .assign(to: &$filteredRepos)
  }

  func loadRepositories() {
    parser.fetchRepositories()
      .assign(to: &$repos)
  }
}
```

The filtering logic in the `.map` closure is **identical** to the computed property. What differs is how and when it runs:

| | Observation (computed) | Combine (pipeline) |
|---|---|---|
| Where the result lives | Nowhere; it's recalculated each time it's read | A stored `@Published var filteredRepos` |
| When the filter runs | Whenever SwiftUI reads `filteredRepos` | When `repos` changes, or 300 ms after typing stops |
| What keeps it in sync | SwiftUI notices that `filteredRepos` reads `repos` and `searchText` | `combineLatest` re-emits when either input emits |
| Who can write it | No one; it's computed | Only the pipeline (`private(set)`) |

More key points for you:

- **Why not `@Observable` here too?** Combine pipelines start from publishers, and `@Published` is what creates `$repos` and `$searchText`. The `@Observable` macro doesn't generate publishers. So choosing Combine for the pipeline means choosing `ObservableObject` for the view model. The view changes in the next section follow from that.
- **`$repos` vs. `repos`:** the `$` prefix gives the *publisher* (a stream of values over time). Without it you get the current value.
- **`combineLatest`** emits a tuple of the latest values whenever *either* input emits. Note that it waits until *both* inputs have emitted at least once.
- **`debounce` belongs on `searchText` only.** Debouncing the combined stream would delay the list from appearing after the fetch. Debouncing just the text input means typing waits, but new data shows up right away.
- **`removeDuplicates`** prevents re-filtering when the debounced text hasn't actually changed, for example when someone types a letter and deletes it within 300 ms.
- **`assign(to: &$property)`** writes each value into a `@Published` property and ties the subscription's lifetime to that property. That's why this version needs **no `Set<AnyCancellable>`, no `.store(in:)` and no `[weak self]`**. Compare it with the TempConverterCombine demo, which uses `sink` + `store(in:)` for side effects.
- **`loadRepositories()` → `.assign(to: &$repos)`:** subscribing starts the request. When the array arrives, it's assigned to `repos`, which flows through the pipeline in `init` into `filteredRepos`. That's two pipelines chained through a `@Published` property.
- **`@ObservationIgnored` has no Combine counterpart** because there's nothing to opt out of: an `ObservableObject` only notifies SwiftUI about properties marked `@Published`, and `parser` isn't one.

### 2.3 View: `ContentView.swift`

Only two lines differ:

```swift
// SwiftRepos
@State private var viewModel = RepositoryViewModel()
.searchable(text: Bindable(viewModel).searchText, prompt: "Search repos")

// SwiftReposCombine
@StateObject private var viewModel = RepositoryViewModel()
.searchable(text: $viewModel.searchText, prompt: "Search repos")
```

- **Owning the view model:** an `ObservableObject` is owned with `@StateObject`; an `@Observable` class is owned with `@State`. (`@ObservedObject` is for an object *passed in* from a parent. Using it for an object the view creates can cause SwiftUI to re-create it and lose its data.)
- **Getting a binding:** a `@StateObject` gives you `$viewModel.searchText` directly. An `@Observable` object needs `Bindable(...)` to produce a binding.
- Everything else, including the `List`, navigation, and the `repos.isEmpty` guard in `.onAppear`, is the same.

### 2.4 Tests: `RepositoryViewModelTests.swift`

Same fixtures, same four tests, same assertions. The one difference:

```swift
// SwiftReposCombine
private func waitForDebounce() async throws {
  try await Task.sleep(for: .milliseconds(400))
}

@Test func searchMatchesSubstring() async throws {
  let vm = RepositoryViewModel()
  vm.repos = sampleRepos()
  vm.searchText = "swift"
  try await waitForDebounce()          // ← not needed in SwiftRepos
  #expect(vm.filteredRepos.contains { $0.name == "SwiftLint" })
  ...
}
```

Because `filteredRepos` is computed in `SwiftRepos`, it's correct the moment you read it. In the Combine version, the debounce means it isn't updated until 300 ms after the last change to `searchText`. Even the initial `""` is debounced. So the tests have to wait. **Time-based operators make code time-dependent to test.** In production code you'd usually inject a scheduler so tests can control time instead of sleeping.

---

## 3. Some Combine vocabulary used here

| Concept | Where | What it does |
|---|---|---|
| `publishDecodable(type:)` | Parser | Alamofire's Combine API: a publisher of the decoded response |
| `.value()` | Parser | Turns a response publisher into a stream of values that can fail with `AFError` |
| `.map(\.items)` | Parser | Key-path `map` that pulls out one field |
| `.catch` + `Just` | Parser | Replaces a failure with a fallback publisher that emits one value |
| `AnyPublisher` / `.eraseToAnyPublisher()` | Parser | Hides the nested operator type behind `AnyPublisher<Output, Failure>` |
| `ObservableObject` / `@Published` | View model | Property publishers (`$repos`, `$searchText`) + SwiftUI change notifications |
| `.combineLatest` | View model | Emits the latest pair whenever either input emits (after both have emitted once) |
| `.debounce(for:scheduler:)` | View model | Emits only after the input has been quiet for an interval |
| `.removeDuplicates()` | View model | Drops a value equal to the previous one |
| `.assign(to: &$property)` | View model | Subscribes and writes each value into a `@Published` property; manages its own lifetime |
| `@StateObject` | ContentView | How a view owns an `ObservableObject` |

---

## 4. Tradeoffs: when to use which

**Callbacks + Observation (`SwiftRepos`)**

- Less code; the filter is a plain property that can't go stale.
- Easy to test: there's no timing involved.
- Apple's direction for new SwiftUI code (`@Observable`, and `async/await` for one-shot network calls).
- Time-based behavior has to be built by hand, e.g., `Task.sleep` inside `.task(id: searchText)`.

**Combine (`SwiftReposCombine`)**

- Time-based and multi-source logic is a single operator (`debounce`, `combineLatest`, `retry`).
- Error handling is visible in the types (`Failure`).
- Network results and user input use the same kind of stream, and can be combined.
- More concepts to learn: publishers, subscriptions, schedulers, lifetimes.
- Can't just use the `@Observable` amcro; need to use `@ObservableObject`
- Timing-based operators make tests time-dependent.

### Rule of thumb:
If a value is a pure function of the current state, use a computed property. If it depends on **time** or on **several async sources**, a Combine pipeline is often the clearest way to express it.

### Qapla'