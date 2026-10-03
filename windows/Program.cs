using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Web.Script.Serialization;
using System.Windows.Forms;

namespace PrinciplesBeforePersonalities
{
    public class Book
    {
        public string id;
        public string title;
        public string subtitle;
        public string note;
        public List<Chapter> chapters = new List<Chapter>();
    }

    public class Chapter
    {
        public string id;
        public string title;
        public string part;
        public List<BookPage> pages = new List<BookPage>();
    }

    public class BookPage
    {
        public string id;
        public string numberLabel;
        public List<string> paragraphs = new List<string>();

        public string Plain
        {
            get { return string.Join("\n\n", paragraphs ?? new List<string>()); }
        }
    }

    public class LibraryFile
    {
        public List<Book> books = new List<Book>();
    }

    public class HighlightMark
    {
        public string id;
        public string bookId;
        public string pageId;
        public int start;
        public int end;
        public string color;
    }

    public class PageRibbon
    {
        public string id;
        public string bookId;
        public string pageId;
        public string color;
    }

    public class StickyNote
    {
        public string id;
        public string bookId;
        public string pageId;
        public string text;
        public string color;
        public double x;
        public double y;
        public double width;
        public double height;
        public int z;
    }

    public class ReadingPlace
    {
        public string bookId;
        public string pageId;
    }

    public class SavedState
    {
        public List<HighlightMark> highlights = new List<HighlightMark>();
        public List<PageRibbon> ribbons = new List<PageRibbon>();
        public ReadingPlace place;
        public List<Book> userBooks = new List<Book>();
        public string pen = "yellow";
        public List<StickyNote> notes = new List<StickyNote>();
    }

    public static class Pens
    {
        public static readonly string[] Names = { "yellow", "amber", "pink", "green", "blue" };

        public static Color Ink(string name)
        {
            switch (name)
            {
                case "amber": return Color.FromArgb(255, 196, 110);
                case "pink": return Color.FromArgb(255, 176, 204);
                case "green": return Color.FromArgb(168, 224, 160);
                case "blue": return Color.FromArgb(160, 206, 255);
                default: return Color.FromArgb(255, 244, 140);
            }
        }

        public static Color Note(string name)
        {
            switch (name)
            {
                case "amber": return Color.FromArgb(255, 214, 140);
                case "pink": return Color.FromArgb(255, 196, 214);
                case "green": return Color.FromArgb(196, 232, 176);
                case "blue": return Color.FromArgb(186, 220, 255);
                default: return Color.FromArgb(255, 242, 150);
            }
        }
    }

    public class ReaderForm : Form
    {
        static readonly Color Navy = Color.FromArgb(12, 18, 28);
        static readonly Color Panel = Color.FromArgb(18, 26, 38);
        static readonly Color Paper = Color.FromArgb(248, 243, 232);
        static readonly Color Ink = Color.FromArgb(42, 34, 26);
        static readonly Color Accent = Color.FromArgb(115, 220, 242);

        readonly string libraryPath;
        readonly string statePath;
        readonly JavaScriptSerializer json = new JavaScriptSerializer { MaxJsonLength = int.MaxValue };

        List<Book> bundled = new List<Book>();
        List<Book> books = new List<Book>();
        SavedState state = new SavedState();

        TreeView tree;
        TextBox filterBox;
        RichTextBox reader;
        Panel pageHost;
        Panel ribbonStrip;
        TextBox pageBox;
        TextBox searchBox;
        Label whereLabel;
        Label statusLabel;
        Button prevChapter;
        Button nextChapter;
        string pen = "yellow";
        int pendingStart = -1;
        int pendingLength;
        string pendingPage;
        bool suppressTree;
        bool loadingPage;
        readonly Dictionary<string, NoteView> noteViews = new Dictionary<string, NoteView>();

        Book currentBook;
        Chapter currentChapter;
        BookPage currentPage;
        int currentIndex;

        public ReaderForm()
        {
            libraryPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "library.json");
            var dir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "Principles Before Personalities");
            Directory.CreateDirectory(dir);
            statePath = Path.Combine(dir, "library-state.json");

            Text = "Principles Before Personalities";
            BackColor = Navy;
            ForeColor = Color.White;
            Font = new Font("Segoe UI", 10f);
            ClientSize = new Size(1180, 780);
            MinimumSize = new Size(900, 640);
            StartPosition = FormStartPosition.CenterScreen;

            LoadLibrary();
            LoadState();
            BuildUi();
            RestorePlace();
        }

        void LoadLibrary()
        {
            if (!File.Exists(libraryPath))
            {
                bundled = new List<Book>();
                return;
            }
            var file = json.Deserialize<LibraryFile>(File.ReadAllText(libraryPath));
            bundled = (file != null && file.books != null) ? file.books : new List<Book>();
            foreach (var book in bundled)
            {
                if (book.chapters == null) book.chapters = new List<Chapter>();
                foreach (var chapter in book.chapters)
                {
                    if (chapter.pages == null) chapter.pages = new List<BookPage>();
                    foreach (var page in chapter.pages)
                        if (page.paragraphs == null) page.paragraphs = new List<string>();
                }
            }
        }

        void LoadState()
        {
            if (File.Exists(statePath))
            {
                try
                {
                    state = json.Deserialize<SavedState>(File.ReadAllText(statePath)) ?? new SavedState();
                }
                catch
                {
                    state = new SavedState();
                }
            }
            if (state.highlights == null) state.highlights = new List<HighlightMark>();
            if (state.ribbons == null) state.ribbons = new List<PageRibbon>();
            if (state.notes == null) state.notes = new List<StickyNote>();
            if (state.userBooks == null) state.userBooks = new List<Book>();
            if (string.IsNullOrEmpty(state.pen)) state.pen = "yellow";
            pen = state.pen;
            books = bundled.Concat(state.userBooks).ToList();
        }

        void Save()
        {
            state.pen = pen;
            state.userBooks = books.Where(b => bundled.All(x => x.id != b.id)).ToList();
            state.place = currentPage == null || currentBook == null
                ? state.place
                : new ReadingPlace { bookId = currentBook.id, pageId = currentPage.id };
            File.WriteAllText(statePath, json.Serialize(state));
        }

        void BuildUi()
        {
            var split = new SplitContainer
            {
                Dock = DockStyle.Fill,
                SplitterWidth = 1,
                BackColor = Color.FromArgb(32, 40, 54),
                FixedPanel = FixedPanel.Panel1
            };
            split.Panel1.BackColor = Panel;
            split.Panel2.BackColor = Navy;
            Controls.Add(split);
            Shown += delegate { split.SplitterDistance = 280; };

            var header = new Label
            {
                Text = "Library",
                Dock = DockStyle.Top,
                Height = 36,
                Padding = new Padding(14, 10, 0, 0),
                ForeColor = Color.White,
                Font = new Font("Segoe UI", 11f, FontStyle.Bold)
            };
            filterBox = new TextBox
            {
                Dock = DockStyle.Top,
                Height = 28,
                BorderStyle = BorderStyle.FixedSingle,
                BackColor = Color.FromArgb(28, 38, 54),
                ForeColor = Color.White
            };
            var filterWrap = new Panel { Dock = DockStyle.Top, Height = 40, Padding = new Padding(12, 4, 12, 8), BackColor = Panel };
            filterBox.Dock = DockStyle.Fill;
            filterWrap.Controls.Add(filterBox);
            filterBox.TextChanged += delegate { RebuildTree(); };

            tree = new TreeView
            {
                Dock = DockStyle.Fill,
                BackColor = Panel,
                ForeColor = Color.White,
                BorderStyle = BorderStyle.None,
                FullRowSelect = true,
                HideSelection = false,
                ShowLines = false,
                ItemHeight = 24,
                Font = new Font("Segoe UI", 10f)
            };
            tree.AfterSelect += TreeAfterSelect;

            var import = new Button
            {
                Text = "Import a text",
                Dock = DockStyle.Bottom,
                Height = 36,
                FlatStyle = FlatStyle.Flat,
                ForeColor = Color.White,
                BackColor = Panel,
                TextAlign = ContentAlignment.MiddleLeft,
                Padding = new Padding(10, 0, 0, 0)
            };
            import.FlatAppearance.BorderSize = 0;
            import.Click += delegate { ImportText(); };

            split.Panel1.Controls.Add(tree);
            split.Panel1.Controls.Add(filterWrap);
            split.Panel1.Controls.Add(header);
            split.Panel1.Controls.Add(import);

            var toolbar = new FlowLayoutPanel
            {
                Dock = DockStyle.Top,
                Height = 52,
                BackColor = Panel,
                Padding = new Padding(12, 10, 12, 8),
                WrapContents = false,
                FlowDirection = FlowDirection.LeftToRight
            };
            whereLabel = new Label
            {
                AutoSize = false,
                Width = 280,
                Height = 32,
                ForeColor = Color.White,
                TextAlign = ContentAlignment.MiddleLeft,
                Font = new Font("Georgia", 12f, FontStyle.Bold)
            };
            toolbar.Controls.Add(whereLabel);
            foreach (var name in Pens.Names)
            {
                var colorName = name;
                var button = new Button
                {
                    Width = 22,
                    Height = 22,
                    Margin = new Padding(4, 6, 0, 0),
                    FlatStyle = FlatStyle.Flat,
                    BackColor = Pens.Ink(colorName),
                    Tag = colorName
                };
                button.FlatAppearance.BorderColor = Color.White;
                button.FlatAppearance.BorderSize = colorName == pen ? 2 : 0;
                button.Click += delegate { ChooseColor(colorName, button); };
                var tip = new ToolTip();
                tip.SetToolTip(button, "Highlight the selection in " + colorName);
                toolbar.Controls.Add(button);
            }
            toolbar.Controls.Add(ToolButton("Erase", "Erase the highlight on the selection", delegate { EraseSelection(); }));
            toolbar.Controls.Add(ToolButton("Mark", "Mark this page", delegate { ToggleRibbon(); }));
            var noteButton = ToolButton("Note", "Add a sticky note to this page", delegate { AddNote(); });
            noteButton.BackColor = Color.FromArgb(255, 236, 120);
            noteButton.ForeColor = Color.FromArgb(60, 45, 10);
            toolbar.Controls.Add(noteButton);
            searchBox = new TextBox
            {
                Width = 160,
                Height = 26,
                Margin = new Padding(12, 4, 0, 0),
                BackColor = Color.FromArgb(28, 38, 54),
                ForeColor = Color.White,
                BorderStyle = BorderStyle.FixedSingle
            };
            searchBox.KeyDown += delegate (object s, KeyEventArgs e)
            {
                if (e.KeyCode == Keys.Enter) { FindNext(); e.SuppressKeyPress = true; }
            };
            toolbar.Controls.Add(searchBox);

            pageHost = new Panel { Dock = DockStyle.Fill, BackColor = Navy, Padding = new Padding(48, 24, 48, 24) };
            var sheet = new Panel { Dock = DockStyle.Fill, BackColor = Paper };
            reader = new RichTextBox
            {
                Dock = DockStyle.Fill,
                BorderStyle = BorderStyle.None,
                BackColor = Paper,
                ForeColor = Ink,
                Font = new Font("Georgia", 14f),
                ReadOnly = true,
                HideSelection = false,
                DetectUrls = false,
                ScrollBars = RichTextBoxScrollBars.Vertical
            };
            reader.SelectionChanged += ReaderSelectionChanged;
            reader.MouseUp += delegate { RememberSelection(); };
            ribbonStrip = new Panel { Dock = DockStyle.Right, Width = 0, BackColor = Pens.Ink("yellow") };
            sheet.Controls.Add(reader);
            sheet.Controls.Add(ribbonStrip);
            pageHost.Controls.Add(sheet);
            pageHost.Resize += delegate { LayoutNotes(); };

            var nav = new Panel { Dock = DockStyle.Bottom, Height = 48, BackColor = Panel };
            prevChapter = NavButton("Previous", true);
            nextChapter = NavButton("Next", false);
            prevChapter.Click += delegate { GoChapter(-1); };
            nextChapter.Click += delegate { GoChapter(1); };
            var prev = new Button { Text = "<", Width = 36, Height = 28, FlatStyle = FlatStyle.Flat, ForeColor = Color.White, BackColor = Panel };
            var next = new Button { Text = ">", Width = 36, Height = 28, FlatStyle = FlatStyle.Flat, ForeColor = Color.White, BackColor = Panel };
            prev.FlatAppearance.BorderSize = 0;
            next.FlatAppearance.BorderSize = 0;
            prev.Click += delegate { GoPage(-1); };
            next.Click += delegate { GoPage(1); };
            pageBox = new TextBox { Width = 52, TextAlign = HorizontalAlignment.Center, Font = new Font("Segoe UI", 11f) };
            pageBox.KeyDown += delegate (object s, KeyEventArgs e)
            {
                if (e.KeyCode == Keys.Enter) { JumpToPage(); e.SuppressKeyPress = true; }
            };
            var pageLabel = new Label { Text = "Page", AutoSize = true, ForeColor = Color.White, Padding = new Padding(0, 6, 0, 0) };
            var center = new FlowLayoutPanel
            {
                FlowDirection = FlowDirection.LeftToRight,
                AutoSize = true,
                WrapContents = false,
                BackColor = Panel,
                Anchor = AnchorStyles.Top
            };
            center.Controls.Add(prev);
            center.Controls.Add(pageLabel);
            center.Controls.Add(pageBox);
            center.Controls.Add(next);
            nav.Controls.Add(prevChapter);
            nav.Controls.Add(nextChapter);
            nav.Controls.Add(center);
            nav.Resize += delegate
            {
                center.Left = Math.Max(0, (nav.Width - center.Width) / 2);
                center.Top = 10;
            };
            statusLabel = new Label
            {
                Dock = DockStyle.Bottom,
                Height = 22,
                ForeColor = Color.FromArgb(170, 190, 205),
                BackColor = Panel,
                Padding = new Padding(14, 2, 0, 0),
                Font = new Font("Segoe UI", 8.5f)
            };

            split.Panel2.Controls.Add(pageHost);
            split.Panel2.Controls.Add(nav);
            split.Panel2.Controls.Add(statusLabel);
            split.Panel2.Controls.Add(toolbar);
        }

        Button ToolButton(string text, string tip, EventHandler click)
        {
            var button = new Button
            {
                Text = text,
                AutoSize = true,
                Height = 28,
                Margin = new Padding(8, 3, 0, 0),
                FlatStyle = FlatStyle.Flat,
                ForeColor = Color.White,
                BackColor = Color.FromArgb(28, 38, 54),
                Padding = new Padding(8, 0, 8, 0)
            };
            button.FlatAppearance.BorderSize = 0;
            button.Click += click;
            new ToolTip().SetToolTip(button, tip);
            return button;
        }

        Button NavButton(string fallback, bool left)
        {
            var button = new Button
            {
                Text = fallback,
                Width = 220,
                Height = 28,
                FlatStyle = FlatStyle.Flat,
                ForeColor = Color.FromArgb(200, 210, 220),
                BackColor = Panel,
                TextAlign = left ? ContentAlignment.MiddleLeft : ContentAlignment.MiddleRight,
                Dock = left ? DockStyle.Left : DockStyle.Right
            };
            button.FlatAppearance.BorderSize = 0;
            return button;
        }

        void RebuildTree()
        {
            suppressTree = true;
            tree.BeginUpdate();
            tree.Nodes.Clear();
            var query = (filterBox.Text ?? "").Trim();
            foreach (var book in books)
            {
                var bookNode = new TreeNode(book.title + "   " + book.subtitle) { Tag = book, NodeFont = new Font(tree.Font, FontStyle.Bold) };
                var groups = book.chapters.GroupBy(c => string.IsNullOrEmpty(c.part) ? "Chapters" : c.part).ToList();
                var showParts = groups.Count > 1;
                foreach (var group in groups)
                {
                    TreeNode parent = bookNode;
                    if (showParts)
                    {
                        parent = new TreeNode(group.Key) { ForeColor = Color.FromArgb(140, 155, 170) };
                        bookNode.Nodes.Add(parent);
                    }
                    foreach (var chapter in group)
                    {
                        if (query.Length > 0 && chapter.title.IndexOf(query, StringComparison.OrdinalIgnoreCase) < 0)
                            continue;
                        var label = chapter.title;
                        if (chapter.part == "The Book" && chapter.pages.Count > 0)
                            label += "    " + chapter.pages[0].numberLabel;
                        if (ChapterHasNote(book, chapter)) label += "   note";
                        var node = new TreeNode(label) { Tag = chapter };
                        if (currentChapter != null && chapter.id == currentChapter.id && currentBook != null && book.id == currentBook.id)
                            node.NodeFont = new Font(tree.Font, FontStyle.Bold);
                        parent.Nodes.Add(node);
                    }
                    if (showParts && parent.Nodes.Count == 0)
                        bookNode.Nodes.Remove(parent);
                }
                if (query.Length > 0 && bookNode.Nodes.Count == 0)
                    continue;
                tree.Nodes.Add(bookNode);
                var open = query.Length > 0 || (currentBook != null && book.id == currentBook.id);
                if (open) bookNode.Expand();
                else bookNode.Collapse();
            }
            tree.EndUpdate();
            suppressTree = false;
        }

        bool ChapterHasNote(Book book, Chapter chapter)
        {
            var ids = new HashSet<string>(chapter.pages.Select(p => p.id));
            return state.notes.Any(n => n.bookId == book.id && ids.Contains(n.pageId));
        }

        void TreeAfterSelect(object sender, TreeViewEventArgs e)
        {
            if (suppressTree || e.Node == null) return;
            var chapter = e.Node.Tag as Chapter;
            var book = e.Node.Tag as Book;
            if (book == null && e.Node.Parent != null)
                book = (e.Node.Parent.Tag as Book) ?? (e.Node.Parent.Parent != null ? e.Node.Parent.Parent.Tag as Book : null);
            if (chapter != null && book != null && chapter.pages.Count > 0)
                Open(book, chapter, chapter.pages[0]);
            else if (book != null && book.chapters.Count > 0 && book.chapters[0].pages.Count > 0)
                Open(book, book.chapters[0], book.chapters[0].pages[0]);
        }

        List<Tuple<Chapter, BookPage>> FlatPages()
        {
            var list = new List<Tuple<Chapter, BookPage>>();
            if (currentBook == null) return list;
            foreach (var chapter in currentBook.chapters)
                foreach (var page in chapter.pages)
                    list.Add(Tuple.Create(chapter, page));
            return list;
        }

        void RestorePlace()
        {
            Book book = null;
            Chapter chapter = null;
            BookPage page = null;
            if (state.place != null)
            {
                book = books.FirstOrDefault(b => b.id == state.place.bookId);
                if (book != null)
                {
                    foreach (var candidate in book.chapters)
                    {
                        page = candidate.pages.FirstOrDefault(p => p.id == state.place.pageId);
                        if (page != null) { chapter = candidate; break; }
                    }
                }
            }
            if (page == null && books.Count > 0 && books[0].chapters.Count > 0 && books[0].chapters[0].pages.Count > 0)
            {
                book = books[0];
                chapter = book.chapters[0];
                page = chapter.pages[0];
            }
            if (page != null) Open(book, chapter, page);
            else RebuildTree();
        }

        void Open(Book book, Chapter chapter, BookPage page)
        {
            currentBook = book;
            currentChapter = chapter;
            currentPage = page;
            pendingStart = -1;
            pendingLength = 0;
            pendingPage = null;
            var flat = FlatPages();
            currentIndex = 0;
            for (var i = 0; i < flat.Count; i++)
            {
                if (flat[i].Item2.id == page.id) { currentIndex = i; break; }
            }
            ShowPage();
            RebuildTree();
            UpdateNav();
            Save();
        }

        void ShowPage()
        {
            loadingPage = true;
            ClearNoteViews();
            reader.Clear();
            reader.Text = currentPage.Plain;
            reader.SelectAll();
            reader.SelectionFont = new Font("Georgia", 14f);
            reader.SelectionColor = Ink;
            reader.SelectionAlignment = HorizontalAlignment.Left;
            reader.SelectionBackColor = Paper;
            FormatHeadings();
            ApplyStoredHighlights();
            reader.Select(0, 0);
            reader.ScrollToCaret();
            loadingPage = false;
            var ribbon = state.ribbons.FirstOrDefault(r => r.bookId == currentBook.id && r.pageId == currentPage.id);
            if (ribbon == null)
            {
                ribbonStrip.Width = 0;
            }
            else
            {
                ribbonStrip.Width = 14;
                ribbonStrip.BackColor = Pens.Ink(ribbon.color);
            }
            whereLabel.Text = currentChapter.title;
            pageBox.Text = currentPage.numberLabel ?? "";
            MountNotes();
        }

        void FormatHeadings()
        {
            var text = reader.Text ?? "";
            var parts = text.Split(new[] { "\n\n" }, StringSplitOptions.None);
            var cursor = 0;
            for (var i = 0; i < parts.Length; i++)
            {
                var paragraph = parts[i];
                if (IsHeading(paragraph))
                {
                    reader.Select(cursor, paragraph.Length);
                    reader.SelectionFont = new Font("Georgia", 12f, FontStyle.Bold);
                    reader.SelectionAlignment = HorizontalAlignment.Center;
                    reader.SelectionColor = Color.FromArgb(26, 40, 70);
                }
                cursor += paragraph.Length;
                if (i < parts.Length - 1) cursor += 2;
            }
        }

        bool IsHeading(string paragraph)
        {
            if (paragraph.StartsWith("Chapter ") && paragraph.Length < 20) return true;
            var letters = paragraph.Count(char.IsLetter);
            if (paragraph.Length >= 48 || letters <= 2) return false;
            foreach (var ch in paragraph)
            {
                if (char.IsLetter(ch) && !char.IsUpper(ch)) return false;
            }
            return true;
        }

        void ApplyStoredHighlights()
        {
            foreach (var mark in state.highlights.Where(h => h.bookId == currentBook.id && h.pageId == currentPage.id).OrderBy(h => h.start))
            {
                if (mark.start < 0 || mark.end > reader.TextLength || mark.start >= mark.end) continue;
                reader.Select(mark.start, mark.end - mark.start);
                reader.SelectionBackColor = Pens.Ink(mark.color);
            }
        }

        void ReaderSelectionChanged(object sender, EventArgs e)
        {
            if (loadingPage || !reader.Focused) return;
            if (reader.SelectionLength > 0)
            {
                pendingStart = reader.SelectionStart;
                pendingLength = reader.SelectionLength;
                pendingPage = currentPage == null ? null : currentPage.id;
                statusLabel.Text = "";
            }
            else
            {
                pendingStart = -1;
                pendingLength = 0;
            }
        }

        void RememberSelection()
        {
            if (reader.SelectionLength > 0 && currentPage != null)
            {
                pendingStart = reader.SelectionStart;
                pendingLength = reader.SelectionLength;
                pendingPage = currentPage.id;
            }
        }

        void ChooseColor(string colorName, Button button)
        {
            pen = colorName;
            foreach (Control control in button.Parent.Controls)
            {
                var peer = control as Button;
                if (peer != null && peer.Tag is string)
                    peer.FlatAppearance.BorderSize = (string)peer.Tag == colorName ? 2 : 0;
            }
            if (pendingLength <= 0 || currentPage == null || pendingPage != currentPage.id)
            {
                statusLabel.Text = "Select some text, then pick a color.";
                Save();
                return;
            }
            statusLabel.Text = "";
            ApplyHighlight(pendingStart, pendingStart + pendingLength, colorName);
            reader.Select(pendingStart, pendingLength);
            reader.SelectionBackColor = Pens.Ink(colorName);
        }

        void ApplyHighlight(int start, int end, string color)
        {
            var cutStart = start;
            var cutEnd = end;
            var kept = new List<HighlightMark>();
            foreach (var mark in state.highlights)
            {
                if (mark.bookId != currentBook.id || mark.pageId != currentPage.id)
                {
                    kept.Add(mark);
                    continue;
                }
                kept.AddRange(Subtract(mark, cutStart, cutEnd));
            }
            kept.Add(new HighlightMark
            {
                id = Guid.NewGuid().ToString(),
                bookId = currentBook.id,
                pageId = currentPage.id,
                start = cutStart,
                end = cutEnd,
                color = color
            });
            state.highlights = kept;
            Save();
        }

        void EraseSelection()
        {
            if (pendingLength <= 0 || currentPage == null || pendingPage != currentPage.id) return;
            var cutStart = pendingStart;
            var cutEnd = pendingStart + pendingLength;
            var kept = new List<HighlightMark>();
            foreach (var mark in state.highlights)
            {
                if (mark.bookId != currentBook.id || mark.pageId != currentPage.id)
                    kept.Add(mark);
                else
                    kept.AddRange(Subtract(mark, cutStart, cutEnd));
            }
            state.highlights = kept;
            reader.Select(cutStart, pendingLength);
            reader.SelectionBackColor = Paper;
            reader.Select(cutStart, pendingLength);
            Save();
        }

        List<HighlightMark> Subtract(HighlightMark mark, int cutStart, int cutEnd)
        {
            var pieces = new List<HighlightMark>();
            if (mark.end <= cutStart || mark.start >= cutEnd)
            {
                pieces.Add(mark);
                return pieces;
            }
            if (mark.start < cutStart)
            {
                pieces.Add(new HighlightMark
                {
                    id = Guid.NewGuid().ToString(),
                    bookId = mark.bookId,
                    pageId = mark.pageId,
                    start = mark.start,
                    end = cutStart,
                    color = mark.color
                });
            }
            if (cutEnd < mark.end)
            {
                pieces.Add(new HighlightMark
                {
                    id = Guid.NewGuid().ToString(),
                    bookId = mark.bookId,
                    pageId = mark.pageId,
                    start = cutEnd,
                    end = mark.end,
                    color = mark.color
                });
            }
            return pieces;
        }

        void ToggleRibbon()
        {
            if (currentPage == null) return;
            var existing = state.ribbons.FirstOrDefault(r => r.bookId == currentBook.id && r.pageId == currentPage.id);
            if (existing != null && existing.color == pen)
                state.ribbons.Remove(existing);
            else
            {
                if (existing != null) state.ribbons.Remove(existing);
                state.ribbons.Add(new PageRibbon
                {
                    id = Guid.NewGuid().ToString(),
                    bookId = currentBook.id,
                    pageId = currentPage.id,
                    color = pen
                });
            }
            ShowPage();
            Save();
        }

        void AddNote()
        {
            if (currentPage == null) return;
            var count = state.notes.Count(n => n.bookId == currentBook.id && n.pageId == currentPage.id);
            var note = new StickyNote
            {
                id = Guid.NewGuid().ToString(),
                bookId = currentBook.id,
                pageId = currentPage.id,
                text = "",
                color = pen,
                x = Math.Min(0.78, 0.58 + (count % 3) * 0.06),
                y = Math.Min(0.72, 0.30 + (count % 4) * 0.08),
                width = 210,
                height = 160,
                z = state.notes.Count == 0 ? 1 : state.notes.Max(n => n.z) + 1
            };
            state.notes.Add(note);
            MountNotes();
            RebuildTree();
            Save();
        }

        void ClearNoteViews()
        {
            foreach (var view in noteViews.Values)
                pageHost.Controls.Remove(view);
            noteViews.Clear();
        }

        void MountNotes()
        {
            ClearNoteViews();
            if (currentPage == null) return;
            foreach (var note in state.notes.Where(n => n.bookId == currentBook.id && n.pageId == currentPage.id).OrderBy(n => n.z))
            {
                var view = new NoteView(note, this);
                noteViews[note.id] = view;
                pageHost.Controls.Add(view);
                view.BringToFront();
            }
            LayoutNotes();
        }

        public void LayoutNotes()
        {
            var sheet = reader.Parent;
            if (sheet == null) return;
            foreach (var note in state.notes.Where(n => currentBook != null && currentPage != null && n.bookId == currentBook.id && n.pageId == currentPage.id))
            {
                NoteView view;
                if (!noteViews.TryGetValue(note.id, out view)) continue;
                var w = (int)note.width;
                var h = (int)note.height;
                view.Bounds = new Rectangle(
                    sheet.Left + (int)(note.x * sheet.Width) - w / 2,
                    sheet.Top + (int)(note.y * sheet.Height) - h / 2,
                    w,
                    h);
            }
        }

        public void CommitNote(StickyNote note)
        {
            var sheet = reader.Parent;
            if (sheet == null || sheet.Width < 1 || sheet.Height < 1) return;
            NoteView view;
            if (noteViews.TryGetValue(note.id, out view))
            {
                note.x = Math.Min(0.92, Math.Max(0.08, (view.Left - sheet.Left + view.Width / 2.0) / sheet.Width));
                note.y = Math.Min(0.94, Math.Max(0.08, (view.Top - sheet.Top + view.Height / 2.0) / sheet.Height));
                note.width = view.Width;
                note.height = view.Height;
            }
            Save();
        }

        public void DeleteNote(StickyNote note)
        {
            state.notes.RemoveAll(n => n.id == note.id);
            NoteView view;
            if (noteViews.TryGetValue(note.id, out view))
            {
                pageHost.Controls.Remove(view);
                noteViews.Remove(note.id);
            }
            Save();
            RebuildTree();
        }

        public void RaiseNote(StickyNote note)
        {
            note.z = (state.notes.Count == 0 ? 1 : state.notes.Max(n => n.z) + 1);
            NoteView view;
            if (noteViews.TryGetValue(note.id, out view)) view.BringToFront();
            Save();
        }

        void UpdateNav()
        {
            var flat = FlatPages();
            var chapters = currentBook == null ? new List<Chapter>() : currentBook.chapters;
            var chapterIndex = currentChapter == null ? -1 : chapters.FindIndex(c => c.id == currentChapter.id);
            prevChapter.Text = chapterIndex > 0 ? "<  " + chapters[chapterIndex - 1].title : "";
            nextChapter.Text = chapterIndex >= 0 && chapterIndex < chapters.Count - 1 ? chapters[chapterIndex + 1].title + "  >" : "";
            prevChapter.Enabled = chapterIndex > 0;
            nextChapter.Enabled = chapterIndex >= 0 && chapterIndex < chapters.Count - 1;
        }

        void GoPage(int delta)
        {
            var flat = FlatPages();
            if (flat.Count == 0) return;
            var next = Math.Max(0, Math.Min(flat.Count - 1, currentIndex + delta));
            Open(currentBook, flat[next].Item1, flat[next].Item2);
        }

        void GoChapter(int delta)
        {
            if (currentBook == null || currentChapter == null) return;
            var index = currentBook.chapters.FindIndex(c => c.id == currentChapter.id);
            var next = index + delta;
            if (next < 0 || next >= currentBook.chapters.Count) return;
            var chapter = currentBook.chapters[next];
            if (chapter.pages.Count == 0) return;
            Open(currentBook, chapter, chapter.pages[0]);
        }

        void JumpToPage()
        {
            var label = (pageBox.Text ?? "").Trim();
            if (label.Length == 0 || currentBook == null) return;
            foreach (var chapter in currentBook.chapters)
            {
                foreach (var page in chapter.pages)
                {
                    if (page.numberLabel == label && (chapter.part == "The Book" || currentChapter == null || currentChapter.part != "The Book"))
                    {
                        Open(currentBook, chapter, page);
                        return;
                    }
                }
            }
        }

        void FindNext()
        {
            var needle = (searchBox.Text ?? "").Trim();
            if (needle.Length < 2 || currentBook == null) return;
            var flat = FlatPages();
            var start = Math.Max(0, currentIndex);
            for (var step = 0; step < flat.Count; step++)
            {
                var item = flat[(start + step) % flat.Count];
                var plain = item.Item2.Plain;
                var from = (step == 0 && item.Item2.id == currentPage.id) ? reader.SelectionStart + reader.SelectionLength : 0;
                var at = plain.IndexOf(needle, from, StringComparison.OrdinalIgnoreCase);
                if (at < 0 && step == 0 && from > 0)
                    at = plain.IndexOf(needle, 0, StringComparison.OrdinalIgnoreCase);
                if (at < 0) continue;
                if (item.Item2.id != currentPage.id)
                    Open(currentBook, item.Item1, item.Item2);
                reader.Select(at, needle.Length);
                reader.ScrollToCaret();
                pendingStart = at;
                pendingLength = needle.Length;
                pendingPage = currentPage.id;
                return;
            }
            statusLabel.Text = "No matches.";
        }

        void ImportText()
        {
            using (var dialog = new OpenFileDialog())
            {
                dialog.Filter = "Text files (*.txt;*.md)|*.txt;*.md|All files (*.*)|*.*";
                dialog.Title = "Import a text you already have the right to read";
                if (dialog.ShowDialog(this) != DialogResult.OK) return;
                var text = File.ReadAllText(dialog.FileName);
                var title = Path.GetFileNameWithoutExtension(dialog.FileName);
                var book = BookFromText(text, title);
                books.Add(book);
                if (book.chapters.Count > 0 && book.chapters[0].pages.Count > 0)
                    Open(book, book.chapters[0], book.chapters[0].pages[0]);
                statusLabel.Text = "Imported " + title + ".";
            }
        }

        Book BookFromText(string text, string title)
        {
            var lines = text.Replace("\r\n", "\n").Split('\n');
            var chapters = new List<Tuple<string, string>>();
            var name = "Text";
            var buffer = new List<string>();
            Action flush = delegate
            {
                var body = string.Join("\n", buffer).Trim();
                buffer.Clear();
                if (body.Length == 0) return;
                chapters.Add(Tuple.Create(name, body));
            };
            foreach (var line in lines)
            {
                var trimmed = line.Trim();
                if (IsImportHeading(trimmed))
                {
                    flush();
                    name = trimmed.TrimStart('#').Trim();
                    continue;
                }
                buffer.Add(line);
            }
            flush();
            if (chapters.Count == 0) chapters.Add(Tuple.Create(title, text));
            var bookId = "user-" + Guid.NewGuid().ToString("N");
            var book = new Book
            {
                id = bookId,
                title = title,
                subtitle = "Imported text",
                note = "A text you imported.",
                chapters = new List<Chapter>()
            };
            for (var i = 0; i < chapters.Count; i++)
            {
                var pages = Chunk(chapters[i].Item2);
                var chapter = new Chapter
                {
                    id = bookId + "-c" + i,
                    title = chapters[i].Item1,
                    part = "Imported",
                    pages = new List<BookPage>()
                };
                for (var p = 0; p < pages.Count; p++)
                {
                    chapter.pages.Add(new BookPage
                    {
                        id = bookId + "-" + i + "-" + p,
                        numberLabel = (p + 1).ToString(),
                        paragraphs = pages[p]
                    });
                }
                book.chapters.Add(chapter);
            }
            return book;
        }

        bool IsImportHeading(string line)
        {
            if (line.StartsWith("#") && line.Length < 80) return true;
            var letters = line.Count(char.IsLetter);
            if (letters < 4 || line.Length > 70 || line.EndsWith(".")) return false;
            foreach (var ch in line)
            {
                if (char.IsLetter(ch) && !char.IsUpper(ch)) return false;
            }
            return true;
        }

        List<List<string>> Chunk(string body)
        {
            var paragraphs = body.Split(new[] { "\n\n" }, StringSplitOptions.RemoveEmptyEntries)
                .Select(p => p.Replace("\n", " ").Trim())
                .Where(p => p.Length > 0)
                .ToList();
            var pages = new List<List<string>>();
            var current = new List<string>();
            var words = 0;
            foreach (var paragraph in paragraphs)
            {
                var count = paragraph.Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries).Length;
                if (current.Count > 0 && words + count > 230 && words > 80)
                {
                    pages.Add(current);
                    current = new List<string> { paragraph };
                    words = count;
                }
                else
                {
                    current.Add(paragraph);
                    words += count;
                }
            }
            if (current.Count > 0) pages.Add(current);
            if (pages.Count == 0) pages.Add(new List<string> { "" });
            return pages;
        }
    }

    public class NoteView : Panel
    {
        readonly StickyNote note;
        readonly ReaderForm owner;
        readonly TextBox body;
        bool dragging;
        Point dragStart;
        Point origin;
        bool resizing;
        Point resizeStart;
        Size sizeOrigin;

        public NoteView(StickyNote note, ReaderForm owner)
        {
            this.note = note;
            this.owner = owner;
            Width = (int)note.width;
            Height = (int)note.height;
            BackColor = Pens.Note(note.color);
            BorderStyle = BorderStyle.FixedSingle;

            var bar = new Panel { Dock = DockStyle.Top, Height = 24, BackColor = Pens.Note(note.color), Cursor = Cursors.SizeAll };
            var flow = new FlowLayoutPanel { Dock = DockStyle.Right, Width = 150, Height = 24, FlowDirection = FlowDirection.LeftToRight, WrapContents = false, BackColor = bar.BackColor };
            foreach (var name in Pens.Names)
            {
                var colorName = name;
                var swatch = new Button
                {
                    Width = 12,
                    Height = 12,
                    Margin = new Padding(2, 6, 0, 0),
                    FlatStyle = FlatStyle.Flat,
                    BackColor = Pens.Ink(colorName)
                };
                swatch.FlatAppearance.BorderSize = 0;
                swatch.Click += delegate
                {
                    note.color = colorName;
                    BackColor = Pens.Note(colorName);
                    bar.BackColor = BackColor;
                    body.BackColor = BackColor;
                    owner.CommitNote(note);
                };
                flow.Controls.Add(swatch);
            }
            var close = new Button
            {
                Text = "x",
                Width = 18,
                Height = 18,
                Margin = new Padding(4, 3, 0, 0),
                FlatStyle = FlatStyle.Flat,
                ForeColor = Color.FromArgb(80, 60, 20),
                BackColor = bar.BackColor
            };
            close.FlatAppearance.BorderSize = 0;
            close.Click += delegate { owner.DeleteNote(note); };
            flow.Controls.Add(close);
            bar.Controls.Add(flow);
            bar.MouseDown += BarDown;
            bar.MouseMove += BarMove;
            bar.MouseUp += BarUp;

            body = new TextBox
            {
                Dock = DockStyle.Fill,
                Multiline = true,
                BorderStyle = BorderStyle.None,
                BackColor = Pens.Note(note.color),
                ForeColor = Color.FromArgb(46, 36, 20),
                Font = new Font("Segoe UI", 10f),
                Text = note.text ?? "",
                ScrollBars = ScrollBars.Vertical
            };
            body.GotFocus += delegate { if (body.Text == "") { } };
            body.TextChanged += delegate
            {
                note.text = body.Text;
                owner.CommitNote(note);
            };

            var grip = new Label
            {
                Text = "/",
                Dock = DockStyle.Bottom,
                Height = 14,
                TextAlign = ContentAlignment.MiddleRight,
                Cursor = Cursors.SizeNWSE,
                ForeColor = Color.FromArgb(120, 90, 30),
                BackColor = Pens.Note(note.color)
            };
            grip.MouseDown += GripDown;
            grip.MouseMove += GripMove;
            grip.MouseUp += delegate { resizing = false; owner.CommitNote(note); };

            Controls.Add(body);
            Controls.Add(grip);
            Controls.Add(bar);
            MouseDown += delegate { owner.RaiseNote(note); };
        }

        void BarDown(object sender, MouseEventArgs e)
        {
            dragging = true;
            dragStart = Control.MousePosition;
            origin = Location;
            owner.RaiseNote(note);
        }

        void BarMove(object sender, MouseEventArgs e)
        {
            if (!dragging) return;
            var now = Control.MousePosition;
            Left = origin.X + (now.X - dragStart.X);
            Top = origin.Y + (now.Y - dragStart.Y);
        }

        void BarUp(object sender, MouseEventArgs e)
        {
            dragging = false;
            owner.CommitNote(note);
        }

        void GripDown(object sender, MouseEventArgs e)
        {
            resizing = true;
            resizeStart = Control.MousePosition;
            sizeOrigin = Size;
        }

        void GripMove(object sender, MouseEventArgs e)
        {
            if (!resizing) return;
            var now = Control.MousePosition;
            Width = Math.Max(160, Math.Min(420, sizeOrigin.Width + (now.X - resizeStart.X)));
            Height = Math.Max(120, Math.Min(480, sizeOrigin.Height + (now.Y - resizeStart.Y)));
        }
    }

    static class Program
    {
        [STAThread]
        static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new ReaderForm());
        }
    }
}
