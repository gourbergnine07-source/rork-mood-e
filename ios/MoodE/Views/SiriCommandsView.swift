//
//  SiriCommandsView.swift
//  MoodE
//

import SwiftUI
import AppIntents

/// "Comandi Siri": explains how to ask Siri for a movie proposal
/// without opening the app, with the official Siri tip and a link
/// to the Shortcuts app for custom phrases.
struct SiriCommandsView: View {
    @State private var siriTipVisible: Bool = true
    @State private var showPaywall: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !PremiumStore.shared.isPremium {
                    premiumLockCard
                }

                Text(L("siri.intro"))
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
                    .lineSpacing(4)

                VStack(spacing: 10) {
                    stepCard(number: 1, text: L("siri.step1"))
                    stepCard(number: 2, text: L("siri.step2"))
                    stepCard(number: 3, text: L("siri.step3"))
                }

                if PremiumStore.shared.isPremium {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L("siri.tip"))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.ink)

                        SiriTipView(intent: WhatToWatchIntent(), isVisible: $siriTipVisible)

                        ShortcutsLink()
                            .shortcutsLinkStyle(.automaticOutline)
                    }
                }

                Text(L("siri.note"))
                    .font(.caption)
                    .italic()
                    .foregroundStyle(Theme.inkSoft.opacity(0.85))
                    .lineSpacing(3)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(L("siri.title"))
        .toolbarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    /// Free users: the guide stays readable, but activation needs Premium.
    private var premiumLockCard: some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Theme.amber, in: .rect(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(L("premium.locked"))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.ink)
                    Text(L("premium.siri.locked"))
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
            }
            .padding(14)
            .background(Theme.amber.opacity(0.1), in: .rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Theme.amber.opacity(0.35), lineWidth: 1)
            )
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func stepCard(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Theme.primary, in: .circle)

            Text(text)
                .font(.footnote)
                .foregroundStyle(Theme.ink)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(Theme.card, in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.primary.opacity(0.12), lineWidth: 1)
        )
    }
}

#Preview {
    NavigationStack {
        SiriCommandsView()
    }
}
