import 'package:flutter_test/flutter_test.dart';

import 'package:smart_teach_client/core/utils.dart';

void main() {
  test('stripHtml 去掉 HTML 标签', () {
    expect(stripHtml('<p>你好<br/>世界</p>'), '你好\n世界');
    expect(stripHtml('<b>加粗</b>&amp;符号'), '加粗&符号');
  });

  test('timeAgo 相对时间', () {
    final now = DateTime.utc(2026, 11, 26, 10, 0, 0);
    final t = now.subtract(const Duration(minutes: 5));
    expect(timeAgo(t.toIso8601String(), now: now), '5 分钟前');
  });

  test('colorFromHex 解析', () {
    expect(colorFromHex('#26a03d').value, 0xFF26A03D);
  });
}
