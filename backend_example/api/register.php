<?php

declare(strict_types=1);

require_once __DIR__ . '/db.php';

// Для Flutter Web (если фронтенд на другом домене)
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

if (mb_strlen($password) < 6) {
    json_response(422, [
        'success' => false,
        'message' => 'Минимум 6 символов в пароле',
    ]);
}

try {
    $db = db_connect();

    // В вашей таблице нет UNIQUE индекса на email, поэтому проверяем вручную.
    $checkStmt = $db->prepare('SELECT id FROM accounts WHERE email = ? LIMIT 1');
    if (!$checkStmt) {
        throw new RuntimeException('Ошибка подготовки запроса проверки');
    }

    $checkStmt->bind_param('s', $email);
    $checkStmt->execute();
    $checkStmt->store_result();

    if ($checkStmt->num_rows > 0) {
        $checkStmt->close();
        json_response(409, [
            'success' => false,
            'message' => 'Пользователь с таким email уже существует',
        ]);
    }
    $checkStmt->close();

    $passwordHash = password_hash($password, PASSWORD_BCRYPT);
    if ($passwordHash === false) {
        throw new RuntimeException('Не удалось создать хеш пароля');
    }

    $insertStmt = $db->prepare('INSERT INTO accounts (email, password) VALUES (?, ?)');
    if (!$insertStmt) {
        throw new RuntimeException('Ошибка подготовки запроса регистрации');
    }

    $insertStmt->bind_param('ss', $email, $passwordHash);
    $ok = $insertStmt->execute();

    if (!$ok) {
        throw new RuntimeException('Не удалось сохранить пользователя');
    }

    $newUserId = $insertStmt->insert_id;
    $insertStmt->close();

    json_response(201, [
        'success' => true,
        'message' => 'Регистрация прошла успешно',
        'user_id' => $newUserId,
    ]);
} catch (Throwable $e) {
    json_response(500, [
        'success' => false,
        'message' => 'Ошибка сервера',
        // Для продакшена лучше убрать debug.
        'debug' => $e->getMessage(),
    ]);
}
