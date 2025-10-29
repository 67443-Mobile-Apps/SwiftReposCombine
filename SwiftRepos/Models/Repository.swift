import Foundation

struct Repositories: Codable {
  let items: [Repository]
  
  enum CodingKeys: String, CodingKey {
    case items
  }
}

struct Repository: Codable, Identifiable {
  let id: Int
  let name: String
  let htmlURL: String
  let itemDescription: String?
  
  enum CodingKeys: String, CodingKey {
    case id
    case name
    case htmlURL = "html_url"
    case itemDescription = "description"
  }
}
