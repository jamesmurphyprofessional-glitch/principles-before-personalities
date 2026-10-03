import AppKit
import SwiftUI

struct PageCanvas: NSViewRepresentable {
    var pageID: String
    var text: String
    var highlights: [HighlightMark]
    var find: NSRange?
    var tool: ReadingTool
    var pen: Pen
    var onPaint: (NSRange) -> Void
    var onTurn: (Int) -> Void
    var onSelection: (String, NSRange) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true

        let view = MarkerTextView()
        view.drawsBackground = false
        view.isEditable = false
        view.isSelectable = true
        view.isRichText = true
        view.allowsUndo = false
        view.isAutomaticLinkDetectionEnabled = false
        view.isAutomaticDataDetectionEnabled = false
        view.enabledTextCheckingTypes = 0
        view.textContainerInset = NSSize(width: 36, height: 28)
        view.isVerticallyResizable = true
        view.isHorizontallyResizable = false
        view.autoresizingMask = [.width]
        view.textContainer?.widthTracksTextView = true
        view.textContainer?.lineFragmentPadding = 8
        view.delegate = context.coordinator
        view.onPaint = { range in
            context.coordinator.parent.onPaint(range)
        }
        view.onTurn = { delta in
            context.coordinator.parent.onTurn(delta)
        }
        view.onSelection = { range in
            context.coordinator.parent.onSelection(context.coordinator.parent.pageID, range)
        }
        scroll.documentView = view
        context.coordinator.view = view
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let view = scroll.documentView as? MarkerTextView else { return }
        view.tool = tool
        view.onPaint = { context.coordinator.parent.onPaint($0) }
        view.onTurn = { context.coordinator.parent.onTurn($0) }
        view.onSelection = { context.coordinator.parent.onSelection(context.coordinator.parent.pageID, $0) }
        let token = renderToken
        if context.coordinator.token != token {
            context.coordinator.token = token
            view.textStorage?.setAttributedString(rendered())
        }
    }

    private var renderToken: String {
        let marks = highlights.map { "\($0.start):\($0.end):\($0.color)" }.joined(separator: "|")
        let found = find.map { "\($0.location):\($0.length)" } ?? ""
        return pageID + "#" + text + "#" + marks + "#" + found
    }

    private func rendered() -> NSAttributedString {
        let result = NSMutableAttributedString(string: text)
        let bodyFont = NSFont(name: "NewYork-Regular", size: 18) ?? NSFont(name: "Georgia", size: 17) ?? .systemFont(ofSize: 17)
        let headFont = NSFont(name: "NewYork-Semibold", size: 15) ?? NSFont.systemFont(ofSize: 15, weight: .semibold)
        let ink = NSColor(calibratedRed: 0.16, green: 0.13, blue: 0.10, alpha: 1)
        let head = NSColor(calibratedRed: 0.10, green: 0.16, blue: 0.28, alpha: 1)
        let paragraphs = text.components(separatedBy: "\n\n")
        var cursor = 0
        for (index, paragraph) in paragraphs.enumerated() {
            let length = (paragraph as NSString).length
            let heading = isHeading(paragraph)
            let style = NSMutableParagraphStyle()
            style.lineSpacing = heading ? 2 : 5
            style.paragraphSpacing = heading ? 8 : 12
            style.alignment = heading ? .center : .left
            style.hyphenationFactor = 0.4
            if length > 0, cursor + length <= (text as NSString).length {
                result.addAttributes([
                    .font: heading ? headFont : bodyFont,
                    .foregroundColor: heading ? head : ink,
                    .paragraphStyle: style,
                    .kern: heading ? 0.8 : 0.1
                ], range: NSRange(location: cursor, length: length))
            }
            cursor += length
            if index < paragraphs.count - 1 { cursor += 2 }
        }
        let full = text as NSString
        for mark in highlights where mark.end <= full.length && mark.start >= 0 && mark.start < mark.end {
            let color = Pen(rawValue: mark.color)?.ink ?? Pen.yellow.ink
            result.addAttribute(.backgroundColor, value: color, range: NSRange(location: mark.start, length: mark.end - mark.start))
        }
        if let find, find.location != NSNotFound, find.location + find.length <= full.length {
            result.addAttribute(
                .underlineStyle,
                value: NSUnderlineStyle.single.rawValue,
                range: find
            )
            result.addAttribute(
                .backgroundColor,
                value: NSColor(calibratedRed: 0.55, green: 0.86, blue: 0.95, alpha: 0.55),
                range: find
            )
        }
        return result
    }

    private func isHeading(_ paragraph: String) -> Bool {
        if paragraph.hasPrefix("Chapter ") && paragraph.count < 20 { return true }
        let letters = paragraph.filter(\.isLetter)
        return paragraph.count < 48 && letters.count > 2 && letters.allSatisfy(\.isUppercase)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: PageCanvas
        var token = ""
        weak var view: MarkerTextView?

        init(parent: PageCanvas) {
            self.parent = parent
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let view = notification.object as? NSTextView else { return }
            let range = view.selectedRange()
            if range.length > 0 {
                parent.onSelection(parent.pageID, range)
            }
        }
    }
}

final class MarkerTextView: NSTextView {
    var tool: ReadingTool = .select
    var onPaint: ((NSRange) -> Void)?
    var onTurn: ((Int) -> Void)?
    var onSelection: ((NSRange) -> Void)?

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        let range = selectedRange()
        onSelection?(range)
        if tool == .eraser, range.length > 0 {
            onPaint?(range)
        }
    }

    override func keyDown(with event: NSEvent) {
        let left = 123
        let right = 124
        if event.keyCode == left || event.keyCode == right, selectedRange().length == 0, tool == .marker {
            onTurn?(event.keyCode == right ? 1 : -1)
            return
        }
        super.keyDown(with: event)
    }
}
