import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Wraps Google Mobile Ads (AdMob) setup, banner loading, and interstitial
/// loading/showing behind a tiny API the rest of the app can call.
///
/// IMPORTANT: every ID in this file is one of Google's official public
/// TEST ad unit IDs. They always fill with a clearly-labeled "Test Ad" and
/// generate no real revenue — safe to ship while developing. Before a real
/// Play Store / App Store release, replace these with the ad unit IDs from
/// your own AdMob account (and the app IDs in AndroidManifest.xml /
/// Info.plist), or you risk your AdMob account being suspended for invalid
/// traffic.
///
/// NOTE: google_mobile_ads only supports Android and iOS — there is no web
/// (or desktop) implementation. Every method below checks [kIsWeb] first and
/// safely no-ops there, so `flutter run -d chrome` still works; ads simply
/// don't appear when testing on web. Run on an Android emulator/device or
/// iOS simulator/device to actually see the test ads.
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  /// True only on Android/iOS, where google_mobile_ads actually works.
  static bool get _adsSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Google test banner ad unit.
  static String get bannerAdUnitId {
    if (Platform.isAndroid) return 'ca-app-pub-3940256099942544/6300978111';
    if (Platform.isIOS) return 'ca-app-pub-3940256099942544/2934735716';
    throw UnsupportedError('Unsupported platform for banner ads');
  }

  /// Google test interstitial ad unit.
  static String get interstitialAdUnitId {
    if (Platform.isAndroid) return 'ca-app-pub-3940256099942544/1033173712';
    if (Platform.isIOS) return 'ca-app-pub-3940256099942544/4411468910';
    throw UnsupportedError('Unsupported platform for interstitial ads');
  }

  InterstitialAd? _interstitialAd;
  bool _interstitialLoading = false;

  /// Call once before runApp(). Safe no-op on web/desktop.
  static Future<void> initialize() async {
    if (!_adsSupported) return;
    await MobileAds.instance.initialize();
  }

  /// Creates a fresh, ready-to-load banner ad, or null on platforms
  /// google_mobile_ads doesn't support (web/desktop). It's already loading
  /// by the time this returns. Dispose the result in the widget's
  /// `dispose()`.
  BannerAd? createBannerAd({required void Function() onLoaded}) {
    if (!_adsSupported) return null;
    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => onLoaded(),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    )..load();
  }

  /// Preloads an interstitial so it's ready the moment [showInterstitial]
  /// is called (e.g. right after a level ends). Safe no-op on web/desktop.
  void preloadInterstitial() {
    if (!_adsSupported) return;
    if (_interstitialLoading || _interstitialAd != null) return;
    _interstitialLoading = true;
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialLoading = false;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              preloadInterstitial(); // get the next one ready
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _interstitialAd = null;
              preloadInterstitial();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _interstitialLoading = false;
          _interstitialAd = null;
        },
      ),
    );
  }

  /// Shows the preloaded interstitial if one is ready; otherwise does
  /// nothing (never blocks gameplay waiting on a network call, and is a
  /// safe no-op on web/desktop).
  void showInterstitial() {
    if (!_adsSupported) return;
    final ad = _interstitialAd;
    if (ad == null) {
      preloadInterstitial();
      return;
    }
    _interstitialAd = null;
    ad.show();
  }
}
