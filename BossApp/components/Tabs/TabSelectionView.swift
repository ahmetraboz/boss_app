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
    @Namespace var animation

    private var tabs: [TabModel] {
        var availableTabs = [TabModel(id: .home, label: "Home", icon: "house.fill", view: .home)]

        if BossConfig[.shelfEnabled] {
            availableTabs.append(TabModel(id: .shelf, label: "Shelf", icon: "tray.fill", view: .shelf))
        }

        availableTabs.append(TabModel(id: .clipboard, label: "Clipboard", icon: "clipboard.fill", view: .clipboard))
        return availableTabs
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
    BossHeader().environmentObject(BossViewModel())
}
