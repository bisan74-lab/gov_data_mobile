import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/compact_text_scale.dart';

/// 홈 화면 상단의 좌우 스크롤 날짜 띠. [minDate]~[maxDate] 범위(기본 과거
/// 2주~미래 2주, 총 4주)를 좌우로 넘기며 날짜를 고를 수 있다.
class HomeDateStrip extends StatefulWidget {
  const HomeDateStrip({
    super.key,
    required this.date,
    required this.minDate,
    required this.maxDate,
    required this.onChanged,
  });

  final DateTime date;
  final DateTime minDate;
  final DateTime maxDate;
  final ValueChanged<DateTime> onChanged;

  @override
  State<HomeDateStrip> createState() => _HomeDateStripState();
}

class _HomeDateStripState extends State<HomeDateStrip> {
  final _controller = ScrollController();
  static const _itemWidth = 52.0;

  int get _totalDays => widget.maxDate.difference(widget.minDate).inDays + 1;

  int _indexFor(DateTime d) => DateUtils.dateOnly(
    d,
  ).difference(DateUtils.dateOnly(widget.minDate)).inDays;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _centerOn(widget.date, animate: false),
    );
  }

  @override
  void didUpdateWidget(covariant HomeDateStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!DateUtils.isSameDay(oldWidget.date, widget.date)) {
      _centerOn(widget.date, animate: true);
    }
  }

  void _centerOn(DateTime date, {required bool animate}) {
    if (!_controller.hasClients) return;
    final index = _indexFor(date);
    final viewport = _controller.position.viewportDimension;
    final target = index * _itemWidth - viewport / 2 + _itemWidth / 2;
    final clamped = target.clamp(0.0, _controller.position.maxScrollExtent);
    if (animate) {
      _controller.animateTo(
        clamped,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _controller.jumpTo(clamped);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 배율 1.0에서 날짜 칩이 필요한 높이. 글자가 커지면 아래 [build]가 이
  /// 값을 배율만큼 늘려 준다(고정해 두면 칩이 세로로 넘친다).
  static const double _baseHeight = 60;

  @override
  Widget build(BuildContext context) {
    // 폭 52px 고정 칩이라 앱 상한(1.5)에서도 글자가 칩을 뚫는다 — 칩만
    // 1.3으로 한 번 더 누르고([CompactTextScale]) 남은 배율만큼 높이를
    // 늘린다. 가로 스크롤 목록이라 높이가 조금 늘어도 배치가 안 깨진다.
    final scaled =
        MediaQuery.textScalerOf(
          context,
        ).clamp(maxScaleFactor: kCompactMaxTextScale).scale(14) /
        14;
    return SizedBox(
      height: _baseHeight * scaled,
      child: ListView.builder(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        itemCount: _totalDays,
        itemBuilder: (context, i) {
          final d = DateUtils.dateOnly(widget.minDate).add(Duration(days: i));
          final isSelected = DateUtils.isSameDay(d, widget.date);
          final isToday = DateUtils.isSameDay(d, DateTime.now());
          return GestureDetector(
            onTap: () => widget.onChanged(d),
            child: CompactTextScale(
              child: Container(
                width: _itemWidth - 6,
                margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: isToday && !isSelected
                      ? Border.all(color: Colors.white70)
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      weekdayKo(d),
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected
                            ? const Color(0xFF0E3454)
                            : Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${d.day}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? const Color(0xFF0E3454)
                            : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
