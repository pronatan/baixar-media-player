 <?php
/**
 * api.php — Endpoint AJAX para buscar informações e baixar vídeos
 * Requer: yt-dlp instalado no servidor (https://github.com/yt-dlp/yt-dlp)
 */

// Sem limite de tempo para downloads grandes
set_time_limit(0);
ini_set('memory_limit', '256M');

// Carrega variáveis do arquivo .env se existir
$_envFile = __DIR__ . '/.env';
if (is_file($_envFile)) {
    foreach (file($_envFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $_line) {
        if (str_starts_with(trim($_line), '#') || !str_contains($_line, '=')) continue;
        [$_k, $_v] = explode('=', $_line, 2);
        $_k = trim($_k); $_v = trim($_v);
        if ($_k && !getenv($_k)) putenv("$_k=$_v");
    }
}

header('Content-Type: application/json; charset=utf-8');
header('X-Content-Type-Options: nosniff');

// Configurações
define('YTDLP_PATH', getenv('YTDLP_PATH') ?: (PHP_OS_FAMILY === 'Windows' ? __DIR__ . '/yt-dlp.exe' : 'python3.11 -m yt_dlp'));   // caminho do binário
define('DOWNLOAD_DIR', __DIR__ . '/downloads/');
define('MAX_FILESIZE_MB', 500);
define('CONCURRENT_FRAGMENTS', 16);
define('BUFFER_SIZE', 1048576);

// Proxy residencial — configure via variável de ambiente ou direto aqui
// Formato: 'http://usuario:senha@host:porta' ou deixe vazio para sem proxy
define('PROXY_URL', getenv('YTDLP_PROXY') ?: '');

// Lista de proxies para rotação (se PROXY_URL estiver vazio, usa esta lista)
// Configure via variável de ambiente YTDLP_PROXY_LIST como JSON:
// ["http://user:pass@host:porta", ...]
$_proxy_list_raw = getenv('YTDLP_PROXY_LIST');
define('PROXY_LIST', $_proxy_list_raw ? json_decode($_proxy_list_raw, true) : []);

// Arquivo de cookies exportado do navegador (resolve Instagram/TikTok com login)
define('COOKIES_FILE', is_file(__DIR__ . '/cookies.txt') ? __DIR__ . '/cookies.txt' : '');
define('ALLOWED_DOMAINS', [
    'tiktok.com', 'vm.tiktok.com', 'vt.tiktok.com',
    'instagram.com', 'www.instagram.com',
    'facebook.com', 'www.facebook.com', 'fb.watch',
    'youtube.com', 'www.youtube.com', 'youtu.be',
    'twitter.com', 'x.com', 't.co',
]);

// Criar diretório de downloads se não existir
if (!is_dir(DOWNLOAD_DIR)) {
    mkdir(DOWNLOAD_DIR, 0755, true);
}

// Roteamento
$action = $_GET['action'] ?? $_POST['action'] ?? '';

switch ($action) {
    case 'fetch':
        fetchVideoInfo();
        break;
    case 'download':
        downloadVideo();
        break;
    default:
        jsonError('Ação inválida.', 400);
}

// ─────────────────────────────────────────────
// Busca informações do vídeo (título, thumbnail, formatos)
// ─────────────────────────────────────────────
function fetchVideoInfo(): void
{
    $url = trim($_POST['url'] ?? '');

    if (empty($url)) {
        jsonError('URL não informada.', 422);
    }

    if (!filter_var($url, FILTER_VALIDATE_URL)) {
        jsonError('URL inválida.', 422);
    }

    if (!isDomainAllowed($url)) {
        jsonError('Plataforma não suportada. Use TikTok, Instagram, Facebook, YouTube ou Twitter/X.', 422);
    }

    // Sanitiza a URL — remove parâmetros de rastreamento desnecessários mas mantém o essencial
    $url = sanitizeUrl($url);

    $proxy = getProxy();


    // Chama yt-dlp para obter metadados em JSON
    // No Linux/EC2: proc_open com arquivo temporário (sem limite de buffer)
    // No Windows com php -S: exec normal (limitado, mas funcional para URLs simples)
    $cmd = buildCommand(array_filter([
        YTDLP_PATH,
        '--dump-json',
        '--no-playlist',
        '--no-warnings',
        '--no-write-subs',
        '--no-write-auto-subs',
        '--socket-timeout', '30',
        '--user-agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        '--add-header', 'Accept-Language:pt-BR,pt;q=0.9,en;q=0.8',
        $proxy       ? '--proxy'   : null,
        $proxy       ?: null,
        COOKIES_FILE ? '--cookies' : null,
        COOKIES_FILE ?: null,
        '--',
        $url,
    ]));

    if (PHP_OS_FAMILY !== 'Windows') {
        // Linux: proc_open com arquivo temporário — sem limite de buffer
        $tmpFile = tempnam(sys_get_temp_dir(), 'ytdlp_');
        $tmpErr  = tempnam(sys_get_temp_dir(), 'ytdlp_err_');
        $descriptors = [0 => ['pipe','r'], 1 => ['file', $tmpFile, 'w'], 2 => ['file', $tmpErr, 'w']];
        $proc = proc_open($cmd, $descriptors, $pipes);
        if (is_resource($proc)) {
            fclose($pipes[0]);
            $exitCode = proc_close($proc);
        } else {
            $exitCode = 1;
        }
        $json   = (string) file_get_contents($tmpFile);
        $errOut = (string) file_get_contents($tmpErr);
        @unlink($tmpFile);
        @unlink($tmpErr);
    } else {
        // Windows: exec com array de output
        $output = [];
        $exitCode = 0;
        exec($cmd . ' 2>&1', $output, $exitCode);
        $json   = implode('', $output);
        $errOut = '';
    }

    if ($exitCode !== 0 || empty($json)) {
        $errMsg = parseYtdlpError($errOut ?: $json);
        jsonError($errMsg, 500);
    }

    $data = json_decode($json, true);

    if (!$data) {
        jsonError('Não foi possível processar as informações do vídeo.', 500);
    }

    // Monta lista de formatos disponíveis
    $formats = buildFormatList($data);

    jsonSuccess([
        'title'     => $data['title'] ?? 'Vídeo sem título',
        'thumbnail' => $data['thumbnail'] ?? '',
        'duration'  => formatDuration($data['duration'] ?? 0),
        'platform'  => detectPlatform($url),
        'uploader'  => $data['uploader'] ?? $data['channel'] ?? '',
        'formats'   => $formats,
        'url'       => $url,
    ]);
}

// ─────────────────────────────────────────────
// Faz o download e envia o arquivo ao navegador
// ─────────────────────────────────────────────
function downloadVideo(): void
{
    $url      = trim($_POST['url'] ?? '');
    $formatId = trim($_POST['format_id'] ?? 'best');
    $type     = trim($_POST['type'] ?? 'video'); // video | audio

    if (empty($url) || !filter_var($url, FILTER_VALIDATE_URL)) {
        jsonError('URL inválida.', 422);
    }

    if (!isDomainAllowed($url)) {
        jsonError('Plataforma não suportada.', 422);
    }

    // Valida format_id — apenas alfanumérico + hífen + ponto
    if (!preg_match('/^[a-zA-Z0-9\-_.+]+$/', $formatId)) {
        jsonError('Formato inválido.', 422);
    }

    $url = sanitizeUrl($url);

    // Nome de arquivo único para evitar colisões
    $filename = 'baixarmp' . uniqid() . 'player';
    $outputTemplate = DOWNLOAD_DIR . $filename . '.%(ext)s';

    $proxy = getProxy();

    $args = [
        YTDLP_PATH,
        '--no-playlist',
        '--no-warnings',
        '--socket-timeout', '60',
        '--concurrent-fragments', (string) CONCURRENT_FRAGMENTS,
        '--retries', '5',
        '--fragment-retries', '5',
        '--file-access-retries', '3',
        '--http-chunk-size', '10M',
        '--user-agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        '--add-header', 'Accept-Language:pt-BR,pt;q=0.9,en;q=0.8',
        '-o', $outputTemplate,
    ];

    if ($proxy) {
        $args = array_merge($args, ['--proxy', $proxy]);
    }

    if (COOKIES_FILE) {
        $args = array_merge($args, ['--cookies', COOKIES_FILE]);
    }

    if ($type === 'audio') {
        $args = array_merge($args, [
            '-x',
            '--audio-format', 'mp3',
            '--audio-quality', '0',
        ]);
    } else {
        if ($formatId === 'best') {
            $args = array_merge($args, ['-f', 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best']);
        } else {
            $args = array_merge($args, ['-f', $formatId]);
        }
        $args = array_merge($args, ['--merge-output-format', 'mp4']);
    }

    $args[] = '--';
    $args[] = $url;

    $cmd = buildCommand($args);

    $output   = [];
    $exitCode = 0;
    exec($cmd . ' 2>&1', $output, $exitCode);

    if ($exitCode !== 0) {
        $errMsg = parseYtdlpError(implode("\n", $output));
        jsonError($errMsg, 500);
    }

    // Encontra o arquivo gerado
    $files = glob(DOWNLOAD_DIR . $filename . '.*');

    if (empty($files)) {
        jsonError('Arquivo não encontrado após download.', 500);
    }

    $filePath = $files[0];
    $ext      = pathinfo($filePath, PATHINFO_EXTENSION);
    $mimeType = getMimeType($ext);
    $fileSize = filesize($filePath);

    // Verifica tamanho máximo
    if ($fileSize > MAX_FILESIZE_MB * 1024 * 1024) {
        unlink($filePath);
        jsonError('Arquivo muito grande (limite: ' . MAX_FILESIZE_MB . 'MB).', 413);
    }

    // Envia o arquivo
    $downloadName = basename($filePath); // já está no formato baixarmp<id>player.ext
    header('Content-Type: ' . $mimeType);
    header('Content-Disposition: attachment; filename="' . $downloadName . '"');
    header('Content-Length: ' . $fileSize);
    header('Cache-Control: no-cache, no-store, must-revalidate');
    header('Pragma: no-cache');
    header('Expires: 0');
    header('X-Accel-Buffering: no'); // desativa buffer do Nginx se houver

    // Limpa buffers de saída
    if (ob_get_level()) {
        ob_end_clean();
    }

    // Envia em chunks de 1MB para máxima velocidade
    $handle = fopen($filePath, 'rb');
    if ($handle) {
        while (!feof($handle)) {
            echo fread($handle, BUFFER_SIZE);
            flush();
        }
        fclose($handle);
    }

    // Remove o arquivo após envio
    unlink($filePath);
    exit;
}

// ─────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────

/**
 * Retorna um proxy para usar — prioriza PROXY_URL, depois rotaciona a lista
 */
function getProxy(): string
{
    if (PROXY_URL) {
        return PROXY_URL;
    }
    $list = PROXY_LIST;
    if (empty($list)) {
        return '';
    }
    // Rotação baseada no segundo atual para distribuir carga
    return $list[time() % count($list)];
}

function isDomainAllowed(string $url): bool
{
    $host = strtolower(parse_url($url, PHP_URL_HOST) ?? '');
    foreach (ALLOWED_DOMAINS as $domain) {
        if ($host === $domain || str_ends_with($host, '.' . $domain)) {
            return true;
        }
    }
    return false;
}

function sanitizeUrl(string $url): string
{
    // Remove fragmentos (#) mas mantém query string necessária
    $parts = parse_url($url);
    $clean = ($parts['scheme'] ?? 'https') . '://' . ($parts['host'] ?? '');
    if (!empty($parts['path'])) {
        $clean .= $parts['path'];
    }
    if (!empty($parts['query'])) {
        $clean .= '?' . $parts['query'];
    }
    return $clean;
}

/**
 * Constrói o comando de forma segura usando escapeshellarg em cada argumento
 */
function buildCommand(array $args): string
{
    return implode(' ', array_map('escapeshellarg', $args));
}

function buildFormatList(array $data): array
{
    $formats  = $data['formats'] ?? [];
    $result   = [];
    $seen     = [];

    // Adiciona opção "Melhor qualidade" sempre
    $result[] = [
        'id'       => 'best',
        'label'    => 'Melhor qualidade (automático)',
        'ext'      => 'mp4',
        'type'     => 'video',
        'quality'  => 'best',
        'filesize' => null,
    ];

    // Formatos de vídeo com resolução
    foreach (array_reverse($formats) as $fmt) {
        if (empty($fmt['vcodec']) || $fmt['vcodec'] === 'none') {
            continue;
        }

        $height = $fmt['height'] ?? 0;
        if (!$height) {
            continue;
        }

        $label = $height . 'p';
        if (isset($seen[$label])) {
            continue;
        }
        $seen[$label] = true;

        $result[] = [
            'id'       => $fmt['format_id'],
            'label'    => $label . ' — ' . strtoupper($fmt['ext'] ?? 'mp4'),
            'ext'      => $fmt['ext'] ?? 'mp4',
            'type'     => 'video',
            'quality'  => $height,
            'filesize' => formatFilesize($fmt['filesize'] ?? $fmt['filesize_approx'] ?? null),
        ];
    }

    // Opção de áudio MP3
    $result[] = [
        'id'       => 'audio_mp3',
        'label'    => 'Somente áudio — MP3',
        'ext'      => 'mp3',
        'type'     => 'audio',
        'quality'  => 0,
        'filesize' => null,
    ];

    return $result;
}

function formatDuration(int $seconds): string
{
    if ($seconds <= 0) {
        return '';
    }
    $h = intdiv($seconds, 3600);
    $m = intdiv($seconds % 3600, 60);
    $s = $seconds % 60;
    if ($h > 0) {
        return sprintf('%d:%02d:%02d', $h, $m, $s);
    }
    return sprintf('%d:%02d', $m, $s);
}

function formatFilesize(?int $bytes): ?string
{
    if (!$bytes) {
        return null;
    }
    if ($bytes >= 1073741824) {
        return round($bytes / 1073741824, 1) . ' GB';
    }
    if ($bytes >= 1048576) {
        return round($bytes / 1048576, 1) . ' MB';
    }
    return round($bytes / 1024, 0) . ' KB';
}

function detectPlatform(string $url): string
{
    $host = strtolower(parse_url($url, PHP_URL_HOST) ?? '');
    if (str_contains($host, 'tiktok'))    return 'TikTok';
    if (str_contains($host, 'instagram')) return 'Instagram';
    if (str_contains($host, 'facebook') || $host === 'fb.watch') return 'Facebook';
    if (str_contains($host, 'youtube') || $host === 'youtu.be') return 'YouTube';
    if (str_contains($host, 'twitter') || str_contains($host, 'x.com')) return 'Twitter/X';
    return 'Desconhecido';
}

function getMimeType(string $ext): string
{
    return match (strtolower($ext)) {
        'mp4'  => 'video/mp4',
        'webm' => 'video/webm',
        'mkv'  => 'video/x-matroska',
        'mp3'  => 'audio/mpeg',
        'm4a'  => 'audio/mp4',
        'ogg'  => 'audio/ogg',
        default => 'application/octet-stream',
    };
}

function parseYtdlpError(string $output): string
{
    if (str_contains($output, 'Private video') || str_contains($output, 'private')) {
        return 'Este vídeo é privado e não pode ser baixado.';
    }
    if (str_contains($output, 'not available') || str_contains($output, 'unavailable')) {
        return 'Vídeo não disponível ou removido.';
    }
    if (str_contains($output, 'Login required') || str_contains($output, 'login')) {
        return 'Este conteúdo requer login para ser acessado.';
    }
    if (str_contains($output, 'Unsupported URL') || str_contains($output, 'unsupported')) {
        return 'URL não suportada. Verifique se o link está correto.';
    }
    if (str_contains($output, 'yt-dlp: not found') || str_contains($output, 'No such file')) {
        return 'yt-dlp não está instalado no servidor. Consulte a documentação de instalação.';
    }
    return 'Não foi possível processar o vídeo. Verifique se o link está correto e tente novamente.';
}

function jsonSuccess(array $data): void
{
    echo json_encode(['success' => true, 'data' => $data], JSON_UNESCAPED_UNICODE);
    exit;
}

function jsonError(string $message, int $code = 400): void
{
    http_response_code($code);
    echo json_encode(['success' => false, 'error' => $message], JSON_UNESCAPED_UNICODE);
    exit;
}
