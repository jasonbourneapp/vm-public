(function() {
    let isRecording = false;
    let observer = null;
    let collectedData = new Set();
    let targetNode = null;

    // Функция сбора текста
    const capture = () => {
        if (!targetNode) return;
        const text = targetNode.innerText || targetNode.textContent;
        // Разбиваем на строки и сохраняем уникальные
        text.split('\n').forEach(line => {
            const trimmed = line.trim();
            if (trimmed) collectedData.add(trimmed);
        });
    };

    // Основной обработчик
    const clickHandler = (e) => {
        // Блокируем стандартное поведение клика, чтобы не переходить по ссылкам
        e.preventDefault();
        e.stopPropagation();

        if (!isRecording) {
            // --- СТАРТ ---
            isRecording = true;
            targetNode = e.target; // Элемент под курсором становится целью

            // Первый захват
            capture();

            // Запускаем тихую слежку за обновлениями DOM (скроллом)
            observer = new MutationObserver(capture);
            observer.observe(targetNode, {
                childList: true,
                subtree: true,
                characterData: true
            });

        } else {
            // --- СТОП ---
            if (observer) observer.disconnect();

            // Финальный захват
            capture();

            // Формируем текст
            const finalString = Array.from(collectedData).join('\n');

            // Молча копируем в буфер
            if (navigator.clipboard) {
                navigator.clipboard.writeText(finalString).catch(() => {});
            } else {
                // Фоллбэк для старых браузеров (на всякий случай)
                const area = document.createElement('textarea');
                area.value = finalString;
                document.body.appendChild(area);
                area.select();
                document.execCommand('copy');
                document.body.removeChild(area);
            }

            // Полная очистка следов
            document.removeEventListener('click', clickHandler, true);
        }
    };

    // Вешаем перехватчик на фазу захвата (capture), чтобы сработать раньше сайта
    document.addEventListener('click', clickHandler, true);
})();
