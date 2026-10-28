// Created by Prof. H in 2026
// Part of the SwiftRepos project
// Using Swift 6.0
// Qapla'

import SwiftUI

struct ContentView: View {
  // TA NOTE: The view model here is an `ObservableObject` (so it can have
  // `@Published` publishers for Combine), and `@StateObject` is how a view OWNS
  // one. The non-Combine SwiftRepos uses `@State` because its view model is
  // `@Observable`. Don't use `@ObservedObject` here: that's for an object
  // passed in from outside, and SwiftUI may re-create it on you.
  @StateObject private var viewModel = RepositoryViewModel()

  var body: some View {
    // TA NOTE: `NavigationStack` (iOS 16+) replaces the deprecated `NavigationView`
    // you used. It supports "value-based" navigation — see `.navigationDestination`
    // below. If a student uses NavigationView it will still compile with warnings.
    NavigationStack {
      List(viewModel.filteredRepos) { repo in
        // TA NOTE: `NavigationLink(value:)` is the new value-based form. Instead
        // of hard-wiring a destination view here, you push a *value* onto the
        // stack and let `.navigationDestination(for:)` decide how to render it.
        // Big wins: decouples list rows from destinations, and lets you drive
        // navigation programmatically by mutating a path binding.
        NavigationLink(value: repo) {
          RepositoryRow(repo: repo)
        }
      }
      .navigationTitle("Swift Repos")
      // TA NOTE: This line is the one students will get stuck on. Breakdown:
      //   - `.searchable` is the modern modifier that gives you a system search
      //     bar; when you took the course you built this by hand with a
      //     TextField and a custom Binding<String>.
      //   - `.searchable` needs a `Binding<String>` (two-way). Because the view
      //     model is a `@StateObject`, `$viewModel.searchText` gives us one
      //     directly. (The non-Combine SwiftRepos needs `Bindable(viewModel)`
      //     here instead, because its view model is @Observable.)
      //   - As the user types, SwiftUI writes back through the binding into the
      //     view model's `@Published searchText`, which feeds the Combine
      //     pipeline, which updates `filteredRepos`, which re-renders the List.
      .searchable(text: $viewModel.searchText, prompt: "Search repos")
      // TA NOTE: The other half of value-based navigation. Any Repository pushed
      // onto the stack via NavigationLink(value:) lands here. `Repository` must
      // be `Hashable` for this to work — see the note in Repository.swift.
      .navigationDestination(for: Repository.self) { repo in
        if let url = URL(string: repo.htmlURL) {
          WebView(url: url)
            .navigationTitle(repo.name)
            .navigationBarTitleDisplayMode(.inline)
        }
      }
      .onAppear {
        // TA NOTE: The `isEmpty` guard prevents refetching every time the view
        // reappears (e.g. popping back from the WebView). Cheap way to cache.
        if viewModel.repos.isEmpty {
          viewModel.loadRepositories()
        }
      }
    }
  }
}
