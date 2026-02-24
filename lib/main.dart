import 'package:flutter/material.dart';
// 1. Импортируем библиотеку для работы с URL (только для Web)
import 'auth_shell.dart';
import 'register_page.dart';
import 'url_strategy.dart';

void main() {
  // 2. Вызываем эту функцию ПЕРЕД runApp. 
  // Она переключает движок с Hash (#) на Path-стратегию.
  usePathUrlStrategy();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  ThemeData _buildTheme(Brightness brightness) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2563EB),
        brightness: brightness,
      ),
    );

    final colorScheme = base.colorScheme;
    final fillColor = brightness == Brightness.light
        ? colorScheme.surfaceContainerHighest.withValues(alpha: 140)
        : colorScheme.surfaceContainerHighest.withValues(alpha: 64);

    return base.copyWith(
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fillColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Auth Demo',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      // Маршруты без решеток
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/forgot-password': (context) => const ForgotPasswordPage(),
      },
    );
  }
}

// --- Твои заглушки страниц (оставляем как были) ---
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const AuthShell(
      title: 'Страница Входа',
      subtitle: 'Войдите в аккаунт или создайте новый.',
      child: _LoginActions(),
    );
  }
}

class _LoginActions extends StatelessWidget {
  const _LoginActions();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/register'),
          icon: const Icon(Icons.person_add_alt_1_outlined),
          label: const Text('Перейти к регистрации'),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.pushNamed(context, '/forgot-password'),
          child: const Text('Забыли пароль?'),
        ),
      ],
    );
  }
}

class ForgotPasswordPage extends StatelessWidget {
  const ForgotPasswordPage({super.key});
  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: 'Восстановление пароля',
      subtitle: 'Эта страница пока заглушка.',
      child: FilledButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Назад'),
      ),
    );
  }
}
