// Created by Prof. H in 2026
// Part of the SwiftRepos project
// Using Swift 6.0
// Qapla'
// Updated to use Combine

import Testing
import Foundation
// TA NOTE: `@testable import` gives the tests access to internal declarations
// of the app module — same as when you took the course.
@testable import SwiftRepos

// TA NOTE: New-since-you-took-it stack:
//   - `import Testing` + `@Test` + `#expect(...)` is Swift Testing (Xcode 16+),
//     Apple's replacement for XCTest. Tests live in a `struct`, not a class.
//     No setUp/tearDown — use init() and deinit if you need them.
//   - `@MainActor` on the struct: the project's SWIFT_DEFAULT_ACTOR_ISOLATION
//     is MainActor, so our view model is main-actor-isolated.
//     Marking the tests @MainActor lets us construct/mutate the vm without
//     Swift 6 concurrency warnings.
// XCTest still works — students may see it in older code — but this course is
// all-in on Swift Testing.
@MainActor
struct RepositoryViewModelTests {

  // TA NOTE: Hand-built fixtures instead of hitting the network. The whole point
  // of putting `repos` and `searchText` on the view model as plain vars is that
  // tests can assign them directly and exercise `filteredRepos` in isolation —
  // no Alamofire, no flakiness. Parser is untested by design.
  private func sampleRepos() -> [Repository] {
    [
      Repository(id: 1, name: "Alamofire",
                 itemDescription: "Elegant HTTP Networking in Swift",
                 htmlURL: "https://github.com/Alamofire/Alamofire",
                 stargazersCount: 40_000),
      Repository(id: 2, name: "SwiftLint",
                 itemDescription: "A tool to enforce Swift style",
                 htmlURL: "https://github.com/realm/SwiftLint",
                 stargazersCount: 18_000),
      Repository(id: 3, name: "Vapor",
                 itemDescription: "A server-side Swift web framework",
                 htmlURL: "https://github.com/vapor/vapor",
                 stargazersCount: 24_000),
    ]
  }

  // TA NOTE: The one real difference from the non-Combine tests. Search text is
  // debounced, so `filteredRepos` doesn't update until 300ms after the last
  // change (including the initial ""). The tests are `async` and wait a little
  // longer than that before checking. In the non-Combine version
  // `filteredRepos` is computed, so its tests can check right away.
  private func waitForDebounce() async throws {
    try await Task.sleep(for: .milliseconds(400))
  }

  @Test func startsEmpty() {
    let vm = RepositoryViewModel()
    #expect(vm.repos.isEmpty)
    #expect(vm.filteredRepos.isEmpty)
    #expect(vm.searchText == "")
  }

  @Test func emptySearchReturnsAllRepos() async throws {
    let vm = RepositoryViewModel()
    vm.repos = sampleRepos()
    try await waitForDebounce()
    #expect(vm.filteredRepos.count == 3)
  }

  @Test func searchMatchesSubstring() async throws {
    let vm = RepositoryViewModel()
    vm.repos = sampleRepos()
    vm.searchText = "swift"
    try await waitForDebounce()
    #expect(vm.filteredRepos.contains { $0.name == "SwiftLint" })
    #expect(!vm.filteredRepos.contains { $0.name == "Alamofire" })
  }

  @Test func searchIsCaseInsensitive() async throws {
    let vm = RepositoryViewModel()
    vm.repos = sampleRepos()
    vm.searchText = "VAPOR"
    try await waitForDebounce()
    #expect(vm.filteredRepos.count == 1)
    #expect(vm.filteredRepos.first?.name == "Vapor")
  }
}
