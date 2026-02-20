import 'package:flutter/material.dart';
// 1. Импортируем библиотеку для работы с URL (только для Web)
import 'package:flutter_web_plugins/url_strategy.dart';

import 'register_page.dart'; 

void main() {
  // 2. Вызываем эту функцию ПЕРЕД runApp. 
  // Она переключает движок с Hash (#) на Path-стратегию.
  usePathUrlStrategy(); 
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Auth Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
      ),
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
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => Navigator.pushNamed(context, '/register'),
          child: const Text('Go to Register'),
        ),
      ),
    );
  }
}

class ForgotPasswordPage extends StatelessWidget {
  const ForgotPasswordPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(), body: const Center(child: Text('Forgot Password')));
  }
}