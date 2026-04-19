/* VideoDown — script.js */
'use strict';

const $ = id => document.getElementById(id);

const fetchBtn      = $('fetchBtn');
const videoUrlInput = $('videoUrl');
const pasteBtn      = $('pasteBtn');
const resultSection = $('resultSection');
const resultCard    = $('resultCard');
const loadingSection = $('loadingSection');
const errorSection  = $('errorSection');
const errorMessage  = $('errorMessage');

// ─── Colar da área de transferência ───
pasteBtn.addEventListener('click', async () => {
    try {
        const text = await navigator.clipboard.readText();
        videoUrlInput.value = text.trim();
        videoUrlInput.focus();
    } catch {
        videoUrlInput.focus();
        showToast('Use Ctrl+V para colar.', 'error');
    }
});

// ─── Buscar ao pressionar Enter ───
videoUrlInput.addEventListener('keydown', e => {
    if (e.key === 'Enter') fetchVideo();
});

fetchBtn.addEventListener('click', fetchVideo);

// ─── Buscar informações do vídeo ───
async function fetchVideo() {
    const url = videoUrlInput.value.trim();

    if (!url) {
        videoUrlInput.focus();
        showToast('Cole um link primeiro.', 'error');
        return;
    }

    if (!isValidUrl(url)) {
        showToast('Link inválido. Verifique e tente novamente.', 'error');
        return;
    }

    showLoading();

    try {
        const res = await fetch('api.php?action=fetch', {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: 'url=' + encodeURIComponent(url),
        });

        const json = await res.json();

        if (!json.success) {
            showError(json.error || 'Erro desconhecido.');
            return;
        }

        renderResult(json.data);
    } catch (err) {
        showError('Falha na conexão. Verifique sua internet e tente novamente.');
    }
}

// ─── Renderiza o card de resultado ───
function renderResult(data) {
    const thumbHtml = data.thumbnail
        ? `<img class="result-thumb" src="${escHtml(data.thumbnail)}" alt="Thumbnail" loading="lazy" onerror="this.replaceWith(thumbPlaceholder())">`
        : thumbPlaceholder().outerHTML;

    const formatsHtml = data.formats.map(fmt => `
        <div class="format-item">
            <div class="format-info">
                <div class="format-icon ${fmt.type}">
                    ${fmt.type === 'audio'
                        ? `<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24"><path fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2 10v3m4-7v11m4-14v18m4-13v7m4-10v13m4-8v3"/></svg>`
                        : `<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24"><path fill="currentColor" fill-rule="evenodd" d="M12 21a9 9 0 1 0 0-18a9 9 0 0 0 0 18M10.783 7.99l5.644 3.136a1 1 0 0 1 0 1.748l-5.644 3.136A1.2 1.2 0 0 1 9 14.96V9.04a1.2 1.2 0 0 1 1.783-1.05" clip-rule="evenodd"/></svg>`
                    }
                </div>
                <div>
                    <div class="format-label">${escHtml(fmt.label)}</div>
                    ${fmt.filesize ? `<div class="format-size">${escHtml(fmt.filesize)}</div>` : ''}
                </div>
            </div>
            <button
                class="btn-download"
                data-url="${escHtml(data.url)}"
                data-format="${escHtml(fmt.id)}"
                data-type="${escHtml(fmt.type)}"
                data-label="${escHtml(fmt.label)}"
                onclick="startDownload(this)"
            >
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none">
                    <path d="M12 3v13M12 16l-4-4M12 16l4-4M3 20h18" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>
                </svg>
                Baixar
            </button>
        </div>
    `).join('');

    resultCard.innerHTML = `
        <div class="result-header">
            ${thumbHtml}
            <div class="result-meta">
                <span class="result-platform">${escHtml(data.platform)}</span>
                <div class="result-title">${escHtml(data.title)}</div>
                <div class="result-info">
                    ${data.uploader ? `<span>${escHtml(data.uploader)}</span>` : ''}
                    ${data.duration  ? `<span>${escHtml(data.duration)}</span>` : ''}
                </div>
            </div>
        </div>
        <div class="formats-section">
            <h3>Escolha o formato</h3>
            <div class="format-list">${formatsHtml}</div>
        </div>
    `;

    hideAll();
    resultSection.style.display = 'block';
    resultSection.scrollIntoView({ behavior: 'smooth', block: 'start' });
}

// ─── Inicia o download ───
async function startDownload(btn) {
    const url      = btn.dataset.url;
    const formatId = btn.dataset.format;
    const type     = btn.dataset.type;
    const label    = btn.dataset.label;

    // Estado de carregamento no botão
    btn.disabled = true;
    btn.classList.add('downloading');
    btn.innerHTML = `
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" style="animation:spin .8s linear infinite">
            <circle cx="12" cy="12" r="9" stroke="currentColor" stroke-width="2" stroke-dasharray="28 56"/>
        </svg>
        Baixando...
    `;

    // Adiciona barra de progresso indeterminada
    const progressHtml = `
        <div class="download-progress" id="dlProgress">
            <div class="progress-bar-wrap">
                <div class="progress-bar-fill" id="dlBar" style="width:0%"></div>
            </div>
            <div class="progress-label" id="dlLabel">Preparando download de "${escHtml(label)}"...</div>
        </div>
    `;

    // Insere após o format-list se ainda não existir
    if (!document.getElementById('dlProgress')) {
        resultCard.insertAdjacentHTML('beforeend', progressHtml);
    }

    animateProgressBar();

    try {
        const res = await fetch('api.php?action=download', {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: `url=${encodeURIComponent(url)}&format_id=${encodeURIComponent(formatId)}&type=${encodeURIComponent(type)}`,
        });

        if (!res.ok) {
            // Tenta ler o JSON de erro
            const json = await res.json().catch(() => ({ error: 'Erro no servidor.' }));
            throw new Error(json.error || 'Erro no servidor.');
        }

        // Verifica se é JSON (erro) ou binário (arquivo)
        const contentType = res.headers.get('Content-Type') || '';
        if (contentType.includes('application/json')) {
            const json = await res.json();
            throw new Error(json.error || 'Erro desconhecido.');
        }

        // Obtém o blob e dispara o download
        const blob = await res.blob();
        const ext  = getExtFromContentType(contentType);
        const filename = `videodown_${Date.now()}.${ext}`;

        const objectUrl = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = objectUrl;
        a.download = filename;
        document.body.appendChild(a);
        a.click();
        a.remove();
        URL.revokeObjectURL(objectUrl);

        showToast('Download concluído!', 'success');
        finishProgress();
    } catch (err) {
        showToast(err.message || 'Falha no download.', 'error');
        removeProgress();
    } finally {
        btn.disabled = false;
        btn.classList.remove('downloading');
        btn.innerHTML = `
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none">
                <path d="M12 3v13M12 16l-4-4M12 16l4-4M3 20h18" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>
            </svg>
            Baixar
        `;
    }
}

// ─── Animação da barra de progresso ───
let progressInterval = null;

function animateProgressBar() {
    const bar   = $('dlBar');
    const label = $('dlLabel');
    if (!bar) return;

    let pct = 0;
    clearInterval(progressInterval);
    progressInterval = setInterval(() => {
        // Sobe rápido até 80%, depois devagar
        const step = pct < 80 ? 2 : 0.3;
        pct = Math.min(pct + step, 95);
        bar.style.width = pct + '%';
        if (label) label.textContent = `Processando... ${Math.round(pct)}%`;
    }, 200);
}

function finishProgress() {
    clearInterval(progressInterval);
    const bar   = $('dlBar');
    const label = $('dlLabel');
    if (bar)   bar.style.width = '100%';
    if (label) label.textContent = 'Concluído!';
    setTimeout(removeProgress, 1500);
}

function removeProgress() {
    clearInterval(progressInterval);
    const el = $('dlProgress');
    if (el) el.remove();
}

// ─── Estados da UI ───
function showLoading() {
    hideAll();
    loadingSection.style.display = 'block';
    fetchBtn.disabled = true;
}

function showError(msg) {
    hideAll();
    errorMessage.textContent = msg;
    errorSection.style.display = 'block';
    fetchBtn.disabled = false;
}

function hideAll() {
    resultSection.style.display  = 'none';
    loadingSection.style.display = 'none';
    errorSection.style.display   = 'none';
    fetchBtn.disabled = false;
}

function resetForm() {
    hideAll();
    videoUrlInput.value = '';
    videoUrlInput.focus();
}

// ─── Helpers ───
function isValidUrl(str) {
    try {
        const u = new URL(str);
        return u.protocol === 'http:' || u.protocol === 'https:';
    } catch { return false; }
}

function escHtml(str) {
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
}

function thumbPlaceholder() {
    const div = document.createElement('div');
    div.className = 'result-thumb-placeholder';
    div.innerHTML = `<svg width="40" height="40" viewBox="0 0 24 24" fill="none">
        <rect x="2" y="2" width="20" height="20" rx="4" stroke="#444" stroke-width="1.5"/>
        <path d="M10 8l6 4-6 4V8z" fill="#444"/>
    </svg>`;
    return div;
}

function getExtFromContentType(ct) {
    if (ct.includes('mp4'))  return 'mp4';
    if (ct.includes('webm')) return 'webm';
    if (ct.includes('mpeg') || ct.includes('mp3')) return 'mp3';
    if (ct.includes('m4a'))  return 'm4a';
    if (ct.includes('ogg'))  return 'ogg';
    return 'mp4';
}

// ─── Toast ───
function showToast(msg, type = 'success') {
    const existing = document.querySelector('.toast');
    if (existing) existing.remove();

    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    toast.textContent = msg;
    document.body.appendChild(toast);

    setTimeout(() => {
        toast.style.opacity = '0';
        toast.style.transition = 'opacity .3s';
        setTimeout(() => toast.remove(), 300);
    }, 3500);
}

// Expõe para uso inline no HTML
window.startDownload = startDownload;
window.resetForm     = resetForm;
