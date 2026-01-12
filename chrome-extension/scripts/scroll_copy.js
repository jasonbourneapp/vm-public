(function() {
    // Защита от повторного запуска
    if (window._isScrollCaptureActive) {
        console.log("Режим захвата уже активен.");
        return;
    }
    window._isScrollCaptureActive = true;

    let isRecording = false;
    let observer = null;
    let collectedData = new Set();
    let targetNode = null;

    // Функция сбора текста
    const capture = () => {
        if (!targetNode) return;
        const text = targetNode.innerText || targetNode.textContent;
        // Разбиваем на строки, чистим и сохраняем уникальные
        text.split('\n').forEach(line => {
            const trimmed = line.trim();
            if (trimmed) collectedData.add(trimmed);
        });
    };

    // Основной обработчик кликов
    const clickHandler = (e) => {
        // Полный стелс: блокируем клик, чтобы сайт не реагировал (не переходил по ссылкам)
        e.preventDefault();
        e.stopPropagation();
        e.stopImmediatePropagation();

        if (!isRecording) {
            // --- ЭТАП 1: НАЧАЛО (Первый клик) ---
            isRecording = true;
            targetNode = e.target;

            // Визуально для себя можно в консоль вывести, но UI не трогаем
            console.log("Start capturing on:", targetNode);

            // Первый захват
            capture();

            // Вешаем наблюдатель за изменениями DOM (подгрузка контента при скролле)
            observer = new MutationObserver(capture);
            observer.observe(targetNode, {
                childList: true,
                subtree: true,
                characterData: true
            });

        } else {
            // --- ЭТАП 2: КОНЕЦ (Второй клик) ---
            if (observer) observer.disconnect();

            // Финальный захват
            capture();

            // Формируем итоговый текст
            const finalString = Array.from(collectedData).join('\n');

            // Убираем слушатели
            document.removeEventListener('click', clickHandler, true);
            window._isScrollCaptureActive = false;

            console.log("Capture finished. Sending to Bridge...");

            // ГЛАВНОЕ ИЗМЕНЕНИЕ:
            // Отправляем данные обратно в background.js через Runtime Message
            // Это попадет в тот самый висящий curl запрос
            chrome.runtime.sendMessage({
                action: "SCROLL_CAPTURE_DONE",
                payload: finalString
            });
        }
    };

    // Вешаем перехватчик на фазу захвата (true), чтобы перехватить раньше всех
    document.addEventListener('click', clickHandler, true);

    console.log("Scroll Capture armed. Click element to start.");
})();
