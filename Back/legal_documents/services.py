from __future__ import annotations

import hashlib
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


def extract_pdf_payload(field_file) -> tuple[str, str, str]:
    """Return empty HTML, extracted plain text and SHA-256 for a text PDF."""
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

    pages = []
    for page in reader.pages:
        try:
            page_text = (page.extract_text() or '').strip()
        except Exception:
            page_text = ''
        if page_text:
            pages.append(page_text)

    plain_text = '\n\n'.join(pages).strip()
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
