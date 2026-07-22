import SwiftUI

public struct ContentView: View {
    public var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "No Saved Items",
                systemImage: "tray",
                description: Text("Share something to ShareGather and come back to it later.")
            )
            .navigationTitle("ShareGather")
        }
    }
    
    public init() {}
}
