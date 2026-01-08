import SwiftUI

struct HomeView: View {
    var body: some View {
        ZStack {
            NetworkBackground()
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "network")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(Color.green)
                    Text("Grid")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.primary)
                    Text("Discover devices on your network with smart port scanning, reverse DNS and latency.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                }

                VStack(spacing: 12) {
                    NavigationLink(value: Route.scan) {
                        Label("Scan Network", systemImage: "wave.3.right")
                            .font(.headline)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .frame(maxWidth: 340)
                    }
                    .buttonStyle(.borderedProminent)

                    Text("You can return here anytime using the back button.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .ignoresSafeArea()
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

enum Route: Hashable {
    case scan
}
