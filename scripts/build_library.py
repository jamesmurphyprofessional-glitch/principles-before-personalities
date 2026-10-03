#!/usr/bin/env python3
"""Build the bundled library from the public-domain Big Book text.

Basic text (pages 1–164), the foreword, and the Doctor's Opinion come from the
Anonymous Press HTML, which uses the page numbers read in meetings. It is the
first edition text (1939) as revised in its 1941 printing (Step Twelve's
"spiritual awakening" wording and the Spiritual Experience appendix), kept
deliberately; that text is public domain in the United States only.
Personal stories are the first-edition stories. Later-edition material and the
BBSG appendix are left out.
"""

from __future__ import annotations

import json
import re
import subprocess
from html.parser import HTMLParser
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "Sources" / "PrinciplesBeforePersonalities" / "Resources" / "library.json"
PAGE_DIR = Path("/tmp/bbpages")
PDF = Path("/tmp/bb1.pdf")
RAW = Path("/tmp/bb1_raw.txt")

CHAPTER_STARTS = {
    1: "Bill's Story",
    17: "There Is a Solution",
    30: "More About Alcoholism",
    44: "We Agnostics",
    58: "How It Works",
    72: "Into Action",
    89: "Working With Others",
    104: "To Wives",
    122: "The Family Afterward",
    136: "To Employers",
    151: "A Vision for You",
}

STORY_TITLES = [
    "THE DOCTOR'S NIGHTMARE",
    "THE UNBELIEVER",
    "THE EUROPEAN DRINKER",
    "A FEMININE VICTORY",
    "OUR SOUTHERN FRIEND",
    "A BUSINESS MAN'S RECOVERY",
    "A DIFFERENT SLANT",
    "TRAVELER, EDITOR, SCHOLAR",
    "THE BACK-SLIDER",
    "HOME BREWMEISTER",
    "THE SEVEN MONTH SLIP",
    "MY WIFE AND I",
    "A WARD OF THE PROBATE COURT",
    "RIDING THE RODS",
    "THE SALESMAN",
    "FIRED AGAIN",
    "THE FEARFUL ONE",
    "TRUTH FREED ME!",
    "SMILE WITH ME, AT ME",
    "A CLOSE SHAVE",
    "EDUCATED AGNOSTIC",
    "ANOTHER PRODIGAL STORY",
    "THE CAR SMASHER",
    "HINDSIGHT",
    "ON HIS WAY",
    "AN ALCOHOLIC'S WIFE",
    "AN ARTIST'S CONCEPT",
    "THE ROLLING STONE",
    "LONE ENDEAVOR",
    "ACE FULL-SEVEN-ELEVEN",
]

# STORY_TITLES above are matchers against the source text's headings. Some
# display titles differ from the source heading. The chapter/page ids stay
# derived from the source heading so saved highlights, notes, and bookmarks
# (keyed by id) keep working.
STORY_DISPLAY_TITLES = {
    "The Seven Month Slip": "The Seventh Month Slip",
}


def slug(text: str) -> str:
    text = text.lower().replace("'", "").replace("’", "")
    text = re.sub(r"[^a-z0-9]+", "-", text).strip("-")
    return text or "section"


def nice_title(text: str) -> str:
    small = {"a", "an", "of", "the", "and", "for", "with", "to", "in", "on", "at"}
    words = text.replace("’", "'").split()
    out = []
    for i, word in enumerate(words):
        lower = word.lower()
        if i and lower in small:
            out.append(lower)
        else:
            out.append(lower[:1].upper() + lower[1:] if lower else lower)
    title = " ".join(out)
    title = title.replace("Aa", "A.A.")
    return title


def clean_paragraph(text: str) -> str:
    text = text.replace("\xa0", " ").replace("\u00ad", "")
    text = text.replace("“", '"').replace("”", '"').replace("‘", "'").replace("’", "'")
    text = text.replace("—", " — ").replace("–", "-")
    text = re.sub(r"\s+", " ", text).strip()
    text = re.sub(r"^([A-Z])\s+([a-z])", r"\1\2", text)
    text = re.sub(r"\bIwas\b", "I was", text)
    text = re.sub(r"\bIhad\b", "I had", text)
    text = re.sub(r"\s+([,.;:!?])", r"\1", text)
    text = re.sub(r"\s{2,}", " ", text)
    return text.strip()


class ParagraphParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.skip = 0
        self.buf: list[str] = []
        self.orphan: list[str] = []
        self.paras: list[str] = []
        self.in_block = False
        self.in_ol = False
        self.item = 0

    def handle_starttag(self, tag: str, attrs) -> None:
        if tag in {"script", "style"}:
            self.skip += 1
        if tag == "ol":
            self.in_ol = True
            self.item = 0
        if tag == "li" and self.in_ol:
            self._flush_block()
            self.item += 1
            self.buf = [f"{self.item}. "]
            self.in_block = True
        if tag == "p":
            self._flush_block()
            self.in_block = True
            self.buf = []
        if tag == "br" and self.in_block:
            self.buf.append(" ")

    def handle_endtag(self, tag: str) -> None:
        if tag in {"script", "style"} and self.skip:
            self.skip -= 1
            return
        if tag == "ol":
            self.in_ol = False
        if tag in {"p", "li"}:
            if self.in_block:
                self._flush_block()
            else:
                self._flush_orphan()

    def handle_data(self, data: str) -> None:
        if self.skip:
            return
        if self.in_block:
            self.buf.append(data)
        elif data.strip():
            self.orphan.append(data)

    def close(self) -> None:
        super().close()
        self._flush_block()
        self._flush_orphan()

    def _flush_block(self) -> None:
        text = clean_paragraph("".join(self.buf))
        self.buf = []
        self.in_block = False
        if text:
            self.paras.append(text)

    def _flush_orphan(self) -> None:
        text = clean_paragraph("".join(self.orphan))
        self.orphan = []
        if text:
            self.paras.append(text)


def html_paragraphs(path: Path) -> list[str]:
    raw = path.read_bytes().decode("cp1252", errors="replace")
    raw = raw.replace("&#151;", " — ").replace("&mdash;", " — ").replace("&ndash;", "-")
    parser = ParagraphParser()
    parser.feed(raw)
    parser.close()
    drop = re.compile(r"^(page\s+\d+|alcoholics anonymous)$", re.I)
    paras = []
    for para in parser.paras:
        if drop.match(para):
            continue
        if para.lower() in {"next page", "previous page"}:
            continue
        paras.append(para)
    return paras


def fetch(url: str, dest: Path) -> None:
    if dest.exists() and dest.stat().st_size > 200:
        return
    subprocess.check_call(["curl", "-fsSL", "--max-time", "30", "-o", str(dest), url])


def chunk_paragraphs(paragraphs: list[str], target_words: int = 220) -> list[list[str]]:
    pages: list[list[str]] = []
    current: list[str] = []
    count = 0
    for para in paragraphs:
        words = len(para.split())
        if current and count + words > target_words and count > 80:
            pages.append(current)
            current = [para]
            count = words
        else:
            current.append(para)
            count += words
    if current:
        pages.append(current)
    return pages or [[]]


def page_obj(page_id: str, label: str, paragraphs: list[str]) -> dict:
    return {"id": page_id, "numberLabel": label, "paragraphs": paragraphs}


def chapter_obj(part: str, title: str, pages: list[dict], chapter_id: str | None = None) -> dict:
    return {
        "id": chapter_id or slug(title),
        "title": title,
        "part": part,
        "pages": pages,
    }


def basic_text_book() -> dict:
    chapters_pages: list[tuple[str, str, list[tuple[str, list[str]]]]] = []

    foreword = html_paragraphs(PAGE_DIR / "foreword.htm")
    opinion = html_paragraphs(PAGE_DIR / "docsopin.htm")
    front = [
        ("Foreword", "Front matter", foreword),
        ("The Doctor's Opinion", "Front matter", opinion),
    ]

    numbered: dict[int, list[str]] = {}
    for number in range(1, 165):
        numbered[number] = html_paragraphs(PAGE_DIR / f"Page_{number}.htm")

    # Group the meeting pages by the canonical chapter starts.
    starts = sorted(CHAPTER_STARTS)
    grouped: list[tuple[str, list[tuple[int, list[str]]]]] = []
    for index, start in enumerate(starts):
        end = starts[index + 1] - 1 if index + 1 < len(starts) else 164
        title = CHAPTER_STARTS[start]
        grouped.append((title, [(n, numbered[n]) for n in range(start, end + 1)]))

    chapters = []
    for title, part, paragraphs in [
        ("Foreword", "Front matter", foreword),
        ("The Doctor's Opinion", "Front matter", opinion),
    ]:
        pages = []
        for i, chunk in enumerate(chunk_paragraphs(paragraphs), start=1):
            pages.append(page_obj(f"{slug(title)}-{i}", str(i), chunk))
        chapters.append(chapter_obj(part, title, pages))

    for title, pairs in grouped:
        pages = []
        for number, paragraphs in pairs:
            if not paragraphs:
                paragraphs = [" "]
            pages.append(page_obj(f"p{number}", str(number), paragraphs))
        chapters.append(chapter_obj("The Book", title, pages))

    appendix_path = PAGE_DIR / "spiritual.htm"
    fetch("https://anonpress.org/bb/Spiritualexperience.htm", appendix_path)
    appendix = html_paragraphs(appendix_path)
    joined = " ".join(appendix)
    if "spiritual experience" in joined.lower() and "spiritual awakening" in joined.lower():
        pages = []
        for i, chunk in enumerate(chunk_paragraphs(appendix), start=1):
            pages.append(page_obj(f"spiritual-experience-{i}", str(i), chunk))
        chapters.append(chapter_obj("Appendices", "Spiritual Experience", pages))

    return {
        "id": "bigbook",
        "title": "Alcoholics Anonymous",
        "subtitle": "The basic text",
        "note": (
            "Public domain in the United States. This is the first edition text (1939) as "
            "revised in its 1941 printing, including the Twelfth Step's \"spiritual awakening\" "
            "wording and the Spiritual Experience appendix. It uses the page numbers read in "
            "meetings: Bill's Story begins on page 1 and How It Works on page 58, through page 164. "
            "This is not the current fourth edition."
        ),
        "chapters": chapters,
    }


def normalize_heading(line: str) -> str:
    line = line.upper().replace("’", "'").replace("`", "'")
    line = line.replace("–", "-").replace("—", "-")
    line = re.sub(r"\s+", " ", line).strip()
    line = line.replace(" - ", "-").replace(" -", "-").replace("- ", "-")
    line = re.sub(r"-+", "-", line)
    return line


def story_paragraphs() -> list[tuple[str, list[str]]]:
    if not RAW.exists():
        subprocess.check_call(["pdftotext", str(PDF), str(RAW)])
    lines = RAW.read_text(errors="replace").splitlines()
    cleaned: list[str] = []
    running = re.compile(
        r"^(?:\d+\s+ALCOHOLICS ANONYMOUS|ALCOHOLICS ANONYMOUS(?:\s+\d+)?|[A-Z][A-Z' ,!\-]{3,}\s+\d{1,3}|\d{1,3})$"
    )
    for line in lines:
        s = line.strip()
        if not s:
            cleaned.append("")
            continue
        if running.match(s):
            continue
        if s in {"THE 4TH EDITION OF", "No Copyright", "No rights reserved."}:
            continue
        cleaned.append(s)

    whole_words = {
        "was", "were", "had", "have", "has", "been", "probably", "learned",
        "cannot", "don't", "went", "came", "made", "took", "felt", "found",
    }
    merged: list[str] = []
    i = 0
    while i < len(cleaned):
        s = cleaned[i]
        if len(s) == 1 and s.isalpha():
            j = i + 1
            while j < len(cleaned) and cleaned[j] == "":
                j += 1
            if j < len(cleaned) and cleaned[j][:1].isupper():
                nxt = cleaned[j]
                first, sep, rest = nxt.partition(" ")
                token = re.sub(r"[^A-Za-z']", "", first)
                if token.isupper() and len(token) > 1:
                    if s in {"I", "A"} and token.lower() in whole_words:
                        cleaned[j] = f"{s} {token.lower()}{first[len(token):]}" + (sep + rest if sep else "")
                    else:
                        glued = s + token
                        glued = glued[:1] + glued[1:].lower()
                        cleaned[j] = glued + first[len(token):] + (sep + rest if sep else "")
                    i += 1
                    continue
        merged.append(s)
        i += 1

    text = "\n".join(merged)
    text = re.sub(r"([A-Za-z])-\n([a-z])", r"\1\2", text)
    text = text.replace("’", "'")

    # Cut publisher appendix. Ace Full-Seven-Eleven is an early story that the
    # reprint placed after its own appendix note, so lift that story back out
    # and stop before the 1944 commentary.
    appendix_at = re.search(r"(?m)^APPENDIX\s*$", text)
    if not appendix_at:
        raise SystemExit("could not find APPENDIX boundary in the story source")
    main = text[: appendix_at.start()]
    tail = text[appendix_at.end() :]
    ace = re.search(r"ACE FULL\s*-\s*SEVEN\s*-\s*ELEVEN", tail)
    if not ace:
        raise SystemExit("could not find Ace Full-Seven-Eleven")
    ace_body = tail[ace.end() :]
    stop = re.search(r"April 27th, 1944|HOW IT WORKED", ace_body)
    if stop:
        ace_body = ace_body[: stop.start()]
    main = main + "\n\nACE FULL-SEVEN-ELEVEN\n" + ace_body

    # Split on story titles.
    pattern = re.compile(
        r"(?m)^(" + "|".join(re.escape(normalize_heading(t)) for t in STORY_TITLES) + r")\s*$"
    )
    # Normalize heading lines in the body so the pattern hits.
    body_lines = []
    for line in main.splitlines():
        norm = normalize_heading(line)
        if norm in {normalize_heading(t) for t in STORY_TITLES}:
            body_lines.append(norm)
        else:
            body_lines.append(line)
    body = "\n".join(body_lines)
    matches = list(pattern.finditer(body))
    body_start = None
    for match in matches:
        window = body[match.end() : match.end() + 500]
        if "New England village" in window:
            body_start = match.start()
            break
    if body_start is None:
        raise SystemExit("could not find the start of the personal stories")
    matches = [m for m in matches if m.start() >= body_start]
    if len(matches) < 20:
        found = [m.group(1) for m in matches]
        raise SystemExit(f"only found {len(matches)} stories: {found}")

    stories: list[tuple[str, list[str]]] = []
    for index, match in enumerate(matches):
        start = match.end()
        end = matches[index + 1].start() if index + 1 < len(matches) else len(body)
        title = nice_title(match.group(1).replace("-", " "))
        if title == "Ace Full Seven Eleven":
            title = "Ace Full-Seven-Eleven"
        chunk = body[start:end].strip()
        paragraphs = []
        for block in re.split(r"\n\s*\n", chunk):
            para = clean_paragraph(block.replace("\n", " "))
            if para and not re.fullmatch(r"\d+", para):
                paragraphs.append(para)
        if paragraphs:
            paragraphs[0] = soften_opening(paragraphs[0])
            stories.append((title, paragraphs))
    return stories


def soften_opening(text: str) -> str:
    """Turn the small-caps opening line of a story into ordinary sentence case."""
    words = text.split(" ")
    out = []
    for i, word in enumerate(words[:16]):
        core = re.sub(r"[^A-Za-z']", "", word)
        if not core or not (core.isupper() or core in {"I", "A"}):
            out.extend(words[i:])
            return " ".join(out)
        if len(core) > 1:
            lowered = core.lower()
            if i == 0:
                lowered = lowered[:1].upper() + lowered[1:]
            word = word.replace(core, lowered, 1)
        elif i > 0 and core == "A":
            word = word.replace("A", "a", 1)
        out.append(word)
    out.extend(words[16:])
    return " ".join(out)


def stories_book() -> dict:
    chapters = []
    for title, paragraphs in story_paragraphs():
        story_id = slug(title)  # from the source heading; keep stable for saved user data
        display_title = STORY_DISPLAY_TITLES.get(title, title)
        pages = []
        for i, chunk in enumerate(chunk_paragraphs(paragraphs, 230), start=1):
            pages.append(page_obj(f"{story_id}-{i}", str(i), chunk))
        chapters.append(chapter_obj("Personal Stories", display_title, pages, chapter_id=story_id))
    return {
        "id": "stories",
        "title": "Personal Stories",
        "subtitle": "First edition",
        "note": (
            "Personal stories from the first edition of Alcoholics Anonymous, "
            "which is in the public domain in the United States. "
            "Stories added in the third and fourth editions are not included."
        ),
        "chapters": chapters,
    }


def assert_book(library: dict) -> None:
    big = library["books"][0]
    pages = {
        page["numberLabel"]: "\n\n".join(page["paragraphs"])
        for chapter in big["chapters"]
        if chapter["part"] == "The Book"
        for page in chapter["pages"]
    }
    checks = {
        "58": "Rarely have we seen a person fail",
        "59": "We admitted we were powerless over alcohol",
        "83": "If we are painstaking about this phase of our development",
        "164": "suggestive only",
        "1": "Bill's Story",
    }
    for label, needle in checks.items():
        text = pages.get(label, "")
        if needle.casefold() not in text.casefold():
            raise SystemExit(f"page {label} is missing {needle!r}. Starts: {text[:180]!r}")
    story_chapters = library["books"][1]["chapters"]
    story_titles = [c["title"] for c in story_chapters]
    story_ids = {c["id"]: c["title"] for c in story_chapters}
    story_count = len(story_titles)
    if (
        story_ids.get("the-seven-month-slip") != "The Seventh Month Slip"
        or "The Seven Month Slip" in story_titles
        or len(set(story_titles)) != len(story_titles)
    ):
        raise SystemExit(f"story set looks incomplete: {story_titles}")
    words = sum(len(p.split()) for b in library["books"] for c in b["chapters"] for page in c["pages"] for p in page["paragraphs"])
    print(f"books={len(library['books'])} stories={story_count} meeting_pages={len(pages)} words={words}")


def main() -> None:
    library = {"books": [basic_text_book(), stories_book()]}
    assert_book(library)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(library, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"wrote {OUT} ({OUT.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
