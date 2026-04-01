import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/home/home_screen.dart';
import '../screens/camera/camera_screen.dart';
import '../screens/item_detail/item_detail_screen.dart';
import '../screens/sell_flow/sell_flow_screen.dart';
import '../screens/export/export_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/category_settings_screen.dart';
import '../screens/settings/keyword_settings_screen.dart';
import '../screens/settings/room_settings_screen.dart';
import '../screens/settings/marketplace_settings_screen.dart';
import '../screens/settings/api_keys_screen.dart';

abstract class AppRoutes {
  static const home          = '/';
  static const camera        = '/camera';
  static const itemDetail    = '/item/:id';
  static const sellFlow      = '/sell/:id';
  static const export        = '/export';
  static const settings      = '/settings';
  static const catSettings   = '/settings/categories';
  static const kwSettings    = '/settings/keywords';
  static const roomSettings  = '/settings/rooms';
  static const mktSettings   = '/settings/marketplaces';
  static const apiSettings   = '/settings/api-keys';
}

final appRouter = GoRouter(
  initialLocation: AppRoutes.home,
  routes: [
    GoRoute(
      path: AppRoutes.home,
      builder: (_, __) => const HomeScreen(),
    ),
    GoRoute(
      path: AppRoutes.camera,
      builder: (_, state) {
        final mode = state.uri.queryParameters['mode'];
        return CameraScreen(initialModeOverride: mode);
      },
    ),
    GoRoute(
      path: AppRoutes.itemDetail,
      builder: (_, state) => ItemDetailScreen(itemId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: AppRoutes.sellFlow,
      builder: (_, state) => SellFlowScreen(itemId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: AppRoutes.export,
      builder: (_, __) => const ExportScreen(),
    ),
    GoRoute(
      path: AppRoutes.settings,
      builder: (_, __) => const SettingsScreen(),
      routes: [
        GoRoute(path: 'categories',   builder: (_, __) => const CategorySettingsScreen()),
        GoRoute(path: 'keywords',     builder: (_, __) => const KeywordSettingsScreen()),
        GoRoute(path: 'rooms',        builder: (_, __) => const RoomSettingsScreen()),
        GoRoute(path: 'marketplaces', builder: (_, __) => const MarketplaceSettingsScreen()),
        GoRoute(path: 'api-keys',     builder: (_, __) => const ApiKeysScreen()),
      ],
    ),
  ],
  errorBuilder: (_, state) => Scaffold(
    body: Center(child: Text('Page not found: ${state.error}')),
  ),
);
