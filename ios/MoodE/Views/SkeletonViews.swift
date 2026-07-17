//
//  SkeletonViews.swift
//  MoodE
//

import SwiftUI

/// Moving highlight applied to skeleton placeholders while data loads.
struct ShimmerModifier: ViewModifier {
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .overlay {
                LinearGradient(
                    colors: [.white.opacity(0), .white.opacity(0.6), .white.opacity(0)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .scaleEffect(x: 1.8)
                .offset(x: isAnimating ? 500 : -500)
                .mask(content)
                .allowsHitTesting(false)
            }
            .onAppear {
                withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

extension View {
    /// Applies the animated shimmer used by loading skeletons.
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

/// Base rounded block used to compose skeleton layouts.
struct SkeletonBlock: View {
    var cornerRadius: CGFloat = 10

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Theme.surface)
    }
}

/// Skeleton for the 2-column poster grids (Tendenze, Al Cinema).
struct SkeletonPosterGrid: View {
    var showsChipsRow: Bool = false

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if showsChipsRow {
                HStack(spacing: 8) {
                    SkeletonBlock(cornerRadius: 18)
                        .frame(width: 72, height: 34)
                    SkeletonBlock(cornerRadius: 18)
                        .frame(width: 104, height: 34)
                    SkeletonBlock(cornerRadius: 18)
                        .frame(width: 88, height: 34)
                }
            }

            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(0..<6, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 8) {
                        SkeletonBlock(cornerRadius: 16)
                            .aspectRatio(2 / 3, contentMode: .fit)
                        SkeletonBlock(cornerRadius: 6)
                            .frame(height: 14)
                            .padding(.trailing, 28)
                        SkeletonBlock(cornerRadius: 6)
                            .frame(width: 84, height: 11)
                    }
                }
            }
        }
        .shimmer()
        .accessibilityLabel("Caricamento in corso")
    }
}

/// Skeleton for the vertical recommendation cards (Home results).
struct SkeletonResultsList: View {
    var body: some View {
        VStack(spacing: 14) {
            ForEach(0..<4, id: \.self) { _ in
                HStack(alignment: .top, spacing: 14) {
                    SkeletonBlock(cornerRadius: 14)
                        .frame(width: 92, height: 132)

                    VStack(alignment: .leading, spacing: 10) {
                        SkeletonBlock(cornerRadius: 6)
                            .frame(height: 16)
                            .padding(.trailing, 44)
                        SkeletonBlock(cornerRadius: 6)
                            .frame(width: 112, height: 12)
                        SkeletonBlock(cornerRadius: 6)
                            .frame(height: 10)
                        SkeletonBlock(cornerRadius: 6)
                            .frame(height: 10)
                            .padding(.trailing, 32)
                        HStack(spacing: 8) {
                            SkeletonBlock(cornerRadius: 16)
                                .frame(width: 78, height: 32)
                            SkeletonBlock(cornerRadius: 16)
                                .frame(width: 88, height: 32)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(.white.opacity(0.5), in: .rect(cornerRadius: 22))
            }
        }
        .shimmer()
        .accessibilityLabel("Caricamento in corso")
    }
}
