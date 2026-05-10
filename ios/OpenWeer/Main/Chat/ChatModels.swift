import Foundation

enum ChatRole: String, Codable, Sendable {
    case user
    case assistant
}

struct ChatMessage: Identifiable, Hashable, Sendable {
    let id: UUID
    var role: ChatRole
    var content: String

    init(id: UUID = UUID(), role: ChatRole, content: String) {
        self.id = id
        self.role = role
        self.content = content
    }
}

/// Exact mirror of `web/app/lib/ai-chat.ts → SHORTCUT_CHIPS`. The chip shows
/// an emoji + short label; tapping sends the long `prompt` to /api/chat.
struct ShortcutChip: Identifiable, Hashable, Sendable {
    var id: String { label }
    let emoji: String
    let label: String
    let prompt: String
}

enum ChatShortcuts {
    static let chips: [ShortcutChip] = [
        ShortcutChip(
            emoji: "☂️",
            label: "Wanneer kan ik droog naar buiten?",
            prompt: "Op basis van de huidige neerslagverwachting voor mijn locatie, wanneer is het komende 2 uur het meest droog?"
        ),
        ShortcutChip(
            emoji: "🚲",
            label: "Kan ik nu fietsen?",
            prompt: "Is het verstandig om de komende 30 minuten te fietsen op mijn locatie? Houd rekening met regen en intensiteit."
        ),
        ShortcutChip(
            emoji: "🌧️",
            label: "Leg het weer uit",
            prompt: "Leg het huidige weerbeeld op mijn locatie in begrijpelijke taal uit. Geef ook tips voor de komende 2 uur."
        ),
        ShortcutChip(
            emoji: "📍",
            label: "Vergelijk met steden in de buurt",
            prompt: "Vergelijk de regen op mijn locatie met andere grote steden in Nederland. Waar is het droger?"
        ),
    ]
}
