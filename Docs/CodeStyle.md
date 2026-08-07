# Code style

Swift source uses four spaces for indentation. Imports are grouped at the top
of each file and sorted alphabetically. Keep lines at or below 120 characters;
lines longer than 160 characters are errors. Comments, URLs, and multiline
strings are excluded from the line-length check.

## SwiftLint

Install SwiftLint using Homebrew:

```bash
brew install swiftlint
```

Run the project lint checks from the repository root:

```bash
swiftlint lint --config .swiftlint.yml
```

For CI or pull-request checks, treat warnings as failures:

```bash
swiftlint lint --strict --config .swiftlint.yml
```
