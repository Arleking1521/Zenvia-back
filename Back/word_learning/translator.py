from deep_translator import GoogleTranslator

# Если коды в таблице Language другие, добавьте их сюда.
CODE_MAP = {'kz': 'kk', 'kk': 'kk', 'cn': 'zh-CN', 'zh': 'zh-CN'}


def translate_many(texts, src, dst):
    if not texts or src == dst:
        return list(texts)
    translator = GoogleTranslator(
        source=CODE_MAP.get(src, src),
        target=CODE_MAP.get(dst, dst),
    )
    return [(t or '').strip() for t in translator.translate_batch(texts)]


def transcribe(code, text):
    """Автотранскрипция только для китайского (пиньинь)."""
    if code in ('zh', 'cn') and text:
        try:
            from pypinyin import pinyin
            return ' '.join(s[0] for s in pinyin(text))
        except ImportError:
            return ''
    return ''