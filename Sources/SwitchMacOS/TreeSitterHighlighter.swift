import SwiftUI
import Foundation
import SwiftTreeSitter
import TreeSitterPython
import TreeSitterCSharp
import TreeSitterBash
import TreeSitterJSON

/// Tree-sitter based syntax highlighter using dracula theme colors.
/// Replaces the old Highlightr (highlight.js) approach with real parsing.
enum TreeSitterHighlighter {

    // MARK: - Dracula Theme Colors

    private static let colors: [String: Color] = [
        // Keywords & control flow
        "keyword": Color(hex: 0xb45bcf),
        "keyword.control": Color(hex: 0xb45bcf),
        "keyword.operator": Color(hex: 0xe9e9f4).opacity(0.7),
        "keyword.type": Color(hex: 0xb45bcf),
        "storage": Color(hex: 0xb45bcf),
        "storage.modifier": Color(hex: 0xb45bcf),
        "storage.type": Color(hex: 0xb45bcf),

        // Functions
        "function": Color(hex: 0x62d6e8),
        "function.builtin": Color(hex: 0xa1efe4),
        "function.call": Color(hex: 0x62d6e8),
        "function.definition": Color(hex: 0x62d6e8),
        "method": Color(hex: 0x62d6e8),
        "method.call": Color(hex: 0x62d6e8),
        "constructor": Color(hex: 0x62d6e8),

        // Strings
        "string": Color(hex: 0xebff87),
        "string.special": Color(hex: 0xebff87),
        "string.interpolated": Color(hex: 0xebff87),

        // Comments
        "comment": Color(hex: 0x626483),

        // Types & classes
        "type": Color(hex: 0xb45bcf),
        "type.builtin": Color(hex: 0xb45bcf),
        "class": Color(hex: 0x00f769),
        "class.identifier": Color(hex: 0x00f769),
        "type.identifier": Color(hex: 0xb45bcf),

        // Variables & properties
        "variable": Color(hex: 0xe9e9f4),
        "variable.builtin": Color(hex: 0xea51b2),
        "variable.parameter": Color(hex: 0xe9e9f4),
        "constant": Color(hex: 0xb45bcf),
        "constant.builtin": Color(hex: 0xb45bcf),
        "property": Color(hex: 0xea51b2),
        "property.definition": Color(hex: 0xea51b2),
        "property.access": Color(hex: 0xea51b2),

        // Numbers
        "number": Color(hex: 0xb45bcf),

        // Operators & punctuation
        "operator": Color(hex: 0xe9e9f4).opacity(0.7),
        "punctuation": Color(hex: 0xe9e9f4).opacity(0.7),
        "punctuation.special": Color(hex: 0xe9e9f4).opacity(0.7),
        "delimiter": Color(hex: 0xe9e9f4).opacity(0.7),

        // Modules & namespaces
        "module": Color(hex: 0x62d6e8),
        "namespace": Color(hex: 0x62d6e8),

        // Misc
        "tag": Color(hex: 0x62d6e8),
        "attribute": Color(hex: 0x62d6e8),
        "label": Color(hex: 0x00f769),
        "title": Color(hex: 0x00f769),
        "regex": Color(hex: 0xa1efe4),
    ]

    /// Default text color (dracula foreground)
    private static let defaultColor = Color(hex: 0xe9e9f4)

    // MARK: - Language Configurations

    private struct LangConfig {
        let name: String
        let config: LanguageConfiguration
        let parser: Parser
    }

    private static var configs: [String: LangConfig]?

    private static func loadConfigs() -> [String: LangConfig] {
        var result: [String: LangConfig] = [:]

        if let lang = try? LanguageConfiguration(tree_sitter_python(), name: "Python") {
            let p = Parser()
            try? p.setLanguage(lang.language)
            result["python"] = LangConfig(name: "Python", config: lang, parser: p)
        }

        if let lang = try? LanguageConfiguration(tree_sitter_c_sharp(), name: "CSharp") {
            let p = Parser()
            try? p.setLanguage(lang.language)
            result["csharp"] = LangConfig(name: "CSharp", config: lang, parser: p)
        }

        if let lang = try? LanguageConfiguration(tree_sitter_bash(), name: "Bash") {
            let p = Parser()
            try? p.setLanguage(lang.language)
            result["bash"] = LangConfig(name: "Bash", config: lang, parser: p)
        }

        if let lang = try? LanguageConfiguration(tree_sitter_json(), name: "JSON") {
            let p = Parser()
            try? p.setLanguage(lang.language)
            result["json"] = LangConfig(name: "JSON", config: lang, parser: p)
        }

        NSLog("[TreeSitter] Loaded: %@", result.keys.sorted().joined(separator: ", "))
        return result
    }

    private static var langConfigs: [String: LangConfig] {
        if let configs { return configs }
        let loaded = loadConfigs()
        configs = loaded
        return loaded
    }

    // MARK: - Public API

    /// Highlight code with a known language.
    static func highlight(_ code: String, language: String) -> AttributedString? {
        let key = language.lowercased()
        guard let lang = langConfigs[key] else { return nil }
        return highlightWithConfig(code: code, lang: lang)
    }

    /// Auto-detect language and highlight.
    static func highlightAuto(_ code: String) -> AttributedString? {
        guard let detected = detectLanguage(code) else { return nil }
        guard let lang = langConfigs[detected] else { return nil }
        return highlightWithConfig(code: code, lang: lang)
    }

    // MARK: - Core Highlighting

    private static func highlightWithConfig(code: String, lang: LangConfig) -> AttributedString? {
        guard let tree = lang.parser.parse(code) else { return nil }
        guard let query = lang.config.queries[.highlights] else { return nil }

        let cursor = query.execute(in: tree)
        let textProvider = code.predicateTextProvider
        let resolved = cursor.resolve(with: .init(textProvider: textProvider))

        let highlights = resolved.highlights()
        guard !highlights.isEmpty else { return nil }

        // Build result: default color for all, then overlay highlights
        var result = AttributedString(code)
        result.foregroundColor = defaultColor

        for hl in highlights {
            let nsRange = hl.range
            guard let stringRange = Range(nsRange, in: code) else { continue }
            guard let attrRange = attrRange(from: stringRange, in: code, attributed: result) else { continue }
            result[attrRange].foregroundColor = colorForCapture(hl.name)
        }

        return result
    }

    private static func colorForCapture(_ name: String) -> Color {
        if let color = colors[name] { return color }
        // Walk up the dot hierarchy: "function.builtin" → "function"
        let parts = name.split(separator: ".").map(String.init)
        for i in stride(from: parts.count - 1, through: 1, by: -1) {
            let parent = parts[0..<i].joined(separator: ".")
            if let color = colors[parent] { return color }
        }
        return defaultColor
    }

    /// Convert a String range to an AttributedString range.
    /// Works because AttributedString is built from the same source string,
    /// so character positions align 1:1.
    private static func attrRange(
        from stringRange: Range<String.Index>,
        in source: String,
        attributed: AttributedString
    ) -> Range<AttributedString.Index>? {
        let chars = attributed.characters
        let startOffset = source.distance(from: source.startIndex, to: stringRange.lowerBound)
        let length = source.distance(from: stringRange.lowerBound, to: stringRange.upperBound)
        guard startOffset >= 0, startOffset < chars.count else { return nil }
        guard let start = chars.index(chars.startIndex, offsetBy: startOffset, limitedBy: chars.endIndex) else { return nil }
        guard let end = chars.index(start, offsetBy: length, limitedBy: chars.endIndex) else { return nil }
        return start..<end
    }

    // MARK: - Language Detection

    static func detectLanguage(_ code: String) -> String? {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // JSON
        if (trimmed.hasPrefix("{") || trimmed.hasPrefix("[")) &&
            (trimmed.contains("\"") || trimmed.contains(":")) {
            return "json"
        }

        // Python (check before C# since "class" and "import" overlap)
        let hasPython = trimmed.contains("def ") ||
            (trimmed.contains("import ") && !trimmed.contains("import(")) ||
            (trimmed.contains("from ") && trimmed.contains(" import ")) ||
            trimmed.hasPrefix("elif ") ||
            trimmed.contains("self,") ||
            trimmed.contains("lambda ")
        if hasPython {
            return "python"
        }

        // C#
        let hasCSharp = trimmed.contains("public ") ||
            trimmed.contains("private ") ||
            trimmed.contains("void ") ||
            trimmed.contains("namespace ") ||
            trimmed.contains("using System") ||
            trimmed.contains(".NET") ||
            trimmed.contains("BaseItem")
        if hasCSharp {
            return "csharp"
        }

        // Bash (check last — most generic patterns)
        let hasBash = trimmed.hasPrefix("#!") ||
            trimmed.hasPrefix("cd ") ||
            trimmed.hasPrefix("ls ") ||
            trimmed.hasPrefix("sudo ") ||
            trimmed.contains("echo ") ||
            trimmed.contains("grep ") ||
            trimmed.contains(" && ") ||
            trimmed.contains(" | ") ||
            trimmed.contains("$(") ||
            trimmed.contains("export ")
        if hasBash {
            return "bash"
        }

        return nil
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}
