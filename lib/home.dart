import 'package:flutter/material.dart';

import 'features/media_scanner/presentation/pages/media_scanner_page.dart';
import 'features/movie_bookmarks/presentation/pages/movie_bookmarks_page.dart';
import 'widgets/app_logo.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  void _logout() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // ignore: no_leading_underscores_for_local_identifiers
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final args = ModalRoute.of(context)?.settings.arguments;

    String? email;
    if (args is Map) {
      email = args['email']?.toString();
    }

    final destinations = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Главная',
      ),
      const NavigationDestination(
        icon: Icon(Icons.document_scanner_outlined),
        selectedIcon: Icon(Icons.document_scanner),
        label: 'Сканер',
      ),
      const NavigationDestination(
        icon: Icon(Icons.bookmark_outline),
        selectedIcon: Icon(Icons.bookmark),
        label: 'Закладки',
      ),
    ];

    final pages = <Widget>[
      _HomeDashboard(
        email: email,
        onOpenScanner: () => setState(() => _selectedIndex = 1),
        onOpenBookmarks: () => setState(() => _selectedIndex = 2),
        onLogout: _logout,
      ),
      const MediaScannerPage(),
      const MovieBookmarksPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const AppLogo(size: 26),
            const SizedBox(width: 10),
            Text(
              _selectedIndex == 0
                  ? 'Главная'
                  : _selectedIndex == 1
                      ? 'Сканер'
                      : 'Закладки',
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _logout,
            tooltip: 'Выйти',
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary.withValues(alpha: 28),
              colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final showRail = constraints.maxWidth >= 860;

              final content = IndexedStack(
                index: _selectedIndex,
                children: pages,
              );

              if (!showRail) {
                return Column(
                  children: [
                    Expanded(child: content),
                    NavigationBar(
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: (value) =>
                          setState(() => _selectedIndex = value),
                      destinations: destinations,
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  NavigationRail(
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: (value) =>
                        setState(() => _selectedIndex = value),
                    labelType: NavigationRailLabelType.all,
                    leading: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        children: [
                          const AppLogo(size: 34),
                          const SizedBox(height: 8),
                          Text(
                            'Menu',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    destinations: [
                      for (final d in destinations)
                        NavigationRailDestination(
                          icon: d.icon,
                          selectedIcon: d.selectedIcon,
                          label: Text(d.label),
                        ),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: content),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HomeDashboard extends StatelessWidget {
  const _HomeDashboard({
    required this.email,
    required this.onOpenScanner,
    required this.onOpenBookmarks,
    required this.onLogout,
  });

  final String? email;
  final VoidCallback onOpenScanner;
  final VoidCallback onOpenBookmarks;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer
                              .withValues(alpha: 140),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.check_circle_outline,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Вы успешно вошли',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (email != null && email!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  email!,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: onLogout,
                        icon: const Icon(Icons.logout),
                        label: const Text('Выйти'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Быстрые действия',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 640;
                  final spacing = wide ? 12.0 : 10.0;

                  final tiles = <Widget>[
                    _ActionTile(
                      title: 'Сканер',
                      subtitle: 'Фото или скрин → OCR → поиск',
                      icon: Icons.document_scanner_outlined,
                      color: colorScheme.primary,
                      onTap: onOpenScanner,
                    ),
                    _ActionTile(
                      title: 'Закладки',
                      subtitle: 'Список фильмов и теги',
                      icon: Icons.bookmark_outline,
                      color: colorScheme.tertiary,
                      onTap: onOpenBookmarks,
                    ),
                  ];

                  if (!wide) {
                    return Column(
                      children: [
                        for (var i = 0; i < tiles.length; i++) ...[
                          tiles[i],
                          if (i != tiles.length - 1)
                            SizedBox(height: spacing),
                        ],
                      ],
                    );
                  }

                  return Row(
                    children: [
                      for (var i = 0; i < tiles.length; i++) ...[
                        Expanded(child: tiles[i]),
                        if (i != tiles.length - 1)
                          SizedBox(width: spacing),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.tips_and_updates_outlined,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'На широких экранах меню автоматически расширяется '
                          '(NavigationRail).',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 20),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withValues(alpha: 40)),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
