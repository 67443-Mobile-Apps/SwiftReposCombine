# Swift Repos Combine

This is a version of the SwiftRepos lab exercise, but refactored to use Combine.  Unlike the TempConverterCombine app, I don't have a separate document of changed, but tried to add a lot of comments to the code at places where Combine was used.  Below are the original lab instructions.

---

## Overview

1. In this lab, we will build an application to look at the most popular Swift repisitories on GitHub using the GitHub API and many of the skills we have learned in class. You are allowed and encouraged to use Alamofire and Codable to make it easier to write this lab and to produce cleaner code. The final application will look like this:

   <img src=https://i.imgur.com/cOtGPmp.png?1 width="25%"/>

## Setup

1. Clone the [starter code](https://github.com/67443-Mobile-Apps/swiftrepos_starter).  When you open the project in Xcode and go to `Models/Parser.swift` you see an error because Xcode does not know what `import Alamofire` means.  

1. To solve this problem, first go to Swift Package Index at [https://swiftpackageindex.com/](https://swiftpackageindex.com/) and look up 'Alamofire'.  Click on the 'Use this Package' button and copy the Package URL. (If you want to see the [Alamofire](https://github.com/Alamofire/Alamofire) repo and read more about it, you can click on the 'View on GitHub' link on the right.)

1. Now to install this dependency in Xcode, we will use Swift Package Manager as it is already baked into Xcode. (The alternative that predates SPM is a Ruby gem called [CocoaPods](https://cocoapods.org/) and you will still see it in widespread use and it will be demo'd in class.)  To do this:

    - in Xcode, go to the menu option `File` and select the `Add Packages...` option 

    - In the modal that pops up, on the far right there is a place to search or enter a package URL.  Paste in the link you got in the prior step and add the package.

    - Once this completes, you are now ready to use Alamofire.  You can verify that by seeing the previous error `Models/Parser.swift` disappears (and a new one appears).

   

## Models

1. To fix the new error, we need to fix our model in `Repository.swift`. Take note of the simple structure of the model.

2. Here is the [JSON](https://api.github.com/search/repositories?q=language:swift&sort=stars&order=desc) we are going to parse. Look at it and take note of its structure, look at the fields you are going to need. Now make this struct conform to both the `Codable` and `Identifiable` protocols.  Remember that for `Codable` you will need to set up `CodingKeys`. (Refer to the earlier playground from class, but note we made a small change so you can't just copy and paste.)

3. Now we need to make a parent struct to hold all these `Repository` objects.  In class we called that `Result` and decoded some other aspects, but now we only care about a having a container to hold our repos, so we will create a new struct called `Repositories` as follows:   

	```swift
	struct Repositories: Codable {
	 let items: [Repository]
	
	 // make sure this conforms to Codable...
	}
	
	```

4. Open up the `Parser.swift` and look over the code there.  Because the network calls via Alamofire is not the main focus of this lab, to save time we are simply giving you a fully working parser.  Note that unlike class, we didn't separate this into two classes (one for parsing, the other for the actual retrieval of data) because this is so simple, but that is normally a good idea.  We aren't necessarily following best practice of splitting out the params because there no opportunity to change them in this simple app; if you want to do this on your own and follow the class example, we certainly encourage you to do so.  

    I realize most students want to just get through lab as quickly as possible, but I would urge you to take a few minutes to look over the [Alamofire documentation](https://github.com/Alamofire/Alamofire) and learn more how this nifty tool works -- you will certainly need it more when it comes to project time.


## View Model

1. Open up the `ViewModel.Swift`.

2. We want changes in our view model to be automatically read by our interface so it can update itself.  For this reason, our view model already conforms to the `ObservableObject` protocol.

3. Now to be an `ObservableObject`, we must have some values with are being 'published' so that other observers can subscribe to and see changes.  I promise we will explain the concept of reactive programming more in lecture soon, but for now we've given you the stubs for three fields that need to be publishable; mark them as published by putting `@Published` in the front of each and set reasonable initial values with the right data types.

    - `repos`: An array of all the `Repository` objects
    - `searchText`: The search bar text as a `String`
    - `filteredRepos`: An array of the filtered `Repository` objects

4. Add the following method that will filter the repos:

    ```swift
      func search(searchText: String) {
        self.filteredRepos = self.repos.filter { repo in
          return repo.name.lowercased().contains(searchText.lowercased())
        }
      }
     ```

## Views

### List Row Cell (`RepositoryRow`)

Let's start easy with the SwiftUI file called `RepositoryRow.swift` that basically holds the contents of an individual table cell.  Recall from lecture that a cell displays the repository's `name` (let's make that a `.headline` font) and `itemDescription` (a `.subheadline` font) and these are placed with the name on top and the description below. Note that the struct will need to have a `Repository` that it can reference for these values.

Hopefully the code you developed in the class exercise on Tuesday will be helpful to you in that regard.  If you are still having issues with this, [here](https://developer.apple.com/tutorials/swiftui/building-lists-and-navigation) is an excellent resource that will also be helpful for creating the List View.

### List View (`ContentView`)

1. Now time to hit the challenging one: our list of repos in `ContentView.swift`.  There are fields that we'd like to have right at the top of the struct before we even go into `var body` to help us manage the state of our app: 

    ```swift
    var searchField: String = ""
    var displayedRepos = [Repository]()
    ```
    As we add things to the search string, our displayed repos should update accordingly.  Oh no.  Houston, we have a problem.  This is a struct (as all SwiftUI views are), not a class, so the state should be immutable and we can't update these values.  To rectify this, we will make them property wrappers by adding `@State` in front of each.  We are now handing over these over to SwiftUI so that it remains persistent in memory as long as the view exists and when the state changes, SwiftUI will automatically reload with the latest changes.

2. Next we have to get a source of truth for the view, to actually know information from the view model, like those published fields we have there.  Right after our `@State` variables, we need to create an instance of the `ViewModel` and since the view model is an `ObservableObject` then this instance would be an `@ObservedObject` (place that in front, similar to what we did with `@State` above).

3. To update the repos responsively (as the user types), we are going to need to create a custom binding for the `searchField` from the search bar:

   ```swift
     let binding = Binding<String>(get: {
       self.searchField
     }, set: {
       self.searchField = $0
       self.viewModel.search(searchText: self.searchField)
       self.displayRepos()
     })
   ```

   This goes immediately inside `var body: some View`.

4. Now this will display an error because we haven't defined a function called `displayRepos()`.  To correct that, go outside the `var body: some View {}` block (but still in the struct) and add the following code:

    ```swift
    func loadData() {
      Parser().fetchRepositories { (repos) in
        self.viewModel.repos = repos
        self.displayedRepos = repos
      }
    }

    func displayRepos() {
      if searchField == "" {
        displayedRepos = viewModel.repos
      } else {
        displayedRepos = viewModel.filteredRepos
      }
    }
    ```

    As a bonus, this will give us a method to load data as well.

5. Now we get to creating the view itself.  Within the `var body: some View {}` block (but after our `binding`, go ahead and return a VStack; the first thing it will have is a `TextField` and in the placeholder `text: Value` replace the value with `binding`.

6. The next thing in our VStack is a `List` that is populated with `RepositoryRow` views as we did in class with PriceCheck.  This list is based off of `displayedRepos`, which can change as the search is activated.  Finally, add the `.navigationBarTitle` to the `List` element so it says "Swift Repos".

7. For the entire VStack, add on `.onAppear(perform: loadData)`. This is updating the `displayedRepos` when the View appears.

8. Run the app in a simulator and see that the app displays the repos from the API call and that searching filters out that list.


### WebView (`RepositoryDetail`)

This view is given to you. Look it over to see how it works. Now here's the trick: we want to make sure each row in the list (in the `ContentView`) links to the appropriate GitHub repo. (hint: use a `NavigationLink` like we did in class with the destination being `WebView(request: URLRequest(url:URL(string: repository.htmlURL)!)`.)

If time allows, you can also explore customizing the views more and cleaning up some of the code.  Feel free to explore further--that's where the real fun and learning is!

Qapla'
