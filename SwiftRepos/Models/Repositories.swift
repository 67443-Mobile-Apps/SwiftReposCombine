// Created by Prof. H in 2026
// Part of the SwiftRepos project
// Using Swift 6.0
// Qapla'

import Foundation

// TA NOTE: `nonisolated` on the struct is the load-bearing piece here. This
// project sets SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor, so by default every
// new type is MainActor-isolated. Alamofire's `responseDecodable(of:)` requires
// its type parameter to be `Decodable & Sendable`, and a MainActor-isolated
// conformance can't satisfy a Sendable requirement. Without `nonisolated`
// students will see: "Main actor-isolated conformance of 'Repositories' to
// 'Decodable' cannot satisfy conformance requirement for a 'Sendable' type
// parameter". This is a pure data container — nothing needs main-actor isolation.
// Same reasoning applies to Repository.swift.
nonisolated struct Repositories: Codable {
  // TA NOTE: The GitHub search API wraps results in `{ "items": [...] }`. This
  // struct exists only to peel off that outer envelope — we hand `items` to the
  // view model and throw the wrapper away in Parser.
  let items: [Repository]
}
