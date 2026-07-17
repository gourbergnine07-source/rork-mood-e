//
//  CinemaView.swift
//  MoodE
//

import SwiftUI
import CoreLocation

/// Al Cinema tab: now-playing movies for the user's country plus
/// a placeholder for nearby cinema showtimes.
struct CinemaView: View {
    @State private var locationService = LocationService()
    @State private var viewModel = CinemaViewModel()
    @State private var skippedPermission = false
    @Environment(\.openURL) private var openURL

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                content
            }
            .navigationTitle("Al Cinema")
            .toolbarTitleDisplayMode(.large)
            .navigationDestination(for: TMDBMovie.self) { movie in
                MovieDetailView(movie: movie)
            }
        }
        .tint(Theme.tabCinema)
        .onChange(of: locationService.authorizationStatus) { oldStatus, newStatus in
            guard oldStatus == .notDetermined, newStatus != .notDetermined else { return }
            Task { await loadMovies() }
        }
        .task {
            if locationService.authorizationStatus != .notDetermined, case .idle = viewModel.state {
                await loadMovies()
            }
        }
    }

    // MARK: - Loading

    private func loadMovies() async {
        let region = await resolveRegion()
        await viewModel.load(region: region)
        await loadNearbyCinemas()
    }

    /// Loads nearby cinema names via Apple Maps when location is available.
    private func loadNearbyCinemas() async {
        guard locationService.isAuthorized,
              let location = await locationService.resolveLocation() else { return }
        await viewModel.loadNearbyCinemas(around: location)
    }

    /// Country from the user's position when authorized, otherwise device locale.
    private func resolveRegion() async -> String {
        if locationService.isAuthorized,
           let code = await locationService.resolveCountryCode() {
            return code
        }
        return Locale.current.region?.identifier ?? "IT"
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if locationService.authorizationStatus == .notDetermined && !skippedPermission {
            permissionIntro
        } else {
            switch viewModel.state {
            case .idle, .loading:
                loadingView
            case .failed(let message):
                errorView(message)
            case .loaded(let movies):
                moviesList(movies)
            }
        }
    }

    // MARK: - Permission intro

    private var permissionIntro: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Theme.tabCinema.opacity(0.14))
                    .frame(width: 130, height: 130)
                Circle()
                    .fill(Theme.tabCinema.opacity(0.10))
                    .frame(width: 170, height: 170)
                Image(systemName: "location.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Theme.tabCinema)
            }

            VStack(spacing: 12) {
                Text("Film in sala vicino a te")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)

                Text("Usiamo la tua posizione solo per capire in quale paese ti trovi e mostrarti i film attualmente al cinema nella tua zona. Non la salviamo né la condividiamo con nessuno.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            VStack(spacing: 12) {
                Button {
                    locationService.requestPermission()
                } label: {
                    Label("Consenti posizione", systemImage: "location.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Theme.tabCinema, in: .rect(cornerRadius: 18))
                        .shadow(color: Theme.tabCinema.opacity(0.35), radius: 10, y: 5)
                }
                .buttonStyle(PressableCardStyle())

                Button {
                    skippedPermission = true
                    Task { await loadMovies() }
                } label: {
                    Text("Non ora")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.inkSoft)
                        .frame(height: 40)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .tint(Theme.tabCinema)
            Text("Trovo i film in sala nella tua zona…")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(Theme.tabCinema)
            Text("Ops!")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
            Button {
                Task { await loadMovies() }
            } label: {
                Label("Riprova", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Theme.tabCinema, in: .capsule)
            }
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Movies list

    private func moviesList(_ movies: [TMDBMovie]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if locationService.isDenied {
                    deniedBanner
                }

                regionHeader

                if movies.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: columns, spacing: 18) {
                        ForEach(movies) { movie in
                            NavigationLink(value: movie) {
                                NowPlayingCard(movie: movie)
                            }
                            .buttonStyle(PressableCardStyle())
                        }
                    }
                    .padding(.horizontal, 24)
                }

                nearbyCinemasSection
            }
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .refreshable {
            await loadMovies()
        }
    }

    private var regionHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "ticket.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.tabCinema)
            Text("In sala in \(viewModel.regionName)")
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 24)
    }

    private var deniedBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 16))
                .foregroundStyle(Theme.tabCinema)

            Text("Posizione disattivata: usiamo il paese del tuo dispositivo.")
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)

            Spacer()

            Button("Impostazioni") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.tabCinema)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.white.opacity(0.65), in: .rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.tabCinema.opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("🎟️")
                .font(.system(size: 44))
            Text("Nessun film in sala trovato")
                .font(.headline)
                .foregroundStyle(Theme.ink)
            Text("Riprova più tardi: aggiorniamo l'elenco ogni giorno.")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
    }

    /// Nearby cinemas found via Apple Maps, with a note that showtimes are coming.
    private var nearbyCinemasSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.tabCinema)
                Text("Cinema vicino a te")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.ink)
            }

            switch viewModel.cinemasState {
            case .loading:
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(Theme.tabCinema)
                    Text("Cerco i cinema nella tua zona…")
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(.white.opacity(0.65), in: .rect(cornerRadius: 20))

            case .loaded(let cinemas):
                VStack(spacing: 10) {
                    ForEach(cinemas) { cinema in
                        NearbyCinemaRow(cinema: cinema)
                    }
                }

                showtimesComingNote

            case .idle, .unavailable:
                fallbackCinemaCard
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    private var showtimesComingNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 14))
                .foregroundStyle(Theme.tabCinema)
            Text("Presto potrai vedere anche gli orari degli spettacoli")
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
        }
        .padding(.top, 2)
    }

    private var fallbackCinemaCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.tabCinema.opacity(0.12))
                    .frame(width: 52, height: 52)
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.tabCinema)
            }

            Text(locationService.isAuthorized
                 ? "Nessun cinema trovato nella tua zona. Presto potrai vedere anche gli orari degli spettacoli."
                 : "Attiva la posizione per vedere i cinema vicino a te e, presto, gli orari degli spettacoli.")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
                .lineSpacing(2)

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(.white.opacity(0.65), in: .rect(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Theme.tabCinema.opacity(0.12), lineWidth: 1)
        )
    }
}

/// Tappable row for a nearby cinema: opens Apple Maps with driving directions.
struct NearbyCinemaRow: View {
    let cinema: NearbyCinema

    @State private var tapCount = 0

    var body: some View {
        Button {
            tapCount += 1
            cinema.openDirectionsInMaps()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.tabCinema.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "popcorn.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.tabCinema)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(cinema.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)

                    if let address = cinema.address {
                        Text(address)
                            .font(.caption)
                            .foregroundStyle(Theme.inkSoft)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 5) {
                    if let distance = cinema.formattedDistance {
                        Text(distance)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.tabCinema)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Theme.tabCinema.opacity(0.12), in: .capsule)
                    }

                    HStack(spacing: 3) {
                        Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                            .font(.system(size: 11))
                        Text("Indicazioni")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(Theme.tabCinema.opacity(0.85))
                }
            }
            .padding(12)
            .background(.white.opacity(0.65), in: .rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Theme.tabCinema.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(PressableCardStyle())
        .sensoryFeedback(.impact(weight: .light), trigger: tapCount)
        .accessibilityLabel("Apri le indicazioni per \(cinema.name)")
    }
}

/// Grid card for a now-playing movie: poster, title and release date.
struct NowPlayingCard: View {
    let movie: TMDBMovie

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            poster

            Text(movie.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            if let date = movie.formattedReleaseDate {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.tabCinema)
                    Text(date)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var poster: some View {
        Color(Theme.surface)
            .aspectRatio(2 / 3, contentMode: .fit)
            .overlay {
                if let url = movie.posterURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .allowsHitTesting(false)
                        case .failure:
                            posterFallback
                        default:
                            ProgressView()
                                .tint(Theme.tabCinema)
                        }
                    }
                } else {
                    posterFallback
                }
            }
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Theme.tabCinema.opacity(0.10), lineWidth: 1)
            )
    }

    private var posterFallback: some View {
        Image(systemName: "film")
            .font(.system(size: 30))
            .foregroundStyle(Theme.tabCinema.opacity(0.4))
    }
}

#Preview {
    CinemaView()
        .environment(MovieLibrary())
}
