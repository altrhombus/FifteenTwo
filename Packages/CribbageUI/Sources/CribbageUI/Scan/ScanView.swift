#if os(iOS) || os(macOS)
import SwiftUI
import CribbageKit
import CribbageVision

/// "Turn your phone into a coach" — see docs/plan.md ("Vision Hand-Scanning"): photograph
/// a real dealt hand, confirm/correct each card, get the same `DiscardSolver` analysis
/// solo play's training screen uses. Camera capture itself is iOS-only (see
/// `CameraCaptureView`); on macOS this screen is reachable but has no capture entry point
/// yet — manual entry (tapping "Add Card" repeatedly) still works everywhere.
public struct ScanView: View {
    @State private var controller = ScanSessionController()
    #if os(iOS)
    @State private var isCapturing = false
    #endif

    public init() {}

    public var body: some View {
        NavigationStack {
            Group {
                if controller.isScanning {
                    ProgressView("Scanning…")
                } else if controller.guesses.isEmpty {
                    startScreen
                } else {
                    confirmationScreen
                }
            }
            .navigationTitle("Scan Hand")
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $isCapturing) {
            CameraCaptureView { image in
                isCapturing = false
                controller.scan(image)
            }
            .ignoresSafeArea()
        }
        #endif
    }

    private var startScreen: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("Lay your 6 cards face-up in a row, then take a photo.")
                .font(.headline)
                .multilineTextAlignment(.center)
            if let errorMessage = controller.scanErrorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            #if os(iOS)
            Button("Take Photo", systemImage: "camera") { isCapturing = true }
                .buttonStyle(.borderedProminent)
            #endif
            Button("Enter Cards Manually", systemImage: "square.and.pencil") {
                for _ in 0..<6 { controller.addBlankGuess() }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    private var confirmationScreen: some View {
        ScrollView {
            VStack(spacing: 16) {
                Toggle("I'm the dealer", isOn: Bindable(controller).isDealer)

                ForEach(controller.guesses) { guess in
                    GuessRow(
                        guess: guess,
                        onUpdate: { rank, suit in controller.updateGuess(id: guess.id, rank: rank, suit: suit) },
                        onRemove: { controller.removeGuess(id: guess.id) }
                    )
                    Divider()
                }

                Button("Add Card", systemImage: "plus") {
                    controller.addBlankGuess()
                }
                .buttonStyle(.bordered)

                if controller.resolvedHand != nil {
                    Button("Analyze Discard") {
                        controller.analyzeDiscard()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Text("Confirm exactly 6 different cards to analyze.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !controller.analysis.isEmpty {
                    ScanDiscardAnalysisView(options: controller.analysis)
                }

                Button("Start Over", role: .destructive) {
                    controller.reset()
                }
                .padding(.top)
            }
            .padding()
        }
    }
}

private struct GuessRow: View {
    let guess: EditableCardGuess
    let onUpdate: (Rank?, Suit?) -> Void
    let onRemove: () -> Void

    @State private var rank: Rank?
    @State private var suit: Suit?

    init(guess: EditableCardGuess, onUpdate: @escaping (Rank?, Suit?) -> Void, onRemove: @escaping () -> Void) {
        self.guess = guess
        self.onUpdate = onUpdate
        self.onRemove = onRemove
        _rank = State(initialValue: guess.rank)
        _suit = State(initialValue: guess.suit)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let cornerImage = guess.cornerImage {
                Image(decorative: cornerImage, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50, height: 70)
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.secondary.opacity(0.4)))
            }
            CardPickerView(rank: $rank, suit: $suit, suggestedColor: guess.suggestedColor)
            Button(role: .destructive, action: onRemove) {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
        }
        .onChange(of: rank) { _, newValue in onUpdate(newValue, suit) }
        .onChange(of: suit) { _, newValue in onUpdate(rank, newValue) }
    }
}

private struct ScanDiscardAnalysisView: View {
    let options: [DiscardOption]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Best Discards").font(.headline)
            ForEach(options.prefix(5), id: \.discarded) { option in
                HStack {
                    Text(option.discarded.map { "\($0.rank.symbol)\($0.suit.symbol)" }.joined(separator: " "))
                    Spacer()
                    Text("\(option.netExpectedValue, specifier: "%.1f") pts")
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    ScanView()
}
#endif
