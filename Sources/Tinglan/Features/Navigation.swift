import SwiftUI

private struct OpenLoginKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var openLogin: () -> Void {
        get { self[OpenLoginKey.self] }
        set { self[OpenLoginKey.self] = newValue }
    }
}

struct PlayerChromeModifier: ViewModifier {
    @EnvironmentObject private var player: PlayerService

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .overlay(alignment: .bottomTrailing) {
                PlayerBar()
                    .frame(maxWidth: .infinity)
            }
            .overlay(alignment: .trailing) {
                rightPanel
            }
            .animation(AppAnimation.standard, value: player.activePanel)
    }

    @ViewBuilder
    private var rightPanel: some View {
        if let panel = player.activePanel {
            Group {
                switch panel {
                case .lyrics:
                    LyricsPanel()
                case .queue:
                    QueuePanel()
                }
            }
            .padding(.top, 12)
            .padding(.bottom, Theme.Layout.playerChromeClearance + 10)
            .padding(.trailing, 16)
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }
    }
}

enum SidebarItem: Hashable {
    case home
    case explore
    case fm
    case search
    case likedSongs
    case daily
    case recents
    case collections
    case cloud
    case playlist(Int)
}

enum Destination: Hashable {
    case playlist(Int)
    case radarPlaylist(Int)
    case album(Int)
    case artist(Int)
    case daily
    case toplists
    case recents
    case collections
    case cloud
    case search(String)
}

/// Registers all shared navigation destinations on a stack.
struct DestinationsModifier: ViewModifier {
    var searchText: Binding<String>?
    var isSearchVisible: Binding<Bool>?

    func body(content: Content) -> some View {
        content.navigationDestination(for: Destination.self) { destination in
            Group {
                switch destination {
                case .playlist(let id):
                    PlaylistDetailView(playlistID: id)
                case .radarPlaylist(let id):
                    PlaylistDetailView(playlistID: id, recommendationContext: .radar)
                case .album(let id):
                    AlbumDetailView(albumID: id)
                case .artist(let id):
                    ArtistDetailView(artistID: id)
                case .daily:
                    DailySongsView()
                case .toplists:
                    ToplistsView()
                case .recents:
                    RecentsView()
                case .collections:
                    CollectionsView()
                case .cloud:
                    CloudView()
                case .search(let query):
                    SearchView(query: query, searchText: searchText)
                        .onAppear {
                            isSearchVisible?.wrappedValue = true
                        }
                        .onDisappear {
                            isSearchVisible?.wrappedValue = false
                        }
                }
            }
            .playerContentInset()
        }
    }
}

extension View {
    func playerChrome() -> some View {
        modifier(PlayerChromeModifier())
    }

    /// Pages clear the floating player bar with an explicit trailing
    /// `PlayerClearanceSpacer` in their scroll content; safeAreaPadding
    /// proved unreliable inside navigation stacks (#12).
    func playerContentInset() -> some View {
        self
    }

    func appDestinations() -> some View {
        modifier(DestinationsModifier(searchText: nil, isSearchVisible: nil))
    }

    func appDestinations(
        searchText: Binding<String>,
        isSearchVisible: Binding<Bool>
    ) -> some View {
        modifier(DestinationsModifier(
            searchText: searchText,
            isSearchVisible: isSearchVisible
        ))
    }
}

/// Trailing spacer for scrollable pages so the last row clears the
/// floating player bar.
struct PlayerClearanceSpacer: View {
    var body: some View {
        #if os(iOS)
        Color.clear.frame(height: 80) // mini player bar above the tab bar
        #else
        Color.clear.frame(height: Theme.Layout.playerChromeClearance + 8)
        #endif
    }
}
