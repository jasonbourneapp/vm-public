const WindowManager = {
    zIndexCounter: 100,
    ALWAYS_ON_TOP_Z: 10000, // Очень высокое значение для JB

    init: function(windowId, handleId) {
        const win = document.getElementById(windowId);
        const handle = document.getElementById(handleId);

        win.addEventListener('mousedown', () => {
            this.bringToFront(win);
        });

        let isDragging = false;
        let startX, startY, initialLeft, initialTop;

        handle.addEventListener('mousedown', (e) => {
            if (e.target.closest('.window-controls') || e.target.closest('.tab') || e.target.closest('.new-tab')) return;
            if (win.classList.contains('maximized')) return;

            isDragging = true;
            startX = e.clientX;
            startY = e.clientY;

            const rect = win.getBoundingClientRect();
            initialLeft = rect.left;
            initialTop = rect.top;

            document.body.style.userSelect = 'none';
        });

        document.addEventListener('mousemove', (e) => {
            if (!isDragging) return;
            const dx = e.clientX - startX;
            const dy = e.clientY - startY;
            win.style.left = `${initialLeft + dx}px`;
            win.style.top = `${initialTop + dy}px`;
        });

        document.addEventListener('mouseup', () => {
            isDragging = false;
            document.body.style.userSelect = '';
        });

        handle.addEventListener('dblclick', (e) => {
             if (e.target.closest('.window-controls') || e.target.closest('.tab')) return;
             const appName = windowId.replace('app-', '');
             this.toggleMaximize(appName);
        });
    },

    bringToFront: function(element) {
        // Если это JasonBourne, он всегда получает супер-Z-index
        if (element.id === 'app-jasonbourne') {
            element.style.zIndex = this.ALWAYS_ON_TOP_Z;
        } else {
            // Обычное окно получает инкремент
            this.zIndexCounter++;
            element.style.zIndex = this.zIndexCounter;

            // ПРИНУДИТЕЛЬНО возвращаем JasonBourne наверх, если он открыт
            const jbWindow = document.getElementById('app-jasonbourne');
            if (jbWindow && !jbWindow.classList.contains('closed')) {
                jbWindow.style.zIndex = this.ALWAYS_ON_TOP_Z;
            }
        }
    },

    toggleMaximize: function(appName) {
        const win = document.getElementById(`app-${appName}`);
        win.classList.toggle('maximized');
        this.bringToFront(win);
    }
};
