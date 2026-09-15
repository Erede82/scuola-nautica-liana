import 'dart:async';

import 'package:flutter/foundation.dart';

import 'anti_loop_storage.dart';
import 'app_build_info.dart';
import 'stripe_checkout_guard.dart';
import 'version_fetcher.dart';
import 'web_reload_adapter.dart';

/// Controller globale PWA auto-update (detector = version.json).
class AppUpdateCoordinator extends ChangeNotifier {
  AppUpdateCoordinator._();

  static AppUpdateCoordinator? _instance;

  static AppUpdateCoordinator get instance =>
      _instance ??= AppUpdateCoordinator._();

  static const Duration startupDelay = Duration(seconds: 2);
  static const Duration periodicInterval = Duration(minutes: 15);
  static const Duration minCheckInterval = Duration(seconds: 30);
  static const Duration manualDeferDuration = Duration(minutes: 15);
  static const Duration antiLoopCooldown = Duration(minutes: 10);
  static const Duration safeApplyDebounce = Duration(milliseconds: 500);
  static const Duration unsafeCloseDebounce = Duration(milliseconds: 500);

  VersionJsonFetcher versionJsonFetcher = defaultVersionJsonFetcher;
  WebReloadAdapter reloadAdapter = defaultWebReloadAdapter;
  DateTime Function() now = DateTime.now;

  @visibleForTesting
  bool debugForceCheckerEnabled = false;

  bool get _checkerActive =>
      debugForceCheckerEnabled || AppBuildInfo.isUpdateCheckerEnabled;

  int _unsavedWorkCount = 0;
  int _activeMutationCount = 0;
  bool _updateAvailable = false;
  String? _remoteAppVersion;
  DateTime? _manualDeferUntil;
  DateTime? _lastCheckAt;
  bool _checkInFlight = false;
  Timer? _periodicTimer;
  Timer? _applyDebounceTimer;
  Timer? _unsafeCloseDebounceTimer;
  bool _bannerVisible = false;

  @visibleForTesting
  Duration safeApplyDebounceDuration = safeApplyDebounce;

  @visibleForTesting
  Duration unsafeCloseDebounceDuration = unsafeCloseDebounce;

  @visibleForTesting
  Duration periodicIntervalDuration = periodicInterval;

  @visibleForTesting
  Duration minCheckIntervalDuration = minCheckInterval;

  int get unsavedWorkCount => _unsavedWorkCount;
  int get activeMutationCount => _activeMutationCount;
  bool get updateAvailable => _updateAvailable;
  String? get remoteAppVersion => _remoteAppVersion;
  bool get bannerVisible => _bannerVisible;

  bool get isManualDeferActive {
    final until = _manualDeferUntil;
    if (until == null) return false;
    if (!now().isBefore(until)) {
      _manualDeferUntil = null;
      return false;
    }
    return true;
  }

  bool get canReloadSafely =>
      _updateAvailable &&
      _unsavedWorkCount == 0 &&
      _activeMutationCount == 0 &&
      !StripeCheckoutGuard.isCheckoutPending &&
      !isManualDeferActive &&
      _antiLoopAllowsReload();

  bool get isUnsafeForUpdate =>
      _unsavedWorkCount > 0 ||
      _activeMutationCount > 0 ||
      StripeCheckoutGuard.isCheckoutPending;

  void beginUnsafeWork() {
    _unsavedWorkCount++;
    _syncBannerVisibility();
    notifyListeners();
  }

  void endUnsafeWork() {
    if (_unsavedWorkCount > 0) {
      _unsavedWorkCount--;
    }
    _syncBannerVisibility();
    notifyListeners();
    _scheduleApplyAfterUnsafeClose();
  }

  void beginMutation() {
    _activeMutationCount++;
    _syncBannerVisibility();
    notifyListeners();
  }

  void endMutation() {
    if (_activeMutationCount > 0) {
      _activeMutationCount--;
    }
    _syncBannerVisibility();
    notifyListeners();
    _scheduleApplyAfterUnsafeClose();
  }

  void deferUpdate() {
    _manualDeferUntil = now().add(manualDeferDuration);
    _syncBannerVisibility();
    notifyListeners();
  }

  Future<void> checkForUpdate({bool force = false}) async {
    if (!_checkerActive) return;
    if (_checkInFlight) return;

    final current = now();
    if (!force &&
        _lastCheckAt != null &&
        current.difference(_lastCheckAt!) < minCheckIntervalDuration) {
      return;
    }

    _checkInFlight = true;
    _lastCheckAt = current;
    try {
      final remote = await fetchRemoteAppVersion(
        fetcher: versionJsonFetcher,
        cacheBustEpochMs: current.millisecondsSinceEpoch,
      );
      if (remote == null) return;

      final changed = remote.appVersion != AppBuildInfo.version;
      if (!changed) {
        if (_updateAvailable) {
          _updateAvailable = false;
          _remoteAppVersion = null;
          _syncBannerVisibility();
          notifyListeners();
        }
        return;
      }

      _updateAvailable = true;
      _remoteAppVersion = remote.appVersion;
      _syncBannerVisibility();
      notifyListeners();
      _scheduleAutoApply();
    } finally {
      _checkInFlight = false;
    }
  }

  void updateNow() {
    if (!canReloadSafely) {
      _syncBannerVisibility(forceShowWhenUnsafe: true);
      notifyListeners();
      return;
    }
    _performReload();
  }

  void installLifecycle({
    Duration startupDelayOverride = startupDelay,
  }) {
    if (!_checkerActive) return;

    AppUpdateCoordinatorBridge.onStripeChanged = () {
      _syncBannerVisibility();
      notifyListeners();
      _scheduleApplyAfterUnsafeClose();
    };

    Future<void>.delayed(startupDelayOverride, () {
      unawaited(checkForUpdate(force: true));
    });

    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(periodicIntervalDuration, (_) {
      unawaited(checkForUpdate());
    });
  }

  void onAppResumed() {
    unawaited(checkForUpdate());
  }

  void onVisibilityVisible() {
    unawaited(checkForUpdate());
  }

  void disposeLifecycle() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _applyDebounceTimer?.cancel();
    _unsafeCloseDebounceTimer?.cancel();
    AppUpdateCoordinatorBridge.onStripeChanged = null;
  }

  void _scheduleAutoApply() {
    if (!_updateAvailable || isManualDeferActive) return;
    if (isUnsafeForUpdate) return;
    if (!_antiLoopAllowsReload()) return;

    _applyDebounceTimer?.cancel();
    _applyDebounceTimer = Timer(safeApplyDebounceDuration, () {
      if (canReloadSafely) {
        _performReload();
      } else {
        _syncBannerVisibility();
        notifyListeners();
      }
    });
  }

  void _scheduleApplyAfterUnsafeClose() {
    if (!_updateAvailable || isManualDeferActive) return;
    if (isUnsafeForUpdate) return;

    _unsafeCloseDebounceTimer?.cancel();
    _unsafeCloseDebounceTimer = Timer(unsafeCloseDebounceDuration, () {
      if (canReloadSafely && _antiLoopAllowsReload()) {
        _performReload();
      } else {
        _syncBannerVisibility();
        notifyListeners();
      }
    });
  }

  void _performReload() {
    final remote = _remoteAppVersion;
    if (remote == null) return;

    AntiLoopStorage.writeLastAttemptedRemoteVersion(remote);
    AntiLoopStorage.writeLastReloadTimestamp(now().toUtc());

    reloadAdapter();
  }

  bool _antiLoopAllowsReload() {
    final remote = _remoteAppVersion;
    if (remote == null) return false;

    final lastVersion = AntiLoopStorage.readLastAttemptedRemoteVersion();
    final lastReload = AntiLoopStorage.readLastReloadTimestamp();
    if (lastVersion != remote) return true;
    if (lastReload == null) return true;

    return now().toUtc().difference(lastReload) >= antiLoopCooldown;
  }

  void _syncBannerVisibility({bool forceShowWhenUnsafe = false}) {
    if (!_updateAvailable || isManualDeferActive) {
      _bannerVisible = false;
      return;
    }
    if (canReloadSafely && !forceShowWhenUnsafe) {
      _bannerVisible = false;
      return;
    }
    _bannerVisible = true;
  }

  @visibleForTesting
  void resetForTest() {
    _unsavedWorkCount = 0;
    _activeMutationCount = 0;
    _updateAvailable = false;
    _remoteAppVersion = null;
    _manualDeferUntil = null;
    _lastCheckAt = null;
    _checkInFlight = false;
    _bannerVisible = false;
    debugForceCheckerEnabled = false;
    _applyDebounceTimer?.cancel();
    _unsafeCloseDebounceTimer?.cancel();
    _periodicTimer?.cancel();
    AntiLoopStorage.resetForTest();
    StripeCheckoutGuard.resetForTest();
    notifyListeners();
  }

  @visibleForTesting
  void setRemoteForTest(String remoteVersion) {
    _updateAvailable = remoteVersion != AppBuildInfo.version;
    _remoteAppVersion = remoteVersion;
    _syncBannerVisibility();
    notifyListeners();
  }

  @visibleForTesting
  void scheduleAutoApplyForTest() => _scheduleAutoApply();
}
