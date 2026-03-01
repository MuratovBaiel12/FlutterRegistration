<?php

declare(strict_types=1);

require_once __DIR__ . '/db.php';

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Accept');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET' && $_SERVER['REQUEST_METHOD'] !== 'POST') {
    json_response(405, [
        'success' => false,
        'message' => 'Method not allowed',
    ]);
}

$action = strtolower(trim((string)($_REQUEST['action'] ?? 'list')));
$accountId = require_account_id($_REQUEST['account_id'] ?? null);

try {
    $db = db_connect();

    switch ($action) {
        case 'list':
            handle_list($db, $accountId);
            break;
        case 'upsert':
            handle_upsert($db, $accountId);
            break;
        case 'delete':
            handle_delete($db, $accountId);
            break;
        default:
            json_response(422, [
                'success' => false,
                'message' => 'Unknown action',
            ]);
    }
} catch (Throwable $e) {
    json_response(500, [
        'success' => false,
        'message' => 'Server error',
        'debug' => $e->getMessage(),
    ]);
}

function handle_list(mysqli $db, int $accountId): void
{
    $stmt = $db->prepare(
        'SELECT id, account_id, cover_image, title, description, notes, tags, created_at, updated_at '
        . 'FROM marks WHERE account_id = ? ORDER BY updated_at DESC'
    );
    if (!$stmt) {
        throw new RuntimeException('Failed to prepare list statement');
    }

    $stmt->bind_param('i', $accountId);
    $stmt->execute();
    $result = $stmt->get_result();

    $items = [];
    while ($row = $result ? $result->fetch_assoc() : null) {
        if (!is_array($row)) {
            continue;
        }
        $items[] = normalize_mark_row($row);
    }
    $stmt->close();

    json_response(200, [
        'success' => true,
        'items' => $items,
    ]);
}

function handle_upsert(mysqli $db, int $accountId): void
{
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        json_response(405, [
            'success' => false,
            'message' => 'Method not allowed for upsert',
        ]);
    }

    $title = trim((string)($_POST['title'] ?? ''));
    $description = trim((string)($_POST['description'] ?? ''));
    $notes = nullable_trim($_POST['notes'] ?? null);
    $coverImage = nullable_trim($_POST['cover_image'] ?? null);
    $tagsCsv = parse_tags_input_to_csv($_POST['tags'] ?? '');

    if ($title === '') {
        json_response(422, [
            'success' => false,
            'message' => 'Title is required',
        ]);
    }

    if (mb_strlen($title) > 120) {
        json_response(422, [
            'success' => false,
            'message' => 'Title is too long',
        ]);
    }

    if ($description === '') {
        json_response(422, [
            'success' => false,
            'message' => 'Description is required',
        ]);
    }

    if (mb_strlen($description) > 2000) {
        json_response(422, [
            'success' => false,
            'message' => 'Description is too long',
        ]);
    }

    if ($notes !== null && mb_strlen($notes) > 1000) {
        json_response(422, [
            'success' => false,
            'message' => 'Notes are too long',
        ]);
    }

    $idRaw = trim((string)($_POST['id'] ?? ''));
    $id = ctype_digit($idRaw) ? (int)$idRaw : 0;

    if ($id > 0) {
        if (!mark_exists($db, $id, $accountId)) {
            json_response(404, [
                'success' => false,
                'message' => 'Mark not found for this account',
            ]);
        }

        $stmt = $db->prepare(
            'UPDATE marks SET cover_image = ?, title = ?, description = ?, notes = ?, tags = ? '
            . 'WHERE id = ? AND account_id = ?'
        );
        if (!$stmt) {
            throw new RuntimeException('Failed to prepare update statement');
        }

        $stmt->bind_param('sssssii', $coverImage, $title, $description, $notes, $tagsCsv, $id, $accountId);
        $ok = $stmt->execute();
        $stmt->close();

        if (!$ok) {
            throw new RuntimeException('Failed to update mark');
        }
    } else {
        $stmt = $db->prepare(
            'INSERT INTO marks (account_id, cover_image, title, description, notes, tags) VALUES (?, ?, ?, ?, ?, ?)'
        );
        if (!$stmt) {
            throw new RuntimeException('Failed to prepare insert statement');
        }

        $stmt->bind_param('isssss', $accountId, $coverImage, $title, $description, $notes, $tagsCsv);
        $ok = $stmt->execute();
        $newId = (int)$stmt->insert_id;
        $stmt->close();

        if (!$ok || $newId <= 0) {
            throw new RuntimeException('Failed to create mark');
        }

        $id = $newId;
    }

    $item = get_mark_by_id($db, $id, $accountId);
    if ($item === null) {
        throw new RuntimeException('Saved mark was not found');
    }

    json_response(200, [
        'success' => true,
        'message' => 'Mark saved',
        'id' => (string)$id,
        'item' => $item,
    ]);
}

function handle_delete(mysqli $db, int $accountId): void
{
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        json_response(405, [
            'success' => false,
            'message' => 'Method not allowed for delete',
        ]);
    }

    $idRaw = trim((string)($_POST['id'] ?? ''));
    if (!ctype_digit($idRaw) || (int)$idRaw <= 0) {
        json_response(422, [
            'success' => false,
            'message' => 'Valid id is required',
        ]);
    }

    $id = (int)$idRaw;
    $stmt = $db->prepare('DELETE FROM marks WHERE id = ? AND account_id = ?');
    if (!$stmt) {
        throw new RuntimeException('Failed to prepare delete statement');
    }

    $stmt->bind_param('ii', $id, $accountId);
    $ok = $stmt->execute();
    $affected = $stmt->affected_rows;
    $stmt->close();

    if (!$ok) {
        throw new RuntimeException('Failed to delete mark');
    }

    if ($affected === 0) {
        json_response(404, [
            'success' => false,
            'message' => 'Mark not found for this account',
        ]);
    }

    json_response(200, [
        'success' => true,
        'message' => 'Mark deleted',
    ]);
}

function mark_exists(mysqli $db, int $id, int $accountId): bool
{
    $stmt = $db->prepare('SELECT id FROM marks WHERE id = ? AND account_id = ? LIMIT 1');
    if (!$stmt) {
        throw new RuntimeException('Failed to prepare exists statement');
    }

    $stmt->bind_param('ii', $id, $accountId);
    $stmt->execute();
    $stmt->store_result();
    $exists = $stmt->num_rows > 0;
    $stmt->close();

    return $exists;
}

function get_mark_by_id(mysqli $db, int $id, int $accountId): ?array
{
    $stmt = $db->prepare(
        'SELECT id, account_id, cover_image, title, description, notes, tags, created_at, updated_at '
        . 'FROM marks WHERE id = ? AND account_id = ? LIMIT 1'
    );
    if (!$stmt) {
        throw new RuntimeException('Failed to prepare select statement');
    }

    $stmt->bind_param('ii', $id, $accountId);
    $stmt->execute();
    $result = $stmt->get_result();
    $row = $result ? $result->fetch_assoc() : null;
    $stmt->close();

    if (!is_array($row)) {
        return null;
    }

    return normalize_mark_row($row);
}

function normalize_mark_row(array $row): array
{
    return [
        'id' => (string)($row['id'] ?? ''),
        'account_id' => (string)($row['account_id'] ?? ''),
        'cover_image' => nullable_trim($row['cover_image'] ?? null),
        'title' => (string)($row['title'] ?? ''),
        'description' => (string)($row['description'] ?? ''),
        'notes' => nullable_trim($row['notes'] ?? null),
        'tags' => csv_to_tags((string)($row['tags'] ?? '')),
        'created_at' => (string)($row['created_at'] ?? ''),
        'updated_at' => (string)($row['updated_at'] ?? ''),
    ];
}

function csv_to_tags(string $csv): array
{
    if ($csv === '') {
        return [];
    }

    $parts = explode(',', $csv);
    $tags = [];
    foreach ($parts as $part) {
        $tag = trim($part);
        if ($tag === '') {
            continue;
        }
        if (!in_array($tag, $tags, true)) {
            $tags[] = $tag;
        }
    }

    return $tags;
}

function parse_tags_input_to_csv($raw): string
{
    if (is_array($raw)) {
        $tags = [];
        foreach ($raw as $item) {
            $tag = trim((string)$item);
            if ($tag === '') {
                continue;
            }
            if (!in_array($tag, $tags, true)) {
                $tags[] = $tag;
            }
        }
        return implode(',', $tags);
    }

    $rawText = trim((string)$raw);
    if ($rawText === '') {
        return '';
    }

    if (strlen($rawText) > 1 && $rawText[0] === '[') {
        $decoded = json_decode($rawText, true);
        if (is_array($decoded)) {
            return parse_tags_input_to_csv($decoded);
        }
    }

    return parse_tags_input_to_csv(explode(',', $rawText));
}

function require_account_id($raw): int
{
    $value = trim((string)$raw);
    if (!ctype_digit($value)) {
        json_response(422, [
            'success' => false,
            'message' => 'account_id is required',
        ]);
    }

    $accountId = (int)$value;
    if ($accountId <= 0) {
        json_response(422, [
            'success' => false,
            'message' => 'account_id must be > 0',
        ]);
    }

    return $accountId;
}

function nullable_trim($value): ?string
{
    $text = trim((string)($value ?? ''));
    return $text === '' ? null : $text;
}
