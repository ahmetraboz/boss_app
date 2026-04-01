import AppKit
import SwiftUI

struct ClipboardView: View {
    @EnvironmentObject var vm: BossViewModel
    @ObservedObject var coordinator = BossViewCoordinator.shared
    @StateObject private var clipboard = ClipboardStateViewModel.shared
    @State private var isSearchExpanded = false
    @FocusState private var isSearchFocused: Bool

    private var visibleItems: [ClipboardItem] {
        clipboard.filteredItems
    }

    private var shouldShowSearchField: Bool {
        isSearchExpanded || !clipboard.searchQuery.isEmpty
    }

    private var topControlsInset: CGFloat {
        40
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(Color.white.opacity(0.12), lineWidth: 1)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.03))
            )
            .overlay {
                content
                    .padding(.horizontal, 12)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
            }
            .transaction { transaction in
                transaction.animation = vm.animation
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var content: some View {
        Group {
            if clipboard.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "clipboard")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(.gray.opacity(0.9))
                    Text("Copy text, images, or files")
                        .foregroundStyle(.gray)
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if visibleItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                    Text("No matches")
                        .foregroundStyle(.white)
                        .font(.system(.headline, design: .rounded))
                    Text("Try a different word or clear the search field.")
                        .foregroundStyle(.secondary)
                        .font(.system(.subheadline, design: .rounded))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(visibleItems) { item in
                            ClipboardRowView(
                                item: item,
                                onCopy: { clipboard.copy(item) },
                                onTogglePin: { clipboard.togglePin(item) },
                                onDelete: { clipboard.remove(item) }
                            )
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .scrollIndicators(.never)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay(alignment: .topTrailing) {
            HStack(alignment: .center, spacing: 8) {
                if shouldShowSearchField {
                    compactSearchField
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                } else {
                    Button { expandSearch() } label: {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                }

                Button { toggleExpandedMode() } label: {
                    Image(systemName: coordinator.isClipboardExpanded
                        ? "arrow.down.right.and.arrow.up.left"
                        : "arrow.up.left.and.arrow.down.right")
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help(coordinator.isClipboardExpanded ? "Collapse clipboard" : "Expand clipboard")

                if !clipboard.isEmpty {
                    Button { clipboard.clearUnpinned() } label: {
                        Text("Clear")
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(1)
                }
            }
            .animation(.smooth(duration: 0.2), value: shouldShowSearchField)
        }
    }

    private var compactSearchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search", text: $clipboard.searchQuery)
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
                .focused($isSearchFocused)

            Button {
                clipboard.searchQuery = ""
                collapseSearch()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(minWidth: 150, idealWidth: 180, maxWidth: 200)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func expandSearch() {
        withAnimation(.smooth(duration: 0.2)) {
            isSearchExpanded = true
        }

        DispatchQueue.main.async {
            isSearchFocused = true
        }
    }

    private func collapseSearch() {
        isSearchFocused = false
        withAnimation(.smooth(duration: 0.2)) {
            isSearchExpanded = false
        }
    }

    private func toggleExpandedMode() {
        coordinator.toggleClipboardExpanded()
    }
}

private struct ClipboardRowView: View {
    let item: ClipboardItem
    let onCopy: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            preview

            Button(action: onCopy) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(item.title)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(item.kindBadgeText)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.88))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.white.opacity(0.08)))
                    }

                    Text(item.previewText)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 6) {
                        if let icon = sourceApplicationIcon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 14, height: 14)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }

                        Text(item.detailText)
                            .lineLimit(1)

                        Text("•")

                        Text(item.relativeTimestamp)
                            .lineLimit(1)

                        if item.copyCount > 1 {
                            Text("• \(item.copyCount)x")
                                .lineLimit(1)
                        }
                    }
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 6) {
                actionButton(systemName: item.isPinned ? "pin.fill" : "pin") {
                    onTogglePin()
                }

                actionButton(systemName: "trash") {
                    onDelete()
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(isHovering ? 0.09 : 0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(isHovering ? 0.1 : 0.05), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onHover { isHovering = $0 }
    }

    @ViewBuilder
    private var preview: some View {
        Group {
            if let image = item.image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: item.iconName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white.opacity(0.06))
            }
        }
        .frame(width: 38, height: 38)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var sourceApplicationIcon: NSImage? {
        guard let bundleIdentifier = item.sourceBundleIdentifier,
              let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return nil
        }

        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        icon.size = NSSize(width: 14, height: 14)
        return icon
    }

    private func actionButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }
}
