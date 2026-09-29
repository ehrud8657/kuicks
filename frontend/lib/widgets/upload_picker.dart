import 'package:file_picker/file_picker.dart';

import '../format.dart';

/// 사용자가 고른 zip 파일.
class PickedZip {
  const PickedZip({required this.name, required this.bytes});
  final String name;
  final List<int> bytes;

  int get size => bytes.length;
}

/// zip 파일을 고르는 함수. 취소하면 null. 테스트에서는 가짜 함수로 바꿔 끼운다.
typedef ZipPicker = Future<PickedZip?> Function();

/// 서버 기본 제한(SUBMISSION_MAX_BYTES=50MB)과 맞춘다. 최종 검사는 서버가 한다.
const maxSubmissionBytes = 50 * 1024 * 1024;

Future<PickedZip?> pickZipFile() async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: const ['zip'],
  );
  if (file == null) return null;
  return PickedZip(name: file.name, bytes: await file.readAsBytes());
}

/// 올리기 전에 걸러낼 수 있는 문제. 없으면 null.
String? checkZip(PickedZip file) {
  if (!file.name.toLowerCase().endsWith('.zip')) {
    return 'zip 파일만 제출할 수 있습니다.';
  }
  if (file.size == 0) return '빈 파일은 제출할 수 없습니다.';
  if (file.size > maxSubmissionBytes) {
    return '파일 크기는 ${formatSize(maxSubmissionBytes)} 이하여야 합니다.';
  }
  // zip 파일은 'PK'로 시작한다. 이름만 .zip으로 바꾼 파일을 올리기 전에 거른다.
  if (file.bytes[0] != 0x50 || (file.size > 1 && file.bytes[1] != 0x4B)) {
    return '올바른 zip 파일이 아닙니다.';
  }
  return null;
}
