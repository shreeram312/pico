import Foundation

/// One thing Pico can do to the selected text.
struct Action: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    /// SF Symbol name.
    var icon: String
    /// Instruction for the model. May use {{language}} for the user's chosen language.
    var prompt: String
    /// Only show this action for text written in an Indic/Arabic script (true) or not (false). nil = always.
    var requiresNativeScript: Bool? = nil
}

enum Actions {
    static let systemPrompt = """
    You are Pico, a text tool that lives in a tiny popup on the user's Mac. The user selected some \
    text and picked an action. Apply the action and return ONLY the resulting text: no quotes, no \
    preamble, no explanation, no markdown fences, unless the action itself asks for an explanation.

    Detect the language and script of the input yourself. Treat romanized Indian languages \
    (Hinglish, Tenglish/Telugu in English letters, Tanglish, Manglish, Marathi or Gujarati in \
    English letters, and so on) as languages in their own right: keep them romanized, with natural \
    chat spelling, unless the action explicitly asks to change the script. Preserve names, numbers, \
    URLs, emoji, line breaks and formatting. Match the register of the input: a casual WhatsApp \
    message stays casual, an email stays an email.
    """

    static let builtIn: [Action] = [
        Action(id: "fix", title: "Fix", icon: "checkmark.circle",
               prompt: "Fix spelling, grammar and punctuation. Keep the same language, script, tone and meaning. Change as little as possible."),
        Action(id: "native", title: "To native script", icon: "character.book.closed",
               prompt: "This text is an Indian language written in English letters. Rewrite it in that language's native script (Devanagari, Telugu, Tamil, Kannada, Bengali, Gujarati, Gurmukhi, Malayalam, Odia or Urdu as appropriate). Keep English brand names and technical terms the way a native speaker would write them in that script. If the text is actually plain English, translate it into {{language}} in native script instead.",
               requiresNativeScript: false),
        Action(id: "roman", title: "To romanized", icon: "textformat.abc",
               prompt: "Rewrite this text in romanized form: the same language, but in English letters, spelled the natural way people type it in chat.",
               requiresNativeScript: true),
        Action(id: "english", title: "To English", icon: "globe",
               prompt: "Translate this text into natural, fluent English. Keep the tone."),
        Action(id: "mine", title: "To my language", icon: "arrow.left.arrow.right",
               prompt: "Translate this text into {{language}}. Keep the tone and meaning."),
        Action(id: "formal", title: "Formal", icon: "briefcase",
               prompt: "Rewrite this in a polite, professional tone suitable for a manager or client, in the same language and script. Keep it concise."),
        Action(id: "shorter", title: "Shorter", icon: "arrow.down.right.and.arrow.up.left",
               prompt: "Rewrite this at about half the length, keeping every important point, in the same language and script."),
        Action(id: "reply", title: "Draft reply", icon: "arrowshape.turn.up.left",
               prompt: "This is a message the user received. Draft a short, natural reply in the same language and script, matching its tone. Return only the reply."),
        Action(id: "explain", title: "Explain", icon: "questionmark.circle",
               prompt: "Explain what this text means in simple terms, in {{language}}. If it is a single word or phrase, give its meaning and one example sentence. If it is code, explain what it does. Keep it under 80 words."),
    ]

    /// Custom actions from ~/Library/Application Support/Pico/actions.json (an array of Action objects).
    static var customActionsURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Pico/actions.json")
    }

    static func custom() -> [Action] {
        guard let data = try? Data(contentsOf: customActionsURL) else { return [] }
        return (try? JSONDecoder().decode([Action].self, from: data)) ?? []
    }

    static func all() -> [Action] { builtIn + custom() }

    /// Built-in actions that make sense for this text, plus every custom action.
    static func visible(for text: String) -> [Action] {
        let native = containsNativeScript(text)
        return all().filter { $0.requiresNativeScript == nil || $0.requiresNativeScript == native }
    }

    /// True if the text contains Indic or Arabic-script characters (Devanagari … Malayalam, Urdu).
    static func containsNativeScript(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x0900...0x0DFF).contains(scalar.value) || (0x0600...0x06FF).contains(scalar.value)
        }
    }

    @MainActor
    static func userMessage(for action: Action, text: String, settings: Settings) -> String {
        let instruction = action.prompt.replacingOccurrences(of: "{{language}}", with: settings.languageDescription)
        return """
        Action: \(instruction)

        Text:
        \(text)
        """
    }
}
