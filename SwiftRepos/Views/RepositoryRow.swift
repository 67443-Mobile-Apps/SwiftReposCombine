// Created by Prof. H in 2026
// Part of the SwiftRepos project
// Using Swift 6.0
// Qapla'

import SwiftUI

struct RepositoryRow: View {
  let repo: Repository

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(repo.name)
        .font(.headline)
      if let description = repo.itemDescription {
        Text(description)
          .font(.subheadline)
          .foregroundColor(.secondary)
          .lineLimit(2)
      }
      HStack(spacing: 4) {
        Image(systemName: "star.fill")
          .font(.caption)
          .foregroundColor(.yellow)
        Text("\(repo.stargazersCount.formatted())")
          .font(.caption)
          .foregroundColor(.secondary)
      }
    }
    .padding(.vertical, 4)
  }
}
