//
//  CinemaMapDetailView.swift
//  MoodE
//
//  In-app map for a cinema from the "Al Cinema" tab: shows the venue on
//  an integrated MapKit map (pin + info card) BEFORE handing off to the
//  external Maps app. "Indicazioni" remains the explicit second step.
//

import SwiftUI
import MapKit
import CoreLocation

/// Unified map target for both nearby results and saved favorites.
struct CinemaMapTarget: Identifiable {
    let id: String
    let name: String
    let address: String?
    let coordinate: CLLocationCoordinate2D
    let formattedDistance: String?

    init?(cinema: NearbyCinema) {
        guard let latitude = cinema.latitude, let longitude = cinema.longitude else { return nil }
        id = cinema.id
        name = cinema.name
        address = cinema.address
        coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        formattedDistance = cinema.formattedDistance
    }

    init?(favorite: FavoriteCinema, currentLocation: CLLocation?) {
        guard let latitude = favorite.latitude, let longitude = favorite.longitude else { return nil }
        id = favorite.id
        name = favorite.name
        address = favorite.address
        coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        formattedDistance = favorite.formattedDistance(from: currentLocation)
    }

    /// Hands off to the external Maps app with driving directions set.
    func openDirectionsInMaps() {
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}

/// Sheet with the integrated map: pin on the cinema, user position when
/// authorized, and a prominent "Indicazioni" button as the explicit
/// hand-off to the external Maps app. Closes with the ✕ button or a
/// swipe-down, so multiple cinemas can be compared without leaving the app.
struct CinemaMapDetailView: View {
    let target: CinemaMapTarget

    @Environment(\.dismiss) private var dismiss
    @State private var directionsTapCount = 0

    /// On iPad the sheet uses page sizing for a much larger map canvas;
    /// the info card is width-capped so it floats over the map instead of
    /// stretching edge-to-edge.
    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    var body: some View {
        if isPad {
            sheetContent
                .presentationSizing(.page)
        } else {
            sheetContent
        }
    }

    private var sheetContent: some View {
        NavigationStack {
            Map(initialPosition: .region(region)) {
                Marker(target.name, systemImage: "popcorn.fill", coordinate: target.coordinate)
                    .tint(Theme.tabCinema)
                UserAnnotation()
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            .ignoresSafeArea(edges: .bottom)
            .safeAreaInset(edge: .bottom) {
                infoCard
            }
            .navigationTitle(target.name)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Theme.inkSoft.opacity(0.7))
                    }
                    .accessibilityLabel(L("common.close"))
                }
            }
        }
        .tint(Theme.tabCinema)
        .presentationDragIndicator(.visible)
    }

    private var region: MKCoordinateRegion {
        MKCoordinateRegion(
            center: target.coordinate,
            latitudinalMeters: 1500,
            longitudinalMeters: 1500
        )
    }

    /// Venue details + the external-directions hand-off button.
    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.tabCinema.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "popcorn.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.tabCinema)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(target.name)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)

                    if let address = target.address {
                        Text(address)
                            .font(.caption)
                            .foregroundStyle(Theme.inkSoft)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 8)

                if let distance = target.formattedDistance {
                    Text(distance)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.tabCinema)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.tabCinema.opacity(0.12), in: .capsule)
                }
            }

            Button {
                directionsTapCount += 1
                target.openDirectionsInMaps()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text(L("cinema.directions"))
                        .font(.footnote.weight(.bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Theme.tabCinema, in: .rect(cornerRadius: 12))
            }
            .buttonStyle(PressableCardStyle())
            .sensoryFeedback(.impact(weight: .light), trigger: directionsTapCount)
            .accessibilityLabel(LF("cinema.a11y.directions", target.name))
        }
        .padding(16)
        .background(.thinMaterial, in: .rect(cornerRadius: 20))
        .frame(maxWidth: 560)
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }
}
