// === KEEP ALIVE MECHANISM ===
// Chrome MV3 убивает воркеры через 30 секунд бездействия.
// Мы "дергаем" API каждые 5 секунд, чтобы сбросить этот таймер.
const keepAlive = () => {
    setInterval(() => {
        chrome.runtime.getPlatformInfo().then(() => {
            // Пустой вызов API не дает воркеру уснуть
        }).catch(() => {});
    }, 5000); // 5 секунд — это надежнее, чем 20
};
chrome.runtime.onStartup.addListener(keepAlive);
keepAlive();


// === WEBSOCKET LOGIC ===
let ws = null;
let pingInterval = null;
let connectionTimeout = null; // Таймер для сброса зависшего подключения

// Слушатель сообщений от скриптов (для scroll_copy)
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
    if (message && message.action === "SCROLL_CAPTURE_DONE") {
        console.log("Received async scroll data from content script");
        sendResponseToBridge(message.payload);
    }
});

function connect() {
    // Если уже подключено или в процессе подключения — выходим, чтобы не плодить дубли
    if (ws && (ws.readyState === WebSocket.OPEN || ws.readyState === WebSocket.CONNECTING)) {
        return;
    }

    // Создаем подключение
    ws = new WebSocket('ws://localhost:13171');

    // ЗАЩИТА ОТ ЗАВИСАНИЯ:
    // Если через 5 секунд не соединились (onopen не сработал),
    // принудительно закрываем и пробуем снова.
    connectionTimeout = setTimeout(() => {
        if (ws && ws.readyState !== WebSocket.OPEN) {
            console.log('Connection timed out, resetting...');
            ws.close(); // Это вызовет onclose и запустит ретрай
        }
    }, 5000);

    ws.onopen = () => {
        console.log('Connected to bridge (port 13171)');

        // Очищаем таймер сброса, так как мы успешно подключились
        if (connectionTimeout) clearTimeout(connectionTimeout);

        // Запускаем пинг внутри WS, чтобы прокси/роутеры не рвали соединение
        if (pingInterval) clearInterval(pingInterval);
        pingInterval = setInterval(() => {
            if (ws && ws.readyState === WebSocket.OPEN) {
                ws.send('ping');
            }
        }, 10000); // Пинг каждые 10 сек
    };

    ws.onmessage = async (event) => {
        const msg = event.data.trim();
        if (msg === 'pong') return;

        console.log('Request from curl:', msg);

        try {
            const [tab] = await chrome.tabs.query({ active: true, lastFocusedWindow: true });

            if (!tab) {
                sendResponseToBridge("Error: No active tab found.");
                return;
            }

            if (!tab.url || tab.url.startsWith("chrome://") || tab.url.startsWith("edge://")) {
                sendResponseToBridge("Error: Cannot access system pages.");
                return;
            }

            let scriptFile = '';
            let isAsync = false;

            switch (msg) {
                case 'get_text':
                    scriptFile = 'scripts/get_text.js';
                    break;
                case 'dump_html':
                    scriptFile = 'scripts/snapshot.js';
                    break;
                case 'copy_scroll':
                    scriptFile = 'scripts/scroll_copy.js';
                    isAsync = true;
                    break;
                default:
                    sendResponseToBridge("Error: Unknown command.");
                    return;
            }

            const result = await chrome.scripting.executeScript({
                target: { tabId: tab.id },
                files: [scriptFile]
            });

            if (!isAsync) {
                if (result && result[0]) {
                    const output = result[0].result;
                    sendResponseToBridge(output !== undefined ? output : "Done.");
                } else {
                    sendResponseToBridge("Error: Script failed.");
                }
            } else {
                console.log("Waiting for user interaction (scroll copy)...");
            }

        } catch (err) {
            console.error('Execution Error:', err);
            sendResponseToBridge("Error: " + err.message);
        }
    };

    ws.onclose = () => {
        console.log('Connection closed. Reconnecting in 1s...');
        cleanup();
        // РЕКОННЕКТ: Строго через 1 секунду
        setTimeout(connect, 1000);
    };

    ws.onerror = (err) => {
        console.error('WS Error:', err);
        // При ошибке ничего не делаем, ws.close() вызовется браузером
        // или сработает наш connectionTimeout, что приведет к onclose
        if (ws && ws.readyState !== WebSocket.CLOSED && ws.readyState !== WebSocket.CLOSING) {
             ws.close();
        }
    };
}

function cleanup() {
    if (pingInterval) clearInterval(pingInterval);
    if (connectionTimeout) clearTimeout(connectionTimeout);
    ws = null;
}

function sendResponseToBridge(data) {
    if (ws && ws.readyState === WebSocket.OPEN) {
        const payload = typeof data === 'object' ? JSON.stringify(data) : String(data);
        ws.send(payload);
    } else {
        console.error("Cannot send response, WS closed.");
    }
}

// Первичное подключение
connect();
