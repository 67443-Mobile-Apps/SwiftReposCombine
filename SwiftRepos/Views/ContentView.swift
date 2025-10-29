import SwiftUI

struct ContentView: View {

    // MARK: - Properties
    // @ObservedObject automatically subscribes to @Published properties in ViewModel
    // When any @Published property changes, SwiftUI automatically re-renders this view
    // This is Combine working behind the scenes!
    @ObservedObject var viewModel = ViewModel()

    // MARK: - Body
    var body: some View {
        NavigationView {
            VStack {
                // TEACHING NOTE: Notice how simple this is now!
                // We directly bind to viewModel.searchText
                // The ViewModel's Combine pipeline handles debouncing and filtering
                // No manual binding closures needed!
                TextField("Search repositories...", text: $viewModel.searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                    .padding(.top, 5)
                    .autocapitalization(.none)

                // Show loading indicator when fetching
                if viewModel.isLoading {
                    if #available(iOS 14.0, *) {
                        ProgressView("Loading repositories...")
                            .padding()
                    } else {
                        Text("Loading repositories...")
                            .foregroundColor(.gray)
                            .padding()
                    }
                }

                // Show error message if there's an error
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                        .multilineTextAlignment(.center)
                }

                // TEACHING NOTE: We use filteredRepos directly from ViewModel
                // Thanks to Combine's combineLatest, this automatically updates
                // whenever either repos or searchText changes!
                List(viewModel.filteredRepos) { repository in
                    NavigationLink(
                        destination: WebView(request: URLRequest(url: URL(string: repository.htmlURL)!))
                            .navigationBarTitle(repository.name)
                    ) {
                        RepositoryRowView(repository: repository)
                    }
                }
                .navigationBarTitle("Swift Repos", displayMode: .inline)

                Spacer()
            }
            // TEACHING NOTE: onAppear calls our Combine-based fetch method
            // This triggers the entire Combine pipeline in ViewModel
            .onAppear {
                viewModel.fetchRepositories()
            }
        }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}


// MARK: - Teaching Notes for ContentView
/*
 KEY COMBINE CONCEPTS DEMONSTRATED IN THIS VIEW:

 1. AUTOMATIC UI UPDATES WITH @Published AND @ObservedObject
    - ViewModel has @Published properties
    - ContentView uses @ObservedObject to watch the ViewModel
    - When @Published properties change, SwiftUI automatically re-renders
    - This is Combine's integration with SwiftUI!

 2. SIMPLIFIED BINDING
    - Old approach: Complex Binding<String> with get/set closures
    - New approach: Direct binding with $viewModel.searchText
    - The ViewModel handles all the Combine logic internally

 3. REACTIVE DATA FLOW
    - User types → searchText updates → Debounce waits
    - → ViewModel filters → filteredRepos updates → UI re-renders
    - All of this happens automatically through Combine!

 4. SEPARATION OF CONCERNS
    - View: Only responsible for displaying data
    - ViewModel: Handles all business logic and Combine pipelines
    - This makes testing and maintenance much easier

 5. NO MANUAL STATE MANAGEMENT
    - We removed @State var searchField
    - We removed @State var displayedRepos
    - We removed loadData() and displayRepos() methods
    - Everything is handled by ViewModel's Combine pipelines

 DISCUSSION QUESTIONS FOR STUDENTS:
 - What happens when you type in the search field?
 - How does the 300ms debounce improve performance?
 - Why don't we need manual state management anymore?
 - How does @ObservedObject know when to update the UI?
 - What's the difference between @State and @ObservedObject?
 */
