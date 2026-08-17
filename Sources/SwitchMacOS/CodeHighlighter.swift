import SwiftUI
import Highlightr

/// Syntax highlighting for language-tagged code blocks, backed by
/// highlight.js via Highlightr. Everything here is best-effort: any failure
/// (unmapped language, missing theme, JS error) falls back to the uniform
/// code block styling in `MarkdownMessage`.
enum CodeHighlighter {
    /// highlight.js runs in a single JS context and every caller is on the
    /// main thread, so one shared instance is safe.
    static let shared: Highlightr? = { () -> Highlightr? in
        let hl = Highlightr()
        if let hl {
            let themes = hl.availableThemes()
            NSLog("[CodeHighlighter] INIT OK — availableThemes count: %d, has dracula: %d, has pojoaque: %d",
                  themes.count, themes.contains("dracula"), themes.contains("pojoaque"))
        } else {
            NSLog("[CodeHighlighter] INIT FAILED — Highlightr() returned nil")
        }
        return hl
    }()

    /// `setTheme` re-reads and re-parses the theme CSS on every call; the
    /// theme only changes when the system appearance flips, so remember the
    /// last applied name. Main-thread only — callers are SwiftUI bodies.
    private static var appliedTheme: String?

    /// Map the fence info strings we actually see in agent output to
    /// highlight.js language IDs.
    private static let languageMap: [String: String] = [
        "bash": "bash", "sh": "bash", "shell": "bash", "zsh": "bash",
        "console": "bash", "shell-session": "bash",
        "python": "python", "py": "python",
        "swift": "swift",
        "json": "json",
        "javascript": "javascript", "js": "javascript",
        "typescript": "typescript", "ts": "typescript",
        "yaml": "yaml", "yml": "yaml",
        "toml": "toml",
        "go": "go", "golang": "go",
        "rust": "rust", "rs": "rust",
        "ruby": "ruby", "rb": "ruby",
        "java": "java",
        "c": "c",
        "cpp": "cpp", "c++": "cpp", "cxx": "cpp",
        "csharp": "csharp", "cs": "csharp",
        "html": "xml", "xml": "xml", "svg": "xml",
        "css": "css",
        "sql": "sql",
        "dockerfile": "dockerfile", "docker": "dockerfile",
        "markdown": "markdown", "md": "markdown",
        "diff": "diff", "patch": "diff",
    ]

    static func highlighted(_ code: String, language: String, colorScheme: ColorScheme) -> AttributedString? {
        guard let jsLanguage = languageMap[language.lowercased()] else { return nil }
        return highlighted(code, jsLanguage: jsLanguage, colorScheme: colorScheme)
    }

    /// Highlight tool output whose language is not known from metadata.
    static func highlightedAuto(_ code: String, colorScheme: ColorScheme) -> AttributedString? {
        // Try tree-sitter auto-detection first
        if let result = TreeSitterHighlighter.highlightAuto(code) {
            return result
        }
        // Fall back to highlight.js auto-detection
        return highlighted(code, jsLanguage: nil, colorScheme: colorScheme)
    }

    private static func highlighted(
        _ code: String,
        jsLanguage: String?,
        colorScheme: ColorScheme
    ) -> AttributedString? {
        // Try tree-sitter first for known languages
        if let jsLanguage, let tsResult = TreeSitterHighlighter.highlight(code, language: jsLanguage) {
            return tsResult
        }

        // Fall back to highlight.js
        let themeName = colorScheme == .dark ? "dracula" : "github"
        guard let hl = shared,
              setThemeIfNeeded(themeName, on: hl),
              let ns = hl.highlight(code, as: jsLanguage) else {
            return nil
        }
        let result = toSwiftUI(ns)
        return result.characters.isEmpty ? nil : result
    }

    private static func setThemeIfNeeded(_ name: String, on hl: Highlightr) -> Bool {
        guard appliedTheme != name else { return true }
        let ok = hl.setTheme(to: name)
        NSLog("[CodeHighlighter] setTheme(%@) → %@", name, ok ? "OK" : "FAILED")
        guard ok else { return false }
        appliedTheme = name
        return true
    }

    /// Carry the per-token colors out of a highlighted NSAttributedString by
    /// walking its runs explicitly, rather than relying on the
    /// NS↔Swift attribute-scope bridging. Fonts are applied later in
    /// `highlightedBlock`, so only foreground color needs carrying over.
    private static func toSwiftUI(_ ns: NSAttributedString) -> AttributedString {
        var out = AttributedString()
        guard ns.length > 0 else { return out }
        ns.enumerateAttributes(in: NSRange(location: 0, length: ns.length)) { attrs, range, _ in
            let text = (ns.string as NSString).substring(with: range)
            var run = AttributedString(text)
            if let color = attrs[.foregroundColor] as? NSColor {
                run.foregroundColor = Color(nsColor: color)
            }
            out += run
        }
        return out
    }

    /// Split an AttributedString into lines, preserving per-run attributes.
    /// `AttributedString` itself is not a character collection — iterate the
    /// `characters` view, whose `Index` is `AttributedString.Index`, so the
    /// same indices can slice the original string.
    static func splitLines(_ attributed: AttributedString) -> [AttributedString] {
        var lines: [AttributedString] = []
        let chars = attributed.characters
        var lineStart = chars.startIndex
        var i = chars.startIndex
        let end = chars.endIndex
        while i < end {
            if chars[i] == "\n" {
                lines.append(AttributedString(attributed[lineStart..<i]))
                lineStart = chars.index(after: i)
            }
            i = chars.index(after: i)
        }
        lines.append(AttributedString(attributed[lineStart..<end]))
        return lines
    }
}
