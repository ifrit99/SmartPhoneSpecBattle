import 'package:flutter/widgets.dart';

import '../domain/services/analytics_service.dart';
import 'firebase_options.dart';
import 'local_storage_service.dart';

abstract class AnalyticsEventSink {
  Future<void> setCollectionEnabled(bool enabled);
  Future<void> setConsentGranted(bool granted);
  Future<void> logEvent(String name, Map<String, Object?> params);
}

class NoopAnalyticsEventSink implements AnalyticsEventSink {
  const NoopAnalyticsEventSink();

  @override
  Future<void> setCollectionEnabled(bool enabled) async {}

  @override
  Future<void> setConsentGranted(bool granted) async {}

  @override
  Future<void> logEvent(String name, Map<String, Object?> params) async {}
}

class FirebaseAnalyticsClient implements AnalyticsService {
  final LocalStorageService _storage;
  final AnalyticsEventSink _sink;
  AnalyticsConsent _consent = AnalyticsConsent.unanswered;
  bool _initialized = false;

  FirebaseAnalyticsClient(
    this._storage, {
    AnalyticsEventSink? sink,
  }) : _sink = sink ?? const NoopAnalyticsEventSink();

  @override
  AnalyticsConsent get consent => _consent;

  @override
  bool get isEnabled => _consent == AnalyticsConsent.granted;

  @override
  Future<void> initialize() async {
    _consent = _storage.getAnalyticsConsent();
    await _sink.setConsentGranted(false);
    await _sink.setCollectionEnabled(false);
    _initialized = true;

    if (_consent == AnalyticsConsent.granted) {
      await _enableCollection();
    }
  }

  @override
  Future<void> setConsent(AnalyticsConsent consent) async {
    _consent = consent;
    await _storage.setAnalyticsConsent(consent);

    if (consent == AnalyticsConsent.granted) {
      await _enableCollection();
    } else {
      await _sink.setConsentGranted(false);
      await _sink.setCollectionEnabled(false);
    }
  }

  @override
  Future<void> logEvent(
    String name, {
    Map<String, Object?> params = const {},
  }) async {
    if (!_initialized || !isEnabled) return;
    await _sink.logEvent(name, _sanitizeParams(params));
  }

  @override
  Future<void> logScreenView(String screenName) {
    return logEvent('screen_view', params: {'screen_name': screenName});
  }

  Future<void> _enableCollection() async {
    if (!FirebaseOptionsConfig.hasConfig && _sink is NoopAnalyticsEventSink) {
      return;
    }
    await _sink.setConsentGranted(true);
    await _sink.setCollectionEnabled(true);
  }

  Map<String, Object?> _sanitizeParams(Map<String, Object?> params) {
    final sanitized = <String, Object?>{};
    for (final entry in params.entries) {
      final value = entry.value;
      if (value == null) continue;
      if (value is String || value is num || value is bool) {
        sanitized[entry.key] = value;
      } else {
        sanitized[entry.key] = value.toString();
      }
    }
    return sanitized;
  }
}

class AnalyticsNavigatorObserver extends NavigatorObserver {
  final AnalyticsService analytics;

  AnalyticsNavigatorObserver(this.analytics);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _log(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) _log(newRoute);
  }

  void _log(Route<dynamic> route) {
    final screenName = route.settings.name ?? route.runtimeType.toString();
    analytics.logScreenView(screenName);
  }
}
