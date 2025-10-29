import Foundation
import Combine

// MARK: - Custom Errors for Better Error Handling
enum NetworkError: Error {
  case invalidURL
  case invalidResponse
  case decodingError
  case networkError(Error)

  var localizedDescription: String {
    switch self {
    case .invalidURL:
      return "The URL is invalid"
    case .invalidResponse:
      return "Invalid response from server"
    case .decodingError:
      return "Failed to decode the response"
    case .networkError(let error):
      return "Network error: \(error.localizedDescription)"
    }
  }
}

class Parser {

  // MARK: - Properties
  let urlString = "https://api.github.com/search/repositories?q=language:swift&sort=stars&order=desc"

  // MARK: - Combine-based Network Request
  // This method demonstrates several key Combine concepts:
  // 1. Publisher creation with URLSession.dataTaskPublisher
  // 2. Operator chaining (map, decode, catch)
  // 3. Thread management with receive(on:)
  // 4. Type erasure with eraseToAnyPublisher()

  func fetchRepositories() -> AnyPublisher<[Repository], NetworkError> {
    // Validate URL
    guard let url = URL(string: urlString) else {
      return Fail(error: NetworkError.invalidURL)
        .eraseToAnyPublisher()
    }

    // Create a dataTaskPublisher - this is a Combine publisher
    // that wraps URLSession's data task functionality
    return URLSession.shared.dataTaskPublisher(for: url)
      // Map operator: Transform the output from (data, response) to just data
      // This demonstrates the map operator, one of the most common Combine operators
      .map(\.data)
      // Decode operator: Automatically decode JSON to our Repositories struct
      // This shows how Combine integrates with Codable
      .decode(type: Repositories.self, decoder: JSONDecoder())
      // Another map to extract just the items array from Repositories
      .map(\.items)
      // MapError: Convert any errors to our custom NetworkError type
      // This demonstrates error handling in Combine
      .mapError { error -> NetworkError in
        if error is DecodingError {
          return .decodingError
        }
        return .networkError(error)
      }
      // Receive(on:): Ensure we receive results on the main thread
      // This is crucial for updating UI from network responses
      .receive(on: DispatchQueue.main)
      // EraseToAnyPublisher: Type erasure to simplify the return type
      // This hides the complex nested type and makes the API cleaner
      .eraseToAnyPublisher()
  }

  // MARK: - Alternative: Using Subjects for More Control
  // PassthroughSubject allows manual control over when values are sent
  private let repositoriesSubject = PassthroughSubject<[Repository], NetworkError>()

  func repositoriesPublisher() -> AnyPublisher<[Repository], NetworkError> {
    return repositoriesSubject.eraseToAnyPublisher()
  }

  // This method can be called to manually trigger updates
  func manualFetch() {
    guard let url = URL(string: urlString) else {
      repositoriesSubject.send(completion: .failure(.invalidURL))
      return
    }

    URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
      if let error = error {
        self?.repositoriesSubject.send(completion: .failure(.networkError(error)))
        return
      }

      guard let data = data else {
        self?.repositoriesSubject.send(completion: .failure(.invalidResponse))
        return
      }

      do {
        let repositories = try JSONDecoder().decode(Repositories.self, from: data)
        self?.repositoriesSubject.send(repositories.items)
      } catch {
        self?.repositoriesSubject.send(completion: .failure(.decodingError))
      }
    }.resume()
  }
}
