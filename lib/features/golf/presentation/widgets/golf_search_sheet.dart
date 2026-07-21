import 'package:flutter/material.dart';

import '../../data/models/golf_course.dart';

/// 골프장 이름 검색 바텀시트. 선택한 골프장을 [Navigator.pop]으로 돌려준다.
/// (Windy 지도의 돋보기 아이콘에서 연다.)
Future<GolfCourse?> showGolfSearchSheet(
  BuildContext context,
  List<GolfCourse> courses,
) {
  return showModalBottomSheet<GolfCourse>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _GolfSearchSheet(courses: courses),
  );
}

class _GolfSearchSheet extends StatefulWidget {
  const _GolfSearchSheet({required this.courses});

  final List<GolfCourse> courses;

  @override
  State<_GolfSearchSheet> createState() => _GolfSearchSheetState();
}

class _GolfSearchSheetState extends State<_GolfSearchSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim();
    final results = q.isEmpty
        ? widget.courses
        : widget.courses
              .where(
                (c) =>
                    c.name.contains(q) ||
                    c.region.contains(q) ||
                    c.address.contains(q),
              )
              .toList();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        builder: (context, controller) => Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: '골프장 이름·지역 검색',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: results.isEmpty
                  ? const Center(child: Text('검색 결과가 없습니다.'))
                  : ListView.builder(
                      controller: controller,
                      itemCount: results.length,
                      itemBuilder: (context, i) {
                        final c = results[i];
                        return ListTile(
                          leading: const Icon(Icons.golf_course),
                          title: Text(c.name),
                          subtitle: Text(
                            c.address.isEmpty
                                ? '${c.region} · ${c.holes}홀'
                                : '${c.address} · ${c.holes}홀',
                          ),
                          onTap: () => Navigator.of(context).pop(c),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
