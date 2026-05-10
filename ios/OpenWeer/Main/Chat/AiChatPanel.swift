import SwiftUI
import CoreLocation

struct AiChatPanel: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var messages: [ChatMessage] = []
    @State private var draft: String = ""
    @State private var streamingTask: Task<Void, Never>?
    @State private var isStreaming = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if messages.isEmpty {
                    emptyState
                } else {
                    messageList
                }
                inputBar
            }
            .background(Color.owSurface)
            .navigationTitle("Vraag het OpenWeer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.owInkSecondary)
                            .font(.system(size: 22))
                    }
                    .accessibilityLabel("Sluiten")
                }
            }
        }
        .onDisappear { streamingTask?.cancel() }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color.owAccent)
            Text("Stel een weervraag")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.owInkPrimary)
            Text("Ik heb het actuele weer en de regenverwachting voor jouw locatie en de grote NL-steden bij de hand.")
                .multilineTextAlignment(.center)
                .font(.system(size: 14))
                .foregroundStyle(Color.owInkSecondary)
                .padding(.horizontal, 32)
            VStack(spacing: 8) {
                ForEach(suggestionPrompts, id: \.self) { p in
                    Button(action: { sendPrompt(p) }) {
                        Text(p)
                            .font(.system(size: 14, weight: .medium))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.owSurfaceCard)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(Color.owInkPrimary)
                    }
                }
            }
            .padding(.horizontal, 16)
            Spacer()
        }
    }

    private var suggestionPrompts: [String] {
        switch appState.language {
        case .nl: return [
            "Gaat het de komende twee uur regenen?",
            "Heb ik een paraplu nodig vanmiddag?",
            "Wat is het weer in Rotterdam?"
        ]
        case .en: return [
            "Will it rain in the next two hours?",
            "Do I need an umbrella this afternoon?",
            "What's the weather in Rotterdam?"
        ]
        }
    }

    @ViewBuilder
    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(messages) { msg in
                        ChatBubble(message: msg).id(msg.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .onChange(of: messages.last?.content) { _, _ in
                if let last = messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var inputBar: some View {
        VStack(spacing: 8) {
            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.owDanger)
                    .padding(.horizontal, 16)
            }
            HStack(spacing: 8) {
                TextField("Bericht…", text: $draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.owSurfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .disabled(isStreaming)
                    .accessibilityIdentifier("chat.input")

                Button(action: { sendPrompt(draft) }) {
                    Image(systemName: isStreaming ? "stop.fill" : "arrow.up")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(canSend ? Color.owAccent : Color.owInkSecondary.opacity(0.4))
                        .clipShape(Circle())
                }
                .disabled(!canSend && !isStreaming)
                .accessibilityLabel(isStreaming ? "Stop" : "Verstuur")
                .accessibilityIdentifier("chat.send")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(Color.owSurface)
        .overlay(alignment: .top) {
            Divider().opacity(0.4)
        }
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func sendPrompt(_ text: String) {
        if isStreaming {
            streamingTask?.cancel()
            isStreaming = false
            return
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        draft = ""
        error = nil

        let userMsg = ChatMessage(role: .user, content: trimmed)
        messages.append(userMsg)
        let assistantId = UUID()
        messages.append(ChatMessage(id: assistantId, role: .assistant, content: ""))
        isStreaming = true

        let conversation = messages.dropLast()
        let coord = appState.coordinate
        let lang = appState.language
        let locName = appState.locationName

        streamingTask = Task {
            do {
                try await ChatStreamClient().stream(
                    messages: Array(conversation),
                    coordinate: coord,
                    language: lang,
                    locationName: locName
                ) { delta in
                    if let i = messages.firstIndex(where: { $0.id == assistantId }) {
                        messages[i].content += delta
                    }
                }
            } catch is CancellationError {
                // user-initiated stop
            } catch {
                self.error = String(describing: error)
            }
            isStreaming = false
        }
    }
}

private struct ChatBubble: View {
    let message: ChatMessage
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 32)
                bubble
                    .background(Color.owAccent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                bubble
                    .background(Color.owSurfaceCard)
                    .foregroundStyle(Color.owInkPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                Spacer(minLength: 32)
            }
        }
    }
    private var bubble: some View {
        Text(message.content.isEmpty ? "…" : message.content)
            .font(.system(size: 15))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .textSelection(.enabled)
            .frame(minHeight: 22, alignment: .leading)
    }
}
