import Foundation
import Combine

class ViewModel: ObservableObject {

    // MARK: - Published Properties
    // @Published creates a publisher that emits whenever the value changes
    // This is one of the simplest ways to create a publisher in Combine

    @Published var searchText: String = ""
    @Published var repos: [Repository] = []
    @Published var filteredRepos: [Repository] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Private Properties
    private let parser = Parser()
    // AnyCancellable stores references to subscriptions
    // When these are deallocated, subscriptions are automatically cancelled
    private var cancellables = Set<AnyCancellable>()


    // MARK: - Initialization
    init() {
        setupSearchPipeline()
        setupRepositoriesObserver()
    }


    // MARK: - Combine Pipelines

    // This method demonstrates a sophisticated Combine pipeline:
    // 1. Debounce: Waits for user to stop typing (300ms delay)
    // 2. RemoveDuplicates: Only processes if search text actually changed
    // 3. Map: Transform the search text to lowercase for comparison
    // 4. Sink: Subscribe and perform the filtering action
    private func setupSearchPipeline() {
        // $searchText is the publisher for the searchText property
        $searchText
            // Debounce: Wait 0.3 seconds after user stops typing
            // This prevents excessive filtering while user is typing
            // Great for performance and reducing unnecessary work
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            // RemoveDuplicates: Only emit if value actually changed
            // Prevents redundant processing if same search is entered
            .removeDuplicates()
            // Sink: Subscribe to the publisher and perform action
            // This is where we actually do something with the values
            .sink { [weak self] searchText in
                self?.filterRepositories(searchText: searchText)
            }
            // Store: Keep reference to subscription in cancellables set
            // Without this, the subscription would be immediately cancelled
            .store(in: &cancellables)
    }

    // This method shows how to react to changes in one property
    // and update another property based on that change
    private func setupRepositoriesObserver() {
        // Observe changes to repos array
        $repos
            // CombineLatest: Combine two publishers into one
            // Emits whenever either repos OR searchText changes
            .combineLatest($searchText)
            // Map: Transform the combined values
            .map { (repositories, searchText) -> [Repository] in
                // If search is empty, return all repos
                if searchText.isEmpty {
                    return repositories
                }
                // Otherwise filter based on search text
                return repositories.filter { repo in
                    repo.name.lowercased().contains(searchText.lowercased())
                }
            }
            // Sink: Subscribe and update the property
            // Note: We use sink instead of assign(to: &$) for iOS 13 compatibility
            // assign(to: &$) is only available in iOS 14+
            .sink { [weak self] filtered in
                self?.filteredRepos = filtered
            }
            .store(in: &cancellables)
    }


    // MARK: - Methods

    // This method demonstrates subscribing to a custom publisher
    // and handling both success and failure cases
    func fetchRepositories() {
        isLoading = true
        errorMessage = nil

        // Call our parser's fetchRepositories which returns a Publisher
        parser.fetchRepositories()
            // Sink with completion handler: Handle both values and completion
            .sink(
                // receiveCompletion: Handle success or failure
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    switch completion {
                    case .finished:
                        // Successfully completed
                        print("Successfully fetched repositories")
                    case .failure(let error):
                        // Handle error
                        self?.errorMessage = error.localizedDescription
                        print("Error fetching repositories: \(error.localizedDescription)")
                    }
                },
                // receiveValue: Handle each emitted value
                receiveValue: { [weak self] repositories in
                    self?.repos = repositories
                }
            )
            .store(in: &cancellables)
    }

    // Manual filtering method for demonstration purposes
    // In practice, this is now handled automatically by setupRepositoriesObserver
    private func filterRepositories(searchText: String) {
        if searchText.isEmpty {
            filteredRepos = repos
        } else {
            filteredRepos = repos.filter { repo in
                repo.name.lowercased().contains(searchText.lowercased())
            }
        }
    }

    // MARK: - Advanced Combine Example: Retry Logic
    // This method shows how to add retry logic to network requests
    func fetchRepositoriesWithRetry(maxRetries: Int = 3) {
        isLoading = true
        errorMessage = nil

        parser.fetchRepositories()
            // Retry: Automatically retry failed requests
            // This will retry up to maxRetries times before giving up
            .retry(maxRetries)
            // Catch: Replace errors with a default value
            // This prevents the entire pipeline from failing
            .catch { error -> AnyPublisher<[Repository], Never> in
                print("All retries failed: \(error.localizedDescription)")
                // Return an empty array wrapped in a Just publisher
                // Just creates a publisher that emits a single value and completes
                return Just([])
                    .eraseToAnyPublisher()
            }
            .sink { [weak self] repositories in
                self?.isLoading = false
                self?.repos = repositories
            }
            .store(in: &cancellables)
    }

    // MARK: - Cleanup
    // When ViewModel is deallocated, all subscriptions in cancellables
    // will be automatically cancelled - no manual cleanup needed!
}
