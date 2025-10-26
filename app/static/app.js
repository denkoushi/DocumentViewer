(() => {
  const config = window.DOCVIEWER_CONFIG || {};
  const apiBaseRaw = typeof config.apiBase === 'string' ? config.apiBase.trim() : '';
  const apiBase = apiBaseRaw.endsWith('/') ? apiBaseRaw.slice(0, -1) : apiBaseRaw;
  const apiToken = typeof config.apiToken === 'string' ? config.apiToken.trim() : '';

  const buildApiUrl = (path) => {
    const normalized = path.startsWith('/') ? path : `/${path}`;
    if (!apiBase) {
      return normalized;
    }
    return `${apiBase}${normalized}`;
  };

  const buildHeaders = () => {
    const headers = {
      Accept: 'application/json',
    };
    if (apiToken) {
      headers.Authorization = `Bearer ${apiToken}`;
    }
    return headers;
  };

  const resolveDocumentUrl = (url) => {
    if (!url) {
      return '';
    }
    const absolutePattern = /^(?:[a-z]+:)?\/\//i;
    if (absolutePattern.test(url)) {
      return url;
    }
    if (!apiBase) {
      return url;
    }
    const normalized = url.startsWith('/') ? url : `/${url}`;
    return `${apiBase}${normalized}`;
  };

  const app = document.getElementById('app');
  const barcodeInput = document.getElementById('barcode-input');
  const manualOpenButton = document.getElementById('manual-open');
  const statusIndicator = document.getElementById('status-indicator');
  const viewerPartNumber = document.getElementById('viewer-part-number');
  const viewerFilename = document.getElementById('viewer-filename');
  const pdfFrame = document.getElementById('pdf-frame');
  const returnButton = document.getElementById('return-to-idle');
  const errorResetButton = document.getElementById('error-reset');
  const errorMessage = document.getElementById('error-message');
  const errorTimer = document.getElementById('error-timer');

  let errorTimeoutId = null;
  let countdownIntervalId = null;
  const isEmbedded = window.self !== window.top;
  let currentPartNumber = '';
  let currentFilename = '';

  const notifyParent = (state) => {
    if (window.parent && window.parent !== window) {
      try {
        window.parent.postMessage({
          type: 'viewer-state',
          state,
          part: currentPartNumber,
          filename: currentFilename
        }, '*');
      } catch (_) {}
    }
  };

  const setState = (state) => {
    app.dataset.state = state;
    app.classList.toggle('scan-ready', state === 'idle');
    switch (state) {
      case 'idle':
        statusIndicator.textContent = '待機中';
        barcodeInput.value = '';
        pdfFrame.src = '';
        viewerPartNumber.textContent = '';
        viewerFilename.textContent = '';
        currentPartNumber = '';
        currentFilename = '';
        clearTimers();
        focusInput();
        break;
      case 'viewer':
        statusIndicator.textContent = '表示中';
        clearTimers();
        break;
      case 'error':
        statusIndicator.textContent = 'エラー';
        break;
      case 'searching':
        statusIndicator.textContent = '検索中…';
        focusInput();
        break;
      default:
        statusIndicator.textContent = '';
    }
    statusIndicator.dataset.state = state;
    ensureFocus();
    notifyParent(state);
  };

  const clearTimers = () => {
    if (errorTimeoutId) {
      clearTimeout(errorTimeoutId);
      errorTimeoutId = null;
    }
    if (countdownIntervalId) {
      clearInterval(countdownIntervalId);
      countdownIntervalId = null;
    }
    errorTimer.textContent = '';
  };

  const focusInput = () => {
    if (!barcodeInput) return;
    try {
      barcodeInput.focus({ preventScroll: true });
    } catch (_) {
      barcodeInput.focus();
    }
  };

  const ensureFocus = () => {
    if (document.activeElement !== barcodeInput) {
      focusInput();
    }
  };

  window.addEventListener('load', () => {
    if (!isEmbedded) {
      ensureFocus();
    } else {
      focusInput();
    }
    setState('idle');
  });

  if (!isEmbedded) {
    setInterval(ensureFocus, 1500);
  }

  const lookupDocument = async (partNumber) => {
    const trimmed = partNumber.trim();
    if (!trimmed) {
      return;
    }

    if (window.parent && window.parent !== window) {
      try {
        window.parent.postMessage({ type: 'dv-barcode', part: trimmed, order: '' }, '*');
      } catch (_) {}
    }

    setState('searching');

    try {
      const response = await fetch(buildApiUrl(`/api/documents/${encodeURIComponent(trimmed)}`), {
        headers: buildHeaders(),
      });

      if (!response.ok) {
        const data = await response.json().catch(() => ({ message: 'document not found' }));
        throw new Error(data.message || 'document not found');
      }

      const data = await response.json();
      currentPartNumber = trimmed;
      currentFilename = data.filename;
      viewerPartNumber.textContent = trimmed;
      viewerFilename.textContent = data.filename;
      const documentUrl = resolveDocumentUrl(data.url);
      pdfFrame.src = documentUrl ? `${documentUrl}#toolbar=1&navpanes=0` : '';
      setState('viewer');
      notifyParent('viewer');
      if (window.parent && window.parent !== window) {
        try {
          window.parent.postMessage({ type: 'dv-barcode', part: trimmed, order: data.order || '' }, '*');
        } catch (_) {}
      }
    } catch (error) {
      console.error(error);
      displayError(trimmed, error.message || '該当資料が見つかりません');
    } finally {
      barcodeInput.value = '';
    }
  };

  const displayError = (partNumber, message) => {
    errorMessage.textContent = `部品番号「${partNumber}」: ${message}`;
    setState('error');
    startErrorCountdown();
  };

  const startErrorCountdown = (seconds = 5) => {
    let remaining = seconds;
    errorTimer.textContent = `${remaining} 秒後に待機画面に戻ります`;

    countdownIntervalId = setInterval(() => {
      remaining -= 1;
      if (remaining <= 0) {
        clearTimers();
        setState('idle');
      } else {
        errorTimer.textContent = `${remaining} 秒後に待機画面に戻ります`;
      }
    }, 1000);

    errorTimeoutId = setTimeout(() => {
      clearTimers();
      setState('idle');
    }, seconds * 1000);
  };

  barcodeInput.addEventListener('keydown', (event) => {
    if (event.key === 'Enter') {
      event.preventDefault();
      lookupDocument(barcodeInput.value);
    } else if (event.key === 'Escape') {
      event.preventDefault();
      setState('idle');
    }
  });

  manualOpenButton.addEventListener('click', () => {
    lookupDocument(barcodeInput.value);
  });

  returnButton.addEventListener('click', () => {
    setState('idle');
  });

  errorResetButton.addEventListener('click', () => {
    setState('idle');
  });

  document.addEventListener('visibilitychange', () => {
    if (!document.hidden) {
      ensureFocus();
    }
  });

  window.addEventListener('click', () => {
    ensureFocus();
  });

  window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || typeof data !== 'object') return;
    if (data.type === 'focus-request') {
      focusInput();
      return;
    }
    if (data.type === 'viewer-return') {
      setState('idle');
    }
  });
})();
