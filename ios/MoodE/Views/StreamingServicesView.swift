//
//  StreamingServicesView.swift
//  MoodE
//

import SwiftUI

/// Settings screen where the user marks the streaming services they are
/// subscribed to. Movies included in one of these services show the
/// "Available now" badge on their poster across the app.
struct StreamingServicesView: View {
    private var store: StreamingServicesStore { .shared }

    @State private var toggleHaptic = false

    var body: some View {
        List {
            Section {
                ForEach(StreamingServicesStore.allServices) { service in
                    serviceRow(service)
                }
            } header: {
                Text(L("services.header"))
            } footer: {
                Text(L("services.footer"))
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
            }
            .listRowBackground(Theme.card)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle(L("services.title"))
        .toolbarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: toggleHaptic)
    }

    private func serviceRow(_ service: StreamingServicesStore.Service) -> some View {
        let isSelected = store.isSelected(service)

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                store.toggle(service)
            }
            toggleHaptic.toggle()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "play.tv.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : Theme.inkSoft)
                    .frame(width: 29, height: 29)
                    .background(
                        isSelected ? Theme.seenGreen : Theme.surface,
                        in: .rect(cornerRadius: 7)
                    )

                Text(service.name)
                    .font(.body.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(Theme.ink)

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isSelected ? Theme.seenGreen : Theme.inkSoft.opacity(0.4))
                    .contentTransition(.symbolEffect(.replace))
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(service.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    NavigationStack {
        StreamingServicesView()
    }
}
