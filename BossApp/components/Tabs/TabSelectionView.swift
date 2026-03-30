//
//  TabSelectionView.swift
//  Boss App
//
//

import BossConfig
import SwiftUI

struct TabModel: Identifiable, Hashable {
    let id: NotchViews
    let label: String
    let icon: String
    let view: NotchViews
}

struct TabSelectionView: View {
    @ObservedObject var coordinator = BossViewCoordinator.shared
    let tabs: [TabModel]
    let animation: Namespace.ID

    static func allTabs() -> [TabModel] {
        var availableTabs = [TabModel(id: .home, label: "Home", icon: "music.note", view: .home)]

        if BossConfig[.shelfEnabled] {
            availableTabs.append(TabModel(id: .shelf, label: "Shelf", icon: "tray.fill", view: .shelf))
        }

        availableTabs.append(TabModel(id: .clipboard, label: "Clipboard", icon: "clipboard.fill", view: .clipboard))
        availableTabs.append(TabModel(id: .screenshots, label: "Screenshots", icon: "camera.viewfinder", view: .screenshots))
        availableTabs.append(TabModel(id: .notes, label: "Quick Notes", icon: "note.text", view: .notes))
        return availableTabs
    }

    static func splitTabs() -> (left: [TabModel], right: [TabModel]) {
        let tabs = allTabs()
        let leftCount = Int(ceil(Double(tabs.count) / 2.0))
        return (Array(tabs.prefix(leftCount)), Array(tabs.dropFirst(leftCount)))
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                TabButton(label: tab.label, icon: tab.icon, selected: coordinator.currentView == tab.view) {
                    withAnimation(.smooth) {
                        coordinator.currentView = tab.view
                    }
                }
                .frame(height: 26)
                .foregroundStyle(tab.view == coordinator.currentView ? .white : .gray)
                .background {
                    if tab.view == coordinator.currentView {
                        Capsule()
                            .fill(coordinator.currentView == tab.view ? Color(nsColor: .secondarySystemFill) : Color.clear)
                            .matchedGeometryEffect(id: "capsule", in: animation)
                    } else {
                        Capsule()
                            .fill(coordinator.currentView == tab.view ? Color(nsColor: .secondarySystemFill) : Color.clear)
                            .matchedGeometryEffect(id: "capsule", in: animation)
                            .hidden()
                    }
                }
            }
        }
        .clipShape(Capsule())
    }
}

#Preview {
    PreviewTabSelection()
}

private struct PreviewTabSelection: View {
    @Namespace private var animation

    var body: some View {
        let split = TabSelectionView.splitTabs()

        HStack(spacing: 12) {
            TabSelectionView(tabs: split.left, animation: animation)
            TabSelectionView(tabs: split.right, animation: animation)
        }
    }
}
