#!/usr/bin/env python3
"""
Fallback para download de conteúdo privado do Instagram via Selenium.
Usa o sssinstagram.com como intermediário quando o yt-dlp falha.

Uso: python3 instagram_selenium.py <url> <output_dir>
Retorna JSON: {"success": true, "file": "/path/to/file.mp4"}
          ou: {"success": false, "error": "mensagem"}
"""

import sys
import os
import json
import time
import re
import shutil
import tempfile
import urllib.request
import urllib.parse

def log(msg):
    print(f"[selenium] {msg}", file=sys.stderr)

def download_via_selenium(url: str, output_dir: str) -> dict:
    try:
        from selenium import webdriver
        from selenium.webdriver.chrome.options import Options
        from selenium.webdriver.chrome.service import Service
        from selenium.webdriver.common.by import By
        from selenium.webdriver.support.ui import WebDriverWait
        from selenium.webdriver.support import expected_conditions as EC
        from webdriver_manager.chrome import ChromeDriverManager
    except ImportError as e:
        return {"success": False, "error": f"Selenium não instalado: {e}"}

    # Configura cache do webdriver-manager em local acessível pelo www-data
    os.environ['WDM_LOCAL'] = '1'
    os.environ['WDM_CACHE_PATH'] = '/opt/wdm-cache'
    # Define HOME temporário para evitar problemas com www-data
    os.environ['HOME'] = '/tmp'
    os.environ['XDG_CONFIG_HOME'] = '/tmp/.config'
    os.environ['XDG_DATA_HOME'] = '/tmp/.local/share'

    driver = None
    chrome_profile = None

    try:
        # Cria diretório de perfil temporário para o Chrome
        chrome_profile = tempfile.mkdtemp(prefix='chrome_profile_')
        log(f"Perfil Chrome: {chrome_profile}")

        opts = Options()
        opts.add_argument('--headless=new')
        opts.add_argument('--no-sandbox')
        opts.add_argument('--disable-dev-shm-usage')
        opts.add_argument('--disable-gpu')
        opts.add_argument('--disable-software-rasterizer')
        opts.add_argument('--disable-extensions')
        opts.add_argument('--disable-background-networking')
        opts.add_argument('--disable-default-apps')
        opts.add_argument('--disable-sync')
        opts.add_argument('--disable-translate')
        opts.add_argument('--metrics-recording-only')
        opts.add_argument('--mute-audio')
        opts.add_argument('--no-first-run')
        opts.add_argument('--safebrowsing-disable-auto-update')
        opts.add_argument('--window-size=1920,1080')
        opts.add_argument(f'--user-data-dir={chrome_profile}')
        opts.add_argument('--user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36')

        # Desabilita imagens para carregar mais rápido
        prefs = {"profile.managed_default_content_settings.images": 2}
        opts.add_experimental_option("prefs", prefs)

        log("Iniciando Chrome...")
        driver = webdriver.Chrome(
            service=Service(ChromeDriverManager().install()),
            options=opts
        )
        driver.set_page_load_timeout(30)

        # Abre o sssinstagram com a URL já preenchida via query string
        encoded_url = urllib.parse.quote(url, safe='')
        target = f"https://sssinstagram.com/pt?url={encoded_url}"
        log(f"Abrindo: {target}")
        driver.get(target)

        wait = WebDriverWait(driver, 20)

        # Aguarda o campo de input e preenche a URL
        try:
            input_field = wait.until(EC.presence_of_element_located(
                (By.CSS_SELECTOR, 'input[type="text"], input[type="url"], input.form-control')
            ))
            input_field.clear()
            input_field.send_keys(url)
            log("URL inserida no campo")
        except Exception:
            log("Campo de input não encontrado, tentando continuar...")

        # Clica no botão de download/busca
        try:
            btn = wait.until(EC.element_to_be_clickable(
                (By.CSS_SELECTOR, 'button[type="submit"], .btn-download, button.download-btn, button.submit-btn')
            ))
            btn.click()
            log("Botão clicado")
        except Exception:
            try:
                driver.execute_script("document.querySelector('form').submit()")
                log("Form submetido via JS")
            except Exception as e:
                log(f"Erro ao submeter: {e}")

        # Aguarda links de download aparecerem
        log("Aguardando links de download...")
        time.sleep(5)

        download_url = None

        # Estratégia 1: links diretos com .mp4
        links = driver.find_elements(
            By.CSS_SELECTOR,
            'a[href*=".mp4"], a[href*="download"], a.download-link, a[download]'
        )
        for link in links:
            href = link.get_attribute('href') or ''
            if href and ('mp4' in href or 'video' in href or 'cdninstagram' in href or 'fbcdn' in href):
                download_url = href
                log(f"Link mp4 encontrado: {download_url[:80]}...")
                break

        # Estratégia 2: botões com data-url ou data-href
        if not download_url:
            btns = driver.find_elements(By.CSS_SELECTOR, '[data-url], [data-href], [data-src]')
            for btn in btns:
                for attr in ['data-url', 'data-href', 'data-src']:
                    val = btn.get_attribute(attr) or ''
                    if val and ('mp4' in val or 'cdninstagram' in val or 'fbcdn' in val):
                        download_url = val
                        log(f"data-url encontrado: {download_url[:80]}...")
                        break
                if download_url:
                    break

        # Estratégia 3: procura no source da página
        if not download_url:
            page_source = driver.page_source
            patterns = [
                r'https://[^"\']+\.mp4[^"\']*',
                r'https://[^"\']*cdninstagram[^"\']+',
                r'https://[^"\']*fbcdn[^"\']+\.mp4[^"\']*',
            ]
            for pattern in patterns:
                matches = re.findall(pattern, page_source)
                if matches:
                    download_url = matches[0].replace('\\u0026', '&').replace('&amp;', '&')
                    log(f"URL encontrada no source: {download_url[:80]}...")
                    break

        if not download_url:
            driver.save_screenshot('/tmp/selenium_debug.png')
            log("Nenhum link encontrado. Screenshot salvo em /tmp/selenium_debug.png")
            return {"success": False, "error": "Não foi possível encontrar o link de download no sssinstagram"}

        # Baixa o arquivo
        log(f"Baixando arquivo...")
        filename = f"baixarmp{int(time.time())}player.mp4"
        output_path = os.path.join(output_dir, filename)

        req = urllib.request.Request(
            download_url,
            headers={
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                'Referer': 'https://sssinstagram.com/',
            }
        )
        with urllib.request.urlopen(req, timeout=60) as response:
            with open(output_path, 'wb') as f:
                while True:
                    chunk = response.read(65536)
                    if not chunk:
                        break
                    f.write(chunk)

        size = os.path.getsize(output_path)
        log(f"Arquivo baixado: {output_path} ({size} bytes)")

        if size < 1000:
            os.unlink(output_path)
            return {"success": False, "error": "Arquivo baixado muito pequeno, provavelmente inválido"}

        return {"success": True, "file": output_path}

    except Exception as e:
        log(f"Erro: {e}")
        return {"success": False, "error": str(e)}

    finally:
        if driver:
            try:
                driver.quit()
            except Exception:
                pass
        if chrome_profile and os.path.isdir(chrome_profile):
            shutil.rmtree(chrome_profile, ignore_errors=True)


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print(json.dumps({"success": False, "error": "Uso: instagram_selenium.py <url> <output_dir>"}))
        sys.exit(1)

    url = sys.argv[1]
    output_dir = sys.argv[2]

    if not os.path.isdir(output_dir):
        os.makedirs(output_dir, exist_ok=True)

    result = download_via_selenium(url, output_dir)
    print(json.dumps(result))
    sys.exit(0 if result["success"] else 1)
