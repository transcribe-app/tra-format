import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:go_router/go_router.dart';
import '/pages/home.dart';

// FFR: Not really needed for single-page app for now
final GoRouter router = GoRouter(
  initialLocation: '/home',
  routes: [
    GoRoute(
      path: '/home',
      builder: (context, state) {
        return SafeArea(
          child: Scaffold(
            // DefaultTextStyle(style: uiTypography.base.copyWith(color: uiTheme.colorScheme.foreground, child: ... )
            child: const HomePage()
          )
        );
      },
    ),
  ],
);