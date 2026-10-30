
import requests

CODE_MAP = {
    'kz': 'kk',
    'kk': 'kk',
    'cn': 'zh-CN',
    'zh': 'zh-CN',
}

GOOGLE_TRANSLATE_URL = (
    "https://translate.google.com/translate_a/single"
)


def translate_many(texts, src, dst):
    if not texts or src == dst:
        return list(texts)

    source = CODE_MAP.get(src, src)
    target = CODE_MAP.get(dst, dst)

    results = []

    for text in texts:
        text = (text or '').strip()

        if not text:
            results.append('')
            continue

        params = {
            'client': 'gtx',
            'sl': source,
            'tl': target,
            'dt': 't',
            'q': text[:255],
        }

        response = requests.get(
            GOOGLE_TRANSLATE_URL,
            params=params,
            timeout=15,
        )
        response.raise_for_status()

        data = response.json()

        translated = ''.join(
            part[0]
            for part in data[0]
            if part and part[0]
        )

        results.append(translated.strip())

    return results


def transcribe(code, text):
    """Автотранскрипция только для китайского (пиньинь)."""
    if code in ('zh', 'cn') and text:
        try:
            from pypinyin import pinyin
            return ' '.join(s[0] for s in pinyin(text))
        except ImportError:
            return ''

    return ''
