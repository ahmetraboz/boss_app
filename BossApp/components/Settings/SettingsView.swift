//
//  SettingsView.swift
//  Boss App
//
//

import AVFoundation
import BossAutostart
import BossConfig
import SwiftUI

struct SettingsView: View {
    @State private var selectedTab = "General"

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                NavigationLink(value: "General") {
                    Label("Genel", systemImage: "gear")
                }
                NavigationLink(value: "Appearance") {
                    Label("Görünüm", systemImage: "eye")
                }
                NavigationLink(value: "Media") {
                    Label("Müzik", systemImage: "music.note")
                }
//                NavigationLink(value: "Downloads") {
//                    Label("İndirmeler", systemImage: "square.and.arrow.down")
//                }
                NavigationLink(value: "Shelf") {
                    Label("Raf", systemImage: "books.vertical")
                }
                NavigationLink(value: "Notes") {
                    Label("Notlar", systemImage: "note.text")
                }
                NavigationLink(value: "Screenshots") {
                    Label("Ekran Görüntüleri", systemImage: "photo.on.rectangle")
                }
                NavigationLink(value: "Clipboard") {
                    Label("Pano", systemImage: "clipboard")
                }
                // NavigationLink(value: "Extensions") {
                //     Label("Eklentiler", systemImage: "puzzlepiece.extension")
                // }
                NavigationLink(value: "About") {
                    Label("Hakkında", systemImage: "info.circle")
                }
            }
            .listStyle(SidebarListStyle())
            .tint(.effectiveAccent)
            .toolbar(removing: .sidebarToggle)
            .navigationSplitViewColumnWidth(200)
        } detail: {
            Group {
                switch selectedTab {
                case "General":
                    GeneralSettings()
                case "Appearance":
                    Appearance()
                case "Media":
                    Media()
                case "Shelf":
                    Shelf()
                case "Notes":
                    NotesSettings()
                case "Screenshots":
                    ScreenshotsSettings()
                case "Clipboard":
                    ClipboardSettings()
                case "Extensions":
                    GeneralSettings()
                case "About":
                    About()
                default:
                    GeneralSettings()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar(removing: .sidebarToggle)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("")
                    .frame(width: 0, height: 0)
                    .accessibilityHidden(true)
            }
        }
        .formStyle(.grouped)
        .frame(width: 700)
        .background(Color(NSColor.windowBackgroundColor))
        .tint(.effectiveAccent)
    }
}

struct GeneralSettings: View {
    @State private var screens: [(uuid: String, name: String)] = NSScreen.screens.compactMap { screen in
        guard let uuid = screen.displayUUID else { return nil }
        return (uuid, screen.localizedName)
    }
    @EnvironmentObject var vm: BossViewModel
    @ObservedObject var coordinator = BossViewCoordinator.shared

    @Default(.mirrorShape) var mirrorShape
    @Default(.showEmojis) var showEmojis
    @Default(.minimumHoverDuration) var minimumHoverDuration
    @Default(.nonNotchHeight) var nonNotchHeight
    @Default(.nonNotchHeightMode) var nonNotchHeightMode
    @Default(.notchHeight) var notchHeight
    @Default(.notchHeightMode) var notchHeightMode
    @Default(.showOnAllDisplays) var showOnAllDisplays
    @Default(.automaticallySwitchDisplay) var automaticallySwitchDisplay
    @Default(.openNotchOnHover) var openNotchOnHover
    

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(
                    get: { BossConfig[.menubarIcon] },
                    set: { BossConfig[.menubarIcon] = $0 }
                )) {
                    Text("Menü çubuğu simgesini göster")
                }
                .tint(.effectiveAccent)
                BossAutostart.Toggle("Girişte başlat")
                BossConfig.Toggle(key: .showOnAllDisplays) {
                    Text("Tüm ekranlarda göster")
                }
                .onChange(of: showOnAllDisplays) {
                    NotificationCenter.default.post(
                        name: Notification.Name.showOnAllDisplaysChanged, object: nil)
                }
                Picker("Tercih edilen ekran", selection: $coordinator.preferredScreenUUID) {
                    ForEach(screens, id: \.uuid) { screen in
                        Text(screen.name).tag(screen.uuid as String?)
                    }
                }
                .onChange(of: NSScreen.screens) {
                    screens = NSScreen.screens.compactMap { screen in
                        guard let uuid = screen.displayUUID else { return nil }
                        return (uuid, screen.localizedName)
                    }
                }
                .disabled(showOnAllDisplays)
                
                BossConfig.Toggle(key: .automaticallySwitchDisplay) {
                    Text("Ekranları otomatik değiştir")
                }
                    .onChange(of: automaticallySwitchDisplay) {
                        NotificationCenter.default.post(
                            name: Notification.Name.automaticallySwitchDisplayChanged, object: nil)
                    }
                    .disabled(showOnAllDisplays)
            } header: {
                Text("Sistem Özellikleri")
            }

            Section {
                Picker(
                    selection: $notchHeightMode,
                    label:
                        Text("Çentikli ekranlarda boyut")
                ) {
                    Text("Gerçek çentik boyutuyla eşleştir")
                        .tag(WindowHeightMode.matchRealNotchSize)
                    Text("Menü çubuğu yüksekliğiyle eşleştir")
                        .tag(WindowHeightMode.matchMenuBar)
                    Text("Özel boyut")
                        .tag(WindowHeightMode.custom)
                }
                .onChange(of: notchHeightMode) {
                    switch notchHeightMode {
                    case .matchRealNotchSize:
                        notchHeight = 38
                    case .matchMenuBar:
                        notchHeight = 44
                    case .custom:
                        notchHeight = 38
                    }
                    NotificationCenter.default.post(
                        name: Notification.Name.notchHeightChanged, object: nil)
                }
                if notchHeightMode == .custom {
                    Slider(value: $notchHeight, in: 15...45, step: 1) {
                        Text("Özel boyut değeri - \(notchHeight, specifier: "%.0f")")
                    }
                    .onChange(of: notchHeight) {
                        NotificationCenter.default.post(
                            name: Notification.Name.notchHeightChanged, object: nil)
                    }
                }
                Picker("Çentiksiz ekranlarda boyut", selection: $nonNotchHeightMode) {
                    Text("Menü çubuğu yüksekliğiyle eşleştir")
                        .tag(WindowHeightMode.matchMenuBar)
                    Text("Gerçek çentik boyutuyla eşleştir")
                        .tag(WindowHeightMode.matchRealNotchSize)
                    Text("Özel boyut")
                        .tag(WindowHeightMode.custom)
                }
                .onChange(of: nonNotchHeightMode) {
                    switch nonNotchHeightMode {
                    case .matchMenuBar:
                        nonNotchHeight = 24
                    case .matchRealNotchSize:
                        nonNotchHeight = 32
                    case .custom:
                        nonNotchHeight = 32
                    }
                    NotificationCenter.default.post(
                        name: Notification.Name.notchHeightChanged, object: nil)
                }
                if nonNotchHeightMode == .custom {
                    Slider(value: $nonNotchHeight, in: 0...40, step: 1) {
                        Text("Özel boyut değeri - \(nonNotchHeight, specifier: "%.0f")")
                    }
                    .onChange(of: nonNotchHeight) {
                        NotificationCenter.default.post(
                            name: Notification.Name.notchHeightChanged, object: nil)
                    }
                }
            } header: {
                Text("Çentik Boyutlandırma")
            }

            NotchBehaviour()
        }
        .toolbar {
            Button("Uygulamadan Çık") {
                NSApp.terminate(self)
            }
            .controlSize(.extraLarge)
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Genel")
    }

    @ViewBuilder
    func NotchBehaviour() -> some View {
        Section {
            Toggle("Son sekmeyi hatırla", isOn: $coordinator.openLastTabByDefault)
            Slider(value: $minimumHoverDuration, in: 0...1, step: 0.1) {
                HStack {
                    Text("Gecikme süresi")
                    Spacer()
                    Text("\(minimumHoverDuration, specifier: "%.1f")sn")
                        .foregroundStyle(.secondary)
                }
            }
            .onChange(of: minimumHoverDuration) {
                NotificationCenter.default.post(
                    name: Notification.Name.notchHeightChanged, object: nil)
            }
        } header: {
            Text("Çentik Davranışı")
        }
    }
}

//struct Downloads: View {
//    @Default(.selectedDownloadIndicatorStyle) var selectedDownloadIndicatorStyle
//    @Default(.selectedDownloadIconStyle) var selectedDownloadIconStyle
//    var body: some View {
//        Form {
//            warningBadge("We don't support downloads yet", "It will be supported later on.")
//            Section {
//                BossConfig.Toggle(key: .enableDownloadListener) {
//                    Text("Show download progress")
//                }
//                    .disabled(true)
//                BossConfig.Toggle(key: .enableSafariDownloads) {
//                    Text("Enable Safari Downloads")
//                }
//                    .disabled(!BossConfig[.enableDownloadListener])
//                Picker("Download indicator style", selection: $selectedDownloadIndicatorStyle) {
//                    Text("Progress bar")
//                        .tag(DownloadIndicatorStyle.progress)
//                    Text("Percentage")
//                        .tag(DownloadIndicatorStyle.percentage)
//                }
//                Picker("Download icon style", selection: $selectedDownloadIconStyle) {
//                    Text("Only app icon")
//                        .tag(DownloadIconStyle.onlyAppIcon)
//                    Text("Only download icon")
//                        .tag(DownloadIconStyle.onlyIcon)
//                    Text("Both")
//                        .tag(DownloadIconStyle.iconAndAppIcon)
//                }
//
//            } header: {
//                HStack {
//                    Text("Download indicators")
//                    comingSoonTag()
//                }
//            }
//            Section {
//                List {
//                    ForEach([].indices, id: \.self) { index in
//                        Text("\(index)")
//                    }
//                }
//                .frame(minHeight: 96)
//                .overlay {
//                    if true {
//                        Text("No excluded apps")
//                            .foregroundStyle(Color(.secondaryLabelColor))
//                    }
//                }
//                .actionBar(padding: 0) {
//                    Group {
//                        Button {
//                        } label: {
//                            Image(systemName: "plus")
//                                .frame(width: 25, height: 16, alignment: .center)
//                                .contentShape(Rectangle())
//                                .foregroundStyle(.secondary)
//                        }
//
//                        Divider()
//                        Button {
//                        } label: {
//                            Image(systemName: "minus")
//                                .frame(width: 20, height: 16, alignment: .center)
//                                .contentShape(Rectangle())
//                                .foregroundStyle(.secondary)
//                        }
//                    }
//                }
//            } header: {
//                HStack(spacing: 4) {
//                    Text("Exclude apps")
//                    comingSoonTag()
//                }
//            }
//        }
//        .navigationTitle("Downloads")
//    }
//}

struct Media: View {
    @Default(.mediaController) var mediaController
    @ObservedObject var coordinator = BossViewCoordinator.shared
    @Default(.hideNotchOption) var hideNotchOption

    var body: some View {
        Form {
            Section {
                Picker("Müzik Kaynağı", selection: $mediaController) {
                    ForEach(availableMediaControllers) { controller in
                        Text(controller.rawValue).tag(controller)
                    }
                }
                .onChange(of: mediaController) { _, _ in
                    NotificationCenter.default.post(
                        name: Notification.Name.mediaControllerChanged,
                        object: nil
                    )
                }
            } header: {
                Text("Müzik Kaynağı")
            } footer: {
                if MusicManager.shared.isNowPlayingDeprecated {
                    HStack {
                        Text("YouTube Music oynatımı için Boss App masaüstü köprüsü kurulmalıdır.")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                } else {
                    Text(
                        "'Şu An Çalınan' önceki sürümlerdeki tek seçenekti ve tüm uygulamalarla çalışır."
                    )
                    .foregroundStyle(.secondary)
                    .font(.caption)
                }
            }
            
            Section {
                Toggle(
                    "Müzik canlı etkinliğini göster",
                    isOn: $coordinator.musicLiveActivityEnabled.animation()
                )
                Picker(
                    selection: $hideNotchOption,
                    label: Text("Tam ekran davranışı")
                ) {
                    Text("Tüm uygulamalar için gizle").tag(HideNotchOption.always)
                    Text("Yalnızca müzik uygulaması için gizle").tag(
                        HideNotchOption.nowPlayingOnly)
                    Text("Asla gizleme").tag(HideNotchOption.never)
                }
            } header: {
                Text("Müzik Canlı Etkinliği")
            }
            
            Section {
                MusicSlotConfigurationView()
            } header: {
                Text("Müzik Kontrolleri")
            }  footer: {
                Text("Müzik çalarda hangi kontrollerin görüneceğini özelleştirin.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Müzik")
    }

    // Only show controller options that are available on this macOS version
    private var availableMediaControllers: [MediaControllerType] {
        if MusicManager.shared.isNowPlayingDeprecated {
            return MediaControllerType.allCases.filter { $0 != .nowPlaying }
        } else {
            return MediaControllerType.allCases
        }
    }
}

struct About: View {
    @State private var showBuildNumber: Bool = false
    @Environment(\.openWindow) var openWindow
    var body: some View {
        VStack {
            Form {
                Section {
                    HStack {
                        Text("Versiyon")
                        Spacer()
                        if showBuildNumber {
                            Text("(\(Bundle.main.buildVersionNumber ?? ""))")
                                .foregroundStyle(.secondary)
                        }
                        Text("1.00")
                            .foregroundStyle(.secondary)
                    }
                    .onTapGesture {
                        withAnimation {
                            showBuildNumber.toggle()
                        }
                    }
                } header: {
                    Text("Sürüm Bilgisi")
                }

                Text("Bu sürüm kişisel Boss App kullanımı için yapılandırılmıştır.")
                    .foregroundStyle(.secondary)
            }
            VStack(spacing: 0) {
                Divider()
                Text("Boss App olarak yerel ortamda özelleştirildi \n Geliştiren: Ahmet Boz")
                    .foregroundStyle(.secondary)
                    .padding(.top, 5)
                    .padding(.bottom, 7)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .toolbar {
            //            Button("Welcome window") {
            //                openWindow(id: "onboarding")
            //            }
            //            .controlSize(.extraLarge)
        }
        .navigationTitle("Hakkında")
    }
}

struct Shelf: View {
    @Default(.expandedDragDetection) var expandedDragDetection: Bool

    var body: some View {
        Form {
            Section {
                BossConfig.Toggle(key: .shelfEnabled) {
                    Text("Rafı etkinleştir")
                }
                BossConfig.Toggle(key: .openShelfByDefault) {
                    Text("Öğeler varsa rafı varsayılan olarak aç")
                }
                BossConfig.Toggle(key: .expandedDragDetection) {
                    Text("Genişletilmiş sürükleme algılama alanı")
                }
                .onChange(of: expandedDragDetection) {
                    NotificationCenter.default.post(
                        name: Notification.Name.expandedDragDetectionChanged,
                        object: nil
                    )
                }
                BossConfig.Toggle(key: .copyOnDrag) {
                    Text("Sürüklerken öğeleri kopyala")
                }
                BossConfig.Toggle(key: .autoRemoveShelfItems) {
                    Text("Sürükledikten sonra raftan kaldır")
                }

            } header: {
                HStack {
                    Text("Genel")
                }
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Raf")
    }
}

//struct Extensions: View {
//    @State private var effectTrigger: Bool = false
//    var body: some View {
//        Form {
//            Section {
//                List {
//                    ForEach(extensionManager.installedExtensions.indices, id: \.self) { index in
//                        let item = extensionManager.installedExtensions[index]
//                        HStack {
//                            AppIcon(for: item.bundleIdentifier)
//                                .resizable()
//                                .frame(width: 24, height: 24)
//                            Text(item.name)
//                            ListItemPopover {
//                                Text("Description")
//                            }
//                            Spacer(minLength: 0)
//                            HStack(spacing: 6) {
//                                Circle()
//                                    .frame(width: 6, height: 6)
//                                    .foregroundColor(
//                                        isExtensionRunning(item.bundleIdentifier)
//                                            ? .green : item.status == .disabled ? .gray : .red
//                                    )
//                                    .conditionalModifier(isExtensionRunning(item.bundleIdentifier))
//                                { view in
//                                    view
//                                        .shadow(color: .green, radius: 3)
//                                }
//                                Text(
//                                    isExtensionRunning(item.bundleIdentifier)
//                                        ? "Running"
//                                        : item.status == .disabled ? "Disabled" : "Stopped"
//                                )
//                                .contentTransition(.numericText())
//                                .foregroundStyle(.secondary)
//                                .font(.footnote)
//                            }
//                            .frame(width: 60, alignment: .leading)
//
//                            Menu(
//                                content: {
//                                    Button("Restart") {
//                                        let ws = NSWorkspace.shared
//
//                                        if let ext = ws.runningApplications.first(where: {
//                                            $0.bundleIdentifier == item.bundleIdentifier
//                                        }) {
//                                            ext.terminate()
//                                        }
//
//                                        if let appURL = ws.urlForApplication(
//                                            withBundleIdentifier: item.bundleIdentifier)
//                                        {
//                                            ws.openApplication(
//                                                at: appURL, configuration: .init(),
//                                                completionHandler: nil)
//                                        }
//                                    }
//                                    .keyboardShortcut("R", modifiers: .command)
//                                    Button("Disable") {
//                                        if let ext = NSWorkspace.shared.runningApplications.first(
//                                            where: { $0.bundleIdentifier == item.bundleIdentifier })
//                                        {
//                                            ext.terminate()
//                                        }
//                                        extensionManager.installedExtensions[index].status =
//                                            .disabled
//                                    }
//                                    .keyboardShortcut("D", modifiers: .command)
//                                    Divider()
//                                    Button("Uninstall", role: .destructive) {
//                                        //
//                                    }
//                                },
//                                label: {
//                                    Image(systemName: "ellipsis.circle")
//                                        .foregroundStyle(.secondary)
//                                }
//                            )
//                            .controlSize(.regular)
//                        }
//                        .buttonStyle(PlainButtonStyle())
//                        .padding(.vertical, 5)
//                    }
//                }
//                .frame(minHeight: 120)
//                .actionBar {
//                    Button {
//                    } label: {
//                        HStack(spacing: 3) {
//                            Image(systemName: "plus")
//                            Text("Add manually")
//                        }
//                        .foregroundStyle(.secondary)
//                    }
//                    .disabled(true)
//                    Spacer()
//                    Button {
//                        withAnimation(.linear(duration: 1)) {
//                            effectTrigger.toggle()
//                        } completion: {
//                            effectTrigger.toggle()
//                        }
//                        extensionManager.checkIfExtensionsAreInstalled()
//                    } label: {
//                        HStack(spacing: 3) {
//                            Image(systemName: "arrow.triangle.2.circlepath")
//                                .rotationEffect(effectTrigger ? .degrees(360) : .zero)
//                        }
//                        .foregroundStyle(.secondary)
//                    }
//                }
//                .controlSize(.small)
//                .buttonStyle(PlainButtonStyle())
//                .overlay {
//                    if extensionManager.installedExtensions.isEmpty {
//                        Text("No extension installed")
//                            .foregroundStyle(Color(.secondaryLabelColor))
//                            .padding(.bottom, 22)
//                    }
//                }
//            } header: {
//                HStack(spacing: 0) {
//                    Text("Installed extensions")
//                    if !extensionManager.installedExtensions.isEmpty {
//                        Text(" – \(extensionManager.installedExtensions.count)")
//                            .foregroundStyle(.secondary)
//                    }
//                }
//            }
//        }
//        .accentColor(.effectiveAccent)
//        .navigationTitle("Extensions")
//        // .padding(.horizontal, 19)
//    }
//}

struct Appearance: View {
    @ObservedObject var coordinator = BossViewCoordinator.shared
    @Default(.mirrorShape) var mirrorShape


    var body: some View {
        Form {
            Section {
                Toggle("Sekmeleri her zaman göster", isOn: $coordinator.alwaysShowTabs)
                BossConfig.Toggle(key: .settingsIconInNotch) {
                    Text("Ayarlar simgesini çentikte göster")
                }

            } header: {
                Text("Genel Görünüm")
            }



            Section {
                BossConfig.Toggle(key: .showMirror) {
                    Text("Ayna modunu etkinleştir")
                }
                    .disabled(!checkVideoInput())
                Picker("Ayna Şekli", selection: $mirrorShape) {
                    Text("Daire")
                        .tag(MirrorShapeEnum.circle)
                    Text("Kare")
                        .tag(MirrorShapeEnum.rectangle)
                }
            } header: {
                HStack {
                    Text("Ek Görsel Özellikler")
                }
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Görünüm")
    }

    func checkVideoInput() -> Bool {
        if AVCaptureDevice.default(for: .video) != nil {
            return true
        }

        return false
    }
}

func proFeatureBadge() -> some View {
    Text("Pro'ya Yükselt")
        .foregroundStyle(Color(red: 0.545, green: 0.196, blue: 0.98))
        .font(.footnote.bold())
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 4).stroke(
                Color(red: 0.545, green: 0.196, blue: 0.98), lineWidth: 1))
}

func comingSoonTag() -> some View {
    Text("Yakında")
        .foregroundStyle(.secondary)
        .font(.footnote.bold())
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(Color(nsColor: .secondarySystemFill))
        .clipShape(.capsule)
}

struct NotesSettings: View {
    var body: some View {
        Form {
            Section {
                Text("Notlar özellikleri için ayarlar buraya eklenecek.")
                    .foregroundStyle(.secondary)
            } header: {
                Text("Genel")
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Notlar")
    }
}

struct ScreenshotsSettings: View {
    var body: some View {
        Form {
            Section {
                Text("Ekran görüntüleri özellikleri için ayarlar buraya eklenecek.")
                    .foregroundStyle(.secondary)
            } header: {
                Text("Genel")
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Ekran Görüntüleri")
    }
}

struct ClipboardSettings: View {
    var body: some View {
        Form {
            Section {
                Text("Pano özellikleri için ayarlar buraya eklenecek.")
                    .foregroundStyle(.secondary)
            } header: {
                Text("Genel")
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Pano")
    }
}

func customBadge(text: String) -> some View {
    Text(text)
        .foregroundStyle(.secondary)
        .font(.footnote.bold())
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(Color(nsColor: .secondarySystemFill))
        .clipShape(.capsule)
}

func warningBadge(_ text: String, _ description: String) -> some View {
    Section {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 22))
                .foregroundStyle(.yellow)
            VStack(alignment: .leading) {
                Text(text)
                    .font(.headline)
                Text(description)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

 
