import XCTest
@testable import Folio

final class SourceDTOTests: XCTestCase {
    func testDecodeSourceListWithSheetStructuredContentWithoutHTML() throws {
        let json = """
        {
          "status": "success",
          "data": {
            "sources": [
              {
                "id": "57181ce6-bac7-4c7e-a6ce-1fab5b18b22b",
                "researchSpaceId": "135b9c01-0924-48fe-9f2f-6f8c83bce47b",
                "sourceType": "Manual",
                "title": "Summarize all the evidence.",
                "author": "AI-assisted note by Tony Nguyen",
                "sourceUrl": null,
                "fileName": null,
                "fileSize": null,
                "fileType": null,
                "pageCount": null,
                "characterCount": 1225,
                "content": "Test content",
                "structuredContent": {
                  "type": "document",
                  "html": "<p>Test html</p>"
                },
                "processingState": "ready",
                "processingError": null,
                "createdAt": "2026-08-31T04:32:16.851Z",
                "updatedAt": "2026-08-31T04:32:18.370Z"
              },
              {
                "id": "sheet-source-id",
                "researchSpaceId": "135b9c01-0924-48fe-9f2f-6f8c83bce47b",
                "sourceType": "File",
                "title": "file_example_XLSX_5000.xlsx",
                "author": "Tony Nguyen",
                "sourceUrl": null,
                "fileName": "file_example_XLSX_5000.xlsx",
                "fileSize": 188887,
                "fileType": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                "pageCount": null,
                "characterCount": null,
                "content": null,
                "structuredContent": {
                  "type": "sheets",
                  "sheets": [
                    {
                      "name": "Sheet1",
                      "rows": [["1", "Dulce"]]
                    }
                  ]
                },
                "processingState": "ready",
                "processingError": null,
                "createdAt": "2026-08-31T04:32:16.851Z",
                "updatedAt": "2026-08-31T04:32:18.370Z"
              }
            ]
          }
        }
        """

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            guard let date = formatter.date(from: dateString) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(dateString)")
            }
            return date
        }
        let data = json.data(using: .utf8)!
        let response = try decoder.decode(SourceListResponseDTO.self, from: data)
        let domain = response.toDomain()

        XCTAssertEqual(domain.sources.count, 2)
        XCTAssertEqual(domain.sources[0].structuredContent?.html, "<p>Test html</p>")
        XCTAssertEqual(domain.sources[1].structuredContent?.html, "")
        XCTAssertEqual(domain.sources[1].structuredContent?.type, "sheets")
    }
}
