import AppKit
import SwiftUI

struct NoteLayer: NSViewRepresentable {
    var notes: [StickyNote]
    var onUpdate: (StickyNote) -> Void
    var onDelete: (UUID) -> Void

    func makeNSView(context: Context) -> PassThroughView {
        let view = PassThroughView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ view: PassThroughView, context: Context) {
        context.coordinator.sync(notes: notes, in: view, onUpdate: onUpdate, onDelete: onDelete)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    final class Coordinator {
        var hosts: [UUID: NSHostingView<StickyCard>] = [:]
        var boxes: [UUID: NoteBox] = [:]

        func sync(notes: [StickyNote], in view: PassThroughView, onUpdate: @escaping (StickyNote) -> Void, onDelete: @escaping (UUID) -> Void) {
            let ids = Set(notes.map(\.id))
            for id in hosts.keys where !ids.contains(id) {
                hosts[id]?.removeFromSuperview()
                hosts[id] = nil
                boxes[id] = nil
            }
            let bounds = view.bounds
            guard bounds.width > 1, bounds.height > 1 else { return }
            for note in notes.sorted(by: { $0.z < $1.z }) {
                let box: NoteBox
                if let existing = boxes[note.id] {
                    box = existing
                    if existing.note != note {
                        existing.note = note
                    }
                } else {
                    box = NoteBox(note: note)
                    boxes[note.id] = box
                    let host = NSHostingView(rootView: StickyCard(box: box))
                    host.translatesAutoresizingMaskIntoConstraints = true
                    view.addSubview(host)
                    hosts[note.id] = host
                }
                box.onUpdate = onUpdate
                box.onDelete = onDelete
                box.paperSize = bounds.size
                let host = hosts[note.id]
                host?.frame = NSRect(
                    x: note.x * bounds.width - note.width / 2,
                    y: note.y * bounds.height - note.height / 2,
                    width: note.width,
                    height: note.height
                )
            }
        }
    }
}

final class PassThroughView: NSView {
    weak var coordinator: NoteLayer.Coordinator?

    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        return hit === self ? nil : hit
    }

    override func layout() {
        super.layout()
        guard let coordinator else { return }
        let bounds = self.bounds
        guard bounds.width > 1 else { return }
        for (id, host) in coordinator.hosts {
            guard let note = coordinator.boxes[id]?.note else { continue }
            coordinator.boxes[id]?.paperSize = bounds.size
            host.frame = NSRect(
                x: note.x * bounds.width - note.width / 2,
                y: note.y * bounds.height - note.height / 2,
                width: note.width,
                height: note.height
            )
        }
    }
}

@MainActor
final class NoteBox: ObservableObject {
    @Published var note: StickyNote
    var onUpdate: (StickyNote) -> Void = { _ in }
    var onDelete: (UUID) -> Void = { _ in }
    var paperSize: CGSize = CGSize(width: 1, height: 1)

    init(note: StickyNote) {
        self.note = note
    }
}

struct StickyCard: View {
    @ObservedObject var box: NoteBox
    @State private var draft: String

    init(box: NoteBox) {
        self.box = box
        _draft = State(initialValue: box.note.text)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ZStack(alignment: .topLeading) {
                if draft.isEmpty {
                    Text("Write a note…")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.black.opacity(0.32))
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $draft)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(red: 0.18, green: 0.14, blue: 0.08))
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(noteColor)
        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            resizeHandle
        }
        .shadow(color: .black.opacity(0.22), radius: 6, y: 3)
        .onChange(of: draft) { _, newValue in
            guard newValue != box.note.text else { return }
            var next = box.note
            next.text = newValue
            box.note = next
            box.onUpdate(next)
        }
    }

    private var header: some View {
        HStack(spacing: 4) {
            WindowDragHandle(onDown: bringForward) { dx, dy in
                move(dx: dx, dy: dy)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .help("Drag the note")
            HStack(spacing: 4) {
                ForEach(Pen.allCases) { pen in
                    Button {
                        var next = box.note
                        next.color = pen.rawValue
                        box.note = next
                        box.onUpdate(next)
                    } label: {
                        Circle()
                            .fill(pen.color)
                            .frame(width: 8, height: 8)
                            .overlay(Circle().strokeBorder(Color.black.opacity(box.note.color == pen.rawValue ? 0.45 : 0), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .help("Note color")
                }
                Button {
                    box.onDelete(box.note.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.45))
                        .frame(width: 14, height: 14)
                }
                .buttonStyle(.plain)
                .help("Remove note")
            }
            .padding(.horizontal, 6)
        }
        .frame(height: 22)
        .background(noteColor.opacity(0.85))
    }

    private var resizeHandle: some View {
        WindowDragHandle { dx, dy in
            var next = box.note
            next.width = min(360, max(150, next.width + dx))
            next.height = min(420, max(110, next.height + dy))
            box.note = next
            box.onUpdate(next)
        }
        .frame(width: 16, height: 16)
        .overlay {
            Image(systemName: "arrow.down.right")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(Color.black.opacity(0.35))
                .allowsHitTesting(false)
        }
        .help("Resize note")
    }

    private var noteColor: Color {
        switch Pen(rawValue: box.note.color) ?? .yellow {
        case .yellow: Color(red: 1.0, green: 0.94, blue: 0.55)
        case .amber: Color(red: 1.0, green: 0.80, blue: 0.45)
        case .pink: Color(red: 1.0, green: 0.75, blue: 0.82)
        case .green: Color(red: 0.74, green: 0.92, blue: 0.66)
        case .blue: Color(red: 0.70, green: 0.86, blue: 1.0)
        }
    }

    private func move(dx: CGFloat, dy: CGFloat) {
        let width = max(box.paperSize.width, 1)
        let height = max(box.paperSize.height, 1)
        var next = box.note
        next.x = min(0.92, max(0.08, next.x + dx / width))
        next.y = min(0.94, max(0.08, next.y + dy / height))
        box.note = next
        box.onUpdate(next)
    }

    private func bringForward() {
        var next = box.note
        next.z += 1
        box.note = next
        box.onUpdate(next)
    }
}

struct WindowDragHandle: NSViewRepresentable {
    var onDown: () -> Void = {}
    var onDelta: (CGFloat, CGFloat) -> Void

    func makeNSView(context: Context) -> DragStrip {
        let view = DragStrip()
        view.onDown = onDown
        view.onDelta = onDelta
        return view
    }

    func updateNSView(_ view: DragStrip, context: Context) {
        view.onDown = onDown
        view.onDelta = onDelta
    }
}

final class DragStrip: NSView {
    var onDown: (() -> Void)?
    var onDelta: ((CGFloat, CGFloat) -> Void)?
    private var last: NSPoint?

    override func mouseDown(with event: NSEvent) {
        last = event.locationInWindow
        onDown?()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let last else { return }
        let point = event.locationInWindow
        let dx = point.x - last.x
        let dy = last.y - point.y
        self.last = point
        onDelta?(dx, dy)
    }

    override func mouseUp(with event: NSEvent) {
        last = nil
    }
}

struct StickyButtonIcon: View {
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color(red: 1.0, green: 0.92, blue: 0.42))
            StickyFold()
                .fill(Color(red: 0.86, green: 0.72, blue: 0.18))
                .frame(width: 6, height: 6)
        }
        .frame(width: 15, height: 16)
        .shadow(color: .black.opacity(0.25), radius: 0.5, y: 0.5)
    }
}

struct StickyFold: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
