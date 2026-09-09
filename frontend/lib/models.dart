enum MemberRole { dormant, member, leader, admin }

class Member {
  const Member({
    required this.studentId,
    required this.name,
    required this.role,
    required this.mustChangePassword,
  });

  final String studentId;
  final String name;
  final MemberRole role;
  final bool mustChangePassword;

  factory Member.fromJson(Map<String, dynamic> json) => Member(
    studentId: json['student_id'] as String,
    name: json['name'] as String,
    role: MemberRole.values.firstWhere(
      (value) => value.name == json['role'],
      orElse: () => MemberRole.member,
    ),
    mustChangePassword: json['must_change_password'] as bool? ?? false,
  );
}

enum ParticipationStatus { active, completed, excellent, withdrawn }

class Participant {
  const Participant({
    required this.name,
    required this.studentIdTail,
    required this.status,
  });
  final String name;

  /// 학번 뒷 2자리. 동명이인을 구분하는 용도로만 쓰며 학번 전체는 받지 않는다.
  final String studentIdTail;
  final ParticipationStatus status;

  /// 명단 표기용 이름. 예: `홍길동(44)`
  String get label => studentIdTail.isEmpty ? name : '$name($studentIdTail)';

  factory Participant.fromJson(Map<String, dynamic> json) => Participant(
    name: json['member_name'] as String? ?? '',
    studentIdTail: json['student_id_tail'] as String? ?? '',
    status: ParticipationStatus.values.firstWhere(
      (value) => value.name == json['status'],
      orElse: () => ParticipationStatus.active,
    ),
  );
}

class Study {
  const Study({
    required this.id,
    required this.title,
    required this.leader,
    required this.description,
    required this.prerequisites,
    required this.recommended,
    required this.participants,
  });

  final int id;
  final String title;
  final String leader;
  final String description;
  final String prerequisites;
  final String recommended;
  final List<Participant> participants;

  factory Study.fromJson(Map<String, dynamic> json) => Study(
    id: json['id'] as int,
    title: json['title'] as String,
    leader: json['leader_name'] as String? ?? '미정',
    description: json['description'] as String? ?? '',
    prerequisites: json['prerequisites'] as String? ?? '없음',
    recommended: json['recommended'] as String? ?? '없음',
    participants: (json['participations'] as List<dynamic>? ?? const [])
        .map((item) => Participant.fromJson(item as Map<String, dynamic>))
        .toList(),
  );
}

class Semester {
  const Semester({required this.id, required this.name, required this.studies});
  final int id;
  final String name;
  final List<Study> studies;

  factory Semester.fromJson(Map<String, dynamic> json) => Semester(
    id: json['id'] as int,
    name: json['name'] as String,
    studies: (json['studies'] as List<dynamic>? ?? const [])
        .map((item) => Study.fromJson(item as Map<String, dynamic>))
        .toList(),
  );
}

/// 마이페이지에서 쓰는, 로그인 회원 본인의 스터디 참여 이력.
class MyStudy {
  const MyStudy({
    required this.studyId,
    required this.title,
    required this.semester,
    required this.status,
  });

  final int studyId;
  final String title;
  final String semester;
  final ParticipationStatus status;

  bool get isOngoing => status == ParticipationStatus.active;
  bool get isCompleted =>
      status == ParticipationStatus.completed ||
      status == ParticipationStatus.excellent;

  factory MyStudy.fromJson(Map<String, dynamic> json) => MyStudy(
    studyId: json['study_id'] as int,
    title: json['title'] as String,
    semester: json['semester'] as String? ?? '',
    status: ParticipationStatus.values.firstWhere(
      (value) => value.name == json['status'],
      orElse: () => ParticipationStatus.active,
    ),
  );
}
