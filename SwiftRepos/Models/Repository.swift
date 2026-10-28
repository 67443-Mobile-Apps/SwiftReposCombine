// Created by Prof. H in 2026
// Part of the SwiftRepos project
// Using Swift 6.0
// Qapla'

import Foundation

// TA NOTE: See Repositories.swift for the full `nonisolated` explanation — short
// version: without it, Alamofire's `Decodable & Sendable` requirement fails
// because the project defaults every type to MainActor isolation.
//
// `Hashable` is the one that will confuse students: they'll ask "isn't Identifiable
// enough?". Answer: value-based NavigationLink (`NavigationLink(value: repo)` +
// `.navigationDestination(for: Repository.self)`) requires the value to be
// Hashable so NavigationStack can store and diff it in its typed path. Identifiable
// is for List row identity; Hashable is for the navigation path. Both needed.
nonisolated struct Repository: Codable, Identifiable, Hashable {
  let id: Int
  let name: String
  // TA NOTE: Renamed away from `description` because `Swift.CustomStringConvertible`
  // reserves that name — using `description` as a stored property fights the compiler.
  // The CodingKey below maps the JSON's "description" back onto this field.
  let itemDescription: String?
  let htmlURL: String
  let stargazersCount: Int

  // TA NOTE: GitHub's JSON is snake_case; Swift is camelCase. CodingKeys bridges
  // the two so JSONDecoder (via Alamofire) can wire fields up automatically.
  // Only the renamed cases need an "=" — `id` and `name` match verbatim.
  enum CodingKeys: String, CodingKey {
    case id
    case name
    case itemDescription = "description"
    case htmlURL = "html_url"
    case stargazersCount = "stargazers_count"
  }
}
