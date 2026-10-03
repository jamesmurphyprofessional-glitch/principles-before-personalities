import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct LibraryFile: Codable {
    var books: [Book]
}

struct Book: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var subtitle: String
    var note: String
    var chapters: [Chapter]
}

struct Chapter: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var part: String
    var pages: [BookPage]
}

struct BookPage: Codable, Identifiable, Hashable {
    var id: String
    var numberLabel: String
    var paragraphs: [String]

    var plain: String {
        paragraphs.joined(separator: "\n\n")
    }
}

struct HighlightMark: Codable, Identifiable, Hashable {
    var id: UUID
    var bookId: String
    var pageId: String
    var start: Int
    var end: Int
    var color: String
}

struct PageRibbon: Codable, Identifiable, Hashable {
    var id: UUID
    var bookId: String
    var pageId: String
    var color: String
}

struct StickyNote: Codable, Identifiable, Equatable {
    var id: UUID
    var bookId: String
    var pageId: String
    var text: String
    var color: String
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var z: Int
}

struct TextSelection: Equatable {
    var bookId: String
    var pageId: String
    var range: NSRange
}

struct ReadingPlace: Codable, Hashable {
    var bookId: String
    var pageId: String
}

enum Pen: String, CaseIterable, Identifiable, Codable {
    case yellow, amber, pink, green, blue

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .yellow: Color(red: 0.98, green: 0.86, blue: 0.35)
        case .amber: Color(red: 0.96, green: 0.68, blue: 0.32)
        case .pink: Color(red: 0.96, green: 0.55, blue: 0.70)
        case .green: Color(red: 0.55, green: 0.82, blue: 0.52)
        case .blue: Color(red: 0.45, green: 0.74, blue: 0.98)
        }
    }

    var ink: NSColor {
        switch self {
        case .yellow: NSColor(calibratedRed: 0.99, green: 0.88, blue: 0.28, alpha: 0.72)
        case .amber: NSColor(calibratedRed: 0.98, green: 0.70, blue: 0.28, alpha: 0.70)
        case .pink: NSColor(calibratedRed: 0.98, green: 0.55, blue: 0.72, alpha: 0.62)
        case .green: NSColor(calibratedRed: 0.55, green: 0.84, blue: 0.48, alpha: 0.62)
        case .blue: NSColor(calibratedRed: 0.45, green: 0.75, blue: 1.0, alpha: 0.58)
        }
    }
}

enum ReadingTool: String, Codable {
    case marker
    case select
    case eraser
}

private struct SavedState: Codable {
    var highlights: [HighlightMark]
    var ribbons: [PageRibbon]
    var place: ReadingPlace?
    var userBooks: [Book]
    var pen: Pen
    var tool: ReadingTool
    var notes: [StickyNote]

    init(
        highlights: [HighlightMark],
        ribbons: [PageRibbon],
        place: ReadingPlace?,
        userBooks: [Book],
        pen: Pen,
        tool: ReadingTool,
        notes: [StickyNote]
    ) {
        self.highlights = highlights
        self.ribbons = ribbons
        self.place = place
        self.userBooks = userBooks
        self.pen = pen
        self.tool = tool
        self.notes = notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        highlights = try container.decodeIfPresent([HighlightMark].self, forKey: .highlights) ?? []
        ribbons = try container.decodeIfPresent([PageRibbon].self, forKey: .ribbons) ?? []
        place = try container.decodeIfPresent(ReadingPlace.self, forKey: .place)
        userBooks = try container.decodeIfPresent([Book].self, forKey: .userBooks) ?? []
        pen = try container.decodeIfPresent(Pen.self, forKey: .pen) ?? .yellow
        tool = try container.decodeIfPresent(ReadingTool.self, forKey: .tool) ?? .select
        notes = try container.decodeIfPresent([StickyNote].self, forKey: .notes) ?? []
    }
}

@MainActor
final class LibraryModel: ObservableObject {
    @Published var books: [Book] = []
    @Published var place: ReadingPlace
    @Published var highlights: [HighlightMark] = []
    @Published var ribbons: [PageRibbon] = []
    @Published var notes: [StickyNote] = []
    @Published var pen: Pen = .yellow
    @Published var tool: ReadingTool = .select
    @Published var searchText = ""
    @Published var searchHit = 0
    @Published var showImporter = false
    @Published var status = ""
    var pendingSelection: TextSelection?

    private let supportURL: URL
    private let stateURL: URL
    private var bundled: [Book] = []

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Principles Before Personalities", isDirectory: true)
        supportURL = base
        stateURL = base.appendingPathComponent("library-state.json")
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        bundled = Self.loadBundled()
        let saved = Self.loadState(from: stateURL)
        highlights = saved?.highlights ?? []
        ribbons = saved?.ribbons ?? []
        notes = saved?.notes ?? []
        pen = saved?.pen ?? .yellow
        tool = saved?.tool ?? .select
        let loaded = bundled + (saved?.userBooks ?? [])
        books = loaded
        if let savedPlace = saved?.place, Self.contains(savedPlace, in: loaded) {
            place = savedPlace
        } else if let first = loaded.first, let page = first.chapters.first?.pages.first {
            place = ReadingPlace(bookId: first.id, pageId: page.id)
        } else {
            place = ReadingPlace(bookId: "", pageId: "")
        }
    }

    var currentBook: Book? { books.first { $0.id == place.bookId } }

    var flatPages: [(chapter: Chapter, page: BookPage)] {
        currentBook?.chapters.flatMap { chapter in
            chapter.pages.map { (chapter, $0) }
        } ?? []
    }

    var currentIndex: Int {
        flatPages.firstIndex { $0.page.id == place.pageId } ?? 0
    }

    var currentChapter: Chapter? { flatPages.isEmpty ? nil : flatPages[currentIndex].chapter }
    var currentPage: BookPage? { flatPages.isEmpty ? nil : flatPages[currentIndex].page }

    var pageHighlights: [HighlightMark] {
        guard let page = currentPage else { return [] }
        return highlights
            .filter { $0.bookId == place.bookId && $0.pageId == page.id }
            .sorted { $0.start < $1.start }
    }

    var currentRibbon: PageRibbon? {
        ribbons.first { $0.bookId == place.bookId && $0.pageId == place.pageId }
    }

    var pageNotes: [StickyNote] {
        notes
            .filter { $0.bookId == place.bookId && $0.pageId == place.pageId }
            .sorted { $0.z < $1.z }
    }

    var searchHits: [(chapter: Chapter, page: BookPage, location: Int)] {
        let needle = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard needle.count >= 2, let book = currentBook else { return [] }
        var hits: [(Chapter, BookPage, Int)] = []
        for chapter in book.chapters {
            for page in chapter.pages {
                let hay = page.plain as NSString
                var start = 0
                while start < hay.length {
                    let found = hay.range(
                        of: needle,
                        options: [.caseInsensitive],
                        range: NSRange(location: start, length: hay.length - start)
                    )
                    if found.location == NSNotFound { break }
                    hits.append((chapter, page, found.location))
                    start = found.location + max(found.length, 1)
                    if hits.count > 400 { return hits }
                }
            }
        }
        return hits
    }

    func open(book: Book, page: BookPage) {
        pendingSelection = nil
        place = ReadingPlace(bookId: book.id, pageId: page.id)
        save()
    }

    func openChapter(_ chapter: Chapter) {
        guard let page = chapter.pages.first, let book = currentBook else { return }
        open(book: book, page: page)
    }

    func go(delta: Int) {
        let pages = flatPages
        guard !pages.isEmpty else { return }
        let next = min(max(currentIndex + delta, 0), pages.count - 1)
        pendingSelection = nil
        place = ReadingPlace(bookId: place.bookId, pageId: pages[next].page.id)
        save()
    }

    func jumpToBookPage(_ label: String) {
        let trimmed = label.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if let match = flatPages.first(where: { $0.page.numberLabel == trimmed && $0.chapter.part == "The Book" })
            ?? flatPages.first(where: { $0.page.numberLabel == trimmed }) {
            pendingSelection = nil
            place = ReadingPlace(bookId: place.bookId, pageId: match.page.id)
            save()
        }
    }

    func reportSelection(pageID: String, range: NSRange) {
        guard pageID == currentPage?.id else { return }
        if range.length == 0 {
            pendingSelection = nil
        } else {
            pendingSelection = TextSelection(bookId: place.bookId, pageId: pageID, range: range)
            status = ""
        }
    }

    func chooseColor(_ chosen: Pen) {
        pen = chosen
        tool = .marker
        guard let selection = pendingSelection,
              selection.bookId == place.bookId,
              selection.pageId == currentPage?.id,
              selection.range.length > 0 else {
            status = "Select some text, then pick a color."
            save()
            return
        }
        status = ""
        applyHighlight(selection.range, color: chosen)
    }

    func eraseSelection() {
        tool = .eraser
        guard let selection = pendingSelection,
              selection.bookId == place.bookId,
              selection.pageId == currentPage?.id,
              selection.range.length > 0 else {
            save()
            return
        }
        erase(selection.range)
    }

    func paint(range: NSRange) {
        guard range.length > 0 else { return }
        if tool == .eraser {
            erase(range)
        } else {
            applyHighlight(range, color: pen)
        }
    }

    func addNote() {
        guard currentPage != nil else { return }
        let count = pageNotes.count
        let note = StickyNote(
            id: UUID(),
            bookId: place.bookId,
            pageId: place.pageId,
            text: "",
            color: pen.rawValue,
            x: min(0.78, 0.56 + Double(count % 3) * 0.06),
            y: min(0.7, 0.28 + Double(count % 4) * 0.08),
            width: 210,
            height: 160,
            z: (notes.map(\.z).max() ?? 0) + 1
        )
        notes.append(note)
        save()
    }

    func updateNote(_ note: StickyNote) {
        guard let index = notes.firstIndex(where: { $0.id == note.id }) else { return }
        notes[index] = note
        save()
    }

    func deleteNote(_ id: UUID) {
        notes.removeAll { $0.id == id }
        save()
    }

    private func applyHighlight(_ range: NSRange, color: Pen) {
        guard let page = currentPage, range.length > 0 else { return }
        let cut = range.location..<(range.location + range.length)
        var kept: [HighlightMark] = []
        for mark in highlights {
            if mark.bookId == place.bookId && mark.pageId == page.id {
                kept.append(contentsOf: subtract(mark, cut))
            } else {
                kept.append(mark)
            }
        }
        kept.append(HighlightMark(
            id: UUID(),
            bookId: place.bookId,
            pageId: page.id,
            start: cut.lowerBound,
            end: cut.upperBound,
            color: color.rawValue
        ))
        highlights = kept
        save()
    }

    private func erase(_ range: NSRange) {
        guard let page = currentPage, range.length > 0 else { return }
        let cut = range.location..<(range.location + range.length)
        highlights = highlights.flatMap { mark -> [HighlightMark] in
            guard mark.bookId == place.bookId, mark.pageId == page.id else { return [mark] }
            return subtract(mark, cut)
        }
        save()
    }

    func toggleRibbon() {
        guard currentPage != nil else { return }
        if let existing = currentRibbon {
            if existing.color == pen.rawValue {
                ribbons.removeAll { $0.id == existing.id }
            } else {
                ribbons.removeAll { $0.id == existing.id }
                ribbons.append(PageRibbon(id: UUID(), bookId: place.bookId, pageId: place.pageId, color: pen.rawValue))
            }
        } else {
            ribbons.append(PageRibbon(id: UUID(), bookId: place.bookId, pageId: place.pageId, color: pen.rawValue))
        }
        save()
    }

    func jumpToSearch(delta: Int) {
        let hits = searchHits
        guard !hits.isEmpty else { return }
        searchHit = (searchHit + delta + hits.count) % hits.count
        let hit = hits[searchHit]
        pendingSelection = nil
        place = ReadingPlace(bookId: place.bookId, pageId: hit.page.id)
        save()
    }

    func importFile(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard let text = Self.readText(url) else {
            status = "Could not read that file."
            return
        }
        let title = url.deletingPathExtension().lastPathComponent
        let book = Self.book(from: text, title: title)
        books.append(book)
        if let page = book.chapters.first?.pages.first {
            place = ReadingPlace(bookId: book.id, pageId: page.id)
        }
        status = "Imported \(title)."
        save()
    }

    func save() {
        let userBooks = books.filter { book in !bundled.contains { $0.id == book.id } }
        let state = SavedState(
            highlights: highlights,
            ribbons: ribbons,
            place: place,
            userBooks: userBooks,
            pen: pen,
            tool: tool,
            notes: notes
        )
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: stateURL, options: .atomic)
    }

    private func subtract(_ mark: HighlightMark, _ cut: Range<Int>) -> [HighlightMark] {
        let span = mark.start..<mark.end
        guard span.overlaps(cut) else { return [mark] }
        var pieces: [HighlightMark] = []
        if span.lowerBound < cut.lowerBound {
            pieces.append(HighlightMark(id: UUID(), bookId: mark.bookId, pageId: mark.pageId, start: span.lowerBound, end: cut.lowerBound, color: mark.color))
        }
        if cut.upperBound < span.upperBound {
            pieces.append(HighlightMark(id: UUID(), bookId: mark.bookId, pageId: mark.pageId, start: cut.upperBound, end: span.upperBound, color: mark.color))
        }
        return pieces
    }

    private static func contains(_ place: ReadingPlace, in books: [Book]) -> Bool {
        books.contains { book in
            book.id == place.bookId && book.chapters.contains { $0.pages.contains { $0.id == place.pageId } }
        }
    }

    private static func loadBundled() -> [Book] {
        let candidates = [
            Bundle.main.url(forResource: "library", withExtension: "json"),
            Bundle.main.resourceURL?.appendingPathComponent("library.json"),
            Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/library.json")
        ]
        for case let url? in candidates {
            if let data = try? Data(contentsOf: url),
               let file = try? JSONDecoder().decode(LibraryFile.self, from: data) {
                return file.books
            }
        }
        return []
    }

    private static func loadState(from url: URL) -> SavedState? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(SavedState.self, from: data)
    }

    private static func readText(_ url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        if let text = String(data: data, encoding: .utf8) { return text }
        return String(data: data, encoding: .utf16)
    }

    private static func book(from text: String, title: String) -> Book {
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        var chapters: [(String, [String])] = []
        var name = "Text"
        var buffer: [String] = []
        func flush() {
            let body = buffer.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            buffer.removeAll()
            guard !body.isEmpty else { return }
            let paragraphs = body.components(separatedBy: "\n\n").map {
                $0.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
            }.filter { !$0.isEmpty }
            chapters.append((name, paragraphs))
        }
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if isHeading(trimmed) {
                flush()
                name = trimmed.replacingOccurrences(of: "^#+\\s*", with: "", options: .regularExpression)
                continue
            }
            buffer.append(line)
        }
        flush()
        if chapters.isEmpty {
            chapters = [(title, [text])]
        }
        let bookId = "user-" + UUID().uuidString.lowercased()
        let built = chapters.enumerated().map { index, item in
            let pages = chunk(item.1).enumerated().map { pageIndex, paragraphs in
                BookPage(id: "\(bookId)-\(index)-\(pageIndex)", numberLabel: "\(pageIndex + 1)", paragraphs: paragraphs)
            }
            return Chapter(id: "\(bookId)-c\(index)", title: item.0, part: "Imported", pages: pages)
        }
        return Book(
            id: bookId,
            title: title,
            subtitle: "Imported text",
            note: "A text you imported. Highlights and page markers stay on this Mac.",
            chapters: built
        )
    }

    private static func isHeading(_ line: String) -> Bool {
        if line.hasPrefix("#") && line.count < 80 { return true }
        let letters = line.filter(\.isLetter)
        guard letters.count >= 4, line.count <= 70, !line.hasSuffix(".") else { return false }
        return letters.allSatisfy(\.isUppercase)
    }

    private static func chunk(_ paragraphs: [String]) -> [[String]] {
        var pages: [[String]] = []
        var current: [String] = []
        var words = 0
        for paragraph in paragraphs {
            let count = paragraph.split(separator: " ").count
            if !current.isEmpty && words + count > 230 && words > 80 {
                pages.append(current)
                current = [paragraph]
                words = count
            } else {
                current.append(paragraph)
                words += count
            }
        }
        if !current.isEmpty { pages.append(current) }
        return pages.isEmpty ? [[""]] : pages
    }
}
