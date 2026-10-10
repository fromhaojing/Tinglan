# Changelog

每个版本必须在此记录变更；发布流程会提取对应版本的段落，作为 GitHub Release
正文并渲染进 Sparkle appcast 的更新说明。Sections are the change categories
(`### Added / 新增`, `### Fixed / 修复`, `### Improved / 改进`); within each
section the English bullets come first, followed by their Simplified Chinese
counterparts. 段落格式：`## <版本号> - <日期>`，条目必须写成单行。

## 1.3.0 - 2026-10-10

### Added / 新增

- Added sleep timers, reduce-recommendation actions, per-source gray-track controls, and customizable macOS shortcuts with opt-in global hotkeys
- 新增睡眠定时、减少推荐、灰色歌曲音源独立开关，以及 macOS 自定义快捷键和默认关闭的全局快捷键

### Fixed / 修复

- Fixed main-window restoration from the Dock, home card sizing, macOS playback-mode choices, iPad settings/search access, and the iOS launch-screen declaration
- 修复 Dock 唤出主窗口、首页卡片宽度、macOS 播放模式选项、iPad 设置与搜索入口，以及 iOS 启动屏声明
- Validate third-party audio title, artist and duration; retry unreachable NetEase CDN hosts once and isolate obsolete playback callbacks after track changes
- 校验第三方音源的歌名、歌手与时长；网易云 CDN 主机不可达时重试备用主机，并隔离切歌后过期的播放回调

### Improved / 改进

- iOS update IPAs are accessible in Files and can be shared to signing tools; improve landscape player sizing and tap-cover behavior
- iOS 更新包可在文件 App 中找到并分享至签名工具；改进横屏播放页尺寸与点击封面收起歌词的行为

## 1.2.1 - 2026-09-01

### Fixed / 修复

- Fixed inconsistent macOS appearance updates across the main window, sidebar materials, settings window, and immersive player when switching between Light, Dark, and Follow System
- 修复 macOS 在浅色、深色与跟随系统之间切换时，主窗口、侧边栏材质、设置窗口和沉浸播放页外观不同步的问题

## 1.2.0 - 2026-08-31

### Added / 新增

- Added a retro vinyl now-playing mode, real audio-spectrum playing indicators, Japanese furigana, and word-by-word karaoke lyrics
- 新增黑胶唱片播放模式、真实音频频谱播放指示、日文振假名和逐字卡拉 OK 歌词
- Added automatic update-check and horizontally centered desktop-lyrics options
- 新增启动时自动检查更新和桌面歌词水平居中选项

### Fixed / 修复

- Fixed reopening the single main window from the Dock and corrected the desktop-lyrics button state
- 修复从 Dock 重新打开单一主窗口以及桌面歌词按钮状态显示

### Improved / 改进

- Reduced idle interface redraws and improved artwork caching, lyric rendering, playback reporting, and gray-track fallback behavior
- 减少界面空闲时的重复刷新，并改进封面缓存、歌词渲染、播放记录和灰色歌曲回退行为

## 1.1.4 - 2026-08-27

### Improved / 改进

- Optimized code performance
- 优化代码性能

## 1.1.3 - 2026-08-27

### Improved / 改进

- On macOS, titles and the search field now fade continuously with scrolling across Home, Explore, library, search, and detail pages, preventing content from overlapping the transparent toolbar
- macOS 上推荐、精选、音乐库、搜索及详情页面的标题和搜索框现在会随滚动距离连续渐隐，避免内容与透明工具栏重叠

## 1.1.2 - 2026-08-26

### Fixed / 修复

- Home cards now use value-based navigation, so switching sidebar sections after opening Daily Recommendations, a playlist, an album, or an artist correctly returns to the selected section
- On iOS 16 and 17, tapping the mini player now opens the full-screen Now Playing page with a bottom slide-up transition
- macOS buttons no longer show an unwanted focus outline after being clicked; text-field focus feedback remains unchanged
- The macOS Check for Updates menu item now displays its update icon
- 推荐页卡片改为值驱动导航；打开每日推荐、歌单、专辑或歌手后再切换侧边栏，可以正确进入所选页面
- iOS 16 和 17 上点击迷你播放器现在可以通过底部上滑动画正常打开全屏播放页
- macOS 按钮点击后不再显示多余的焦点外框，文本输入框的焦点提示保持不变
- macOS 的“检查更新”菜单项现在会正常显示更新图标

## 1.1.1 - 2026-08-26

### Fixed / 修复

- Pressing Return on the default search suggestion now performs the search on the first attempt, and returning from search to Home clears the search field
- 首次打开应用后直接对默认搜索词按回车即可正常搜索；从搜索页返回推荐页时会清空搜索框

## 1.1.0 - 2026-08-26

### Added / 新增

- Added AirPlay and Bluetooth output selection, macOS Dock playback controls with recent sources, and optional romaji above Japanese lyrics
- iOS gains an immersive Now Playing experience, Liquid Glass tab navigation, iOS 16 support, and TrollStore-assisted in-app updates
- 新增 AirPlay 与蓝牙输出设备选择、macOS Dock 播放控制和最近播放来源，以及可选的日文歌词罗马音
- iOS 新增沉浸式播放页、液态玻璃标签导航、iOS 16 支持及 TrollStore 应用内更新

### Fixed / 修复

- Fixed macOS window sizing and toolbar spacing around the immersive player, and corrected SMS login, library navigation, playback controls, and several iOS layouts
- 修复 macOS 沉浸播放页的窗口尺寸与工具栏留白，并修复短信登录、音乐库导航、播放控制及多处 iOS 布局问题

### Improved / 改进

- Playback state updates now redraw less of the interface, while compact track lists and Now Playing layouts adapt more cleanly across device sizes
- 优化播放状态刷新范围，并改进紧凑歌曲列表与播放页面在不同设备尺寸下的适配

## 1.0.0 - 2026-08-25

### Added / 新增

- The app is now released as Tinglan, owned by Haojing, with independent macOS and iOS bundle identifiers and its own GitHub update channel
- Light, Dark, and Follow System appearance modes now apply consistently to SwiftUI content, the native macOS titlebar, and sidebar materials
- 听澜现作为好景独立维护的应用发布，使用独立的 macOS / iOS Bundle ID 与 GitHub 更新通道
- 新增浅色、深色、跟随系统三种外观模式，并统一适配 SwiftUI 内容、macOS 原生标题栏与侧边栏材质

### Improved / 改进

- The macOS sidebar now uses a native AppKit split view for smooth collapse and expansion, fixed width, full-height material, and a correctly tracking system toggle
- Search uses one consistent native field across Home and search results; loading, error, and player layouts now fill the detail column correctly
- macOS 侧边栏改用 AppKit 原生分栏，实现流畅展开收起、固定宽度、全高材质与正确跟随的系统按钮
- 推荐页与搜索结果页统一使用同一个原生搜索框；加载、失败状态和播放器现可正确占满右侧内容区
