import '../models.dart';
import '../theme.dart';

extension AttendanceStatusStyle on AttendanceStatus {
  BadgeTone get tone => switch (this) {
        AttendanceStatus.present => BadgeTone.success,
        AttendanceStatus.late => BadgeTone.warning,
        AttendanceStatus.absent => BadgeTone.danger,
        AttendanceStatus.excused => BadgeTone.info,
      };

  /// 현황표에 쓰는 한 글자 표기. 예: 출, 지, 결, 공
  String get short => label.substring(0, 1);
}

extension ParticipationStatusStyle on ParticipationStatus {
  BadgeTone get tone => switch (this) {
        ParticipationStatus.active => BadgeTone.info,
        ParticipationStatus.completed => BadgeTone.success,
        ParticipationStatus.excellent => BadgeTone.danger,
        ParticipationStatus.withdrawn => BadgeTone.neutral,
      };
}
