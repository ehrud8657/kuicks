import 'package:flutter/foundation.dart';

/// 홈 화면에서 로고를 2번, 제목의 "보안"을 6번 차례로 누르되
/// 첫 번째 누름부터 5초 안에 모두 누르면 [completed]를 하나 올린다.
/// 로고는 홈 화면에서 누른 것만 넘겨야 한다(부르는 쪽에서 확인).
class HomeTapSequence {
  HomeTapSequence._();

  static final instance = HomeTapSequence._();

  static const logoTapsNeeded = 2;
  static const titleTapsNeeded = 6;
  static const window = Duration(seconds: 5);

  final completed = ValueNotifier<int>(0);

  /// 테스트에서 시계를 바꿔 끼운다.
  @visibleForTesting
  DateTime Function() now = DateTime.now;

  final _logoTaps = <DateTime>[];
  int _titleTaps = 0;

  void reset() {
    _logoTaps.clear();
    _titleTaps = 0;
  }

  void logoTapped() {
    final at = now();
    if (_titleTaps > 0) reset();
    _logoTaps.add(at);
    // 로고를 더 여러 번 눌렀으면 마지막 두 번부터 센다.
    while (_logoTaps.length > logoTapsNeeded) {
      _logoTaps.removeAt(0);
    }
  }

  void titleTapped() {
    final at = now();
    if (_logoTaps.length < logoTapsNeeded ||
        at.difference(_logoTaps.first) > window) {
      reset();
      return;
    }
    _titleTaps++;
    if (_titleTaps >= titleTapsNeeded) {
      reset();
      completed.value++;
    }
  }
}
