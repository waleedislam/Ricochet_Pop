import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Wraps Google Mobile Ads (AdMob) setup, banner loading, and rewarded
/// interstitial loading/showing behind a tiny API the rest of the app can
/// call.
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

  /// Google test rewarded interstitial ad unit. Rewarded interstitials are
  /// full-screen like a plain interstitial, but reward the player for
  /// watching — better for player goodwill and typically better eCPM than
  /// a plain interstitial in the same placement.
  static String get rewardedInterstitialAdUnitId {
    if (Platform.isAndroid) return 'ca-app-pub-3940256099942544/5354046379';
    if (Platform.isIOS) return 'ca-app-pub-3940256099942544/6978759866';
    throw UnsupportedError('Unsupported platform for rewarded interstitial ads');
  }

  RewardedInterstitialAd? _rewardedAd;
  bool _rewardedLoading = false;

  /// Counts level-ends (win or lose, combined) so the ad prompt only shows
  /// every [_levelEndsPerAd] times instead of after every single level —
  /// showing a full-screen ad after every level feels punishing regardless
  /// of whether the player won or lost, so this is a flat counter rather
  /// than being tied to win/loss.
  static const int _levelEndsPerAd = 3;
  int _levelEndCount = 0;

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

  /// Preloads a rewarded interstitial so it's ready the moment
  /// [showRewardedInterstitial] is called. Safe no-op on web/desktop.
  void preloadRewardedInterstitial() {
    if (!_adsSupported) return;
    if (_rewardedLoading || _rewardedAd != null) return;
    _rewardedLoading = true;
    RewardedInterstitialAd.load(
      adUnitId: rewardedInterstitialAdUnitId,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _rewardedLoading = false;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _rewardedAd = null;
              preloadRewardedInterstitial(); // get the next one ready
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _rewardedAd = null;
              preloadRewardedInterstitial();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _rewardedLoading = false;
          _rewardedAd = null;
        },
      ),
    );
  }

  /// Call this once per level end (win or lose). Returns true every
  /// [_levelEndsPerAd]th time — the caller should then show an intro
  /// prompt (reward + skip option, per Google's rewarded-interstitial
  /// guidance) before actually calling [showRewardedInterstitial].
  bool shouldOfferLevelEndAd() {
    _levelEndCount++;
    return _levelEndCount % _levelEndsPerAd == 0;
  }

  /// True if a rewarded interstitial is loaded and ready to show right
  /// now. Lets the caller decide not to bother offering it if not.
  bool get isRewardedInterstitialReady => _rewardedAd != null;

  /// Shows the preloaded rewarded interstitial if one is ready, calling
  /// [onReward] with the reward amount once the player actually earns it
  /// (i.e. watches enough of the ad — not just for opening it). Does
  /// nothing if no ad is ready (never blocks gameplay waiting on a
  /// network call), and is a safe no-op on web/desktop.
  void showRewardedInterstitial({required void Function(int amount) onReward}) {
    if (!_adsSupported) return;
    final ad = _rewardedAd;
    if (ad == null) {
      preloadRewardedInterstitial();
      return;
    }
    _rewardedAd = null;
    ad.show(
      onUserEarnedReward: (ad, reward) => onReward(reward.amount.toInt()),
    );
  }
}
