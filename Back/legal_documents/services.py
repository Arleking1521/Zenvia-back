from __future__ import annotations

import hashlib
from io import BytesIO

import bleach
import mammoth


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


def extract_docx_payload(field_file) -> tuple[str, str, str]:
    """Return sanitized HTML, plain text and SHA-256 for a DOCX FileField."""
    if getattr(field_file, '_committed', True):
        field_file.open('rb')
        try:
            raw = field_file.read()
        finally:
            field_file.close()
    else:
        # Новый UploadedFile ещё должен быть сохранён Django после model.save().
        # Поэтому читаем его для конвертации, но не закрываем поток.
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

    if not raw:
        raise ValueError('Загруженный DOCX-файл пуст.')

    sha256 = hashlib.sha256(raw).hexdigest()

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

    return clean_html, plain_text, sha256
