import DumpCore
import SwiftUI

/// The app's one screen: a text field that has the keyboard up as soon as the
/// app opens, and a Dump button above the keyboard (`docs/specs/capture.md`).
struct ComposerView: View {
    @AppStorage(AppConstants.draftKey) private var draft = ""
    @FocusState private var isFocused: Bool
    @Environment(\.scenePhase) private var scenePhase
    @State private var captureCount = 0

    var body: some View {
        NavigationStack {
            TextEditor(text: $draft)
                .focused($isFocused)
                .padding(.horizontal, AppConstants.composerPadding)
                .navigationTitle("Dump")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) { keyboardBar }
                }
        }
        .task { isFocused = true }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { isFocused = true }
        }
        .sensoryFeedback(.success, trigger: captureCount)
    }

    @ViewBuilder private var keyboardBar: some View {
        StatusHint()
        Spacer()
        Button("Dump", action: capture)
            .bold()
            .disabled(EntryRules.content(from: draft) == nil)
    }

    /// Clears the field at once and saves the entry on the phone; sending
    /// happens after, in the background. If the save fails, the text comes
    /// back so nothing is lost.
    private func capture() {
        let text = draft
        draft = ""
        captureCount += 1
        Task {
            do {
                try await Dependencies.outbox.capture(text)
                await Dependencies.outbox.flush()
            } catch {
                if draft.isEmpty { draft = text }
            }
        }
    }
}

#Preview {
    ComposerView()
        .environment(SyncStatus.shared)
}
