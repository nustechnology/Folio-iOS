import Foundation

enum SourceHTMLBuilder {

    static func fullHTML(for source: Source) -> String {
        let body = bodyHTML(for: source)
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src https: data:; style-src 'unsafe-inline';">
        <style>
        \(css)
        </style>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }

    // MARK: - Body

    private static func bodyHTML(for source: Source) -> String {
        if let structured = source.structuredContent,
           !structured.html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return sanitize(structured.html)
        }
        switch contentType(of: source) {
        case .sheet:
            return tableHTML(from: source.content)
        case .slides:
            return slidesHTML(from: source.content)
        case .document, .web, .text:
            return documentHTML(from: source.content)
        }
    }

    private enum ContentType {
        case document, slides, sheet, web, text
    }

    private static func contentType(of source: Source) -> ContentType {
        if let structured = source.structuredContent {
            switch structured.kind {
            case .slides: return .slides
            case .sheet: return .sheet
            case .web: return .web
            case .text: return .text
            case .document: return .document
            }
        }
        let ext = (source.fileName as NSString).pathExtension.lowercased()
        let fileType = source.fileType.lowercased()
        if ext == "pptx" || ext == "ppt" || fileType.contains("presentation") { return .slides }
        if ext == "xlsx" || ext == "xls" || ext == "csv" || fileType.contains("spreadsheet") || fileType == "text/csv" { return .sheet }
        return .document
    }

    // MARK: - Document

    private static func documentHTML(from content: String) -> String {
        let lines = content.components(separatedBy: .newlines)
        var html = ""
        var paragraph: [String] = []
        var list: [String] = []
        var tableLines: [String] = []

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            html += "<p>\(paragraph.map { escaped($0) }.joined(separator: "<br>"))</p>"
            paragraph = []
        }

        func flushList() {
            guard !list.isEmpty else { return }
            html += "<ul>" + list.map { "<li>\(escaped($0))</li>" }.joined() + "</ul>"
            list = []
        }

        func flushTable() {
            guard !tableLines.isEmpty else { return }
            if let table = buildTableHTML(fromMarkdownLines: tableLines) {
                html += table
            } else {
                for line in tableLines {
                    paragraph.append(line)
                }
                flushParagraph()
            }
            tableLines = []
        }

        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespaces)

            if isMarkdownTableLine(line) {
                flushList()
                flushParagraph()
                tableLines.append(line)
                continue
            } else {
                flushTable()
            }

            if line.isEmpty {
                flushList()
                flushParagraph()
                continue
            }

            if let page = pageMarker(line) {
                flushList()
                flushParagraph()
                html += "<div class=\"page-divider\">\(escaped(page))</div>"
                continue
            }

            if let heading = headingHTML(line) {
                flushList()
                flushParagraph()
                html += heading
                continue
            }

            if line.hasPrefix(">") {
                flushList()
                flushParagraph()
                html += "<blockquote>\(escaped(trimmed(line, prefix: ">")))</blockquote>"
                continue
            }

            if let bullet = bulletText(line) {
                flushParagraph()
                list.append(bullet)
                continue
            }

            paragraph.append(line)
        }

        flushList()
        flushParagraph()
        flushTable()
        return html
    }

    // MARK: - Slides

    private static func slidesHTML(from content: String) -> String {
        let lines = content.components(separatedBy: .newlines)
        var html = ""
        var list: [String] = []

        func flushList() {
            guard !list.isEmpty else { return }
            html += "<ul>" + list.map { "<li>\(escaped($0))</li>" }.joined() + "</ul>"
            list = []
        }

        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespaces)

            if line.isEmpty {
                flushList()
                continue
            }

            if let heading = headingHTML(line) {
                flushList()
                html += heading
                continue
            }

            if let slide = slideHeading(line) {
                flushList()
                html += "<div class=\"slide-divider\"><span class=\"slide-label\">\(escaped(slide))</span></div>"
                continue
            }

            if let bullet = bulletText(line) {
                list.append(bullet)
                continue
            }

            flushList()
            html += "<p>\(escaped(line))</p>"
        }

        flushList()
        return html
    }

    // MARK: - Sheets

    private static func tableHTML(from content: String) -> String {
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var blocks: [[String]] = []
        var currentBlock: [String] = []
        var currentIsTable = false

        for line in lines {
            let isTable = isMarkdownTableLine(line)
            if currentBlock.isEmpty || isTable == currentIsTable {
                currentBlock.append(line)
                currentIsTable = isTable
            } else {
                blocks.append(currentBlock)
                currentBlock = [line]
                currentIsTable = isTable
            }
        }
        if !currentBlock.isEmpty {
            blocks.append(currentBlock)
        }

        let hasTableBlock = blocks.contains { $0.allSatisfy(isMarkdownTableLine) }
        guard hasTableBlock else {
            let rows = parseCSVRows(content)
            guard !rows.isEmpty else { return documentHTML(from: content) }
            return renderTable(rows: rows)
        }

        var result = ""
        for block in blocks {
            if block.allSatisfy(isMarkdownTableLine) {
                if let table = buildTableHTML(fromMarkdownLines: block) {
                    result += table
                }
            } else {
                result += documentHTML(from: block.joined(separator: "\n"))
            }
        }
        return result
    }

    private static func isMarkdownTableLine(_ line: String) -> Bool {
        line.hasPrefix("|") && line.hasSuffix("|") && line.contains("|")
    }

    private static func isMarkdownTableSeparator(_ line: String) -> Bool {
        guard isMarkdownTableLine(line) else { return false }
        let inner = line.trimmingCharacters(in: CharacterSet(charactersIn: "|"))
        let components = inner.components(separatedBy: "|")
        return !components.isEmpty && components.allSatisfy { comp in
            let trimmed = comp.trimmingCharacters(in: .whitespaces)
            return trimmed.allSatisfy { $0 == "-" || $0 == ":" } && !trimmed.isEmpty
        }
    }

    private static func parseMarkdownTableRow(_ line: String) -> [String] {
        var trimmedLine = line
        if trimmedLine.hasPrefix("|") { trimmedLine.removeFirst() }
        if trimmedLine.hasSuffix("|") { trimmedLine.removeLast() }
        return trimmedLine.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func buildTableHTML(fromMarkdownLines lines: [String]) -> String? {
        let tableLines = lines.filter { isMarkdownTableLine($0) }
        guard !tableLines.isEmpty else { return nil }

        var parsedRows: [[String]] = []
        var separatorFound = false

        for line in tableLines {
            if isMarkdownTableSeparator(line) {
                separatorFound = true
                continue
            }
            parsedRows.append(parseMarkdownTableRow(line))
        }

        guard !parsedRows.isEmpty, (separatorFound || tableLines.count >= 2) else { return nil }
        return renderTable(rows: parsedRows)
    }

    private static func renderTable(rows: [[String]]) -> String {
        guard !rows.isEmpty else { return "" }
        var html = "<div class=\"table-wrap\"><table>"
        html += "<thead><tr>" + rows[0].map { "<th>\(escaped($0))</th>" }.joined() + "</tr></thead>"
        html += "<tbody>"
        for row in rows.dropFirst() {
            html += "<tr>" + row.map { "<td>\(escaped($0))</td>" }.joined() + "</tr>"
        }
        html += "</tbody></table></div>"
        return html
    }

    // MARK: - Line parsing helpers

    private static func headingHTML(_ line: String) -> String? {
        if line.hasPrefix("### ") {
            return "<h3>\(escaped(trimmed(line, prefix: "###")))</h3>"
        }
        if line.hasPrefix("## ") {
            return "<h2>\(escaped(trimmed(line, prefix: "##")))</h2>"
        }
        if line.hasPrefix("# ") {
            return "<h1>\(escaped(trimmed(line, prefix: "#")))</h1>"
        }
        return nil
    }

    private static func bulletText(_ line: String) -> String? {
        for prefix in ["- ", "* ", "• ", "‣ "] {
            if line.hasPrefix(prefix) {
                return String(line.dropFirst(prefix.count))
            }
        }
        return nil
    }

    private static func pageMarker(_ line: String) -> String? {
        guard line.hasPrefix("[page") || line.hasPrefix("[Page") else { return nil }
        let cleaned = line.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        let parts = cleaned.split(separator: " ")
        if parts.count >= 2, parts[0].lowercased() == "page" {
            return "Page \(parts[1])"
        }
        return nil
    }

    private static func slideHeading(_ line: String) -> String? {
        guard let range = line.range(of: "^Slide\\s+\\d+", options: .regularExpression) else { return nil }
        let raw = String(line[range])
        if let number = raw.split(separator: " ").last {
            return "Slide \(number)"
        }
        return raw
    }

    private static func trimmed(_ line: String, prefix: String) -> String {
        guard line.hasPrefix(prefix) else { return line }
        return String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
    }

    // MARK: - CSV

    private static func parseCSVRows(_ content: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        let chars = Array(content)
        var index = 0

        while index < chars.count {
            let char = chars[index]

            if inQuotes {
                if char == "\"" {
                    if index + 1 < chars.count, chars[index + 1] == "\"" {
                        field.append("\"")
                        index += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(char)
                }
            } else {
                switch char {
                case "\"":
                    inQuotes = true
                case ",":
                    row.append(field)
                    field = ""
                case "\n", "\r":
                    if !field.isEmpty || !row.isEmpty {
                        row.append(field)
                        rows.append(row)
                    }
                    row = []
                    field = ""
                    if char == "\r", index + 1 < chars.count, chars[index + 1] == "\n" {
                        index += 1
                    }
                default:
                    field.append(char)
                }
            }
            index += 1
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows
    }

    private static func escaped(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static let allowedElements: Set<String> = [
        "h1", "h2", "h3", "p", "ul", "ol", "li",
        "blockquote", "a", "table", "thead", "tbody", "tr", "th", "td",
        "div", "span", "br", "strong", "em", "b", "i", "u",
        "code", "pre", "hr", "sub", "sup", "img"
    ]

    private static func sanitize(_ html: String) -> String {
        guard let tagRegex = try? NSRegularExpression(pattern: "<(/)?(\\w+)((?:\\s+[^>]*)?)\\s*(/?)>") else {
            return html
        }

        var result = ""
        let nsString = html as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)
        var lastEnd = 0

        tagRegex.enumerateMatches(in: html, range: fullRange) { match, _, _ in
            guard let match = match else { return }

            if match.range.location > lastEnd {
                let textRange = NSRange(location: lastEnd, length: match.range.location - lastEnd)
                result += nsString.substring(with: textRange)
            }

            let isClosing = match.range(at: 1).length > 0
            let tagName = nsString.substring(with: match.range(at: 2)).lowercased()
            let attrsRange = match.range(at: 3)
            let attrs = attrsRange.length > 0 ? nsString.substring(with: attrsRange) : ""
            let isSelfClosing = match.range(at: 4).length > 0

            if allowedElements.contains(tagName) {
                if isClosing {
                    result += "</\(tagName)>"
                } else {
                    let safeAttrs = sanitizeAttributes(attrs, tag: tagName)
                    result += "<\(tagName)\(safeAttrs)\(isSelfClosing ? " /" : "")>"
                }
            }

            lastEnd = match.range.location + match.range.length
        }

        if lastEnd < nsString.length {
            let tailRange = NSRange(location: lastEnd, length: nsString.length - lastEnd)
            result += nsString.substring(with: tailRange)
        }

        result = result.replacingOccurrences(
            of: "\\s+on\\w+\\s*=\\s*(\"[^\"]*\"|'[^']*'|[^\\s>]*)",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        result = result.replacingOccurrences(
            of: "javascript\\s*:",
            with: "blocked:",
            options: [.regularExpression, .caseInsensitive]
        )

        // Ensure all <table> tags are wrapped inside <div class="table-wrap"> for horizontal scroll support
        if result.contains("<table") {
            result = result.replacingOccurrences(of: "(?<!<div class=\"table-wrap\">)(<table[^>]*>)", with: "<div class=\"table-wrap\">$1", options: .regularExpression)
            result = result.replacingOccurrences(of: "(</table>)(?!</div>)", with: "$1</div>", options: .regularExpression)
        }

        return result
    }


    private static func sanitizeAttributes(_ attrString: String, tag: String) -> String {
        guard let attrRegex = try? NSRegularExpression(pattern: "(\\w[\\w-]*)\\s*=\\s*(\"[^\"]*\"|'[^']*')") else {
            return ""
        }

        var result = ""
        let nsAttrs = attrString as NSString
        let fullRange = NSRange(location: 0, length: nsAttrs.length)

        attrRegex.enumerateMatches(in: attrString, range: fullRange) { match, _, _ in
            guard let match = match else { return }
            let name = nsAttrs.substring(with: match.range(at: 1)).lowercased()
            guard !name.hasPrefix("on") else { return }

            let isData = name.hasPrefix("data-")
            if name == "class" || name == "id" || isData {
                let full = nsAttrs.substring(with: match.range)
                result += " \(full)"
            }

            if name == "href", tag == "a" {
                var value = nsAttrs.substring(with: match.range(at: 2))
                value = value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                let lower = value.lowercased()
                if lower.hasPrefix("http://") || lower.hasPrefix("https://")
                    || value.hasPrefix("/") || value.hasPrefix("#")
                    || value.hasPrefix("mailto:") {
                    result += " href=\"\(value)\""
                }
            }

            if tag == "img" {
                if name == "src" {
                    var value = nsAttrs.substring(with: match.range(at: 2))
                    value = value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                    let lower = value.lowercased()
                    if lower.hasPrefix("https://") || (lower.hasPrefix("data:image/") && !lower.hasPrefix("data:image/svg+xml")) {
                        result += " src=\"\(value)\""
                    }
                } else if name == "alt" || name == "title" {
                    let full = nsAttrs.substring(with: match.range)
                    result += " \(full)"
                } else if name == "width" || name == "height" {
                    let value = nsAttrs.substring(with: match.range(at: 2))
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                    let isNumeric = value.allSatisfy { $0.isNumber }
                    let isPixelUnit = value.hasSuffix("px") && value.dropLast(2).allSatisfy { $0.isNumber }
                    if isNumeric || isPixelUnit {
                        result += " \(name)=\"\(value)\""
                    }
                }
            }
        }

        return result
    }

    // MARK: - CSS

    private static var css: String {
        """
        :root { color-scheme: light; }
        html, body { margin: 0; padding: 0; }
        body {
          font-family: -apple-system, "Helvetica Neue", sans-serif;
          color: #0C241E;
          font-size: 16px;
          line-height: 1.65;
          padding: 0;
          word-wrap: break-word;
          overflow-wrap: anywhere;
          -webkit-text-size-adjust: 100%;
        }
        img {
          max-width: 100%;
          height: auto;
          display: block;
          margin: 12px 0;
          border-radius: 8px;
        }
        h1, h2, h3 {
          font-family: Georgia, "Times New Roman", serif;
          color: #13332A;
          line-height: 1.25;
          font-weight: 600;
        }
        h1 { font-size: 27px; margin: 26px 0 12px; }
        h2 { font-size: 22px; margin: 22px 0 10px; }
        h3 { font-size: 19px; margin: 18px 0 8px; }
        p { margin: 0 0 14px; }
        ul, ol { margin: 0 0 14px; padding-left: 22px; }
        li { margin: 4px 0; }
        blockquote {
          margin: 14px 0;
          padding: 10px 16px;
          border-left: 3px solid #C28D3E;
          background: rgba(194, 141, 62, 0.08);
          color: #5B5244;
          font-style: italic;
        }
        a { color: #5D86B3; overflow-wrap: anywhere; }
        table {
          border-collapse: collapse;
          width: 100%;
          font-size: 13px;
          margin: 14px 0;
          background: #FAF8F5;
          border-radius: 8px;
          overflow: hidden;
          box-shadow: inset 0 0 0 1px #E5DEC9;
        }
        th, td {
          border: 1px solid #E5DEC9;
          padding: 10px 12px;
          text-align: left;
          vertical-align: middle;
        }
        th {
          white-space: nowrap;
          background: #EFEAD9;
          font-weight: 600;
          color: #13332A;
        }
        tr:nth-child(even) td { background: #F5F0E1; }
        tr:nth-child(odd) td { background: #FAF7EE; }
        .table-wrap {
          width: 100%;
          overflow-x: auto;
          -webkit-overflow-scrolling: touch;
          margin-bottom: 16px;
        }
        .page-divider {
          margin: 4px 0 8px;
          font-size: 17px;
          font-weight: 700;
          color: #5B5244;
        }
        .slide-divider {
          margin: 22px 0 16px;
          padding: 8px 0;
          font-size: 12px;
          font-weight: 700;
          letter-spacing: 1.2px;
          text-transform: uppercase;
          color: #8F8570;
          border-top: 2px solid #D6C29C;
          text-align: center;
          background: transparent;
        }
        .pdf-page + .pdf-page { margin-top: 24px; }
        .folio-evidence-highlight {
          background-color: #FFF3B0 !important;
          transition: background-color 1.6s ease;
        }
        """
    }
}

