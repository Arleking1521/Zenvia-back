from __future__ import annotations

import hashlib
import math
import re
from collections import Counter
from io import BytesIO
from pathlib import Path

import bleach
import mammoth
from pypdf import PdfReader


_ALLOWED_TAGS = [
    'p', 'br', 'strong', 'em', 'b', 'i', 'u',
    'h1', 'h2', 'h3', 'h4',
    'ol', 'ul', 'li',
    'a', 'blockquote',
    'table', 'thead', 'tbody', 'tr', 'th', 'td',
]
_ALLOWED_ATTRIBUTES = {
    'a': ['href', 'title', 'target', 'rel'],
}
_ALLOWED_PROTOCOLS = ['http', 'https', 'mailto']


def _read_field_file_bytes(field_file) -> bytes:
    if getattr(field_file, '_committed', True):
        field_file.open('rb')
        try:
            raw = field_file.read()
        finally:
            field_file.close()
    else:
        # UploadedFile ещё не сохранён Django; читаем поток и возвращаем позицию назад.
        stream = field_file.file
        try:
            stream.seek(0)
        except (AttributeError, OSError):
            pass
        raw = stream.read()
        try:
            stream.seek(0)
        except (AttributeError, OSError):
            pass
    return raw


def _sha256(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def extract_docx_payload(field_file) -> tuple[str, str, str]:
    """Return sanitized HTML, plain text and SHA-256 for a DOCX FileField."""
    raw = _read_field_file_bytes(field_file)
    if not raw:
        raise ValueError('Загруженный DOCX-файл пуст.')

    html_result = mammoth.convert_to_html(BytesIO(raw))
    clean_html = bleach.clean(
        html_result.value,
        tags=_ALLOWED_TAGS,
        attributes=_ALLOWED_ATTRIBUTES,
        protocols=_ALLOWED_PROTOCOLS,
        strip=True,
    ).strip()

    text_result = mammoth.extract_raw_text(BytesIO(raw))
    plain_text = text_result.value.strip()
    if not plain_text:
        raise ValueError('DOCX не содержит распознаваемого текста.')

    return clean_html, plain_text, _sha256(raw)


def _normalize_pdf_line(value: str) -> str:
    """Normalize whitespace only for comparing repeated PDF margin lines."""
    return re.sub(r'\s+', ' ', value or '').strip()


def _compact_pdf_lines(lines: list[str]) -> list[str]:
    """Trim line endings and collapse long blank runs to one empty line."""
    compact: list[str] = []
    previous_blank = True
    for line in lines:
        cleaned = line.rstrip()
        is_blank = not cleaned.strip()
        if is_blank:
            if not previous_blank:
                compact.append('')
        else:
            compact.append(cleaned.strip())
        previous_blank = is_blank

    while compact and not compact[0]:
        compact.pop(0)
    while compact and not compact[-1]:
        compact.pop()
    return compact


def _edge_line_indexes(lines: list[str], *, from_start: bool, limit: int = 3) -> list[int]:
    """Return non-empty lines nearest a page edge without top/bottom overlap."""
    nonempty = [index for index, line in enumerate(lines) if _normalize_pdf_line(line)]
    if not nonempty:
        return []

    # Long legal pages can safely inspect up to three edge lines. For very
    # short pages reduce the window so the same body line is not classified
    # as both a header and a footer.
    edge_count = min(limit, max(1, len(nonempty) // 4))
    return nonempty[:edge_count] if from_start else nonempty[-edge_count:]


def _deduplicate_pdf_headers_and_footers(page_texts: list[str]) -> str:
    """Keep repeated page headers once at start and footers once at end.

    PDF text extraction often repeats Word headers/footers on every page. In
    layout mode they are located at the visual top/bottom of each page, so we
    compare only a few edge lines and never remove matching text from a page
    body. A margin line must occur on at least 60% of pages (and at least two)
    before it is treated as a repeated header/footer.
    """
    pages = [_compact_pdf_lines(text.splitlines()) for text in page_texts if text.strip()]
    if not pages:
        return ''
    if len(pages) == 1:
        return '\n'.join(pages[0]).strip()

    minimum_pages = max(2, math.ceil(len(pages) * 0.60))

    header_counts: Counter[str] = Counter()
    footer_counts: Counter[str] = Counter()
    header_indexes: list[list[int]] = []
    footer_indexes: list[list[int]] = []

    for lines in pages:
        top = _edge_line_indexes(lines, from_start=True)
        bottom = _edge_line_indexes(lines, from_start=False)
        header_indexes.append(top)
        footer_indexes.append(bottom)
        header_counts.update({_normalize_pdf_line(lines[i]) for i in top})
        footer_counts.update({_normalize_pdf_line(lines[i]) for i in bottom})

    repeated_headers = {
        line for line, count in header_counts.items() if line and count >= minimum_pages
    }
    repeated_footers = {
        line for line, count in footer_counts.items() if line and count >= minimum_pages
    }

    # If a line somehow qualifies at both edges, prefer its visual footer role.
    repeated_headers.difference_update(repeated_footers)

    canonical_header: list[str] = []
    canonical_footer: list[str] = []

    for lines, indexes in zip(pages, header_indexes):
        for i in indexes:
            normalized = _normalize_pdf_line(lines[i])
            if normalized in repeated_headers and normalized not in {
                _normalize_pdf_line(item) for item in canonical_header
            }:
                canonical_header.append(lines[i])
        if canonical_header:
            break

    # Preserve footer order as it appears on the page.
    for lines, indexes in reversed(list(zip(pages, footer_indexes))):
        selected = [lines[i] for i in indexes if _normalize_pdf_line(lines[i]) in repeated_footers]
        if selected:
            canonical_footer = selected
            break

    cleaned_pages: list[str] = []
    for page_number, lines in enumerate(pages):
        remove_indexes: set[int] = set()
        for i in header_indexes[page_number]:
            if _normalize_pdf_line(lines[i]) in repeated_headers:
                remove_indexes.add(i)
        for i in footer_indexes[page_number]:
            if _normalize_pdf_line(lines[i]) in repeated_footers:
                remove_indexes.add(i)

        cleaned = _compact_pdf_lines([
            line for index, line in enumerate(lines) if index not in remove_indexes
        ])
        if cleaned:
            cleaned_pages.append('\n'.join(cleaned).strip())

    parts: list[str] = []
    if canonical_header:
        parts.append('\n'.join(canonical_header).strip())
    parts.extend(cleaned_pages)
    if canonical_footer:
        parts.append('\n'.join(canonical_footer).strip())

    return '\n\n'.join(part for part in parts if part).strip()


def extract_pdf_payload(field_file) -> tuple[str, str, str]:
    """Return empty HTML, cleaned plain text and SHA-256 for a text PDF."""
    raw = _read_field_file_bytes(field_file)
    if not raw:
        raise ValueError('Загруженный PDF-файл пуст.')

    try:
        reader = PdfReader(BytesIO(raw), strict=False)
    except Exception as exc:
        raise ValueError('Не удалось прочитать PDF. Проверьте, что файл не повреждён.') from exc

    if reader.is_encrypted:
        try:
            unlocked = reader.decrypt('')
        except Exception as exc:
            raise ValueError('PDF защищён паролем. Загрузите PDF без пароля.') from exc
        if not unlocked:
            raise ValueError('PDF защищён паролем. Загрузите PDF без пароля.')

    pages: list[str] = []
    for page in reader.pages:
        try:
            # Layout mode keeps visual top-to-bottom order. This is important:
            # ordinary extraction may return a footer before the page body.
            page_text = page.extract_text(extraction_mode='layout') or ''
        except Exception:
            try:
                page_text = page.extract_text() or ''
            except Exception:
                page_text = ''
        if page_text.strip():
            pages.append(page_text)

    plain_text = _deduplicate_pdf_headers_and_footers(pages)
    if len(plain_text) < 40:
        raise ValueError(
            'PDF не содержит достаточного текстового слоя. '
            'Загрузите текстовый PDF, экспортированный из Word, а не скан.'
        )

    # Для PDF точное форматирование показывает оригинальный файл, поэтому HTML не реконструируем.
    return '', plain_text, _sha256(raw)


def extract_legal_payload(field_file) -> tuple[str, str, str]:
    """Extract searchable content from supported legal-document formats."""
    extension = Path(getattr(field_file, 'name', '') or '').suffix.lower()
    if extension == '.pdf':
        return extract_pdf_payload(field_file)
    if extension == '.docx':
        return extract_docx_payload(field_file)
    raise ValueError('Поддерживаются только файлы PDF и DOCX.')
