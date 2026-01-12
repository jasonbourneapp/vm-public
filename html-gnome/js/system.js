const System = {
    apps: {
        chrome: { isOpen: true, isMinimized: false },
        jasonbourne: { isOpen: false, isMinimized: false }
    },

    init: function() {
        this.updateClock();
        setInterval(() => this.updateClock(), 1000);

        this.updateDockUI('chrome');
        this.updateDockUI('jasonbourne');

        WindowManager.init('app-chrome', 'chrome-title-bar');
        WindowManager.init('app-jasonbourne', 'jb-title-bar');

        MeetTab.init();
        CodeTab.init();
        JasonBourneApp.init();
    },

    updateClock: function() {
        const now = new Date();
        const options = { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit', hour12: false };
        const timeString = now.toLocaleTimeString('en-US', options).replace(',', '');
        document.getElementById('clock').innerText = timeString;
    },

    toggleApp: function(appName) {
        const app = this.apps[appName];
        if (!app.isOpen) {
            this.openApp(appName);
        } else {
            if (app.isMinimized) {
                this.restoreApp(appName);
            } else {
                this.minimizeApp(appName);
            }
        }
    },

    openApp: function(appName) {
        const windowEl = document.getElementById(`app-${appName}`);
        this.apps[appName].isOpen = true;
        this.apps[appName].isMinimized = false;

        windowEl.classList.remove('closed');
        setTimeout(() => {
            windowEl.classList.remove('minimized');
            WindowManager.bringToFront(windowEl); // Это установит нужный z-index
        }, 10);

        this.updateDockUI(appName);
    },

    minimizeApp: function(appName) {
        const windowEl = document.getElementById(`app-${appName}`);
        this.apps[appName].isMinimized = true;
        windowEl.classList.add('minimized');
        this.updateDockUI(appName);
    },

    restoreApp: function(appName) {
        const windowEl = document.getElementById(`app-${appName}`);
        this.apps[appName].isMinimized = false;
        windowEl.classList.remove('minimized');
        WindowManager.bringToFront(windowEl);
        this.updateDockUI(appName);
    },

    closeApp: function(appName) {
        const windowEl = document.getElementById(`app-${appName}`);
        this.apps[appName].isOpen = false;
        this.apps[appName].isMinimized = false;

        windowEl.classList.add('minimized');
        setTimeout(() => {
            windowEl.classList.add('closed');
            windowEl.classList.remove('maximized');
            // Сброс позиций
            if (appName === 'chrome') {
                windowEl.style.top = '80px'; windowEl.style.left = '100px';
                windowEl.style.width = '900px'; windowEl.style.height = '600px';
            } else if (appName === 'jasonbourne') {
                windowEl.style.top = '100px'; windowEl.style.left = '150px';
                windowEl.style.width = '800px'; windowEl.style.height = '600px';
                windowEl.style.zIndex = ''; // Сброс z-index при закрытии
            }
        }, 300);

        this.updateDockUI(appName);
    },

    updateDockUI: function(appName) {
        const dockItem = document.querySelector(`.dock-item[onclick*="${appName}"]`);
        const app = this.apps[appName];
        if (app.isOpen) {
            dockItem.classList.add('running');
            if (!app.isMinimized) dockItem.classList.add('focused');
            else dockItem.classList.remove('focused');
        } else {
            dockItem.classList.remove('running', 'focused');
        }
    }
};

document.addEventListener('DOMContentLoaded', () => {
    System.init();
});
