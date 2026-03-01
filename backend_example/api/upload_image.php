<?php

declare(strict_types=1);

require_once __DIR__ . '/db.php';

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Accept');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    json_response(405, [
        'success' => false,
        'message' => 'Method not allowed',
    ]);
}

if (!isset($_FILES['image']) || !is_array($_FILES['image'])) {
    json_response(422, [
        'success' => false,
        'message' => 'Image file is required',
    ]);
}

$file = $_FILES['image'];
$errorCode = (int)($file['error'] ?? UPLOAD_ERR_NO_FILE);
if ($errorCode !== UPLOAD_ERR_OK) {
    json_response(422, [
        'success' => false,
        'message' => 'Upload failed',
        'error_code' => $errorCode,
    ]);
}

$tmpName = (string)($file['tmp_name'] ?? '');
if ($tmpName === '' || !is_uploaded_file($tmpName)) {
    json_response(422, [
        'success' => false,
        'message' => 'Invalid uploaded file',
    ]);
}

$finfo = new finfo(FILEINFO_MIME_TYPE);
$mimeType = $finfo->file($tmpName) ?: '';

$allowedMime = [
    'image/jpeg' => 'jpg',
    'image/png' => 'png',
    'image/webp' => 'webp',
    'image/gif' => 'gif',
];

if (!array_key_exists($mimeType, $allowedMime)) {
    json_response(422, [
        'success' => false,
        'message' => 'Unsupported image type',
        'mime' => $mimeType,
    ]);
}

$extension = $allowedMime[$mimeType];
$targetDir = dirname(__DIR__) . '/img';

if (!is_dir($targetDir)) {
    $created = mkdir($targetDir, 0755, true);
    if (!$created && !is_dir($targetDir)) {
        json_response(500, [
            'success' => false,
            'message' => 'Failed to create image directory',
        ]);
    }
}

$fileName = 'movie_' . date('Ymd_His') . '_' . bin2hex(random_bytes(4)) . '.' . $extension;
$targetPath = $targetDir . '/' . $fileName;

if (!move_uploaded_file($tmpName, $targetPath)) {
    json_response(500, [
        'success' => false,
        'message' => 'Failed to save image',
    ]);
}

$scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
$host = (string)($_SERVER['HTTP_HOST'] ?? '');
$path = '/img/' . rawurlencode($fileName);

$url = $host === '' ? $path : ($scheme . '://' . $host . $path);

json_response(200, [
    'success' => true,
    'message' => 'Image uploaded',
    'url' => $url,
]);
