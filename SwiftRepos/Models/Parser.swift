// Created by Prof. H in 2026
// Part of the SwiftRepos project
// Using Swift 6.0
// Qapla'
// Updated to use Combine

import Foundation
import Combine
// TA NOTE: Alamofire comes in via Swift Package Manager (see the project's
// Package Dependencies). If a student's build fails with "no such module
// 'Alamofire'", first check File > Packages > Reset Package Caches, then that
// the target has Alamofire in Frameworks & Libraries.
import Alamofire

class Parser {
  private let url = "https://api.github.com/search/repositories?q=language:swift&sort=stars&order=desc"

  // TA NOTE: Compare with the non-Combine SwiftRepos: same request, same
  // `.validate()`, same Codable decoding — but instead of taking a completion
  // handler, this *returns a publisher*. Nothing hits the network until someone
  // subscribes (see `loadRepositories()` in the view model).
  //   - `publishDecodable(type:)` is Alamofire's Combine twin of
  //     `responseDecodable(of:)`. It delivers on the main queue by default, so
  //     no `.receive(on:)` is needed.
  //   - `.value()` turns the response into a plain stream of `Repositories`
  //     that fails with `AFError`.
  //   - `.catch` is the Combine version of the `.failure` case: log the error
  //     and hand back an empty array. Because errors are handled here, the
  //     return type's Failure is `Never`.
  //   - `eraseToAnyPublisher()` hides the long nested operator type from callers.
  func fetchRepositories() -> AnyPublisher<[Repository], Never> {
    AF.request(url)
      .validate()
      .publishDecodable(type: Repositories.self)
      .value()
      .map(\.items)
      .catch { error -> Just<[Repository]> in
        // TA NOTE: Deliberately simple — for the lab we just log and hand back
        // an empty array. In a real app you'd surface the error to the view.
        print("Error fetching repositories: \(error.localizedDescription)")
        return Just([])
      }
      .eraseToAnyPublisher()
  }
}
