<?php
declare(strict_types=1);

/*
 * Host version config
 * Put your PasarGuard panel address here, without a trailing slash.
 * Example: const BASE_URL = 'https://panel.example.com';
 */
const BASE_URL = 'https://YOUR-PANEL-DOMAIN';
const REQUEST_TIMEOUT = 15;

function panel_base_url(): string
{
    $base = rtrim(trim(BASE_URL), '/');
    if ($base === '' || $base === 'https://YOUR-PANEL-DOMAIN') {
        http_response_code(500);
        header('Content-Type: text/plain; charset=utf-8');
        echo 'BASE_URL is not configured in index.php';
        exit;
    }
    if (!preg_match('~^https?://~i', $base)) {
        $base = 'https://' . $base;
    }
    return $base;
}

function current_proxy_path(): string
{
    if (isset($_GET['proxy'])) {
        return '/' . ltrim((string) $_GET['proxy'], '/');
    }

    $requestPath = (string) parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH);
    $scriptDir = str_replace('\\', '/', dirname($_SERVER['SCRIPT_NAME'] ?? ''));
    $scriptDir = $scriptDir === '/' ? '' : rtrim($scriptDir, '/');

    if ($scriptDir !== '' && strpos($requestPath, $scriptDir) === 0) {
        $requestPath = substr($requestPath, strlen($scriptDir));
    }

    return '/' . ltrim($requestPath, '/');
}

function is_proxy_request(string $path): bool
{
    return (isset($_GET['proxy']) || is_app_subscription_request($path))
        && strpos($path, '..') === false
        && preg_match('~^/[A-Za-z0-9._\~!$&\'()*+,;=:@%/-]+$~', $path);
}

function is_app_subscription_request(string $path): bool
{
    if (isset($_GET['proxy'])) {
        return false;
    }
    if (!preg_match('~^/[A-Za-z0-9._~-]+/[A-Za-z0-9._~-]+/?$~', $path)) {
        return false;
    }

    $accept = strtolower($_SERVER['HTTP_ACCEPT'] ?? '');
    return strpos($accept, 'text/html') === false;
}

function normalize_proxy_path(string $path): string
{
    if (preg_match('~^/[A-Za-z0-9._~-]+/[A-Za-z0-9._~-]+$~', $path)) {
        return $path . '/';
    }
    return $path;
}

function forwarded_query(): string
{
    $params = $_GET;
    unset($params['proxy']);
    return http_build_query($params);
}

function proxy_panel_request(string $path): void
{
    $path = normalize_proxy_path($path);
    $target = panel_base_url() . $path;
    $query = forwarded_query();
    if ($query !== '') {
        $target .= '?' . $query;
    }

    $headers = [
        'Accept: ' . ($_SERVER['HTTP_ACCEPT'] ?? '*/*'),
        'User-Agent: ' . ($_SERVER['HTTP_USER_AGENT'] ?? 'PasarGuardHost/1.0'),
    ];

    foreach (['HTTP_X_HWID', 'HTTP_X_DEVICE_OS', 'HTTP_X_VER_OS', 'HTTP_X_DEVICE_MODEL'] as $key) {
        if (!empty($_SERVER[$key])) {
            $name = str_replace(' ', '-', ucwords(strtolower(str_replace('_', ' ', substr($key, 5)))));
            $headers[] = $name . ': ' . $_SERVER[$key];
        }
    }

    if (function_exists('curl_init')) {
        $ch = curl_init($target);
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_HEADER => true,
            CURLOPT_FOLLOWLOCATION => true,
            CURLOPT_MAXREDIRS => 3,
            CURLOPT_CONNECTTIMEOUT => REQUEST_TIMEOUT,
            CURLOPT_TIMEOUT => REQUEST_TIMEOUT,
            CURLOPT_HTTPHEADER => $headers,
        ]);
        $response = curl_exec($ch);
        if ($response === false) {
            http_response_code(502);
            header('Content-Type: text/plain; charset=utf-8');
            echo 'Panel request failed';
            curl_close($ch);
            return;
        }

        $status = (int) curl_getinfo($ch, CURLINFO_RESPONSE_CODE);
        $headerSize = (int) curl_getinfo($ch, CURLINFO_HEADER_SIZE);
        $rawHeaders = substr($response, 0, $headerSize);
        $body = substr($response, $headerSize);
        curl_close($ch);

        http_response_code($status ?: 200);
        emit_proxy_headers($rawHeaders);
        echo $body;
        return;
    }

    $context = stream_context_create([
        'http' => [
            'method' => 'GET',
            'timeout' => REQUEST_TIMEOUT,
            'ignore_errors' => true,
            'follow_location' => 1,
            'max_redirects' => 3,
            'header' => implode("\r\n", $headers),
        ],
    ]);
    $body = @file_get_contents($target, false, $context);
    if ($body === false) {
        http_response_code(502);
        header('Content-Type: text/plain; charset=utf-8');
        echo 'Panel request failed';
        return;
    }

    $status = 200;
    $rawHeaders = isset($http_response_header) ? implode("\r\n", $http_response_header) : '';
    if (preg_match('~^HTTP/\S+\s+(\d+)~m', $rawHeaders, $m)) {
        $status = (int) $m[1];
    }

    http_response_code($status);
    emit_proxy_headers($rawHeaders);
    echo $body;
}

function public_base_url(): string
{
    $https = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off')
        || (($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '') === 'https');
    $scheme = $https ? 'https' : 'http';
    $host = $_SERVER['HTTP_HOST'] ?? 'localhost';
    $scriptDir = str_replace('\\', '/', dirname($_SERVER['SCRIPT_NAME'] ?? ''));
    $scriptDir = $scriptDir === '/' ? '' : rtrim($scriptDir, '/');

    return $scheme . '://' . $host . $scriptDir;
}

function emit_proxy_headers(string $rawHeaders): void
{
    $allowed = ['content-type', 'cache-control', 'expires', 'announce', 'announce-url'];
    foreach (preg_split('/\r\n|\n|\r/', $rawHeaders) as $line) {
        if (strpos($line, ':') === false) {
            continue;
        }
        [$name, $value] = array_map('trim', explode(':', $line, 2));
        if (in_array(strtolower($name), $allowed, true)) {
            header($name . ': ' . $value, true);
        }
    }
}

function serve_index(): void
{
    panel_base_url();

    $file = __DIR__ . '/index.html';
    if (!is_file($file)) {
        http_response_code(404);
        header('Content-Type: text/plain; charset=utf-8');
        echo 'index.html not found';
        return;
    }

    $script = $_SERVER['SCRIPT_NAME'] ?? 'index.php';
    $config = '<script>window.PASARGUARD_HOST=' . json_encode([
        'publicUrl' => public_base_url(),
        'proxyUrl' => $script . '?proxy=',
        'subscriptionUrl' => public_base_url(),
        'hosted' => true,
    ], JSON_UNESCAPED_SLASHES) . ';</script>';

    $html = file_get_contents($file);
    $html = str_replace('</title>', '</title>' . "\n  " . $config, $html);

    header('Content-Type: text/html; charset=utf-8');
    echo $html;
}

$path = current_proxy_path();
if (is_proxy_request($path)) {
    proxy_panel_request($path);
} else {
    serve_index();
}
