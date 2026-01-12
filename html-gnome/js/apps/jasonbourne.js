const JasonBourneApp = {
    init: function() {
        const contentArea = document.getElementById('jb-content-area');

        contentArea.innerHTML = `
            <!-- Верхняя панель: Транскрипция -->
            <div class="jb-panel jb-transcription">
                <div class="jb-header-row">
                    <span class="jb-section-title">Транскрипция</span>
                    <div style="display:flex; align-items:center;">
                        <div class="toggle-wrapper">
                            <span class="toggle-label">Тестовый режим</span>
                            <div class="toggle-switch"></div>
                        </div>
                        <div class="jb-bk-badge">BK</div>
                    </div>
                </div>
                <div class="jb-status-text">
                    Система готова<br>
                    <span style="color:#666; font-size:12px;">Запись началась... (Segment: 30s)</span>
                </div>
            </div>

            <!-- Средняя панель: AI Chat -->
            <div class="jb-panel jb-chat">
                <div class="jb-chat-header">
                    <span class="jb-section-title">AI Chat</span>
                    <span style="color:#555; font-size:11px; margin-left:auto; margin-right:10px;">Info</span>
                    <div class="jb-chat-actions">
                        <div class="jb-btn-small">Уточнить</div>
                        <div class="jb-btn-small">Тесты</div>
                        <div class="jb-btn-small">Запутался</div>
                        <div class="jb-btn-small">Доработать</div>
                    </div>
                </div>
                <div class="jb-chat-area">
                    Готов к работе
                </div>
            </div>

            <!-- Поле ввода -->
            <div class="jb-input-container">
                <input type="text" class="jb-input" placeholder="Введите команду или запрос...">
            </div>

            <!-- Нижняя панель управления -->
            <div class="jb-controls">
                <!-- Кнопка записи -->
                <div class="jb-rec-btn">
                    <div class="jb-rec-inner"></div>
                </div>

                <!-- Модели -->
                <div class="jb-models">
                    <button class="jb-btn-model">claude</button>
                    <button class="jb-btn-model active">gemini</button>
                </div>

                <!-- Действия -->
                <div class="jb-actions">
                    <button class="jb-btn-action">Run Code</button>
                    <button class="jb-btn-action">Объяснить</button>
                    <button class="jb-btn-action">Code Review</button>
                    <button class="jb-btn-action">Sys Design</button>
                </div>

                <div class="jb-sep"></div>

                <!-- SQL/Bash -->
                <div class="jb-big-btn">SQL/Bash</div>

                <!-- Правые иконки -->
                <div class="jb-right-icons">
                    <div class="jb-icon-box icon-orange"><svg viewBox="0 0 24 24"><path d="M14 2H6c-1.1 0-1.99.9-1.99 2L4 20c0 1.1.89 2 1.99 2H18c1.1 0 2-.9 2-2V8l-6-6zm2 16H8v-2h8v2zm0-4H8v-2h8v2zm-3-5V3.5L18.5 9H13z"/></svg></div>
                    <div class="jb-icon-box icon-green"><svg viewBox="0 0 24 24"><path d="M9.4 16.6L4.8 12l4.6-4.6L8 6l-6 6 6 6 1.4-1.4zm5.2 0l4.6-4.6-4.6-4.6L16 6l6 6-6 6-1.4-1.4z"/></svg></div>
                    <div class="jb-icon-box icon-blue"><svg viewBox="0 0 24 24"><path d="M17 1.01L7 1c-1.1 0-2 .9-2 2v18c0 1.1.9 2 2 2h10c1.1 0 2-.9 2-2V3c0-1.1-.9-1.99-2-1.99zM17 19H7V5h10v14z"/></svg></div>
                    <div class="jb-icon-box icon-purple"><svg viewBox="0 0 24 24"><path d="M21 19V5c0-1.1-.9-2-2-2H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2zM8.5 13.5l2.5 3.01L14.5 12l4.5 6H5l3.5-4.5z"/></svg></div>

                    <!-- Мелкие серые квадратики -->
                    <div class="jb-icon-box icon-gray" style="background: #aeb9e6;"></div>
                    <div class="jb-icon-box icon-gray"></div>
                    <div class="jb-icon-box icon-gray"></div>
                    <div class="jb-icon-box icon-gray"></div>
                </div>
            </div>
        `;
    }
};
