// Created by Prof. H in 2026
// Part of the SwiftRepos project
// Using Swift 6.0
// Qapla'

import SwiftUI
import WebKit

// TA NOTE: `UIViewRepresentable` is the SwiftUI-to-UIKit bridge. Students build
// this themselves in this version of the lab (in the older lab it was handed to
// them). The two required methods:
//   - makeUIView: build the UIKit view once
//   - updateUIView: called whenever SwiftUI state changes; push new state in
// `Context` carries coordinator/environment info — unused here since we're read-only.
struct WebView: UIViewRepresentable {
  let url: URL

  func makeUIView(context: Context) -> WKWebView {
    WKWebView()
  }

  func updateUIView(_ webView: WKWebView, context: Context) {
    webView.load(URLRequest(url: url))
  }
}
