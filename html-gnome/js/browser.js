const Browser = {
    /**
     * Переключает вкладки по ID
     */
    switchTab: function(tabId) {
        // 1. Вкладки
        const tabs = document.querySelectorAll('.tab');
        tabs.forEach(tab => tab.classList.remove('active'));
        document.getElementById(`tab-btn-${tabId}`).classList.add('active');

        // 2. Контент
        const contents = document.querySelectorAll('.tab-content');
        contents.forEach(content => content.classList.remove('active'));
        document.getElementById(`tab-content-${tabId}`).classList.add('active');

        // 3. Адресная строка
        const urlInput = document.getElementById('url-input');
        if (tabId === 1) {
            urlInput.value = 'https://meet.google.com/abc-defg-hij';
        } else if (tabId === 2) {
            urlInput.value = 'https://code.yandex-team.ru/interview/12345';
        }
    }
};
