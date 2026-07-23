//
//  ScanTutorialView.swift
//  MoodE
//

import SwiftUI

/// First-run overlay for "Scansiona un poster": an animated framing
/// illustration (poster + viewfinder corners + scanning beam) with quick
/// tips that boost recognition accuracy. Reopenable from the toolbar.
struct ScanTutorialView: View {
    let onDismiss: () -> Void

    @State private var isAnimating = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                illustration
                    .padding(.top, 26)

                Text(L("scan.tut.title"))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 12) {
                    tipRow(icon: "sun.max.fill", tint: .orange, text: L("scan.tut.tip.light"))
                    tipRow(icon: "viewfinder", tint: Theme.primary, text: L("scan.tut.tip.fill"))
                    tipRow(icon: "iphone", tint: .blue, text: L("scan.tut.tip.straight"))
                    tipRow(icon: "hand.raised.fill", tint: Theme.seenGreen, text: L("scan.tut.tip.steady"))
                }
                .padding(.horizontal, 22)

                Button {
                    onDismiss()
                } label: {
                    Text(L("scan.tut.ok"))
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
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
                .sensoryFeedback(.impact(weight: .light), trigger: isAnimating)
                .padding(.horizontal, 22)
                .padding(.bottom, 22)
            }
            .background(Theme.background, in: .rect(cornerRadius: 28))
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(Theme.primary.opacity(0.15), lineWidth: 1)
            )
            .padding(.horizontal, 28)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }

    // MARK: - Animated framing illustration

    private var illustration: some View {
        ZStack {
            // Poster mock
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [Theme.primary.opacity(0.40), Theme.rose.opacity(0.30)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 104, height: 150)
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: "film")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundStyle(.white.opacity(0.95))
                        Capsule()
                            .fill(.white.opacity(0.85))
                            .frame(width: 52, height: 6)
                        Capsule()
                            .fill(.white.opacity(0.5))
                            .frame(width: 34, height: 5)
                    }
                }

            // Viewfinder corners, gently breathing around the poster
            CornerBracketsShape()
                .stroke(Theme.primary, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                .frame(width: 136, height: 182)
                .scaleEffect(isAnimating ? 1.0 : 1.07)

            // Scanning beam sweeping the poster
            LinearGradient(
                colors: [Theme.primary.opacity(0), Theme.primary, Theme.primary.opacity(0)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 120, height: 2.5)
            .offset(y: isAnimating ? 66 : -66)
            .opacity(0.9)
        }
        .frame(height: 196)
        .accessibilityHidden(true)
    }

    private func tipRow(icon: String, tint: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.12), in: .circle)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Four L-shaped viewfinder corners.
private struct CornerBracketsShape: Shape {
    nonisolated func path(in rect: CGRect) -> Path {
        var path = Path()
        let len: CGFloat = 24

        // Top-left
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + len))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + len, y: rect.minY))
        // Top-right
        path.move(to: CGPoint(x: rect.maxX - len, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + len))
        // Bottom-right
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - len))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - len, y: rect.maxY))
        // Bottom-left
        path.move(to: CGPoint(x: rect.minX + len, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - len))

        return path
    }
}
