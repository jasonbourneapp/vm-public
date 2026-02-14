(async function() {
    try {
        console.log("Запуск сверхглубокого запекания (автономный режим)...");
        const baseUrl = window.location.href;
        const toAbsolute = (url) => {
            if (!url || /^(data:|http|https|\/\/)/.test(url)) return url;
            try { return new URL(url, baseUrl).href; } catch(e) { return url; }
        };

        function getStylesFromRoot(root) {
            let css = "";
            try {
                const sheets = root.styleSheets || [];
                for (let i = 0; i < sheets.length; i++) {
                    const sheet = sheets[i];
                    try {
                        const rules = sheet.cssRules || sheet.rules;
                        for (let j = 0; j < rules.length; j++) css += rules[j].cssText + "\n";
                    } catch (e) {}
                }
            } catch (e) {}
            try {
                if (root.adoptedStyleSheets) {
                    root.adoptedStyleSheets.forEach(sheet => {
                        try {
                            const rules = sheet.cssRules || [];
                            for (let i = 0; i < rules.length; i++) css += rules[i].cssText + "\n";
                        } catch (e) {}
                    });
                }
            } catch (e) {}
            return css;
        }

        const globalDynamicStyles = getStylesFromRoot(document);

        function bake(node) {
            if (node.nodeType === Node.TEXT_NODE) return document.createTextNode(node.nodeValue);
            if (node.nodeType !== Node.ELEMENT_NODE) return null;

            const tag = node.tagName.toUpperCase();
            if (['SCRIPT', 'NOSCRIPT', 'IFRAME', 'OBJECT', 'EMBED'].includes(tag)) return null;

            let clone;
            if (tag === 'CANVAS') {
                clone = document.createElement('img');
                try { clone.src = node.toDataURL(); } catch(e) { clone = document.createElement('div'); }
            } else {
                clone = document.createElement(tag);
            }

            for (let i = 0; i < node.attributes.length; i++) {
                const attr = node.attributes[i];
                if (attr.name.startsWith('on')) continue;
                let val = attr.value;
                if (['src', 'href', 'poster', 'data'].includes(attr.name)) val = toAbsolute(val);
                if (attr.name === 'srcset') {
                    val = val.split(',').map(s => {
                        const parts = s.trim().split(' ');
                        parts[0] = toAbsolute(parts[0]);
                        return parts.join(' ');
                    }).join(', ');
                }
                if (attr.name === 'style') {
                    val = val.replace(/url\(['"]?(.*?)['"]?\)/g, (m, p1) => `url("${toAbsolute(p1)}")`);
                }
                clone.setAttribute(attr.name, val);
            }

            if (tag === 'A') {
                clone.removeAttribute('href');
                clone.style.cursor = 'text';
            }

            if (node.shadowRoot) {
                const shadowContent = document.createElement('div');
                shadowContent.setAttribute('data-shadow-host', tag);
                shadowContent.style.display = 'contents';
                const shadowStyles = getStylesFromRoot(node.shadowRoot);
                if (shadowStyles) {
                    const st = document.createElement('style');
                    st.innerHTML = shadowStyles.replace(/url\(['"]?(.*?)['"]?\)/g, (m, p1) => `url("${toAbsolute(p1)}")`);
                    shadowContent.appendChild(st);
                }
                for (let i = 0; i < node.shadowRoot.childNodes.length; i++) {
                    const b = bake(node.shadowRoot.childNodes[i]);
                    if (b) shadowContent.appendChild(b);
                }
                clone.appendChild(shadowContent);
            }

            for (let i = 0; i < node.childNodes.length; i++) {
                const b = bake(node.childNodes[i]);
                if (b) clone.appendChild(b);
            }

            if (tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT') {
                if (node.type === 'checkbox' || node.type === 'radio') {
                    if (node.checked) clone.setAttribute('checked', '');
                } else {
                    clone.setAttribute('value', node.value);
                    if (tag === 'TEXTAREA') clone.textContent = node.value;
                }
                if (tag === 'SELECT') {
                    for (let i = 0; i < node.options.length; i++) {
                        if (node.options[i].selected && clone.options[i]) clone.options[i].setAttribute('selected', '');
                    }
                }
            }
            return clone;
        }

        const bakedDoc = bake(document.documentElement);
        const finalStyle = document.createElement('style');
        finalStyle.innerHTML = `
            ${globalDynamicStyles.replace(/url\(['"]?(.*?)['"]?\)/g, (m, p1) => `url("${toAbsolute(p1)}")`)}
            *, html, body { -webkit-user-select: text !important; user-select: text !important; pointer-events: auto !important; }
            a { cursor: text !important; text-decoration: none !important; }
            .monaco-editor, .ace_editor, .ace_scroller, .monaco-scrollable-element { pointer-events: auto !important; user-select: text !important; }
            .cursor, .monaco-mouse-cursor-text, .ace_cursor-layer, .ace_marker-layer, .ace_scrollbar { display: none !important; }
            .view-lines, .view-line, .ace_line, .ace_text-layer { pointer-events: auto !important; user-select: text !important; }
        `;
        const head = bakedDoc.querySelector('head') || bakedDoc.insertBefore(document.createElement('head'), bakedDoc.firstChild);
        head.appendChild(finalStyle);

        const htmlContent = "<!DOCTYPE html>\n" + bakedDoc.outerHTML;
        const blob = new Blob([htmlContent], { type: 'text/html' });
        const link = document.createElement('a');
        link.href = URL.createObjectURL(blob);
        link.download = 'snapshot_' + new Date().getTime() + '.html';
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
    } catch (e) {
        console.error(e);
        alert("Ошибка запекания: " + e.message);
    }
})();