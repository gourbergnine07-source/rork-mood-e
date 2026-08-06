//
//  DuoNameField.swift
//  MoodE
//

import SwiftUI

/// Optional "name for this friend" field shown right where it matters: when
/// creating or joining a Duo night / friend challenge. Pre-filled with the
/// profile display name ("Nome per i tuoi amici" in Settings); whatever the
/// user confirms is saved back to that same field so it's reused
/// automatically for future challenges. Left empty = stay anonymous.
struct DuoNameField: View {
    @Binding var name: String
    var tint: Color = Theme.primary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L("duo.name.label"), systemImage: "person.text.rectangle")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.ink)

            TextField(L("duo.name.placeholder"), text: $name)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 12)
                .frame(height: 42)
                .background(Theme.surface.opacity(0.7), in: .rect(cornerRadius: 12))
                .onChange(of: name) { _, newValue in
                    if newValue.count > ProfileStore.maxNameLength {
                        name = String(newValue.prefix(ProfileStore.maxNameLength))
                    }
                }

            Text(L("duo.name.hint"))
                .font(.caption2)
                .foregroundStyle(Theme.inkSoft)
                .lineSpacing(2)
        }
        .padding(14)
        .background(Theme.card, in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }
}
