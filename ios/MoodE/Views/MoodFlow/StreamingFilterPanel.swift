//
//  StreamingFilterPanel.swift
//  MoodE
//
//  "Solo le mie piattaforme" panel: unlike a system Menu (which closes
//  at every tap), this popover stays open so the user can toggle several
//  platforms in sequence. It closes only on "Fatto" or tapping outside.
//

import SwiftUI

struct StreamingFilterPanel: View {
    @Environment(\.dismiss) private var dismiss

    private var store: StreamingServicesStore { .shared }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()
                .overlay(Theme.primary.opacity(0.15))

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    filterToggle

                    quickLinks
                        .padding(.top, 6)
                        .padding(.bottom, 4)

                    Text(L("services.title"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.inkSoft)
                        .textCase(.uppercase)
                        .padding(.top, 8)
                        .padding(.bottom, 2)

                    ForEach(StreamingServicesStore.allServices) { service in
                        serviceRow(service)
                    }

                    if !store.hasSelection {
                        Text(L("filter.streaming.hint"))
                            .font(.caption)
                            .foregroundStyle(Theme.inkSoft)
                            .padding(.top, 6)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .scrollIndicators(.hidden)
        }
        .frame(width: 320)
        .frame(maxHeight: 480)
        .presentationCompactAdaptation(.popover)
        .presentationBackground(Theme.background)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "play.tv")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.primary)

            Text(L("filter.streaming.only"))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)

            Spacer(minLength: 8)

            Button {
                dismiss()
            } label: {
                Text(L("common.done"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.primary)
                    .frame(minHeight: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
    }

    // MARK: - Master toggle

    /// Enables/disables the filter itself; the platform list below picks
    /// which subscriptions count.
    private var filterToggle: some View {
        Toggle(isOn: Binding(
            get: { store.filterEnabled },
            set: { store.setFilterEnabled($0) }
        )) {
            Text(L("filter.streaming.enable"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
        }
        .tint(Theme.primary)
        .frame(minHeight: 44)
        .sensoryFeedback(.selection, trigger: store.filterEnabled)
    }

    // MARK: - Quick links

    private var quickLinks: some View {
        HStack(spacing: 8) {
            quickLink(L("filter.streaming.selectAll"), icon: "checkmark.circle") {
                store.selectAll()
            }
            quickLink(L("filter.streaming.deselectAll"), icon: "circle.slash") {
                store.deselectAll()
            }
        }
    }

    private func quickLink(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring(duration: 0.25)) {
                action()
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(Theme.primary)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(Theme.primary.opacity(0.12), in: .capsule)
            .overlay(
                Capsule().stroke(Theme.primary.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Service rows

    /// Tapping a row only flips its checkmark — the panel stays open so
    /// multiple platforms can be changed in sequence.
    private func serviceRow(_ service: StreamingServicesStore.Service) -> some View {
        let isSelected = store.isSelected(service)
        return Button {
            withAnimation(.spring(duration: 0.2)) {
                store.toggle(service)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? Theme.primary : Theme.inkSoft.opacity(0.4))
                    .contentTransition(.symbolEffect(.replace))

                Text(service.name)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(Theme.ink)

                Spacer(minLength: 0)
            }
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityLabel(service.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    StreamingFilterPanel()
}
