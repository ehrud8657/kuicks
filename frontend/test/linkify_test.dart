import 'package:flutter_test/flutter_test.dart';
import 'package:kuics_frontend/main.dart';

/// 링크 조각만 뽑아낸다.
List<String> links(String text) => linkSegments(text)
    .where((segment) => segment.isLink)
    .map((segment) => segment.text)
    .toList();

/// 조각을 다시 이으면 원문과 같아야 한다. (본문이 잘리거나 중복되지 않는지)
void expectLossless(String text) {
  final joined = linkSegments(text).map((segment) => segment.text).join();
  expect(joined, text, reason: '조각을 합치면 원문과 같아야 한다');
}

void main() {
  test('주소가 없으면 통째로 일반 텍스트', () {
    final segments = linkSegments('이번 주 정기 모임은 목요일입니다.');
    expect(segments.length, 1);
    expect(segments.first.isLink, isFalse);
  });

  test('빈 문자열도 안전하게 처리한다', () {
    expect(linkSegments(''), isEmpty);
  });

  test('http/https 주소를 찾는다', () {
    expect(links('신청은 https://kuics.org/apply 에서'), ['https://kuics.org/apply']);
    expect(links('http://example.com 참고'), ['http://example.com']);
  });

  test('www로 시작하는 주소도 찾는다', () {
    expect(links('www.kuics.org 를 방문하세요'), ['www.kuics.org']);
  });

  test('주소 뒤 마침표는 링크에서 제외한다', () {
    expect(links('자세한 건 https://kuics.org.'), ['https://kuics.org']);
    expect(links('여기(https://kuics.org)를 보세요'), ['https://kuics.org']);
    expect(links('https://kuics.org, 그리고'), ['https://kuics.org']);
  });

  test('한 본문에 여러 주소가 있어도 모두 찾는다', () {
    expect(
      links('공지 https://a.com 와 신청 https://b.com/form 을 확인'),
      ['https://a.com', 'https://b.com/form'],
    );
  });

  test('한글 바로 뒤에 붙은 주소도 찾는다', () {
    expect(links('링크:https://kuics.org'), ['https://kuics.org']);
  });

  test('점이 없으면 주소로 보지 않는다', () {
    expect(links('http://.'), isEmpty);
  });

  test('원문이 손실되지 않는다', () {
    expectLossless('신청은 https://kuics.org/apply 에서 받습니다.');
    expectLossless('여러 개 https://a.com 그리고 www.b.org 입니다.');
    expectLossless('주소 없는 평범한 공지입니다.');
    expectLossless('끝에 주소 https://kuics.org');
  });

  test('링크와 텍스트 순서가 유지된다', () {
    final segments = linkSegments('앞 https://a.com 뒤');
    expect(segments.map((s) => s.isLink).toList(), [false, true, false]);
    expect(segments.first.text, '앞 ');
    expect(segments.last.text, ' 뒤');
  });
}
