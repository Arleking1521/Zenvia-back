
(function () {
    'use strict';

    const form = document.getElementById('imp-form');
    if (!form) return;

    const SRC = form.dataset.src;
    const TR_URL = form.dataset.translateUrl;
    const CHUNK = 15;

    const csrf = form.querySelector('[name=csrfmiddlewaretoken]').value;

    const $ = (s, r = document) => r.querySelector(s);
    const $$ = (s, r = document) => [...r.querySelectorAll(s)];

    const status = $('#imp-status');

    // --- Выделение ---

    let last = null;

    const sels = () => $$('.sel');
    const checked = () => sels().filter(s => s.checked);

    const upd = () => {
        $('#sel-count').textContent = checked().length;
    };

    document.addEventListener('click', e => {
        if (!e.target.matches('.sel')) return;

        if (e.shiftKey && last && last !== e.target) {
            const all = sels();
            const a = all.indexOf(last);
            const b = all.indexOf(e.target);

            for (let i = Math.min(a, b); i <= Math.max(a, b); i++) {
                all[i].checked = e.target.checked;
            }
        }

        last = e.target;
        upd();
    });

    $$('.sel-topic').forEach(cb => {
        cb.addEventListener('change', () => {
            $$('.sel', cb.closest('section')).forEach(s => {
                s.checked = cb.checked;
            });
            upd();
        });
    });

    $('#sel-all').addEventListener('click', () => {
        sels().forEach(s => s.checked = true);
        upd();
    });

    $('#sel-none').addEventListener('click', () => {
        sels().forEach(s => s.checked = false);
        upd();
    });

    // --- Массовые действия ---

    const rows = () => checked().map(s => s.closest('tr'));

    $('#bulk-apply').addEventListener('click', () => {
        const v = $('#bulk-diff').value;

        rows().forEach(r => {
            const select = $('.dsel', r);
            if (select) select.value = v;
        });
    });

    const setInc = on => rows().forEach(r => {
        const input = $('.inc', r);
        if (!input) return;

        input.value = on ? '1' : '0';
        r.classList.toggle('excluded', !on);
    });

    $('#bulk-exclude').addEventListener('click', () => setInc(false));
    $('#bulk-include').addEventListener('click', () => setInc(true));

    // --- Перевод ---

    async function translate(groups) {
        const items = [];

        groups.forEach(g => {
            if (!g || g.classList.contains('excluded')) return;

            const source = $(`.tx[data-code="${SRC}"]`, g);

            if (!source || !source.value.trim()) return;

            const targets = $$('.tx', g)
                .filter(input =>
                    input.dataset.code !== SRC &&
                    (!input.value.trim() || input.dataset.auto === '1')
                )
                .map(input => input.dataset.code);

            if (targets.length) {
                items.push({
                    id: g.dataset.group,
                    text: source.value.trim(),
                    targets
                });
            }
        });

        for (let k = 0; k < items.length; k += CHUNK) {
            status.textContent =
                `Перевод: ${Math.min(k + CHUNK, items.length)} / ${items.length}…`;

            try {
                const response = await fetch(TR_URL, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'X-CSRFToken': csrf
                    },
                    body: JSON.stringify({
                        src: SRC,
                        items: items.slice(k, k + CHUNK)
                    })
                });

                if (!response.ok) {
                    throw new Error(`HTTP ${response.status}`);
                }

                const data = await response.json();

                if (data.error) {
                    throw new Error(data.error);
                }

                for (const [id, byCode] of Object.entries(data.result || {})) {
                    const group = document.querySelector(
                        `[data-group="${CSS.escape(id)}"]`
                    );

                    if (!group) continue;

                    for (const [code, value] of Object.entries(byCode)) {
                        const tx = $(`.tx[data-code="${code}"]`, group);

                        if (tx && value.text) {
                            tx.value = value.text;
                            tx.dataset.auto = '1';
                            tx.classList.add('auto');
                        }

                        const tr = $(`.tr[data-code="${code}"]`, group);

                        if (
                            tr &&
                            value.transcription &&
                            (!tr.value.trim() || tr.dataset.auto === '1')
                        ) {
                            tr.value = value.transcription;
                            tr.dataset.auto = '1';
                            tr.classList.add('auto');
                        }
                    }
                }

            } catch (err) {
                status.textContent = 'Ошибка перевода: ' + err.message;
                return;
            }
        }

        status.textContent = items.length ? 'Перевод готов' : '';
    }

    const allGroups = () => $$('[data-group]');

    $('#tr-now').addEventListener('click', () => {
        translate(allGroups());
    });

    // --- Ручное редактирование ---

    document.addEventListener('input', e => {
        const el = e.target;

        if (!el.matches('.tx, .tr')) return;

        if (el.dataset.code !== SRC || el.classList.contains('tr')) {
            delete el.dataset.auto;
            el.classList.remove('auto');
        }
    });

    // --- Автоперевод при изменении исходного слова ---

    document.addEventListener('change', e => {
        const el = e.target;

        if (
            el.matches(`.tx[data-code="${SRC}"]`) &&
            $('#auto-tr').checked
        ) {
            translate([el.closest('[data-group]')]);
        }
    });

    // --- Защита от случайной отправки формы ---

    form.addEventListener('keydown', e => {
        if (
            e.key === 'Enter' &&
            e.target.matches('input[type=text], input[type=number]')
        ) {
            e.preventDefault();
        }
    });

    // --- Подсветка пропускаемых строк ---

    const syncSkipped = () => {
        $$('.crow').forEach(row => {
            const isExisting = !!$('.exist', row);

            row.classList.toggle(
                'skipped',
                isExisting && !$('#upd-existing').checked
            );
        });
    };

    $('#upd-existing').addEventListener('change', syncSkipped);

    syncSkipped();

    // --- Первоначальный перевод ---

    if ($('#auto-tr').checked) {
        translate(allGroups());
    }

})();
