import 'package:flutter/material.dart';

import 'data/store.dart';

/// Dependency injection for the single [AppController].
///
/// `context.watch` → rebuild on any notifyListeners()
/// `context.read`  → one-off access without subscribing (callbacks).
class AppScope extends InheritedNotifier<AppController> {
  const AppScope({
    super.key,
    required AppController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()?.notifier;
}

/// Subscribes only while the widget is on-screen (InheritedNotifier handles
/// the lifecycle); keeps screen files free of provider packages.
extension AppContext on BuildContext {
  AppController get app => AppScope.of(this);
}
