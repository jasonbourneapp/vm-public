const WebSocket = require('ws');
const http = require('http');

// 1. WebSocket сервер для расширения (порт 13171)
const wss = new WebSocket.Server({ port: 13171 });
let chromeSocket = null;
let pendingResponse = null; // Здесь будем хранить объект ответа для текущего CURL запроса

wss.on('connection', (ws) => {
    console.log('>>> Chrome Extension подключился!');
    chromeSocket = ws;

    // Слушаем сообщения от браузера
    ws.on('message', (message) => {
        const msgStr = message.toString();

        // Игнорируем пинги
        if (msgStr === 'ping') return;

        console.log(`<<< Ответ от Chrome (${msgStr.length} байт)`);

        // Если есть висящий HTTP запрос, который ждет ответа
        if (pendingResponse) {
            pendingResponse.writeHead(200);
            pendingResponse.end(msgStr + '\n');
            pendingResponse = null; // Очищаем ожидание
        } else {
            console.log('Получено сообщение, но никто его не ждал:', msgStr.slice(0, 50) + '...');
        }
    });

    ws.on('close', () => {
        console.log('>>> Chrome Extension отключился.');
        chromeSocket = null;
        // Если кто-то ждал ответа, сообщаем об обрыве
        if (pendingResponse) {
            pendingResponse.writeHead(500);
            pendingResponse.end('Ошибка: Chrome отключился во время выполнения запроса.\n');
            pendingResponse = null;
        }
    });

    ws.on('error', (e) => {
        console.error('WS Socket error:', e);
    });
});

// 2. HTTP сервер для CURL (порт 3001)
http.createServer((req, res) => {
    // Устанавливаем заголовки для корректного отображения текста
    res.setHeader('Content-Type', 'text/plain; charset=utf-8');

    if (!chromeSocket || chromeSocket.readyState !== WebSocket.OPEN) {
        res.writeHead(500);
        return res.end('Ошибка: Расширение Chrome не подключено к мосту. Откройте браузер.\n');
    }

    if (pendingResponse) {
        res.writeHead(429);
        return res.end('Ошибка: Мост занят другим запросом. Подождите.\n');
    }

    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', () => {
        // Если тело пустое (простой GET/POST без данных), просим просто текст
        const command = body.trim() || "get_text";

        console.log(`>>> Запрос от CURL: "${command}". Отправляю в Chrome...`);

        try {
            // Сохраняем ссылку на ответ HTTP
            pendingResponse = res;

            // Отправляем команду в Chrome
            chromeSocket.send(command);

            // Таймаут 30 секунд (HTML слепки могут быть большими)
            setTimeout(() => {
                if (pendingResponse === res) {
                    console.log('!!! Таймаут ожидания ответа.');
                    res.writeHead(504);
                    res.end('Ошибка: Таймаут ожидания ответа от Chrome (30 сек).\n');
                    pendingResponse = null;
                }
            }, 30000);

        } catch (e) {
            pendingResponse = null;
            res.writeHead(500);
            res.end('Ошибка отправки в сокет: ' + e.message + '\n');
        }
    });

}).listen(3001, () => {
    console.log('Bridge запущен на порту 3001.');
    console.log('WS сервер на порту 13171.');
    console.log('Ожидание подключения расширения...');
});
