<?php

declare(strict_types=1);

function json_response(int $statusCode, array $payload): void
{
    http_response_code($statusCode);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($payload, JSON_UNESCAPED_UNICODE);
    exit;
}

function db_connect(): mysqli
{
    // Заполните своими данными от хостинга / phpMyAdmin.
    $dbHost = 'MySQL-8.4';
    $dbName = 'flreg';
    $dbUser = 'root';
    $dbPass = '';

    $mysqli = new mysqli($dbHost, $dbUser, $dbPass, $dbName);

    if ($mysqli->connect_errno) {
        throw new RuntimeException('Не удалось подключиться к базе данных');
    }

    $mysqli->set_charset('utf8mb4');

    return $mysqli;
}
