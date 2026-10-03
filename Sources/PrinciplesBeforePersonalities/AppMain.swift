import SwiftUI
import UniformTypeIdentifiers

@main
struct PrinciplesApp: App {
    @StateObject private var model = LibraryModel()

    var body: some Scene {
        WindowGroup {
            ReaderScreen(model: model)
        }
        .defaultSize(width: 1180, height: 800)
        .commands {
            CommandMenu("Book") {
                Button("Previous Page") { model.go(delta: -1) }
                    .keyboardShortcut(.leftArrow, modifiers: [.command])
                Button("Next Page") { model.go(delta: 1) }
                    .keyboardShortcut(.rightArrow, modifiers: [.command])
                Button("Mark This Page") { model.toggleRibbon() }
                    .keyboardShortcut("m", modifiers: [.command])
                Button("Find Next") { model.jumpToSearch(delta: 1) }
                    .keyboardShortcut("g", modifiers: [.command])
                Divider()
                Button("Import a Text…") { model.showImporter = true }
                    .keyboardShortcut("o", modifiers: [.command])
            }
        }
    }
}

struct ReaderScreen: View {
    @ObservedObject var model: LibraryModel
    @State private var pageJump = ""
    @State private var chapterFilter = ""
    @State private var openBooks: Set<String> = []
    @State private var marksOpen = false
    @State private var prepared = false

    private let navy = Color(red: 0.045, green: 0.07, blue: 0.11)
    private let panel = Color(red: 0.07, green: 0.10, blue: 0.15)
    private let paper = Color(red: 0.972, green: 0.955, blue: 0.915)
    private let hairline = Color.white.opacity(0.08)
    private let accent = Color(red: 0.45, green: 0.86, blue: 0.95)

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            reader
        }
        .background(navy)
        .preferredColorScheme(.dark)
        .fileImporter(isPresented: $model.showImporter, allowedContentTypes: importTypes, allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                model.importFile(url)
            }
        }
        .onAppear(perform: prepare)
        .onChange(of: model.place.bookId) { _, id in
            openBooks.insert(id)
        }
        .onChange(of: model.place.pageId) { _, _ in
            pageJump = model.currentPage?.numberLabel ?? ""
        }
    }

    private var importTypes: [UTType] {
        [.plainText, .utf8PlainText, UTType(filenameExtension: "md") ?? .plainText]
    }

    private func prepare() {
        pageJump = model.currentPage?.numberLabel ?? ""
        guard !prepared else { return }
        prepared = true
        if let id = model.currentBook?.id {
            openBooks.insert(id)
        }
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            sidebarHeader
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(model.books) { book in
                            bookSection(book)
                        }
                        if !model.ribbons.isEmpty {
                            marksSection
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                }
                .onChange(of: model.currentChapter?.id) { _, id in
                    guard let id, let bookID = model.currentBook?.id else { return }
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("\(bookID)/\(id)", anchor: .center)
                    }
                }
            }
            sidebarFooter
        }
        .frame(width: 268)
        .background(panel)
        .overlay(alignment: .trailing) { Rectangle().fill(hairline).frame(width: 1) }
    }

    private var sidebarHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Library")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.4))
                TextField("Find a chapter", text: $chapterFilter)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
        }
        .padding(.horizontal, 14)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    private func bookSection(_ book: Book) -> some View {
        let groups = filteredGroups(book)
        let expanded = chapterFilter.isEmpty ? openBooks.contains(book.id) : !groups.isEmpty
        let isCurrent = model.place.bookId == book.id
        return VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 6) {
                Button {
                    toggleBook(book.id)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                        .foregroundStyle(.white.opacity(0.45))
                        .frame(width: 18, height: 28)
                }
                .buttonStyle(.plain)
                Button {
                    openBooks.insert(book.id)
                    if let page = book.chapters.first?.pages.first {
                        model.open(book: book, page: page)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(book.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(isCurrent ? .white : .white.opacity(0.82))
                            .lineLimit(1)
                        Text(book.subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.42))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, 2)
            .padding(.vertical, 2)

            if expanded {
                ForEach(groups, id: \.0) { part, chapters in
                    if groups.count > 1 {
                        Text(part)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.35))
                            .padding(.leading, 28)
                            .padding(.top, 6)
                            .padding(.bottom, 2)
                    }
                    ForEach(chapters) { chapter in
                        chapterRow(book, chapter)
                            .id("\(book.id)/\(chapter.id)")
                    }
                }
            }
        }
        .padding(.bottom, 6)
    }

    private func chapterRow(_ book: Book, _ chapter: Chapter) -> some View {
        let selected = model.currentChapter?.id == chapter.id && model.place.bookId == book.id
        let marked = chapterIsMarked(book, chapter)
        return Button {
            openBooks.insert(book.id)
            if let page = chapter.pages.first {
                model.open(book: book, page: page)
            }
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(marked ? (Pen(rawValue: markColor(book, chapter))?.color ?? accent) : Color.clear)
                    .frame(width: 6, height: 6)
                Text(chapter.title)
                    .font(.system(size: 13, weight: selected ? .medium : .regular))
                    .foregroundStyle(selected ? .white : .white.opacity(0.78))
                    .lineLimit(1)
                Spacer(minLength: 4)
                if chapterHasNote(book, chapter) {
                    Image(systemName: "note.text")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.4))
                }
                if chapter.part == "The Book", let label = chapter.pages.first?.numberLabel {
                    Text(label)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(selected ? accent : .white.opacity(0.32))
                }
            }
            .padding(.leading, 22)
            .padding(.trailing, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(selected ? Color.white.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private var marksSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Button {
                withAnimation(.easeOut(duration: 0.16)) { marksOpen.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .rotationEffect(.degrees(marksOpen ? 90 : 0))
                        .foregroundStyle(.white.opacity(0.45))
                        .frame(width: 18)
                    Text("Marked pages")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text("\(model.ribbons.count)")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .foregroundStyle(.white.opacity(0.85))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)

            if marksOpen {
                ForEach(model.ribbons) { ribbon in
                    if let located = locate(ribbon) {
                        Button {
                            model.open(book: located.book, page: located.page)
                        } label: {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Pen(rawValue: ribbon.color)?.color ?? .yellow)
                                    .frame(width: 6, height: 6)
                                Text(located.chapter.title)
                                    .lineLimit(1)
                                Spacer()
                                Text(located.page.numberLabel)
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.leading, 24)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var sidebarFooter: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                model.showImporter = true
            } label: {
                Label("Import a text", systemImage: "plus")
                    .font(.system(size: 12, weight: .medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.75))
            if !model.status.isEmpty {
                Text(model.status)
                    .font(.system(size: 11))
                    .foregroundStyle(accent.opacity(0.9))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { Rectangle().fill(hairline).frame(height: 1) }
    }

    // MARK: Reader

    private var reader: some View {
        VStack(spacing: 0) {
            toolbar
            paperWell
            navigationBar
        }
    }

    private var toolbar: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 1) {
                Text(model.currentChapter?.title ?? "Principles Before Personalities")
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(whereLine)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(1)
            }
            Spacer(minLength: 12)
            penTray
            toolCapsule
            markButton
            noteButton
            searchField
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(panel.opacity(0.96))
        .overlay(alignment: .bottom) { Rectangle().fill(hairline).frame(height: 1) }
    }

    private var whereLine: String {
        let book = model.currentBook?.title ?? ""
        guard model.currentChapter?.part == "The Book", let page = model.currentPage?.numberLabel else {
            return book
        }
        return "\(book)  ·  page \(page)"
    }

    private var penTray: some View {
        HStack(spacing: 8) {
            ForEach(Pen.allCases) { pen in
                Button {
                    model.chooseColor(pen)
                } label: {
                    Circle()
                        .fill(pen.color)
                        .frame(width: 14, height: 14)
                        .padding(4)
                        .background(
                            Circle().strokeBorder(model.pen == pen ? Color.white.opacity(0.9) : Color.clear, lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
                .help("Highlight the selection in \(pen.rawValue)")
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color.white.opacity(0.05)))
    }

    private var toolCapsule: some View {
        HStack(spacing: 0) {
            toolButton("character.cursor.ibeam", tool: .select, help: "Select text")
            Button {
                model.eraseSelection()
            } label: {
                Image(systemName: "eraser")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 28, height: 22)
                    .foregroundStyle(model.tool == .eraser ? accent : .white.opacity(0.62))
                    .background(
                        Capsule().fill(model.tool == .eraser ? Color.white.opacity(0.1) : Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .help("Erase the highlight on the selection")
        }
        .padding(3)
        .background(Capsule().fill(Color.white.opacity(0.05)))
    }

    private func toolButton(_ symbol: String, tool: ReadingTool, help: String) -> some View {
        Button {
            model.tool = tool
            model.save()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 28, height: 22)
                .foregroundStyle(model.tool == tool ? accent : .white.opacity(0.62))
                .background(
                    Capsule().fill(model.tool == tool ? Color.white.opacity(0.1) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var markButton: some View {
        Button(action: model.toggleRibbon) {
            Image(systemName: model.currentRibbon == nil ? "bookmark" : "bookmark.fill")
                .font(.system(size: 13))
                .foregroundStyle(model.currentRibbon.flatMap { Pen(rawValue: $0.color)?.color } ?? .white.opacity(0.75))
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.white.opacity(0.05)))
        }
        .buttonStyle(.plain)
        .help("Mark this page")
    }

    private var noteButton: some View {
        Button(action: model.addNote) {
            StickyButtonIcon()
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.white.opacity(0.05)))
        }
        .buttonStyle(.plain)
        .help("Add a sticky note to this page")
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.4))
            TextField("Find in book", text: $model.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .frame(width: 128)
                .onSubmit { model.jumpToSearch(delta: 1) }
            if !model.searchText.isEmpty {
                Text(model.searchHits.isEmpty ? "0" : "\(min(model.searchHit + 1, model.searchHits.count))")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                Button { model.jumpToSearch(delta: -1) } label: { Image(systemName: "chevron.up") }
                    .buttonStyle(.plain)
                Button { model.jumpToSearch(delta: 1) } label: { Image(systemName: "chevron.down") }
                    .buttonStyle(.plain)
            }
        }
        .foregroundStyle(.white.opacity(0.75))
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.white.opacity(0.05)))
    }

    private var paperWell: some View {
        ZStack {
            paperSheet
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(navy)
    }

    private var paperSheet: some View {
        let page = model.currentPage
        return ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(paper)
                .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
            if let page {
                PageCanvas(
                    pageID: page.id,
                    text: page.plain,
                    highlights: model.pageHighlights,
                    find: currentFind,
                    tool: model.tool,
                    pen: model.pen,
                    onPaint: { model.paint(range: $0) },
                    onTurn: { model.go(delta: $0) },
                    onSelection: { pageID, range in
                        model.reportSelection(pageID: pageID, range: range)
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                NoteLayer(
                    notes: model.pageNotes,
                    onUpdate: { model.updateNote($0) },
                    onDelete: { model.deleteNote($0) }
                )
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            if let ribbon = model.currentRibbon {
                ribbonTab(Pen(rawValue: ribbon.color)?.color ?? .yellow)
            }
        }
        .padding(.horizontal, 72)
        .padding(.vertical, 32)
        .frame(maxWidth: 820)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func ribbonTab(_ color: Color) -> some View {
        VStack(spacing: 0) {
            Rectangle().fill(color).frame(width: 14, height: 42)
            RibbonPoint().fill(color).frame(width: 14, height: 9)
        }
        .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
        .padding(.top, 16)
        .padding(.trailing, 28)
        .allowsHitTesting(false)
    }

    private var navigationBar: some View {
        ZStack {
            HStack {
                chapterJump(-1)
                Spacer()
                chapterJump(1)
            }
            HStack(spacing: 10) {
                Button { model.go(delta: -1) } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 28, height: 28)
                }
                .disabled(model.currentIndex == 0)
                .buttonStyle(.plain)

                HStack(spacing: 6) {
                    Text("Page")
                        .foregroundStyle(.white.opacity(0.45))
                    TextField("1", text: $pageJump)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.center)
                        .frame(width: 44)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))
                        .onSubmit { model.jumpToBookPage(pageJump) }
                }
                .font(.system(size: 13))

                Button { model.go(delta: 1) } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 28, height: 28)
                }
                .disabled(model.flatPages.isEmpty || model.currentIndex >= model.flatPages.count - 1)
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(.white.opacity(0.88))
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(panel)
        .overlay(alignment: .top) { Rectangle().fill(hairline).frame(height: 1) }
    }

    private func chapterJump(_ delta: Int) -> some View {
        let neighbor = chapter(offset: delta)
        return Button {
            guard let book = model.currentBook, let neighbor, let page = neighbor.pages.first else { return }
            openBooks.insert(book.id)
            model.open(book: book, page: page)
        } label: {
            HStack(spacing: 4) {
                if delta < 0 { Image(systemName: "chevron.left").font(.system(size: 10, weight: .semibold)) }
                Text(neighbor?.title ?? (delta < 0 ? "Start" : "End"))
                    .lineLimit(1)
                if delta > 0 { Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)) }
            }
            .font(.system(size: 12))
            .foregroundStyle(neighbor == nil ? .white.opacity(0.25) : .white.opacity(0.7))
            .frame(maxWidth: 220, alignment: delta < 0 ? .leading : .trailing)
        }
        .buttonStyle(.plain)
        .disabled(neighbor == nil)
    }

    // MARK: Helpers

    private func toggleBook(_ id: String) {
        withAnimation(.easeOut(duration: 0.16)) {
            if openBooks.contains(id) {
                openBooks.remove(id)
            } else {
                openBooks.insert(id)
            }
        }
    }

    private func filteredGroups(_ book: Book) -> [(String, [Chapter])] {
        let query = chapterFilter.trimmingCharacters(in: .whitespacesAndNewlines)
        return grouped(book).compactMap { part, chapters in
            let kept = query.isEmpty ? chapters : chapters.filter { $0.title.localizedCaseInsensitiveContains(query) }
            return kept.isEmpty ? nil : (part, kept)
        }
    }

    private func grouped(_ book: Book) -> [(String, [Chapter])] {
        var order: [String] = []
        var map: [String: [Chapter]] = [:]
        for chapter in book.chapters {
            if map[chapter.part] == nil { order.append(chapter.part) }
            map[chapter.part, default: []].append(chapter)
        }
        return order.map { ($0, map[$0] ?? []) }
    }

    private func chapter(offset: Int) -> Chapter? {
        guard let book = model.currentBook, let current = model.currentChapter,
              let index = book.chapters.firstIndex(where: { $0.id == current.id }) else { return nil }
        let next = index + offset
        guard book.chapters.indices.contains(next) else { return nil }
        return book.chapters[next]
    }

    private func chapterHasNote(_ book: Book, _ chapter: Chapter) -> Bool {
        let ids = Set(chapter.pages.map(\.id))
        return model.notes.contains { $0.bookId == book.id && ids.contains($0.pageId) }
    }

    private func chapterIsMarked(_ book: Book, _ chapter: Chapter) -> Bool {
        let ids = Set(chapter.pages.map(\.id))
        return model.ribbons.contains { $0.bookId == book.id && ids.contains($0.pageId) }
    }

    private func markColor(_ book: Book, _ chapter: Chapter) -> String {
        let ids = Set(chapter.pages.map(\.id))
        return model.ribbons.first { $0.bookId == book.id && ids.contains($0.pageId) }?.color ?? Pen.yellow.rawValue
    }

    private func locate(_ ribbon: PageRibbon) -> (book: Book, chapter: Chapter, page: BookPage)? {
        for book in model.books where book.id == ribbon.bookId {
            for chapter in book.chapters {
                if let page = chapter.pages.first(where: { $0.id == ribbon.pageId }) {
                    return (book, chapter, page)
                }
            }
        }
        return nil
    }

    private var currentFind: NSRange? {
        let hits = model.searchHits
        guard !hits.isEmpty, model.searchHit < hits.count else { return nil }
        let hit = hits[model.searchHit]
        guard hit.page.id == model.place.pageId else { return nil }
        let needle = model.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let hay = hit.page.plain as NSString
        let range = hay.range(
            of: needle,
            options: [.caseInsensitive],
            range: NSRange(location: hit.location, length: hay.length - hit.location)
        )
        return range.location == NSNotFound ? nil : range
    }
}

struct RibbonPoint: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
