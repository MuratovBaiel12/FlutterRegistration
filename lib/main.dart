import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'auth_shell.dart';
import 'features/movie_bookmarks/data/datasources/movie_local_datasource.dart';
import 'features/movie_bookmarks/data/models/movie_model.dart';
import 'home.dart';
import 'register_page.dart';
import 'services/api_connect.dart';
import 'services/auth_session.dart';
import 'services/auth_service.dart';
import 'url_strategy.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  await Hive.initFlutter();
  if (!Hive.isAdapterRegistered(10)) {
    Hive.registerAdapter(MovieModelAdapter());
  }
  await Hive.openBox<MovieModel>(MovieLocalDataSource.boxName);

  runApp(const ProviderScope(child: MyApp()));
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
    // 6-digit HEX colors (#RRGGBB).
    final fillColor = brightness == Brightness.light
        ? const Color(0x90F1F5F9).withValues(alpha: 140 / 255)
        : const Color(0x001F2633);

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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _AppPageTransitionsBuilder(),
          TargetPlatform.iOS: _AppPageTransitionsBuilder(),
          TargetPlatform.macOS: _AppPageTransitionsBuilder(),
          TargetPlatform.windows: _AppPageTransitionsBuilder(),
          TargetPlatform.linux: _AppPageTransitionsBuilder(),
          TargetPlatform.fuchsia: _AppPageTransitionsBuilder(),
        },
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
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/forgot-password': (context) => const ForgotPasswordPage(),
        '/home': (context) => const HomePage(),
      },
    );
  }
}

class _AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const _AppPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return FadeTransition(
      opacity: curvedAnimation,
      child: child,
    );
  }
}

String? _validateEmail(String? value) {
  final email = (value ?? '').trim();
  if (email.isEmpty) {
    return 'Введите email';
  }

  final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  if (!emailPattern.hasMatch(email)) {
    return 'Введите корректный email';
  }

  return null;
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  bool _showPassword = false;
  bool _rememberMe = true;
  bool _isSubmitting = false;
  String? _statusMessage;
  bool _statusIsError = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _authService.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    FocusScope.of(context).unfocus();

    if (_isSubmitting) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _statusMessage = null;
      _statusIsError = false;
    });

    try {
      final result = await _authService.login(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (!mounted) {
        return;
      }

      if (!result.success) {
        setState(() {
          _statusMessage = result.message;
          _statusIsError = true;
        });
        return;
      }

      final loggedInEmail =
          result.raw['email']?.toString() ?? _emailController.text.trim();
      final loggedInUserId = int.tryParse(
        result.raw['user_id']?.toString() ??
            result.raw['account_id']?.toString() ??
            result.raw['id']?.toString() ??
            '',
      );

      if (loggedInUserId == null || loggedInUserId <= 0) {
        setState(() {
          _statusMessage = 'Не удалось определить ID аккаунта';
          _statusIsError = true;
        });
        return;
      }

      AuthSession.set(
        accountId: loggedInUserId,
        email: loggedInEmail,
      );
      await MovieLocalDataSource.clearBox();
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _rememberMe
                  ? 'Вход выполнен. Сессия сохранена для $loggedInEmail'
                  : 'Вход выполнен для $loggedInEmail',
            ),
          ),
        );

      Navigator.pushReplacementNamed(
        context,
        '/home',
      );
    } on TimeoutException {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = 'Сервер не отвечает. Попробуйте позже';
        _statusIsError = true;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = error.message;
        _statusIsError = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = 'Не удалось выполнить вход';
        _statusIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AuthShell(
      title: 'Вход в аккаунт',
      subtitle: 'Введите email и пароль, чтобы продолжить.',
      footer: TextButton(
        onPressed: _isSubmitting
            ? null
            : () => Navigator.pushNamed(context, '/register'),
        child: const Text('Нет аккаунта? Зарегистрироваться'),
      ),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_statusMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (_statusIsError
                            ? colorScheme.errorContainer
                            : colorScheme.primaryContainer)
                        .withValues(alpha: 120),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (_statusIsError
                              ? colorScheme.error
                              : colorScheme.primary)
                          .withValues(alpha: 90),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _statusIsError
                            ? Icons.error_outline
                            : Icons.check_circle_outline,
                        color: _statusIsError
                            ? colorScheme.error
                            : colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _emailController,
                enabled: !_isSubmitting,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: _validateEmail,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                enabled: !_isSubmitting,
                obscureText: !_showPassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _submitForm(),
                decoration: InputDecoration(
                  labelText: 'Пароль',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip:
                        _showPassword ? 'Скрыть пароль' : 'Показать пароль',
                    icon: Icon(
                      _showPassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: _isSubmitting
                        ? null
                        : () => setState(() => _showPassword = !_showPassword),
                  ),
                ),
                validator: (value) {
                  final password = value ?? '';
                  if (password.isEmpty) {
                    return 'Введите пароль';
                  }
                  if (password.length < 6) {
                    return 'Минимум 6 символов';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    value: _rememberMe,
                    onChanged: _isSubmitting
                        ? null
                        : (value) {
                            setState(() => _rememberMe = value ?? false);
                          },
                  ),
                  Expanded(
                    child: Text(
                      'Запомнить меня',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () =>
                            Navigator.pushNamed(context, '/forgot-password'),
                    child: const Text('Забыли пароль?'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _isSubmitting ? null : _submitForm,
                icon: _isSubmitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login),
                label: Text(_isSubmitting ? 'Вход...' : 'Войти'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _linkSent = false;
  String _lastSentEmail = '';

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _backToLogin() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
      return;
    }
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _sendResetLink() {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email = _emailController.text.trim();
    debugPrint('Запрос восстановления пароля: $email');

    setState(() {
      _linkSent = true;
      _lastSentEmail = email;
    });

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Письмо для восстановления отправлено')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AuthShell(
      title: 'Восстановление пароля',
      subtitle: 'Укажите email, и мы отправим ссылку для сброса пароля.',
      footer: TextButton(
        onPressed: _backToLogin,
        child: const Text('Вернуться ко входу'),
      ),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_linkSent) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 120),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 70),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Ссылка отправлена на $_lastSentEmail. '
                          'Проверьте входящие и папку "Спам".',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.email],
                onFieldSubmitted: (_) => _sendResetLink(),
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: _validateEmail,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _sendResetLink,
                icon: Icon(
                  _linkSent
                      ? Icons.refresh_outlined
                      : Icons.mark_email_read_outlined,
                ),
                label: Text(
                  _linkSent ? 'Отправить повторно' : 'Отправить ссылку',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
