import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';

/// 본문을 일반 텍스트와 링크 조각으로 나눈 결과.
class LinkSegment {
  const LinkSegment(this.text, {this.isLink = false});
  final String text;
  final bool isLink;

  @override
  String toString() => isLink ? 'link($text)' : 'text($text)';
}

// http(s)://... 또는 www.로 시작하는 주소.
// 문자 집합을 URL에 쓰이는 문자로 제한한다. [^\s]로 두면 "(https://kuics.org)를"처럼
// 한글이 바로 붙었을 때 주소에 딸려 들어간다.
final _urlPattern = RegExp(
  r"(https?://|www\.)[A-Za-z0-9\-._~:/?#\[\]@!$&'()*+,;=%]+",
  caseSensitive: false,
);

// 주소 뒤에 붙은 문장부호는 링크에서 뺀다.
// ("자세한 내용은 https://kuics.org 를 참고." 처럼 마침표가 붙는 경우)
const _trailingPunctuation = '.,;:!?)]}>\'"';

/// 본문에서 주소를 찾아 링크 조각과 일반 텍스트 조각으로 나눈다.
List<LinkSegment> linkSegments(String text) {
  final segments = <LinkSegment>[];
  var cursor = 0;

  for (final match in _urlPattern.allMatches(text)) {
    var url = match.group(0)!;
    var end = match.end;
    while (
        url.isNotEmpty && _trailingPunctuation.contains(url[url.length - 1])) {
      url = url.substring(0, url.length - 1);
      end -= 1;
    }
    // 주소로 볼 만한 게 남지 않으면 링크로 만들지 않는다
    if (url.isEmpty || !url.contains('.')) continue;

    if (match.start > cursor) {
      segments.add(LinkSegment(text.substring(cursor, match.start)));
    }
    segments.add(LinkSegment(url, isLink: true));
    cursor = end;
  }
  if (cursor < text.length) {
    segments.add(LinkSegment(text.substring(cursor)));
  }
  return segments;
}

/// 본문에 섞인 주소를 눌러서 열 수 있게 만든다.
///
/// TapGestureRecognizer는 직접 dispose해야 새는 걸 막을 수 있어서
/// StatefulWidget으로 두고 수명을 관리한다.
class LinkifiedText extends StatefulWidget {
  const LinkifiedText({super.key, required this.text, this.style});
  final String text;
  final TextStyle? style;

  @override
  State<LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<LinkifiedText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  Future<void> _open(String raw) async {
    final normalized = raw.startsWith('http') ? raw : 'https://$raw';
    final uri = Uri.tryParse(normalized);
    if (uri == null) return;
    final messenger = ScaffoldMessenger.of(context);
    if (!await launchUrl(uri)) {
      messenger.showSnackBar(
        SnackBar(content: Text('링크를 열지 못했습니다: $normalized')),
      );
    }
  }

  List<InlineSpan> _spans() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();

    return [
      for (final segment in linkSegments(widget.text))
        if (!segment.isLink)
          TextSpan(text: segment.text)
        else
          TextSpan(
            text: segment.text,
            style: const TextStyle(
              color: AppColors.crimson,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.crimson,
            ),
            recognizer: _recognizerFor(segment.text),
          ),
    ];
  }

  TapGestureRecognizer _recognizerFor(String url) {
    final recognizer = TapGestureRecognizer()..onTap = () => _open(url);
    _recognizers.add(recognizer);
    return recognizer;
  }

  @override
  Widget build(BuildContext context) => SelectionArea(
        child: Text.rich(
          TextSpan(
            style: widget.style ?? DefaultTextStyle.of(context).style,
            children: _spans(),
          ),
        ),
      );
}
