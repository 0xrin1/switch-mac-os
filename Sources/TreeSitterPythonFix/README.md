# TreeSitterPythonFix

Workaround for a bug in the upstream `tree-sitter-python` SPM package.

Its `Package.swift` uses a conditional to include `src/scanner.c`:

```swift
var sources = ["src/parser.c"]
if FileManager.default.fileExists(atPath: "src/scanner.c") {
    sources.append("src/scanner.c")
}
```

This `FileManager` check fails during SPM manifest evaluation (CWD isn't the
package root), so `scanner.c` never gets compiled. The external scanner
symbols (`tree_sitter_python_external_scanner_*`) are then missing at link time.

This target vendors the `scanner.c` + required tree-sitter core headers so the
symbols are available. Remove this once upstream fixes their manifest.
