(function() {
    console.log("Начинаю создание слепка...");

    const docClone = document.documentElement.cloneNode(true);

    // 1. Удаляем скрипты, iframe и link preload
    const scripts = docClone.querySelectorAll('script, iframe, noscript, link[rel="modulepreload"]');
    scripts.forEach(el => el.remove());

    // 2. Чистим события и инлайновые стили запрета выделения
    const allElements = docClone.querySelectorAll('*');
    allElements.forEach(el => {
        const attrs = el.attributes;
        for (let i = attrs.length - 1; i >= 0; i--) {
            if (attrs[i].name.startsWith('on')) {
                el.removeAttribute(attrs[i].name);
            }
        }
        // Убираем user-select: none из инлайн стилей
        if (el.style.userSelect === 'none') el.style.userSelect = 'text';
        if (el.style.webkitUserSelect === 'none') el.style.webkitUserSelect = 'text';
    });

    // 3. Отключаем ссылки (превращаем в текст)
    const links = docClone.querySelectorAll('a');
    links.forEach(a => {
        a.removeAttribute('href');
        a.removeAttribute('target');
        a.removeAttribute('onclick');
        a.style.cursor = 'text';
    });

    // 4. Абсолютные пути
    const baseUrl = window.location.origin;
    function toAbsolute(path) {
        if (!path) return path;
        if (path.startsWith('http') || path.startsWith('//') || path.startsWith('data:')) return path;
        return new URL(path, window.location.href).href;
    }
    docClone.querySelectorAll('[src], [href]').forEach(el => {
        if (el.hasAttribute('src')) el.setAttribute('src', toAbsolute(el.getAttribute('src')));
        if (el.hasAttribute('href')) el.setAttribute('href', toAbsolute(el.getAttribute('href')));
    });

    // 5. Сохраняем данные форм (Inputs)
    const originalInputs = document.querySelectorAll('input, textarea, select');
    const clonedInputs = docClone.querySelectorAll('input, textarea, select');
    originalInputs.forEach((orig, i) => {
        if (clonedInputs[i]) {
            if (orig.tagName === 'INPUT' && (orig.type === 'checkbox' || orig.type === 'radio')) {
                if (orig.checked) clonedInputs[i].setAttribute('checked', '');
            } else if (orig.tagName === 'SELECT') {
                 const options = clonedInputs[i].querySelectorAll('option');
                 if (options[orig.selectedIndex]) options[orig.selectedIndex].setAttribute('selected', '');
            } else {
                clonedInputs[i].setAttribute('value', orig.value);
                if (orig.tagName === 'TEXTAREA') clonedInputs[i].innerHTML = orig.value;
            }
        }
    });

    // 6. МОЩНЫЙ CSS FIX (Включая Ace Editor)
    const styleFix = document.createElement('style');
    styleFix.innerHTML = `
        /* Глобально разрешаем выделение */
        *, html, body {
            -webkit-user-select: text !important;
            -moz-user-select: text !important;
            -ms-user-select: text !important;
            user-select: text !important;
        }

        /* Ссылки как обычный текст */
        a {
            cursor: text !important;
            pointer-events: auto !important;
        }

        /* --- ЛЕЧЕНИЕ ACE EDITOR (LeetCode и другие редакторы) --- */

        /* 1. Делаем слои с текстом доступными для клика */
        .ace_editor, .ace_scroller, .ace_content, .ace_layer, .ace_line, .ace_text-layer {
            pointer-events: auto !important;
            user-select: text !important;
        }

        /* 2. Убираем слои, которые лежат ПОВЕРХ текста (курсоры, активная строка, маркеры) */
        .ace_cursor-layer,
        .ace_marker-layer,
        .ace_scrollbar,
        .ace_gutter-active-line {
            pointer-events: none !important; /* Чтобы клики проходили сквозь них */
            display: none !important; /* Или просто скрываем их, они не нужны в статике */
        }

        /* 3. Раскрываем скрытый текст, если он был спрятан */
        .ace_text-input {
            display: none !important; /* Скрываем скрытый input редактора */
        }
    `;
    const head = docClone.querySelector('head') || docClone.appendChild(document.createElement('head'));
    head.appendChild(styleFix);

    // 7. Скачивание
    const htmlContent = "<!DOCTYPE html>\n" + docClone.outerHTML;
    const blob = new Blob([htmlContent], { type: 'text/html' });
    const link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = 'static_fixed_editor.html';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);

    console.log('%cГотово! Редакторы кода разблокированы.', 'color: green; font-weight: bold;');
})();
