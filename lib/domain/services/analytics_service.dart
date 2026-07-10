enum AnalyticsConsent {
  unanswered,
  granted,
  denied,
}

extension AnalyticsConsentX on AnalyticsConsent {
  String get storageValue {
    switch (this) {
      case AnalyticsConsent.unanswered:
        return 'unanswered';
      case AnalyticsConsent.granted:
        return 'granted';
      case AnalyticsConsent.denied:
        return 'denied';
    }
  }

  static AnalyticsConsent fromStorageValue(String? value) {
    switch (value) {
      case 'granted':
        return AnalyticsConsent.granted;
      case 'denied':
        return AnalyticsConsent.denied;
      case 'unanswered':
      default:
        return AnalyticsConsent.unanswered;
    }
  }
}

abstract class AnalyticsService {
  AnalyticsConsent get consent;
  bool get isEnabled;

  Future<void> initialize();
  Future<void> setConsent(AnalyticsConsent consent);
  Future<void> logEvent(
    String name, {
    Map<String, Object?> params = const {},
  });

  Future<void> logScreenView(String screenName) {
    return logEvent('screen_view', params: {'screen_name': screenName});
  }
}

class NoopAnalyticsService implements AnalyticsService {
  AnalyticsConsent _consent;

  NoopAnalyticsService({
    AnalyticsConsent consent = AnalyticsConsent.unanswered,
  }) : _consent = consent;

  @override
  AnalyticsConsent get consent => _consent;

  @override
  bool get isEnabled => false;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> setConsent(AnalyticsConsent consent) async {
    _consent = consent;
  }

  @override
  Future<void> logEvent(
    String name, {
    Map<String, Object?> params = const {},
  }) async {}

  @override
  Future<void> logScreenView(String screenName) async {}
}
