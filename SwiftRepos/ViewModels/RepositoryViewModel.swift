// Created by Prof. H in 2026
// Part of the SwiftRepos project
// Using Swift 6.0
// Qapla'
// Updated to use Combine

import Foundation
import Combine

// TA NOTE: Combine pipelines need *publishers* to start from, and `@Published`
// is what gives us `$repos` and `$searchText`. The `@Observable` macro used in
// the non-Combine SwiftRepos does not create publishers, so this version uses
// the `ObservableObject` + `@Published` pattern instead.
class RepositoryViewModel: ObservableObject {
  @Published var repos: [Repository] = []
  // TA NOTE: `searchText` lives on the view model so it's testable and driveable
  // from `.searchable(...)` in ContentView.
  @Published var searchText: String = ""

  // TA NOTE: In the non-Combine version this is a computed property. Here it is
  // *stored*, and the pipeline in `init()` is the only thing that writes it.
  // `private(set)` makes that a rule: nothing outside can assign it.
  @Published private(set) var filteredRepos: [Repository] = []

  private let parser = Parser()

  init() {
    // TA NOTE: One pipeline, read top to bottom:
    //   - `combineLatest` emits whenever `repos` OR the search text changes.
    //   - The search text is debounced first: it only gets through once the
    //     user has stopped typing for 300ms. Filtering 30 repos is instant, so
    //     the debounce isn't needed for speed here — it's shown because it's
    //     the standard move when each search is expensive (e.g. a network call).
    //   - `removeDuplicates` skips a search identical to the last one.
    //   - `map` does the same filtering as the computed property in SwiftRepos.
    //   - `assign(to: &$filteredRepos)` writes each result into the property.
    //     This form ties the subscription's lifetime to the property, so there
    //     is no AnyCancellable to store and no `[weak self]` to remember.
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
    // TA NOTE: Subscribing is what actually starts the request. The value that
    // comes back is assigned to `repos`, which then flows through the pipeline
    // above into `filteredRepos`.
    parser.fetchRepositories()
      .assign(to: &$repos)
  }
}
