const MeetTab = {
    init: function() {
        const container = document.getElementById('tab-content-1');
        container.innerHTML = `
            <div class="meet-container">
                <div class="meet-grid">
                    <!-- Собеседник (Интервьюер) -->
                    <div class="meet-participant">
                        <div class="participant-avatar speaking">
                            <span>AS</span>
                        </div>
                        <div class="participant-name">Alexey Senior (Interviewer)</div>
                        <div class="mic-icon-overlay">
                            <svg fill="white" width="16" height="16" viewBox="0 0 24 24"><path d="M12 14c1.66 0 3-1.34 3-3V5c0-1.66-1.34-3-3-3S9 3.34 9 5v6c0 1.66 1.34 3 3 3z"/><path d="M17 11c0 2.76-2.24 5-5 5s-5-2.24-5-5H5c0 3.53 2.61 6.43 6 6.92V21h2v-3.08c3.39-.49 6-3.39 6-6.92h-2z"/></svg>
                        </div>
                    </div>

                    <!-- Я (PIP) -->
                    <div class="meet-self">
                        <div style="color:white; font-size:12px;">You</div>
                    </div>
                </div>

                <!-- Панель управления -->
                <div class="meet-controls">
                    <div class="meet-btn"><svg viewBox="0 0 24 24" width="24" height="24" fill="currentColor"><path d="M12 14c1.66 0 3-1.34 3-3V5c0-1.66-1.34-3-3-3S9 3.34 9 5v6c0 1.66 1.34 3 3 3z"/><path d="M17 11c0 2.76-2.24 5-5 5s-5-2.24-5-5H5c0 3.53 2.61 6.43 6 6.92V21h2v-3.08c3.39-.49 6-3.39 6-6.92h-2z"/></svg></div>
                    <div class="meet-btn"><svg viewBox="0 0 24 24" width="24" height="24" fill="currentColor"><path d="M15 8v8H5V8h10m1-2H4c-.55 0-1 .45-1 1v10c0 .55.45 1 1 1h12c.55 0 1-.45 1-1v-3.5l4 4v-11l-4 4V7c0-.55-.45-1-1-1z"/></svg></div>
                    <div class="meet-btn"><svg viewBox="0 0 24 24" width="24" height="24" fill="currentColor"><path d="M19 11h-1.7c0 .74-.16 1.43-.43 2.05l1.23 1.23c.56-.98.9-2.09.9-3.28zm-4.02.17c0-.06.02-.11.02-.17V5c0-1.66-1.34-3-3-3S9 3.34 9 5v.18l5.98 5.99zM4.27 3L3 4.27l6.01 6.01V11c0 1.66 1.33 3 2.99 3 .22 0 .44-.03.65-.08l2.97 2.97c-.85.35-1.76.57-2.75.59v-1.9c-2.14-.2-3.87-1.93-4.07-4.07h-1.9c.2 3.08 2.62 5.54 5.76 5.75V21h1.41v-2.61c.91-.06 1.77-.3 2.55-.68l2.75 2.75 1.27-1.27L4.27 3z"/></svg></div>
                    <div class="meet-btn hangup" onclick="System.closeApp('chrome')"><svg viewBox="0 0 24 24" width="24" height="24" fill="currentColor"><path d="M12 9c-1.6 0-3.15.25-4.6.72v3.1c0 .39-.23.74-.56.9-.98.49-1.87 1.12-2.66 1.85-.18.18-.43.28-.7.28-.28 0-.53-.11-.71-.29L.29 13.08c-.18-.17-.29-.42-.29-.7 0-.28.11-.53.29-.71C3.34 8.36 7.46 6 12 6s8.66 2.36 11.71 5.67c.18.18.29.43.29.71 0 .28-.11.53-.29.71l-2.48 2.48c-.18.18-.43.29-.71.29-.27 0-.52-.11-.7-.28-.79-.74-1.69-1.36-2.67-1.85-.33-.16-.56-.5-.56-.9v-3.1C15.15 9.25 13.6 9 12 9z"/></svg></div>
                </div>
            </div>
        `;
    }
};
