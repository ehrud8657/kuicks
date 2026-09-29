import 'package:file_picker/file_picker.dart';

import '../format.dart';

/// 사용자가 고른 파일 하나.
class PickedUpload {
  const PickedUpload({required this.name, required this.bytes});
  final String name;
  final List<int> bytes;

  int get size => bytes.length;
}

/// 파일 하나를 고르는 함수. 취소하면 null. 테스트에서는 가짜 함수로 바꿔 끼운다.
typedef UploadPicker = Future<PickedUpload?> Function();

/// 파일 여러 개를 고르는 함수. 취소하면 빈 목록.
typedef MultiUploadPicker = Future<List<PickedUpload>> Function();

/// 서버 기본 제한(SUBMISSION_MAX_BYTES=50MB)과 맞춘다. 최종 검사는 서버가 한다.
const maxSubmissionBytes = 50 * 1024 * 1024;

/// 서버 기본 제한(STUDY_POST_ATTACHMENT_MAX_BYTES=50MB)과 맞춘다.
const maxStudyPostFileBytes = 50 * 1024 * 1024;

Future<PickedUpload?> pickOneFile() async {
  final file = await FilePicker.pickFile();
  if (file == null) return null;
  return PickedUpload(name: file.name, bytes: await file.readAsBytes());
}

Future<List<PickedUpload>> pickManyFiles() async {
  final files = await FilePicker.pickFiles();
  return [
    for (final file in files)
      PickedUpload(name: file.name, bytes: await file.readAsBytes()),
  ];
}

/// 올리기 전에 걸러낼 수 있는 문제. 없으면 null. 형식은 가리지 않는다.
String? checkUpload(PickedUpload file, {required int maxBytes}) {
  if (file.size == 0) return '빈 파일은 올릴 수 없습니다.';
  if (file.size > maxBytes) {
    return '파일 크기는 ${formatSize(maxBytes)} 이하여야 합니다.';
  }
  return null;
}
