//
//  MarkWatchedSheet.swift
//  MoodE
//

import SwiftUI

/// Small form shown when a planned movie is marked as watched:
/// 5-emoji rating (😞 → 🤩) plus an optional personal comment.
/// Saving turns the plan into a `MovieMemory` and syncs "La mia lista".
struct MarkWatchedSheet: View {
    let scheduled: ScheduledMovie

    @Environment(MoviePlanner.self) private var planner
    @Environment(MovieLibrary.self) private var library
    @Environment(NotificationService.self) private var notifications
    @Environment(\.dismiss) private var dismiss

    @State private var rating: Int = 0
    @State private var comment: String = ""
    @State private var didSave: Bool = false

    private static let maxLength = 200

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        movieHeader

                        VStack(alignment: .leading, spacing: 10) {
                            Text(L("watched.ratingHint"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.inkSoft)
                            emojiRow
                        }

                        commentField

                        saveButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(L("watched.title"))
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L("common.cancel")) { dismiss() }
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
        }
        .presentationDetents([.height(430), .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Sections

    private var movieHeader: some View {
        HStack(spacing: 12) {
            Group {
                if let url = scheduled.posterURL {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Theme.surface
                    }
                } else {
                    Theme.surface.overlay { Text("🎬") }
                }
            }
            .frame(width: 46, height: 69)
            .clipShape(.rect(cornerRadius: 8))

            Text(scheduled.title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.ink)
                .lineLimit(3)
            Spacer()
        }
    }

    private var emojiRow: some View {
        HStack(spacing: 0) {
            ForEach(EmojiRating.range, id: \.self) { value in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        rating = value
                    }
                } label: {
                    Text(EmojiRating.emoji(for: value))
                        .font(.system(size: 32))
                        .scaleEffect(rating == value ? 1.3 : 1)
                        .opacity(rating == 0 || rating == value ? 1 : 0.35)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(value)/5")
            }
        }
        .sensoryFeedback(.selection, trigger: rating)
    }

    private var commentField: some View {
        VStack(alignment: .trailing, spacing: 4) {
            TextField(L("watched.commentPlaceholder"), text: $comment, axis: .vertical)
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
                .lineLimit(3...5)
                .padding(12)
                .background(Theme.card, in: .rect(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Theme.primary.opacity(0.18), lineWidth: 1)
                )
                .onChange(of: comment) { _, newValue in
                    if newValue.count > Self.maxLength {
                        comment = String(newValue.prefix(Self.maxLength))
                    }
                }

            Text("\(comment.count)/\(Self.maxLength)")
                .font(.caption2.weight(.medium))
                .foregroundStyle(comment.count >= Self.maxLength ? Theme.rose : Theme.inkSoft)
                .monospacedDigit()
        }
    }

    private var saveButton: some View {
        Button {
            save()
        } label: {
            Text(L("watched.save"))
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    rating > 0 ? Theme.seenGreen : Theme.inkSoft.opacity(0.35),
                    in: .rect(cornerRadius: 14)
                )
        }
        .disabled(rating == 0)
        .sensoryFeedback(.success, trigger: didSave)
    }

    // MARK: - Save

    private func save() {
        guard rating > 0 else { return }
        planner.markWatched(scheduled.id, rating: rating, comment: comment)

        if !library.isSeen(scheduled.movieId) {
            if library.entry(for: scheduled.movieId) != nil {
                library.markWatched(scheduled.movieId)
            } else {
                library.toggleSeen(minimalMovie)
            }
        }

        notifications.syncMovieNightReminders(planner.scheduled)
        didSave.toggle()
        dismiss()
    }

    private var minimalMovie: TMDBMovie {
        TMDBMovie(
            id: scheduled.movieId,
            title: scheduled.title,
            overview: "",
            posterPath: scheduled.posterPath,
            backdropPath: nil,
            releaseDate: nil,
            voteAverage: 0,
            voteCount: 0,
            genreIds: scheduled.genreIds
        )
    }
}

/// Calendar sheet to move a planned movie to another day.
struct MoveScheduleSheet: View {
    let scheduled: ScheduledMovie

    @Environment(MoviePlanner.self) private var planner
    @Environment(NotificationService.self) private var notifications
    @Environment(\.dismiss) private var dismiss

    @State private var newDay: Date = Date()
    @State private var didMove: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 8) {
                    DatePicker("", selection: $newDay, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(Theme.primary)
                        .padding(.horizontal, 12)

                    Button {
                        planner.move(scheduled.id, to: newDay)
                        notifications.syncMovieNightReminders(planner.scheduled)
                        didMove.toggle()
                        dismiss()
                    } label: {
                        Text(L("planner.move.confirm"))
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Theme.primary, in: .rect(cornerRadius: 14))
                    }
                    .sensoryFeedback(.success, trigger: didMove)
                    .padding(.horizontal, 20)

                    Spacer(minLength: 0)
                }
                .padding(.top, 4)
            }
            .navigationTitle(L("planner.move.title"))
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L("common.cancel")) { dismiss() }
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
        }
        .presentationDetents([.height(540), .large])
        .presentationDragIndicator(.visible)
        .onAppear { newDay = scheduled.day }
    }
}
