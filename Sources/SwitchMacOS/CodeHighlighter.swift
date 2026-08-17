import SwiftUI
import Highlightr

/// Syntax highlighting for language-tagged code blocks, backed by
/// highlight.js via Highlightr. Everything here is best-effort: any failure
/// (unmapped language, missing theme, JS error) falls back to the uniform
/// code block styling in `MarkdownMessage`.
enum CodeHighlighter {
    /// highlight.js runs in a single JS context and every caller is on the
    /// main thread, so one shared instance is safe.
    static let shared: Highlightr? = Highlightr()

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
        let themeName = colorScheme == .dark ? "atom-one-dark" : "atom-one-light"
        guard let hl = shared else {
            diagOnce("FAIL shared Highlightr is nil — highlight.min.js/theme resources not found at runtime (check the .app bundle contains Highlightr_Highlightr.bundle)")
            return nil
        }
        guard let jsLanguage = languageMap[language.lowercased()] else { return nil }
        guard setThemeIfNeeded(themeName, on: hl) else {
            diagOnce("FAIL setTheme(\(themeName)) — theme CSS not found in bundle")
            return nil
        }
        guard let ns = hl.highlight(code, as: jsLanguage) else {
            diagOnce("FAIL highlight() returned nil for language \(jsLanguage)")
            return nil
        }

        let result = toSwiftUI(ns)
        guard !result.characters.isEmpty else { return nil }
        diagOnce("OK highlight language=\(jsLanguage) theme=\(themeName) codeChars=\(code.count)")
        return result
    }

    // One-shot runtime diagnostics so a silent no-op is diagnosable. Writes to
    // stderr and ~/Library/Logs/switch-macos-highlight.log.
    private static var diagState: [String: Bool] = [:]
    private static var toolDiagLogged = false

    /// One-shot diagnostic for the bash tool-call path (separate from the
    /// highlighter's own once-per-key logging).
    static func toolDiagOnce(_ message: String) {
        guard !toolDiagLogged else { return }
        toolDiagLogged = true
        logDiag(message)
    }

    private static func diagOnce(_ message: String) {
        let key = message.split(separator: " ").prefix(2).joined(separator: " ")
        guard diagState[key] != true else { return }
        diagState[key] = true
        logDiag(message)
    }

    private static func logDiag(_ message: String) {
        let line = "[CodeHighlighter \(Date())] \(message)\n"
        let data = line.data(using: .utf8) ?? Data()
        FileHandle.standardError.write(data)
        let fm = FileManager.default
        guard let lib = fm.urls(for: .libraryDirectory, in: .userDomainMask).first else { return }
        let dir = lib.appendingPathComponent("Logs")
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("switch-macos-highlight.log")
        if fm.fileExists(atPath: url.path), let fh = try? FileHandle(forWritingTo: url) {
            fh.seekToEndOfFile()
            try? fh.write(contentsOf: data)
            try? fh.close()
        } else {
            try? data.write(to: url)
        }
    }

    private static func setThemeIfNeeded(_ name: String, on hl: Highlightr) -> Bool {
        guard appliedTheme != name else { return true }
        guard hl.setTheme(to: name) else { return false }
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
