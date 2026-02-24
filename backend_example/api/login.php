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
        'message' => 'Метод не поддерживается',
    ]);
}

$email = trim((string)($_POST['email'] ?? ''));
$password = (string)($_POST['password'] ?? '');

if ($email === '' || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
    json_response(422, [
        'success' => false,
        'message' => 'Введите корректный email',
    ]);
}

if ($password === '') {
    json_response(422, [
        'success' => false,
        'message' => 'Введите пароль',
    ]);
}

try {
    $db = db_connect();

    $stmt = $db->prepare('SELECT id, email, password FROM accounts WHERE email = ? LIMIT 1');
    if (!$stmt) {
        throw new RuntimeException('Ошибка подготовки запроса авторизации');
    }

    $stmt->bind_param('s', $email);
    $stmt->execute();
    $result = $stmt->get_result();
    $user = $result ? $result->fetch_assoc() : null;
    $stmt->close();

    if (!$user) {
        json_response(401, [
            'success' => false,
            'message' => 'Неверный email или пароль',
        ]);
    }

    $hash = (string)($user['password'] ?? '');
    if ($hash === '' || !password_verify($password, $hash)) {
        json_response(401, [
            'success' => false,
            'message' => 'Неверный email или пароль',
        ]);
    }

    json_response(200, [
        'success' => true,
        'message' => 'Вход выполнен успешно',
        'user_id' => (int)$user['id'],
        'email' => (string)$user['email'],
    ]);
} catch (Throwable $e) {
    json_response(500, [
        'success' => false,
        'message' => 'Ошибка сервера',
        // Для продакшена лучше убрать debug.
        'debug' => $e->getMessage(),
    ]);
}
