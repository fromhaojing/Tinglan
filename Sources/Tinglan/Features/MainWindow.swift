import SwiftUI
#if os(macOS)
import AppKit
#endif

struct MainWindow: View {
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif
    @EnvironmentObject private var player: PlayerService
    @EnvironmentObject private var account: AccountStore
    @EnvironmentObject private var settings: SettingsManager
    @EnvironmentObject private var toasts: ToastCenter

    @State private var selection: SidebarItem = .home
    @State private var path = NavigationPath()
    @State private var searchText = ""
    @State private var searchPrompt = "搜索歌曲、歌手、专辑、歌单"
    @State private var placeholderQuery = ""
    @State private var isSearchVisible = false
    @State private var hasSearchDestination = false
    @State private var showLogin = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var visibilityBeforeNowPlaying: NavigationSplitViewVisibility?
    #if os(macOS)
    @State private var isSidebarCollapsed = false
    @State private var sidebarCollapsedBeforeNowPlaying: Bool?
    @State private var toolbarScrollProgress: CGFloat = 0
    #endif

    var body: some View {
        splitContent
        #if os(macOS)
        .toolbar {
            if #available(macOS 26.0, *) {
                ToolbarItem(placement: .primaryAction) {
                    MacSearchField(
                        text: $searchText,
                        prompt: searchPrompt,
                        onSubmit: submitSearch
                    )
                    .frame(width: 320)
                    .opacity(1 - toolbarScrollProgress)
                    .allowsHitTesting(toolbarScrollProgress < 1)
                }
                .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .primaryAction) {
                    MacSearchField(
                        text: $searchText,
                        prompt: searchPrompt,
                        onSubmit: submitSearch
                    )
                    .frame(width: 320)
                    .opacity(1 - toolbarScrollProgress)
                    .allowsHitTesting(toolbarScrollProgress < 1)
                }
            }
        }
        #endif
        #if os(macOS)
        // Immersive now-playing page: hide the whole window toolbar
        // (sidebar toggle, navigation title, search field).
        .toolbar(player.showNowPlaying ? .hidden : .automatic, for: .windowToolbar)
        .background(MainWindowConfigurator())
        #endif
        .environment(\.openLogin, { showLogin = true })
        .task {
            #if os(macOS)
            // Recreate the single main scene when the user clicks the Dock
            // icon after closing the window while the app remains alive.
            AppDelegate.shared?.openMainWindow = { openWindow(id: "main") }
            #endif
            DesktopLyricsController.shared.sync(with: settings.showDesktopLyrics)
            await account.bootstrap()
        }
        .task {
            if let keyword = try? await NeteaseAPI.searchDefaultKeyword(), !keyword.isEmpty {
                searchPrompt = keyword
                placeholderQuery = keyword
            }
        }
        .onChange(of: settings.showDesktopLyrics) { _ in
            DesktopLyricsController.shared.sync(with: settings.showDesktopLyrics)
        }
        // Collapse the sidebar while the immersive page is open: the split
        // view's divider keeps its resize-cursor rect active even underneath
        // an overlay, leaking the drag cursor onto the now-playing page (#6).
        .onChange(of: player.showNowPlaying) { _ in
            #if os(macOS)
            if player.showNowPlaying {
                sidebarCollapsedBeforeNowPlaying = isSidebarCollapsed
                isSidebarCollapsed = true
            } else {
                isSidebarCollapsed = sidebarCollapsedBeforeNowPlaying ?? false
                sidebarCollapsedBeforeNowPlaying = nil
            }
            #else
            if player.showNowPlaying {
                visibilityBeforeNowPlaying = columnVisibility
                columnVisibility = .detailOnly
            } else {
                columnVisibility = visibilityBeforeNowPlaying ?? .all
                visibilityBeforeNowPlaying = nil
            }
            #endif
        }
        .sheet(isPresented: $showLogin) {
            LoginSheet()
        }
        .overlay {
            if player.showNowPlaying {
                NowPlayingView()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay(alignment: .top) {
            if let toast = toasts.current {
                ToastView(toast: toast)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 12)
            }
        }
        .animation(AppAnimation.smooth, value: player.showNowPlaying)
        .animation(.spring(duration: 0.3), value: toasts.current)
    }

    @ViewBuilder
    private var splitContent: some View {
        #if os(macOS)
        MacSplitView(
            isSidebarCollapsed: $isSidebarCollapsed,
            sidebarWidth: Theme.Layout.sidebarWidth
        ) {
            hostedContent(
                SidebarView(selection: $selection, showLogin: $showLogin)
            )
        } detail: {
            hostedContent(detailStack.playerChrome())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .ignoresSafeArea(.container, edges: .top)
        #else
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selection: $selection, showLogin: $showLogin)
                .navigationSplitViewColumnWidth(
                    min: Theme.Layout.sidebarWidth,
                    ideal: Theme.Layout.sidebarWidth,
                    max: Theme.Layout.sidebarWidth
                )
        } detail: {
            detailStack
                .playerChrome()
        }
        #endif
    }

    #if os(macOS)
    private func hostedContent<Content: View>(_ content: Content) -> some View {
        content
            .environmentObject(player)
            .environmentObject(account)
            .environmentObject(settings)
            .environmentObject(toasts)
            .environment(\.openLogin, { showLogin = true })
            .environment(\.macToolbarScrollProgressBinding, $toolbarScrollProgress)
            .tint(Theme.accent)
            .focusEffectDisabled()
    }
    #endif

    @ViewBuilder
    private var detailStack: some View {
        #if os(macOS)
        detailNavigationStack
        #else
        detailNavigationStack
            .searchable(text: $searchText, prompt: Text(searchPrompt))
            .onSubmit(of: .search) {
                submitSearch()
            }
        #endif
    }

    private var detailNavigationStack: some View {
        NavigationStack(path: $path) {
            rootView
                .playerContentInset()
                .appDestinations(
                    searchText: $searchText,
                    isSearchVisible: $isSearchVisible
                )
        }
        .onChange(of: selection) { _ in
            path = NavigationPath()
            #if os(macOS)
            toolbarScrollProgress = 0
            #endif
            if hasSearchDestination {
                searchText = ""
                hasSearchDestination = false
            }
            isSearchVisible = false
        }
        .onChange(of: path.count) { count in
            guard count == 0, hasSearchDestination else { return }
            searchText = ""
            isSearchVisible = false
            hasSearchDestination = false
        }
    }

    private func submitSearch() {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let query = trimmed.isEmpty ? placeholderQuery : trimmed
        guard !query.isEmpty else { return }
        searchText = query
        if !isSearchVisible {
            hasSearchDestination = true
            path.append(Destination.search(query))
        }
    }

    @ViewBuilder
    private var rootView: some View {
        switch selection {
        case .home:
            HomeView()
        case .explore:
            ExploreView()
        case .fm:
            FMView()
        case .search:
            // iPad search entry: SearchView's `.searchable` bar surfaces in the
            // detail nav bar (the desktop toolbar search field doesn't render on
            // iPad). (#59)
            SearchView(query: "")
        case .likedSongs:
            if let playlist = account.likedSongsPlaylist {
                PlaylistDetailView(playlistID: playlist.id, isLikedList: true)
                    .id(playlist.id)
            } else {
                loginPrompt
            }
        case .daily:
            DailySongsView()
        case .recents:
            RecentsView()
        case .collections:
            CollectionsView()
        case .cloud:
            CloudView()
        case .playlist(let id):
            PlaylistDetailView(playlistID: id)
                .id(id)
        }
    }

    private var loginPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.circle")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("登录后查看你喜欢的音乐")
                .font(.headline)
            Button("登录") { showLogin = true }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

}

#if os(macOS)
@MainActor
private final class SidebarMaterialController<Content: View>: NSViewController {
    let host: NSHostingController<Content>
    private let materialView = NSVisualEffectView()

    init(rootView: Content) {
        host = NSHostingController(rootView: rootView)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        materialView.material = .windowBackground
        materialView.blendingMode = .withinWindow
        materialView.state = .followsWindowActiveState
        view = materialView

        addChild(host)
        let hostedView = host.view
        hostedView.translatesAutoresizingMaskIntoConstraints = false
        hostedView.wantsLayer = true
        hostedView.layer?.backgroundColor = NSColor.clear.cgColor
        materialView.addSubview(hostedView)
        NSLayoutConstraint.activate([
            hostedView.leadingAnchor.constraint(equalTo: materialView.leadingAnchor),
            hostedView.trailingAnchor.constraint(equalTo: materialView.trailingAnchor),
            hostedView.topAnchor.constraint(equalTo: materialView.topAnchor),
            hostedView.bottomAnchor.constraint(equalTo: materialView.bottomAnchor),
        ])

        // Keep the list below the traffic lights while the material itself
        // continues through the titlebar area.
        host.safeAreaRegions = .all
    }
}

@MainActor
private final class HostedSplitController<Sidebar: View, Detail: View>: NSSplitViewController {
    let sidebarController: SidebarMaterialController<Sidebar>
    let detailHost: NSHostingController<Detail>
    let sidebarItem: NSSplitViewItem

    var sidebarHost: NSHostingController<Sidebar> {
        sidebarController.host
    }

    init(
        sidebar: Sidebar,
        detail: Detail,
        sidebarWidth: CGFloat,
        collapsed: Bool
    ) {
        sidebarController = SidebarMaterialController(rootView: sidebar)
        detailHost = NSHostingController(rootView: detail)
        detailHost.sizingOptions = []
        sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarController)
        super.init(nibName: nil, bundle: nil)

        splitView.isVertical = true
        splitView.dividerStyle = .thin

        sidebarItem.minimumThickness = sidebarWidth
        sidebarItem.maximumThickness = sidebarWidth
        sidebarItem.allowsFullHeightLayout = true
        sidebarItem.titlebarSeparatorStyle = .none
        sidebarItem.canCollapse = true
        sidebarItem.canCollapseFromWindowResize = false
        sidebarItem.collapseBehavior = .preferResizingSiblingsWithFixedSplitView
        sidebarItem.isCollapsed = collapsed

        addSplitViewItem(sidebarItem)
        addSplitViewItem(NSSplitViewItem(viewController: detailHost))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        configureWindow()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        configureWindow()
        installToolbarItems()
    }

    func setSidebarWidth(_ width: CGFloat) {
        sidebarItem.minimumThickness = width
        sidebarItem.maximumThickness = width
    }

    func setCollapsed(_ collapsed: Bool) {
        guard sidebarItem.isCollapsed != collapsed else { return }
        toggleSidebar(nil)
    }

    private func configureWindow() {
        guard let window = view.window else { return }
        // A sidebar item can occupy the titlebar only when the window exposes
        // that area to its content. The sidebar item then supplies its own
        // native translucent background all the way to the top.
        window.styleMask.insert(.fullSizeContentView)
        window.titlebarAppearsTransparent = true
    }

    func installToolbarItems() {
        configureWindow()
        guard let toolbar = view.window?.toolbar else { return }

        if !toolbar.items.contains(where: { $0.itemIdentifier == .toggleSidebar }) {
            toolbar.insertItem(withItemIdentifier: .toggleSidebar, at: 0)
        }

        if let toggleIndex = toolbar.items.firstIndex(where: {
            $0.itemIdentifier == .toggleSidebar
        }), toggleIndex == 0 || toolbar.items[toggleIndex - 1].itemIdentifier != .flexibleSpace {
            toolbar.insertItem(withItemIdentifier: .flexibleSpace, at: toggleIndex)
        }

        if !toolbar.items.contains(where: {
            $0.itemIdentifier == .sidebarTrackingSeparator
        }) {
            let separatorIndex = toolbar.items.firstIndex(where: {
                $0.itemIdentifier == .toggleSidebar
            }).map { $0 + 1 } ?? 0
            toolbar.insertItem(
                withItemIdentifier: .sidebarTrackingSeparator,
                at: min(separatorIndex, toolbar.items.count)
            )
        }

        if let toggle = toolbar.items.first(where: {
            $0.itemIdentifier == .toggleSidebar
        }) {
            toggle.target = self
            toggle.action = #selector(toggleSidebar(_:))
            configureSidebarToggleFocus(toggle)
        }

        if let separator = toolbar.items.first(where: {
            $0.itemIdentifier == .sidebarTrackingSeparator
        }) as? NSTrackingSeparatorToolbarItem {
            separator.splitView = splitView
            separator.dividerIndex = 0
        }
    }

    private func configureSidebarToggleFocus(_ item: NSToolbarItem) {
        if let itemView = item.view {
            disableFocusRing(in: itemView)
        }

        // AppKit may finish constructing the standard toolbar item's private
        // subviews after insertion, so apply once more on the next run loop.
        DispatchQueue.main.async { [weak self, weak item] in
            guard let self, let itemView = item?.view else { return }
            self.disableFocusRing(in: itemView)
        }
    }

    private func disableFocusRing(in view: NSView) {
        view.focusRingType = .none
        if let control = view as? NSControl {
            control.refusesFirstResponder = true
        }
        view.subviews.forEach(disableFocusRing)
    }
}

@MainActor
private struct MacSplitView<Sidebar: View, Detail: View>: NSViewControllerRepresentable {
    @Binding var isSidebarCollapsed: Bool
    let sidebarWidth: CGFloat
    let sidebar: Sidebar
    let detail: Detail

    init(
        isSidebarCollapsed: Binding<Bool>,
        sidebarWidth: CGFloat,
        @ViewBuilder sidebar: () -> Sidebar,
        @ViewBuilder detail: () -> Detail
    ) {
        _isSidebarCollapsed = isSidebarCollapsed
        self.sidebarWidth = sidebarWidth
        self.sidebar = sidebar()
        self.detail = detail()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(binding: $isSidebarCollapsed)
    }

    func makeNSViewController(
        context: Context
    ) -> HostedSplitController<Sidebar, Detail> {
        let controller = HostedSplitController(
            sidebar: sidebar,
            detail: detail,
            sidebarWidth: sidebarWidth,
            collapsed: isSidebarCollapsed
        )
        context.coordinator.observe(controller)
        return controller
    }

    func updateNSViewController(
        _ controller: HostedSplitController<Sidebar, Detail>,
        context: Context
    ) {
        context.coordinator.binding = $isSidebarCollapsed
        controller.sidebarHost.rootView = sidebar
        controller.detailHost.rootView = detail
        controller.setSidebarWidth(sidebarWidth)
        controller.setCollapsed(isSidebarCollapsed)

        DispatchQueue.main.async { [weak controller] in
            controller?.installToolbarItems()
        }
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsViewController: HostedSplitController<Sidebar, Detail>,
        context: Context
    ) -> CGSize? {
        guard let width = proposal.width, let height = proposal.height else {
            return nil
        }

        // The split view is the window's root layout. Its size must come from
        // the window, not from the current detail view's ideal content size.
        return CGSize(width: width, height: height)
    }

    static func dismantleNSViewController(
        _ controller: HostedSplitController<Sidebar, Detail>,
        coordinator: Coordinator
    ) {
        coordinator.stopObserving()
    }

    @MainActor
    final class Coordinator {
        var binding: Binding<Bool>
        private var collapseObservation: NSKeyValueObservation?

        init(binding: Binding<Bool>) {
            self.binding = binding
        }

        func observe(_ controller: HostedSplitController<Sidebar, Detail>) {
            collapseObservation = controller.sidebarItem.observe(
                \.isCollapsed,
                options: [.new]
            ) { [weak self] _, change in
                guard let collapsed = change.newValue else { return }
                DispatchQueue.main.async {
                    guard
                        let self,
                        self.binding.wrappedValue != collapsed
                    else {
                        return
                    }
                    self.binding.wrappedValue = collapsed
                }
            }
        }

        func stopObserving() {
            collapseObservation?.invalidate()
            collapseObservation = nil
        }
    }
}

@MainActor
private struct MacSearchField: NSViewRepresentable {
    @Binding var text: String
    let prompt: String
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.delegate = context.coordinator
        field.controlSize = .regular
        field.bezelStyle = .roundedBezel
        field.placeholderString = prompt
        field.stringValue = text
        return field
    }

    func updateNSView(_ field: NSSearchField, context: Context) {
        context.coordinator.parent = self
        field.placeholderString = prompt
        if field.stringValue != text {
            field.stringValue = text
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: MacSearchField

        init(parent: MacSearchField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else { return }
            if parent.text != field.stringValue {
                parent.text = field.stringValue
            }
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            guard commandSelector == #selector(NSResponder.insertNewline(_:)) else {
                return false
            }
            if let field = control as? NSSearchField {
                parent.text = field.stringValue
            }
            parent.onSubmit()
            control.window?.makeFirstResponder(nil)
            return true
        }
    }
}
#endif

// MARK: - Toast

struct ToastView: View {
    let toast: Toast

    var body: some View {
        Text(toast.message)
            .font(.system(size: 12.5, weight: .medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .compatGlass(in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }
}

#if os(macOS)
struct MainWindowConfigurator: NSViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async { context.coordinator.attach(to: view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { context.coordinator.attach(to: nsView.window) }
    }

    @MainActor
    final class Coordinator: NSObject, NSWindowDelegate {
        private(set) weak var window: NSWindow?
        private weak var forwardee: NSWindowDelegate?

        func attach(to window: NSWindow?) {
            guard let window, self.window == nil else { return }
            self.window = window
            window.isReleasedWhenClosed = false
            // Insert ourselves as the delegate, forwarding to whatever
            // delegate SwiftUI installed.
            if window.delegate !== self {
                forwardee = window.delegate
                window.delegate = self
            }
            AppDelegate.shared?.mainWindow = window
        }

        // Hide instead of close; keep the scene alive.
        func windowShouldClose(_ sender: NSWindow) -> Bool {
            sender.orderOut(nil)
            return false
        }

        // Transparently forward every other delegate callback to SwiftUI.
        override func responds(to aSelector: Selector!) -> Bool {
            super.responds(to: aSelector) || (forwardee?.responds(to: aSelector) ?? false)
        }

        override func forwardingTarget(for aSelector: Selector!) -> Any? {
            if forwardee?.responds(to: aSelector) == true { return forwardee }
            return super.forwardingTarget(for: aSelector)
        }
    }
}
#endif
