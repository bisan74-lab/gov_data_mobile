import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/env.dart';

/// 실제 광고를 로드해도 되는 상태인지. **[main]에서 광고 SDK 초기화에 성공한
/// 뒤에만 true로 켠다.** 기본값이 false라 위젯 테스트는 광고 플랫폼 채널을
/// 아예 건드리지 않고, 화면에는 아래 앱 소개 박스가 그대로 나온다.
///
/// **테스트에서 이 값을 켜지 말 것** — 켜는 순간 위젯 테스트가 존재하지 않는
/// 플랫폼 채널을 부른다.
bool adsRuntimeEnabled = false;

/// 광고 SDK 초기화가 끝나기를 기다리는 Future. `main()`이 채운다.
///
/// 초기화를 **await한 뒤에야** `runApp`을 부르면, 광고는 부가 기능인데도
/// SDK가 굼뜬 기기에서 첫 프레임이 몇 초씩 밀린다. 그래서 초기화는 띄워만
/// 두고 화면을 먼저 올리고, 배너 자리가 이 Future를 기다렸다가 준비되면
/// 그때 로드한다. 테스트에서는 null이라 플랫폼 채널을 건드리지 않는다.
Future<void>? adsReady;

/// 배너가 붙는 자리. 자리마다 광고 단위를 따로 두면 AdMob 리포트에서 어느
/// 화면이 얼마나 버는지 나눠 볼 수 있다.
enum AdSlot {
  /// 홈 화면 하단.
  home,

  /// 날씨 화면 하단.
  weather,

  /// 설정 화면 하단.
  settings;

  String get adUnitId => switch (this) {
    AdSlot.home => Env.admobBannerAdUnitId,
    AdSlot.weather => Env.admobWeatherBannerAdUnitId,
    AdSlot.settings => Env.admobSettingsBannerAdUnitId,
  };
}

/// 화면 맨 아래 광고 배너 자리. 홈·날씨·설정 화면이 같은 위젯을 공유한다.
///
/// **광고는 부가 기능이라 절대 앱을 막지 않는다.** 배너가 실제로 로드되면
/// 배너를, 그렇지 않으면(광고 비활성·로드 실패·오프라인) **같은 높이의 앱
/// 소개 박스**를 보여준다. 이 폴백을 없애면 광고가 없을 때 레이아웃에 빈 칸이
/// 생긴다.
///
/// 세 화면 모두 이 위젯을 [Scaffold.bottomNavigationBar]가 아니라 본문
/// 아래에 **고정 높이 띠**로 깔고, 본문 스크롤 영역은 그만큼 줄어든다
/// ([AdBannerBar] 참고).
class AdPlaceholder extends StatefulWidget {
  const AdPlaceholder({super.key, required this.slot});

  final AdSlot slot;

  /// 배너(320×50)와 소개 박스가 공유하는 높이.
  static const double height = 56;

  @override
  State<AdPlaceholder> createState() => _AdPlaceholderState();
}

class _AdPlaceholderState extends State<AdPlaceholder> {
  BannerAd? _banner;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (adsRuntimeEnabled) {
      _loadBanner();
    } else {
      // 아직 SDK 초기화가 안 끝났을 수 있다(첫 화면을 막지 않으려고 병렬로
      // 돌린다). 끝나면 그때 로드하고, 끝내 실패하면 소개 박스로 남는다.
      adsReady?.then((_) {
        if (mounted && adsRuntimeEnabled) _loadBanner();
      });
    }
  }

  void _loadBanner() {
    final adUnitId = widget.slot.adUnitId;
    if (!adsRuntimeEnabled || adUnitId.isEmpty) return;
    final banner = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          // 로드 실패(노출 재고 없음·오프라인 등)는 정상 상황이다. 배너를
          // 정리하고 소개 박스로 남는다.
          ad.dispose();
          if (mounted) setState(() => _banner = null);
        },
      ),
    );
    _banner = banner;
    // 어떤 이유로든 로드 호출이 실패해도 앱이 죽지 않고 소개 박스로 넘어간다.
    try {
      banner.load();
    } catch (_) {
      _banner = null;
    }
  }

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banner = _banner;
    if (_loaded && banner != null) {
      return SizedBox(
        height: AdPlaceholder.height,
        child: Center(
          child: SizedBox(
            width: banner.size.width.toDouble(),
            height: banner.size.height.toDouble(),
            child: AdWidget(ad: banner),
          ),
        ),
      );
    }
    return const _AppIntroBox();
  }
}

/// 광고가 없을 때 같은 자리를 채우는 앱 소개 박스.
class _AppIntroBox extends StatelessWidget {
  const _AppIntroBox();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // **이 박스만 글자 배율에 상한을 둔다.** 높이가 배너 광고 규격
    // ([AdPlaceholder.height])에 묶여 있어 늘릴 수 없는데, 시스템 글자 크기를
    // 키우면 안의 두 줄이 그대로 넘친다. 광고 자리를 메우는 장식이라 여기서만
    // 배율을 제한하는 것이 맞다 — **본문 화면에는 이 방식을 쓰지 말 것**
    // (사용자의 접근성 설정을 무시하게 된다).
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.2,
      child: _box(context, scheme),
    );
  }

  Widget _box(BuildContext context, ColorScheme scheme) {
    return Container(
      height: AdPlaceholder.height,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/icon/app_icon.png',
              width: 36,
              height: 36,
              errorBuilder: (_, _, _) =>
                  Icon(Icons.golf_course, size: 32, color: scheme.primary),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '골프윈디',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  '전국 골프장 바람·날씨를 한눈에',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 화면 맨 아래에 까는 광고 띠. 본문과 배너를 [Column]으로 쌓아, 본문이
/// **배너를 뺀 높이**만 쓰도록 재조정한다.
///
/// [Scaffold.bottomNavigationBar]에 넣지 않는 이유: 홈·날씨·설정은 앱 셸의
/// 탭 화면이라 진짜 하단 내비게이션 바가 이미 아래에 있다. 배너를 그 자리에
/// 또 넣으면 내비게이션 바와 자리를 다투게 되므로, 각 화면 body 안에서
/// 마지막 띠로 깐다.
///
/// [SafeArea]로 아래 여백을 확보해, 제스처 내비게이션 기기에서 배너가 홈
/// 인디케이터에 가리지 않게 한다.
class AdBannerBar extends StatelessWidget {
  const AdBannerBar({super.key, required this.slot, required this.child});

  final AdSlot slot;

  /// 배너 위에 놓일 본문. 남는 높이를 전부 갖는다.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: child),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
            child: AdPlaceholder(slot: slot),
          ),
        ),
      ],
    );
  }
}
