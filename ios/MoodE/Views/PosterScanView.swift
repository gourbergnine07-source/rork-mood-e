//
//  PosterScanView.swift
//  MoodE
//

import SwiftUI
import PhotosUI

/// "Scansiona un poster" (Premium): photograph or pick a movie poster,
/// recognize it with AI, and land on the movie detail page — streaming
/// availability, cinema status, trailer — with a prominent shortcut to
/// schedule the movie on a diary day.
struct PosterScanView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var phase: Phase = .pick
    @State private var path: [TMDBMovie] = []
    @State private var showCamera = false
    @State private var libraryItem: PhotosPickerItem?
    @State private var query: String = ""
    @State private var searchResults: [TMDBMovie] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var showTutorial = false
    @AppStorage("posterScanTutorialSeen") private var tutorialSeen = false

    private enum Phase: Equatable {
        case pick
        case analyzing
        case chooser([TMDBMovie], tvTitle: String?)
        case failed(FailReason)

        enum FailReason: Equatable {
            case generic
            case tvSeries(String)
            case notInDatabase(String)
        }
    }

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Theme.background.ignoresSafeArea()

                switch phase {
                case .pick: pickView
                case .analyzing: analyzingView
                case .chooser(let movies, let tvTitle): chooserView(movies, tvTitle: tvTitle)
                case .failed(let reason): failedView(reason: reason)
                }

                if showTutorial {
                    ScanTutorialView {
                        tutorialSeen = true
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            showTutorial = false
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
                    .zIndex(1)
                }
            }
            .navigationTitle(L("scan.title"))
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.inkSoft)
                            .frame(width: 30, height: 30)
                            .background(Theme.card, in: .circle)
                    }
                    .accessibilityLabel(L("common.close"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            showTutorial = true
                        }
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.inkSoft)
                            .frame(width: 30, height: 30)
                            .background(Theme.card, in: .circle)
                    }
                    .accessibilityLabel(L("scan.tut.title"))
                }
            }
            .navigationDestination(for: TMDBMovie.self) { movie in
                ScannedMovieDetailView(movie: movie)
            }
        }
        .tint(Theme.primary)
        .onAppear {
            if !tutorialSeen {
                showTutorial = true
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                analyze(image)
            }
            .ignoresSafeArea()
        }
        .onChange(of: libraryItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    analyze(image)
                }
                libraryItem = nil
            }
        }
    }

    // MARK: - Step 1: acquisition

    private var pickView: some View {
        VStack(spacing: 18) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Theme.primary.opacity(0.25), Theme.rose.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 96, height: 96)
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(Theme.primary)
            }

            Text(L("scan.subtitle"))
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)

            VStack(spacing: 10) {
                if cameraAvailable {
                    Button {
                        showCamera = true
                    } label: {
                        Label(L("scan.camera"), systemImage: "camera.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                LinearGradient(
                                    colors: [Theme.primary, Theme.rose],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: .rect(cornerRadius: 16)
                            )
                    }
                    .buttonStyle(PressableCardStyle())
                    .sensoryFeedback(.impact(weight: .medium), trigger: showCamera)
                }

                PhotosPicker(selection: $libraryItem, matching: .images) {
                    Label(L("scan.library"), systemImage: "photo.on.rectangle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Theme.primary.opacity(0.10), in: .rect(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Theme.primary.opacity(0.30), lineWidth: 1.5)
                        )
                }

                if !cameraAvailable {
                    Text(L("scan.nocamera"))
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            .padding(.horizontal, 28)

            Spacer()

            Label(L("scan.privacy"), systemImage: "lock.shield")
                .font(.caption2)
                .foregroundStyle(Theme.inkSoft.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 14)
        }
    }

    // MARK: - Step 2: analysis

    private var analyzingView: some View {
        VStack(spacing: 18) {
            ProgressView()
                .controlSize(.large)
                .tint(Theme.primary)
            Text(L("scan.analyzing"))
                .font(.headline)
                .foregroundStyle(Theme.ink)
            Text(L("scan.privacy"))
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private func analyze(_ image: UIImage) {
        phase = .analyzing
        AnalyticsService.shared.log("poster_scan_started")
        Task {
            do {
                let outcome = try await PosterScanService.identify(image: image)
                phase = .chooser(outcome.movies, tvTitle: outcome.tvSeriesTitle)
                AnalyticsService.shared.log("poster_scan_recognized")
                if outcome.isConfident, let first = outcome.movies.first {
                    path = [first]
                }
            } catch PosterScanError.tvSeries(let title) {
                AnalyticsService.shared.log("poster_scan_tv_series")
                phase = .failed(.tvSeries(title))
            } catch PosterScanError.notFoundOnTMDB(let title) {
                // The recognized title (non-personal) is the whole point of
                // this event: it feeds the internal "missing on TMDB" board.
                AnalyticsService.shared.log(
                    "poster_scan_not_in_tmdb",
                    meta: ["title": String(title.prefix(80))]
                )
                // Pre-fill the manual search with the recognized title so
                // the user can tweak it right away.
                query = title
                phase = .failed(.notInDatabase(title))
            } catch {
                AnalyticsService.shared.log("poster_scan_failed")
                phase = .failed(.generic)
            }
        }
    }

    // MARK: - Step 3: ambiguity chooser

    private func chooserView(_ movies: [TMDBMovie], tvTitle: String?) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(L("scan.candidates"))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.ink)
                Text(L("scan.candidates.sub"))
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)

                if let tvTitle {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "tv")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.primary)
                            .padding(.top, 2)
                        Text(LF("scan.tv.banner", tvTitle))
                            .font(.footnote)
                            .foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.primary.opacity(0.10), in: .rect(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Theme.primary.opacity(0.25), lineWidth: 1)
                    )
                }

                VStack(spacing: 8) {
                    ForEach(movies) { movie in
                        ScanResultRow(movie: movie) {
                            path.append(movie)
                        }
                    }
                }

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        phase = .failed(.generic)
                    }
                } label: {
                    Label(L("scan.notThese"), systemImage: "magnifyingglass")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.primary)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Step 4: failure + manual search

    private func failedView(reason: Phase.FailReason) -> some View {
        let emoji: String
        let title: String
        let message: String
        switch reason {
        case .generic:
            emoji = "\u{1F3AC}"
            title = L("scan.failed.title")
            message = L("scan.failed.msg")
        case .tvSeries(let name):
            emoji = "\u{1F4FA}"
            title = L("scan.tv.title")
            message = LF("scan.tv.msg", name)
        case .notInDatabase(let name):
            emoji = "\u{1F50D}"
            title = L("scan.notfound.title")
            message = LF("scan.notfound.msg", name)
        }

        return VStack(spacing: 12) {
            Text(emoji)
                .font(.system(size: 40))
                .padding(.top, 24)
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                TextField(L("planner.searchPlaceholder"), text: $query)
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                if !query.isEmpty {
                    Button {
                        query = ""
                        searchResults = []
                        hasSearched = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.inkSoft.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 42)
            .background(Theme.card, in: .rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Theme.primary.opacity(0.18), lineWidth: 1)
            )

            if isSearching {
                ProgressView().tint(Theme.primary).padding(.top, 8)
            }

            if !isSearching && hasSearched && searchResults.isEmpty && query.count >= 2 {
                Text(LF("planner.noResults", query))
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.top, 8)
            }

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(searchResults) { movie in
                        ScanResultRow(movie: movie) {
                            path.append(movie)
                        }
                    }
                }
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.immediately)

            Button {
                query = ""
                searchResults = []
                hasSearched = false
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    phase = .pick
                }
            } label: {
                Label(L("common.retry"), systemImage: "camera.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 11)
                    .background(Theme.primary, in: .capsule)
            }
            .padding(.bottom, 10)
        }
        .padding(.horizontal, 24)
        .task(id: query) {
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= 2 else {
                searchResults = []
                hasSearched = false
                return
            }
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            isSearching = true
            defer { isSearching = false }
            do {
                let found = try await TMDBService.searchMovies(query: trimmed)
                guard !Task.isCancelled else { return }
                searchResults = found
                hasSearched = true
            } catch {
                guard !Task.isCancelled else { return }
                searchResults = []
                hasSearched = true
            }
        }
    }
}

// MARK: - Result row

/// Poster + title + year row used by the candidate chooser and the
/// manual-search fallback.
private struct ScanResultRow: View {
    let movie: TMDBMovie
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                poster
                VStack(alignment: .leading, spacing: 2) {
                    Text(movie.title)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if let year = movie.releaseYear {
                        Text(year)
                            .font(.caption)
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
            }
            .padding(10)
            .background(Theme.card, in: .rect(cornerRadius: 14))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private var poster: some View {
        Group {
            if let url = movie.posterURL {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Theme.surface
                }
            } else {
                Theme.surface.overlay {
                    Image(systemName: "film")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.primary.opacity(0.4))
                }
            }
        }
        .frame(width: 42, height: 63)
        .clipShape(.rect(cornerRadius: 8))
    }
}

// MARK: - Detail wrapper with scheduling

/// Movie detail reached from the scan flow: the standard detail page plus
/// a prominent "Programma per un giorno" bar that opens the diary calendar.
private struct ScannedMovieDetailView: View {
    let movie: TMDBMovie

    @Environment(MoviePlanner.self) private var planner
    @Environment(NotificationService.self) private var notifications
    @State private var showSchedule = false
    @State private var didSchedule = false

    var body: some View {
        MovieDetailView(movie: movie)
            .safeAreaInset(edge: .bottom) {
                Button {
                    showSchedule = true
                } label: {
                    Label(L("scan.schedule"), systemImage: "calendar.badge.plus")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            LinearGradient(
                                colors: [Theme.primary, Theme.rose],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: .rect(cornerRadius: 16)
                        )
                        .shadow(color: Theme.primary.opacity(0.3), radius: 10, y: 5)
                }
                .buttonStyle(PressableCardStyle())
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 6)
                .background(.ultraThinMaterial)
            }
            .sheet(isPresented: $showSchedule) {
                ScanScheduleSheet(movie: movie, didSchedule: $didSchedule)
            }
            .sensoryFeedback(.success, trigger: didSchedule)
    }
}

/// Day picker for planning the scanned movie in the diary.
private struct ScanScheduleSheet: View {
    let movie: TMDBMovie
    @Binding var didSchedule: Bool

    @Environment(MoviePlanner.self) private var planner
    @Environment(NotificationService.self) private var notifications
    @Environment(\.dismiss) private var dismiss
    @State private var day: Date = Date()

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 12) {
                    DatePicker(
                        L("scan.schedule.title"),
                        selection: $day,
                        in: Calendar.current.startOfDay(for: Date())...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .tint(Theme.primary)
                    .padding(.horizontal, 16)

                    Button {
                        planner.schedule(
                            movieId: movie.id,
                            title: movie.title,
                            posterPath: movie.posterPath,
                            genreIds: movie.genreIds,
                            on: day
                        )
                        notifications.syncMovieNightReminders(planner.scheduled)
                        AnalyticsService.shared.log("poster_scan_scheduled")
                        didSchedule.toggle()
                        dismiss()
                    } label: {
                        Label(L("scan.schedule.confirm"), systemImage: "checkmark")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Theme.primary, in: .rect(cornerRadius: 16))
                    }
                    .buttonStyle(PressableCardStyle())
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
                }
                .padding(.top, 8)
            }
            .navigationTitle(L("scan.schedule.title"))
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("common.cancel")) { dismiss() }
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Native camera

/// Native camera sheet (UIImagePickerController). The photo is handed to
/// the recognition flow and never written to the user's library.
private struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = info[.originalImage] as? UIImage
            parent.dismiss()
            if let image {
                parent.onImage(image)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
