const resourcesLoaded = loadDependencies();

async function loadDependencies() {
  await Promise.all([
    injectScript('vendor/jspdf.umd.min.js'),
    injectScript('vendor/html2canvas.min.js'),
    injectScript('vendor/html-docx.js'),
    injectScript('vendor/katex.min.js'),
    injectStyle('vendor/katex.min.css')
  ]);
}

function injectScript(path) {
  return new Promise((resolve, reject) => {
    const script = document.createElement('script');
    script.src = chrome.runtime.getURL(path);
    script.async = false;
    script.onload = () => resolve();
    script.onerror = (err) => reject(err);
    document.documentElement.appendChild(script);
  });
}

function injectStyle(path) {
  return new Promise((resolve, reject) => {
    const link = document.createElement('link');
    link.rel = 'stylesheet';
    link.href = chrome.runtime.getURL(path);
    link.onload = () => resolve();
    link.onerror = (err) => reject(err);
    document.documentElement.appendChild(link);
  });
}

function createControlPanel() {
  if (document.getElementById('chatgpt-pro-exporter')) return;
  const panel = document.createElement('section');
  panel.id = 'chatgpt-pro-exporter';
  panel.innerHTML = `
    <header>
      <strong>Export</strong>
    </header>
    <button type="button" data-action="word">DOCX</button>
    <button type="button" data-action="pdf">PDF</button>
    <div class="hint">Форматирование: заголовки, списки, таблицы и формулы LaTeX</div>
  `;

  panel.addEventListener('click', async (event) => {
    const action = event.target.dataset?.action;
    if (!action) return;

    panel.classList.add('busy');
    try {
      await resourcesLoaded;
      if (action === 'word') {
        await exportToWord();
      } else if (action === 'pdf') {
        await exportToPdf();
      }
    } catch (error) {
      console.error('ChatGPT Pro Exporter error', error);
      alert('Не удалось выполнить экспорт. Подробности в консоли.');
    } finally {
      panel.classList.remove('busy');
    }
  });

  document.body.appendChild(panel);
}

function detectTurns() {
  const selectors = [
    '[data-testid="conversation-turn"]',
    'article:has([data-message-author-role])',
    'article'
  ];
  for (const selector of selectors) {
    const nodes = Array.from(document.querySelectorAll(selector));
    if (nodes.length) return nodes;
  }
  return [];
}

function normalizeTurn(node, index) {
  const role = node.getAttribute('data-message-author-role') ||
    node.querySelector('[data-testid="message-badge"]')?.textContent?.trim() ||
    node.querySelector('[data-vertical-navigation-label]')?.textContent?.trim() ||
    (index % 2 === 0 ? 'user' : 'assistant');
  const message = node.querySelector('[data-message-author-role]') || node;
  const html = message.innerHTML;
  const text = message.textContent?.trim() || '';
  return { role: role || 'assistant', html, text };
}

function renderMath(html) {
  if (!window.katex) return html;
  return html.replace(/\$\$(.+?)\$\$|\$(.+?)\$/gs, (match, blockExpr, inlineExpr) => {
    const expression = blockExpr || inlineExpr;
    try {
      const rendered = window.katex.renderToString(expression, {
        throwOnError: false,
        displayMode: Boolean(blockExpr)
      });
      return rendered;
    } catch (error) {
      console.warn('KaTeX render error', error);
      return match;
    }
  });
}

function buildDocumentHtml(turns) {
  const body = turns.map((turn, index) => {
    const renderedHtml = renderMath(turn.html);
    return `
      <article class="message ${turn.role}">
        <header>
          <span class="pill">${turn.role === 'user' ? 'Пользователь' : 'ChatGPT'}</span>
          <span class="index">#${index + 1}</span>
        </header>
        <div class="content">${renderedHtml}</div>
      </article>
    `;
  }).join('\n');

  return `
    <html>
      <head>
        <meta charset="utf-8" />
        <style>
          body { font-family: 'Calibri', 'Segoe UI', system-ui, sans-serif; font-size: 12pt; color: #0f172a; line-height: 1.5; margin: 24px; }
          h1, h2, h3, h4 { font-weight: 600; color: #111827; }
          .message { border: 1px solid #e5e7eb; border-radius: 12px; padding: 16px 18px; margin-bottom: 14px; background: #fff; }
          .message.assistant { background: #f8fafc; }
          .pill { display: inline-block; padding: 4px 10px; border-radius: 9999px; font-size: 10pt; background: #0ea5e9; color: white; letter-spacing: 0.01em; }
          .message.assistant .pill { background: #10b981; }
          .index { color: #6b7280; margin-left: 8px; font-size: 10pt; }
          .content { margin-top: 8px; }
          ul, ol { padding-left: 20px; }
          table { width: 100%; border-collapse: collapse; margin: 10px 0; }
          table, th, td { border: 1px solid #d1d5db; }
          th, td { padding: 8px; text-align: left; }
          code, pre { font-family: 'JetBrains Mono', 'Fira Code', monospace; background: #f3f4f6; padding: 2px 4px; border-radius: 4px; }
          pre { padding: 10px; overflow: auto; }
          .katex-display { margin: 12px 0; }
        </style>
      </head>
      <body>
        <h1>Экспорт диалога ChatGPT</h1>
        ${body}
      </body>
    </html>
  `;
}

async function exportToWord() {
  const turns = detectTurns().map(normalizeTurn);
  if (!turns.length) throw new Error('Не удалось найти сообщения для экспорта');
  const html = buildDocumentHtml(turns);
  const blob = window.htmlDocx.asBlob(html, { orientation: 'portrait', margins: { top: 720, bottom: 720, left: 720, right: 720 } });
  downloadBlob(blob, makeFileName('docx'));
}

async function exportToPdf() {
  const turns = detectTurns().map(normalizeTurn);
  if (!turns.length) throw new Error('Не удалось найти сообщения для экспорта');
  const html = buildDocumentHtml(turns);
  const doc = new window.jspdf.jsPDF({ unit: 'pt', format: 'a4' });
  const container = document.createElement('div');
  container.style.width = '780px';
  container.style.padding = '24px';
  container.innerHTML = html;
  document.body.appendChild(container);
  await doc.html(container, {
    callback: () => {
      downloadBlob(doc.output('blob'), makeFileName('pdf'));
      container.remove();
    },
    autoPaging: 'text',
    html2canvas: window.html2canvas
  });
}

function downloadBlob(blob, filename) {
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  link.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

function makeFileName(extension) {
  const date = new Date().toISOString().replace(/[:T]/g, '-').split('.')[0];
  return `chatgpt-export-${date}.${extension}`;
}

function init() {
  createControlPanel();
}

document.addEventListener('DOMContentLoaded', init);
if (document.readyState === 'complete' || document.readyState === 'interactive') {
  init();
}
