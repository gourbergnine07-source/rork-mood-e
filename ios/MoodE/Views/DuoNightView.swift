//
//  DuoNightView.swift
//  MoodE
//
//  "Serata in Duo": temporary anonymous two-person session. Each person
//  picks their own mood + goal on their own phone; when both are done the
//  app proposes movies crossing the two combinations.
//

import SwiftUI

struct DuoNightView: View {
    enum Phase {
        case landing
        case picking
        case waiting
        case results([TMDBMovie])
    }

    @Environment(\.dismiss) private var dismiss

    @State private var phase: Phase = .landing
    @State private var role: DuoRole = .host
    @State private var code: String = ""
    @State private var joinCode: String = ""
    @State private var partnerJoined: Bool = false

    @State private var selectedMood: Mood?
    @State private var selectedGoal: ViewingGoal?

    @State private var isBusy: Bool = false
    @State private var errorMessage: String?

    private let moodColumns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]
    private let posterColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        switch phase {
                        case .landing: landing
                        case .picking: picking
                        case .waiting: waiting
                        case .results(let movies): results(movies)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(L("duo.title"))
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    .accessibilityLabel(L("common.close"))
                }
            }
            .navigationDestination(for: TMDBMovie.self) { movie in
                MovieDetailView(movie: movie)
            }
        }
        .tint(Theme.primary)
        .alert(L("common.oops"), isPresented: errorBinding) {
            Button(L("common.ok"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? L("duo.error.generic"))
        }
        .task(id: isWaiting) {
            guard isWaiting else { return }
            await pollUntilReady()
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private var isWaiting: Bool {
        if case .waiting = phase { return true }
        return false
    }

    // MARK: - Landing (create or join)

    private var landing: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L("duo.intro"))
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
                .lineSpacing(4)

            Button {
                createSession()
            } label: {
                HStack(spacing: 7) {
                    if isBusy && role == .host {
                        ProgressView().tint(.white).controlSize(.small)
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    Text(L("duo.create"))
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Theme.primary, in: .rect(cornerRadius: 14))
            }
            .disabled(isBusy)

            HStack {
                Rectangle().fill(Theme.inkSoft.opacity(0.2)).frame(height: 1)
                Text(L("duo.or"))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.inkSoft)
                Rectangle().fill(Theme.inkSoft.opacity(0.2)).frame(height: 1)
            }

            HStack(spacing: 8) {
                TextField(L("duo.code.placeholder"), text: $joinCode)
                    .keyboardType(.numberPad)
                    .font(.title3.weight(.bold).monospaced())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.ink)
                    .frame(height: 46)
                    .background(Theme.card, in: .rect(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Theme.primary.opacity(0.18), lineWidth: 1)
                    )
                    .onChange(of: joinCode) { _, newValue in
                        joinCode = String(newValue.filter(\.isNumber).prefix(6))
                    }

                Button {
                    joinSession()
                } label: {
                    Group {
                        if isBusy && role == .guest {
                            ProgressView().tint(.white).controlSize(.small)
                        } else {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 46, height: 46)
                    .background(
                        joinCode.count == 6 ? Theme.rose : Theme.rose.opacity(0.35),
                        in: .rect(cornerRadius: 14)
                    )
                }
                .disabled(joinCode.count != 6 || isBusy)
                .accessibilityLabel(L("duo.join"))
            }

            Text(L("duo.privacy"))
                .font(.caption2)
                .italic()
                .foregroundStyle(Theme.inkSoft.opacity(0.8))
        }
    }

    // MARK: - Picking (my mood + goal)

    private var picking: some View {
        VStack(alignment: .leading, spacing: 16) {
            codeBanner

            Text(L("duo.mood.title"))
                .font(.headline)
                .foregroundStyle(Theme.ink)
            LazyVGrid(columns: moodColumns, spacing: 8) {
                ForEach(Mood.allCases) { mood in
                    duoChip(
                        emoji: mood.emoji,
                        title: mood.title,
                        tint: mood.tint,
                        isSelected: selectedMood == mood
                    ) {
                        selectedMood = mood
                    }
                }
            }

            Text(L("duo.goal.title"))
                .font(.headline)
                .foregroundStyle(Theme.ink)
            LazyVGrid(columns: moodColumns, spacing: 8) {
                ForEach(ViewingGoal.allCases) { goal in
                    duoChip(
                        emoji: goal.emoji,
                        title: goal.title,
                        tint: goal.tint,
                        isSelected: selectedGoal == goal
                    ) {
                        selectedGoal = goal
                    }
                }
            }

            Button {
                submitChoice()
            } label: {
                HStack(spacing: 7) {
                    if isBusy {
                        ProgressView().tint(.white).controlSize(.small)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    Text(L("duo.submit"))
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(
                    canSubmit ? Theme.primary : Theme.primary.opacity(0.35),
                    in: .rect(cornerRadius: 14)
                )
            }
            .disabled(!canSubmit || isBusy)
        }
    }

    private var canSubmit: Bool {
        selectedMood != nil && selectedGoal != nil
    }

    private func duoChip(emoji: String, title: String, tint: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(emoji).font(.system(size: 20))
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                isSelected ? tint.opacity(0.20) : Theme.card,
                in: .rect(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? tint : Theme.primary.opacity(0.10), lineWidth: isSelected ? 1.5 : 1)
            )
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }

    /// Code + native share sheet so the other person can join.
    private var codeBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("duo.code.yours"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.inkSoft)
                    Text(formattedCode)
                        .font(.title2.weight(.bold).monospaced())
                        .foregroundStyle(Theme.primary)
                }
                Spacer()
                ShareLink(item: LF("duo.share.text", code)) {
                    HStack(spacing: 5) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 12, weight: .semibold))
                        Text(L("duo.share"))
                            .font(.footnote.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Theme.rose, in: .capsule)
                }
            }

            if role == .host {
                Label(
                    partnerJoined ? L("duo.partner.joined") : L("duo.partner.waiting"),
                    systemImage: partnerJoined ? "person.2.fill" : "person.badge.clock"
                )
                .font(.caption2.weight(.semibold))
                .foregroundStyle(partnerJoined ? Theme.seenGreen : Theme.inkSoft)
            }
        }
        .padding(14)
        .background(Theme.card, in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.primary.opacity(0.15), lineWidth: 1)
        )
    }

    private var formattedCode: String {
        guard code.count == 6 else { return code }
        return code.prefix(3) + " " + code.suffix(3)
    }

    // MARK: - Waiting

    private var waiting: some View {
        VStack(spacing: 14) {
            codeBanner

            VStack(spacing: 10) {
                ProgressView()
                    .controlSize(.large)
                    .tint(Theme.primary)
                Text(L("duo.waiting"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text(L("duo.waiting.sub"))
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        }
    }

    // MARK: - Results

    private func results(_ movies: [TMDBMovie]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L("duo.results.title"))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.ink)
                Text(L("duo.results.sub"))
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
            }

            LazyVGrid(columns: posterColumns, spacing: 14) {
                ForEach(movies) { movie in
                    NavigationLink(value: movie) {
                        VStack(spacing: 5) {
                            Color(Theme.surface)
                                .aspectRatio(2 / 3, contentMode: .fit)
                                .overlay {
                                    if let url = movie.posterURL {
                                        AsyncImage(url: url) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .allowsHitTesting(false)
                                        } placeholder: {
                                            ProgressView().tint(Theme.primary)
                                        }
                                    } else {
                                        Text("🎬")
                                    }
                                }
                                .clipShape(.rect(cornerRadius: 12))

                            Text(movie.title)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .buttonStyle(PressableCardStyle())
                }
            }
        }
    }

    // MARK: - Actions

    private func createSession() {
        role = .host
        isBusy = true
        Task {
            do {
                code = try await DuoSessionService.create()
                AnalyticsService.shared.log("duo_session", meta: ["role": "host"])
                withAnimation { phase = .picking }
            } catch {
                errorMessage = L("duo.error.generic")
            }
            isBusy = false
        }
    }

    private func joinSession() {
        role = .guest
        isBusy = true
        Task {
            do {
                let row = try await DuoSessionService.join(code: joinCode)
                code = row.code
                partnerJoined = true
                AnalyticsService.shared.log("duo_session", meta: ["role": "guest"])
                withAnimation { phase = .picking }
            } catch DuoError.notFound {
                errorMessage = L("duo.error.notfound")
            } catch {
                errorMessage = L("duo.error.generic")
            }
            isBusy = false
        }
    }

    private func submitChoice() {
        guard let mood = selectedMood, let goal = selectedGoal else { return }
        isBusy = true
        Task {
            do {
                try await DuoSessionService.submit(code: code, role: role, mood: mood, goal: goal)
                withAnimation { phase = .waiting }
            } catch {
                errorMessage = L("duo.error.generic")
            }
            isBusy = false
        }
    }

    /// Polls the session every 3 seconds until both sides confirmed,
    /// then loads the crossed movie proposal.
    private func pollUntilReady() async {
        while isWaiting && !Task.isCancelled {
            do {
                let row = try await DuoSessionService.fetch(code: code)
                partnerJoined = row.guestJoined || role == .guest
                if row.isReady,
                   let hostMood = row.hostMood.flatMap(Mood.init),
                   let hostGoal = row.hostGoal.flatMap(ViewingGoal.init),
                   let guestMood = row.guestMood.flatMap(Mood.init),
                   let guestGoal = row.guestGoal.flatMap(ViewingGoal.init) {
                    let movies = try await TMDBService.duoDiscover(
                        hostMood: hostMood, hostGoal: hostGoal,
                        guestMood: guestMood, guestGoal: guestGoal
                    )
                    AnalyticsService.shared.log("duo_completed")
                    withAnimation { phase = .results(movies) }
                    return
                }
            } catch DuoError.notFound {
                errorMessage = L("duo.error.notfound")
                withAnimation { phase = .landing }
                return
            } catch {
                // Transient network error: keep polling.
            }
            try? await Task.sleep(for: .seconds(3))
        }
    }
}
