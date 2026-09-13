enum MemberRole {
  dormant('휴회원'),
  member('정회원'),
  leader('스터디장'),
  admin('운영진');

  const MemberRole(this.label);
  final String label;

  /// 스터디 관리 화면에 들어갈 수 있는 등급. 실제 권한은 서버가 다시 검사한다.
  bool get canManageStudies => this == leader || this == admin;
}

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

  Member copyWith({bool? mustChangePassword}) => Member(
        studentId: studentId,
        name: name,
        role: role,
        mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      );

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

enum ParticipationStatus {
  active('수강 중'),
  completed('수료'),
  excellent('우수 수료'),
  withdrawn('중도 포기');

  const ParticipationStatus(this.label);
  final String label;

  static ParticipationStatus parse(Object? name) => values.firstWhere(
        (value) => value.name == name,
        orElse: () => ParticipationStatus.active,
      );
}

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
    this.assignmentCount = 0,
    this.pendingAssignmentCount = 0,
  });

  final int studyId;
  final String title;
  final String semester;
  final ParticipationStatus status;
  final int assignmentCount;

  /// 기한이 남았는데 아직 내지 않은 과제 수.
  final int pendingAssignmentCount;

  bool get isOngoing => status == ParticipationStatus.active;
  bool get isCompleted =>
      status == ParticipationStatus.completed ||
      status == ParticipationStatus.excellent;

  factory MyStudy.fromJson(Map<String, dynamic> json) => MyStudy(
        studyId: json['study_id'] as int,
        title: json['title'] as String,
        semester: json['semester'] as String? ?? '',
        status: ParticipationStatus.parse(json['status']),
        assignmentCount: json['assignment_count'] as int? ?? 0,
        pendingAssignmentCount: json['pending_assignment_count'] as int? ?? 0,
      );
}

enum PostCategory { notice, recruit }

class Post {
  const Post({
    required this.id,
    required this.category,
    required this.title,
    required this.content,
    required this.authorName,
    required this.isPinned,
    required this.publishedAt,
  });

  final int id;
  final PostCategory category;
  final String title;
  final String content;
  final String authorName;
  final bool isPinned;
  final DateTime? publishedAt;

  factory Post.fromJson(Map<String, dynamic> json) => Post(
        id: json['id'] as int,
        category: PostCategory.values.firstWhere(
          (value) => value.name == json['category'],
          orElse: () => PostCategory.notice,
        ),
        title: json['title'] as String? ?? '',
        content: json['content'] as String? ?? '',
        authorName: json['author_name'] as String? ?? '',
        isPinned: json['is_pinned'] as bool? ?? false,
        publishedAt: DateTime.tryParse(json['published_at'] as String? ?? ''),
      );
}

/// 게시글 한 페이지. 서버가 페이지네이션하므로 다음 장이 있는지 함께 받는다.
class PostPage {
  const PostPage({required this.posts, required this.hasMore});
  final List<Post> posts;
  final bool hasMore;
}

// ── 스터디 관리 · 과제 제출 ─────────────────────────────────────

enum AttendanceStatus {
  present('출석'),
  late('지각'),
  absent('결석'),
  excused('공결');

  const AttendanceStatus(this.label);
  final String label;

  static AttendanceStatus? tryParse(Object? name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }
}

enum ReviewStatus {
  pending('미확인'),
  checked('확인');

  const ReviewStatus(this.label);
  final String label;

  static ReviewStatus parse(Object? name) =>
      name == checked.name ? checked : pending;
}

DateTime _parseDate(Object? value) => DateTime.parse(value as String);

DateTime? _parseDateOrNull(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

List<T> _parseList<T>(
  Object? items,
  T Function(Map<String, dynamic> json) parse,
) =>
    (items as List<dynamic>? ?? const [])
        .map((item) => parse(item as Map<String, dynamic>))
        .toList();

/// 스터디 관리 목록의 한 항목.
class ManagedStudy {
  const ManagedStudy({
    required this.id,
    required this.title,
    required this.semester,
    required this.leaderName,
    required this.participantCount,
    required this.sessionCount,
    required this.assignmentCount,
    required this.uncheckedCount,
  });

  final int id;
  final String title;
  final String semester;
  final String leaderName;

  /// 중도 포기자를 뺀 참여자 수.
  final int participantCount;
  final int sessionCount;
  final int assignmentCount;

  /// 아직 확인하지 않은 제출물 수.
  final int uncheckedCount;

  factory ManagedStudy.fromJson(Map<String, dynamic> json) => ManagedStudy(
        id: json['id'] as int,
        title: json['title'] as String? ?? '',
        semester: json['semester'] as String? ?? '',
        leaderName: json['leader_name'] as String? ?? '미정',
        participantCount: json['participant_count'] as int? ?? 0,
        sessionCount: json['session_count'] as int? ?? 0,
        assignmentCount: json['assignment_count'] as int? ?? 0,
        uncheckedCount: json['unchecked_count'] as int? ?? 0,
      );
}

/// 참여자 한 명의 출석 상태별 횟수.
class AttendanceSummary {
  const AttendanceSummary(this._counts);
  final Map<AttendanceStatus, int> _counts;

  int count(AttendanceStatus status) => _counts[status] ?? 0;

  /// 출석률 = (출석 + 지각) / (전체 회차 - 공결). 계산할 수 없으면 null.
  double? rate(int sessionCount) {
    final base = sessionCount - count(AttendanceStatus.excused);
    if (base <= 0) return null;
    final attended =
        count(AttendanceStatus.present) + count(AttendanceStatus.late);
    return (attended / base).clamp(0.0, 1.0);
  }

  factory AttendanceSummary.fromJson(Map<String, dynamic>? json) =>
      AttendanceSummary({
        for (final status in AttendanceStatus.values)
          status: json?[status.name] as int? ?? 0,
      });
}

/// 스터디장 화면의 참여자. [id]는 참여 기록(participation) id다.
class ManagedParticipant {
  const ManagedParticipant({
    required this.id,
    required this.memberName,
    required this.studentId,
    required this.status,
    required this.attendance,
    required this.submittedCount,
  });

  final int id;
  final String memberName;
  final String studentId;
  final ParticipationStatus status;
  final AttendanceSummary attendance;
  final int submittedCount;

  factory ManagedParticipant.fromJson(Map<String, dynamic> json) =>
      ManagedParticipant(
        id: json['id'] as int,
        memberName: json['member_name'] as String? ?? '',
        studentId: json['student_id'] as String? ?? '',
        status: ParticipationStatus.parse(json['status']),
        attendance: AttendanceSummary.fromJson(
          json['attendance'] as Map<String, dynamic>?,
        ),
        submittedCount: json['submitted_count'] as int? ?? 0,
      );
}

/// 스터디 회차.
class StudySessionInfo {
  const StudySessionInfo({
    required this.id,
    required this.number,
    required this.title,
    required this.heldOn,
    required this.recordedCount,
  });

  final int id;
  final int number;
  final String title;
  final DateTime heldOn;

  /// 출석이 기록된 인원 수.
  final int recordedCount;

  /// 예: `3회차 · XSS`
  String get label => title.isEmpty ? '$number회차' : '$number회차 · $title';

  factory StudySessionInfo.fromJson(Map<String, dynamic> json) =>
      StudySessionInfo(
        id: json['id'] as int,
        number: json['number'] as int,
        title: json['title'] as String? ?? '',
        heldOn: _parseDate(json['held_on']),
        recordedCount: json['recorded_count'] as int? ?? 0,
      );
}

/// 스터디장 화면의 과제와 제출 집계.
class AssignmentInfo {
  const AssignmentInfo({
    required this.id,
    required this.title,
    required this.description,
    required this.dueAt,
    required this.submittedCount,
    required this.lateCount,
    required this.uncheckedCount,
    required this.missingCount,
  });

  final int id;
  final String title;
  final String description;
  final DateTime dueAt;
  final int submittedCount;
  final int lateCount;
  final int uncheckedCount;

  /// 중도 포기자를 뺀 미제출자 수.
  final int missingCount;

  bool get isClosed => dueAt.isBefore(DateTime.now());

  factory AssignmentInfo.fromJson(Map<String, dynamic> json) => AssignmentInfo(
        id: json['id'] as int,
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        dueAt: _parseDate(json['due_at']),
        submittedCount: json['submitted_count'] as int? ?? 0,
        lateCount: json['late_count'] as int? ?? 0,
        uncheckedCount: json['unchecked_count'] as int? ?? 0,
        missingCount: json['missing_count'] as int? ?? 0,
      );
}

class ManagedStudyDetail {
  const ManagedStudyDetail({
    required this.id,
    required this.title,
    required this.semester,
    required this.leaderName,
    required this.description,
    required this.participants,
    required this.sessions,
    required this.assignments,
  });

  final int id;
  final String title;
  final String semester;
  final String leaderName;
  final String description;
  final List<ManagedParticipant> participants;
  final List<StudySessionInfo> sessions;
  final List<AssignmentInfo> assignments;

  /// 중도 포기자를 뺀 참여자 수.
  int get rosterCount => participants
      .where(
          (participant) => participant.status != ParticipationStatus.withdrawn)
      .length;

  factory ManagedStudyDetail.fromJson(Map<String, dynamic> json) =>
      ManagedStudyDetail(
        id: json['id'] as int,
        title: json['title'] as String? ?? '',
        semester: json['semester'] as String? ?? '',
        leaderName: json['leader_name'] as String? ?? '미정',
        description: json['description'] as String? ?? '',
        participants:
            _parseList(json['participants'], ManagedParticipant.fromJson),
        sessions: _parseList(json['sessions'], StudySessionInfo.fromJson),
        assignments: _parseList(json['assignments'], AssignmentInfo.fromJson),
      );
}

/// 출석부의 한 줄.
class AttendanceRecord {
  const AttendanceRecord({
    required this.participationId,
    required this.memberName,
    required this.studentId,
    required this.participationStatus,
    required this.status,
    required this.note,
  });

  final int participationId;
  final String memberName;
  final String studentId;
  final ParticipationStatus participationStatus;

  /// 아직 기록하지 않았으면 null.
  final AttendanceStatus? status;
  final String note;

  Map<String, dynamic> toJson() => {
        'participation_id': participationId,
        'status': status?.name,
        'note': note,
      };

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) =>
      AttendanceRecord(
        participationId: json['participation_id'] as int,
        memberName: json['member_name'] as String? ?? '',
        studentId: json['student_id'] as String? ?? '',
        participationStatus:
            ParticipationStatus.parse(json['participation_status']),
        status: AttendanceStatus.tryParse(json['status']),
        note: json['note'] as String? ?? '',
      );
}

class AttendanceSheet {
  const AttendanceSheet({required this.session, required this.records});
  final StudySessionInfo session;
  final List<AttendanceRecord> records;

  factory AttendanceSheet.fromJson(Map<String, dynamic> json) =>
      AttendanceSheet(
        session: StudySessionInfo.fromJson(
          json['session'] as Map<String, dynamic>,
        ),
        records: _parseList(json['records'], AttendanceRecord.fromJson),
      );
}

/// 출석 현황표의 한 줄. [statuses]는 회차 순서와 같다.
class AttendanceMatrixRow {
  const AttendanceMatrixRow({
    required this.participationId,
    required this.memberName,
    required this.studentId,
    required this.participationStatus,
    required this.statuses,
  });

  final int participationId;
  final String memberName;
  final String studentId;
  final ParticipationStatus participationStatus;
  final List<AttendanceStatus?> statuses;

  int count(AttendanceStatus status) =>
      statuses.where((value) => value == status).length;

  /// 출석률 = (출석 + 지각) / (전체 회차 - 공결). 계산할 수 없으면 null.
  double? get rate {
    final base = statuses.length - count(AttendanceStatus.excused);
    if (base <= 0) return null;
    return (count(AttendanceStatus.present) + count(AttendanceStatus.late)) /
        base;
  }

  factory AttendanceMatrixRow.fromJson(Map<String, dynamic> json) =>
      AttendanceMatrixRow(
        participationId: json['participation_id'] as int,
        memberName: json['member_name'] as String? ?? '',
        studentId: json['student_id'] as String? ?? '',
        participationStatus:
            ParticipationStatus.parse(json['participation_status']),
        statuses: (json['statuses'] as List<dynamic>? ?? const [])
            .map(AttendanceStatus.tryParse)
            .toList(),
      );
}

class AttendanceMatrix {
  const AttendanceMatrix({required this.sessions, required this.rows});
  final List<StudySessionInfo> sessions;
  final List<AttendanceMatrixRow> rows;

  factory AttendanceMatrix.fromJson(Map<String, dynamic> json) =>
      AttendanceMatrix(
        sessions: _parseList(json['sessions'], StudySessionInfo.fromJson),
        rows: _parseList(json['rows'], AttendanceMatrixRow.fromJson),
      );
}

/// 과제 제출물. 참여자 본인 응답에는 [reviewedByName]이 없다.
class Submission {
  const Submission({
    required this.id,
    required this.originalName,
    required this.size,
    required this.submittedAt,
    required this.isLate,
    required this.reviewStatus,
    required this.feedback,
    required this.reviewedAt,
    required this.reviewedByName,
  });

  final int id;
  final String originalName;
  final int size;
  final DateTime submittedAt;
  final bool isLate;
  final ReviewStatus reviewStatus;
  final String feedback;
  final DateTime? reviewedAt;
  final String? reviewedByName;

  bool get isChecked => reviewStatus == ReviewStatus.checked;

  factory Submission.fromJson(Map<String, dynamic> json) => Submission(
        id: json['id'] as int,
        originalName: json['original_name'] as String? ?? '',
        size: json['size'] as int? ?? 0,
        submittedAt: _parseDate(json['submitted_at']),
        isLate: json['is_late'] as bool? ?? false,
        reviewStatus: ReviewStatus.parse(json['review_status']),
        feedback: json['feedback'] as String? ?? '',
        reviewedAt: _parseDateOrNull(json['reviewed_at']),
        reviewedByName: json['reviewed_by_name'] as String?,
      );
}

/// 제출 현황의 한 줄. 미제출이면 [submission]이 null이다.
class SubmissionRow {
  const SubmissionRow({
    required this.participationId,
    required this.memberName,
    required this.studentId,
    required this.participationStatus,
    required this.submission,
  });

  final int participationId;
  final String memberName;
  final String studentId;
  final ParticipationStatus participationStatus;
  final Submission? submission;

  factory SubmissionRow.fromJson(Map<String, dynamic> json) => SubmissionRow(
        participationId: json['participation_id'] as int,
        memberName: json['member_name'] as String? ?? '',
        studentId: json['student_id'] as String? ?? '',
        participationStatus:
            ParticipationStatus.parse(json['participation_status']),
        submission: json['submission'] == null
            ? null
            : Submission.fromJson(json['submission'] as Map<String, dynamic>),
      );
}

class SubmissionSheet {
  const SubmissionSheet({required this.assignment, required this.rows});
  final AssignmentInfo assignment;
  final List<SubmissionRow> rows;

  factory SubmissionSheet.fromJson(Map<String, dynamic> json) =>
      SubmissionSheet(
        assignment: AssignmentInfo.fromJson(
          json['assignment'] as Map<String, dynamic>,
        ),
        rows: _parseList(json['rows'], SubmissionRow.fromJson),
      );
}

/// 참여자 본인 기준 회차와 내 출석.
class MySession {
  const MySession({
    required this.id,
    required this.number,
    required this.title,
    required this.heldOn,
    required this.attendance,
  });

  final int id;
  final int number;
  final String title;
  final DateTime heldOn;
  final AttendanceStatus? attendance;

  String get label => title.isEmpty ? '$number회차' : '$number회차 · $title';

  factory MySession.fromJson(Map<String, dynamic> json) => MySession(
        id: json['id'] as int,
        number: json['number'] as int,
        title: json['title'] as String? ?? '',
        heldOn: _parseDate(json['held_on']),
        attendance: AttendanceStatus.tryParse(json['attendance']),
      );
}

/// 참여자 본인 기준 과제와 내 제출.
class MyAssignment {
  const MyAssignment({
    required this.id,
    required this.title,
    required this.description,
    required this.dueAt,
    required this.isClosed,
    required this.submission,
  });

  final int id;
  final String title;
  final String description;
  final DateTime dueAt;
  final bool isClosed;
  final Submission? submission;

  factory MyAssignment.fromJson(Map<String, dynamic> json) => MyAssignment(
        id: json['id'] as int,
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        dueAt: _parseDate(json['due_at']),
        isClosed: json['is_closed'] as bool? ?? false,
        submission: json['submission'] == null
            ? null
            : Submission.fromJson(json['submission'] as Map<String, dynamic>),
      );
}

/// 마이페이지에서 여는 참여자 본인의 스터디 상세.
class MyStudyDetail {
  const MyStudyDetail({
    required this.studyId,
    required this.title,
    required this.semester,
    required this.leaderName,
    required this.description,
    required this.participationStatus,
    required this.canSubmit,
    required this.sessions,
    required this.assignments,
  });

  final int studyId;
  final String title;
  final String semester;
  final String leaderName;
  final String description;
  final ParticipationStatus participationStatus;

  /// 수강 중일 때만 과제를 낼 수 있다.
  final bool canSubmit;
  final List<MySession> sessions;
  final List<MyAssignment> assignments;

  factory MyStudyDetail.fromJson(Map<String, dynamic> json) {
    final study = json['study'] as Map<String, dynamic>;
    final participation = json['participation'] as Map<String, dynamic>;
    return MyStudyDetail(
      studyId: study['id'] as int,
      title: study['title'] as String? ?? '',
      semester: study['semester'] as String? ?? '',
      leaderName: study['leader_name'] as String? ?? '미정',
      description: study['description'] as String? ?? '',
      participationStatus: ParticipationStatus.parse(participation['status']),
      canSubmit: json['can_submit'] as bool? ?? false,
      sessions: _parseList(json['sessions'], MySession.fromJson),
      assignments: _parseList(json['assignments'], MyAssignment.fromJson),
    );
  }
}
