import 'package:flutter/material.dart';

import 'auth_shell.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // 1. Контроллеры для получения текста (как value в JS)
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // 2. Ключ для валидации всей формы
  final _formKey = GlobalKey<FormState>();

  // Переменная для скрытия/показа пароля
  bool _showPasswords = false;

  @override
  void dispose() {
    // Обязательно очищаем контроллеры, чтобы не было утечек памяти
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submitForm() {
    // Аналог preventDefault() и проверки валидности в JS
    if (_formKey.currentState!.validate()) {
      // Здесь вызываем API (например, Firebase или твой Backend)
      debugPrint("Регистрация пользователя: ${_emailController.text}");
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Регистрация прошла успешно!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: 'Создать аккаунт',
      subtitle: 'Заполните данные — это займёт меньше минуты.',
      footer: TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Уже есть аккаунт? Войти'),
      ),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (value) {
                  final email = (value ?? '').trim();
                  if (!email.contains('@') || email.length < 5) {
                    return 'Введите корректный email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: !_showPasswords,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: 'Пароль',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: _showPasswords ? 'Скрыть пароль' : 'Показать пароль',
                    icon: Icon(
                      _showPasswords ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setState(() => _showPasswords = !_showPasswords),
                  ),
                ),
                validator: (value) {
                  final password = value ?? '';
                  if (password.length < 6) {
                    return 'Минимум 6 символов';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: !_showPasswords,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                decoration: const InputDecoration(
                  labelText: 'Повторите пароль',
                  prefixIcon: Icon(Icons.lock_reset),
                ),
                onFieldSubmitted: (_) => _submitForm(),
                validator: (value) {
                  if ((value ?? '').isEmpty) {
                    return 'Повторите пароль';
                  }
                  if (value != _passwordController.text) {
                    return 'Пароли не совпадают';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submitForm,
                child: const Text('Зарегистрироваться'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
