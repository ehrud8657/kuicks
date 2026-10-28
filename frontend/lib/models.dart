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
    this.method = '',
    this.schedule = '',
    this.completionRequirements = '',
  });

  final int id;
  final String title;
  final String leader;
  final String description;
  final String prerequisites;
  final String recommended;
  final List<Participant> participants;

  /// 진행 방식·일정·수료 요건. 운영진이 적지 않았으면 빈 문자열이다.
  final String method;
  final String schedule;
  final String completionRequirements;

  factory Study.fromJson(Map<String, dynamic> json) => Study(
        id: json['id'] as int,
        title: json['title'] as String,
        leader: json['leader_name'] as String? ?? '미정',
        description: json['description'] as String? ?? '',
        prerequisites: json['prerequisites'] as String? ?? '없음',
        recommended: json['recommended'] as String? ?? '없음',
        method: json['method'] as String? ?? '',
        schedule: json['schedule'] as String? ?? '',
        completionRequirements:
            json['completion_requirements'] as String? ?? '',
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

/// 게시글에 붙은 사진이나 문서. 없는 글이 기본이다.
class PostAttachment {
  const PostAttachment({
    required this.id,
    required this.name,
    required this.size,
    required this.contentType,
    required this.isImage,
    required this.url,
  });

  final int id;

  /// 올린 사람이 붙인 원본 파일명. 저장 경로와는 다르다.
  final String name;
  final int size;
  final String contentType;

  /// 사진이면 본문 아래에 바로 띄우고, 아니면 내려받기 줄로 보여준다.
  final bool isImage;
  final String url;

  factory PostAttachment.fromJson(Map<String, dynamic> json) => PostAttachment(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        size: json['size'] as int? ?? 0,
        contentType: json['content_type'] as String? ?? '',
        isImage: json['is_image'] as bool? ?? false,
        url: json['url'] as String? ?? '',
      );
}

class Post {
  const Post({
    required this.id,
    required this.category,
    required this.title,
    required this.content,
    required this.authorName,
    required this.isPinned,
    required this.publishedAt,
    this.attachments = const [],
  });

  final int id;
  final PostCategory category;
  final String title;
  final String content;
  final String authorName;
  final bool isPinned;
  final DateTime? publishedAt;
  final List<PostAttachment> attachments;

  List<PostAttachment> get images =>
      attachments.where((item) => item.isImage).toList();

  List<PostAttachment> get files =>
      attachments.where((item) => !item.isImage).toList();

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
        // 서버가 아직 첨부를 내려주지 않는 경우에도 깨지지 않게 기본값을 둔다.
        attachments: (json['attachments'] as List<dynamic>? ?? const [])
            .map(
                (item) => PostAttachment.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
}

/// 스터디 게시판 글의 분류.
enum StudyPostKind {
  notice('공지'),
  material('자료');

  const StudyPostKind(this.label);
  final String label;

  static StudyPostKind parse(Object? name) =>
      name == material.name ? material : notice;
}

/// 스터디 게시판 글. 해당 스터디 참여자와 스터디장·운영진만 본다.
/// 첨부는 공지사항 첨부와 같은 모양으로 내려오므로 [PostAttachment]를 그대로 쓴다.
class StudyPost {
  const StudyPost({
    required this.id,
    required this.kind,
    required this.title,
    required this.content,
    required this.isPinned,
    required this.authorName,
    required this.createdAt,
    this.attachments = const [],
  });

  final int id;
  final StudyPostKind kind;
  final String title;
  final String content;
  final bool isPinned;
  final String authorName;
  final DateTime createdAt;
  final List<PostAttachment> attachments;

  List<PostAttachment> get images =>
      attachments.where((item) => item.isImage).toList();

  List<PostAttachment> get files =>
      attachments.where((item) => !item.isImage).toList();

  factory StudyPost.fromJson(Map<String, dynamic> json) => StudyPost(
        id: json['id'] as int,
        kind: StudyPostKind.parse(json['kind']),
        title: json['title'] as String? ?? '',
        content: json['content'] as String? ?? '',
        isPinned: json['is_pinned'] as bool? ?? false,
        authorName: json['author_name'] as String? ?? '',
        createdAt: DateTime.parse(json['created_at'] as String),
        attachments: (json['attachments'] as List<dynamic>? ?? const [])
            .map(
                (item) => PostAttachment.fromJson(item as Map<String, dynamic>))
            .toList(),
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
    this.posts = const [],
  });

  final int id;
  final String title;
  final String semester;
  final String leaderName;
  final String description;
  final List<ManagedParticipant> participants;
  final List<StudySessionInfo> sessions;
  final List<AssignmentInfo> assignments;
  final List<StudyPost> posts;

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
        posts: _parseList(json['posts'], StudyPost.fromJson),
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
    this.posts = const [],
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
  final List<StudyPost> posts;

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
      posts: _parseList(json['posts'], StudyPost.fromJson),
    );
  }
}

// ── 활동 아카이브 ────────────────────────────────────────────

/// 활동 종류. [path]가 상세 주소 조각이 된다. 예: /activity/projects/12
enum ActivityKind {
  project('프로젝트', 'projects'),
  contest('대회', 'contests'),
  event('행사', 'events');

  const ActivityKind(this.label, this.path);
  final String label;
  final String path;

  static ActivityKind? tryParse(Object? name) {
    for (final kind in values) {
      if (kind.name == name) return kind;
    }
    return null;
  }

  static ActivityKind? fromPath(String? path) {
    for (final kind in values) {
      if (kind.path == path) return kind;
    }
    return null;
  }
}

enum ActivityStatus {
  planning('준비 중'),
  ongoing('진행 중'),
  done('완료'),
  archived('보관됨');

  const ActivityStatus(this.label);
  final String label;

  static ActivityStatus parse(Object? name) =>
      values.firstWhere((value) => value.name == name, orElse: () => planning);
}

/// 자료 단계. 프로젝트는 제안 → 중간 → 최종 순으로 쌓인다.
enum MaterialStage {
  proposal('제안'),
  interim('중간'),
  finalReport('최종', apiName: 'final'),
  other('기타');

  const MaterialStage(this.label, {String? apiName}) : _apiName = apiName;
  final String label;
  final String? _apiName;

  /// 서버가 쓰는 값. `final`은 Dart 예약어라 이름을 따로 둔다.
  String get apiName => _apiName ?? name;

  static MaterialStage parse(Object? name) =>
      values.firstWhere((value) => value.apiName == name, orElse: () => other);
}

class ActivityMemberInfo {
  const ActivityMemberInfo({required this.name, required this.isLeader});
  final String name;
  final bool isLeader;

  factory ActivityMemberInfo.fromJson(Map<String, dynamic> json) =>
      ActivityMemberInfo(
        name: json['name'] as String? ?? '',
        isLeader: json['role'] == 'leader',
      );
}

/// 활동 자료(제안서·중간 발표·최종 보고서·write-up 등). 첨부는 [PostAttachment] 모양으로 내려온다.
class ActivityMaterial {
  const ActivityMaterial({
    required this.id,
    required this.stage,
    required this.title,
    required this.description,
    required this.date,
    required this.authorName,
    this.files = const [],
    this.canEdit = false,
  });

  final int id;
  final MaterialStage stage;
  final String title;
  final String description;
  final DateTime? date;
  final String authorName;
  final List<PostAttachment> files;

  /// 올린 본인·운영진이면 수정·삭제 메뉴를 보여준다. 실제 권한은 서버가 다시 검사한다.
  final bool canEdit;

  List<PostAttachment> get images =>
      files.where((item) => item.isImage).toList();

  List<PostAttachment> get documents =>
      files.where((item) => !item.isImage).toList();

  factory ActivityMaterial.fromJson(Map<String, dynamic> json) =>
      ActivityMaterial(
        id: json['id'] as int,
        stage: MaterialStage.parse(json['stage']),
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        date: DateTime.tryParse(json['date'] as String? ?? ''),
        authorName: json['author_name'] as String? ?? '',
        files: _parseList(json['files'], PostAttachment.fromJson),
        canEdit: json['can_edit'] as bool? ?? false,
      );
}

/// 목록에 보이는 활동 요약. 상세 응답도 같은 필드를 포함한다.
class Activity {
  const Activity({
    required this.id,
    required this.kind,
    required this.semester,
    required this.title,
    this.topic = '',
    this.summary = '',
    this.status = ActivityStatus.planning,
    this.startDate,
    this.endDate,
    this.result = '',
    this.tags = const [],
    this.members = const [],
    this.materialCount = 0,
    this.stages = const [],
  });

  final int id;
  final ActivityKind kind;
  final String semester;
  final String title;

  /// 프로젝트 주제. 비어 있으면 아직 정하지 않은 것이다.
  final String topic;
  final String summary;
  final ActivityStatus status;
  final DateTime? startDate;
  final DateTime? endDate;

  /// 대회 순위·수상.
  final String result;
  final List<String> tags;
  final List<ActivityMemberInfo> members;
  final int materialCount;

  /// 자료가 하나라도 있는 단계.
  final List<MaterialStage> stages;

  List<String> get leaderNames => [
        for (final member in members)
          if (member.isLeader) member.name
      ];

  factory Activity.fromJson(Map<String, dynamic> json) => Activity(
        id: json['id'] as int,
        kind: ActivityKind.tryParse(json['kind']) ?? ActivityKind.project,
        semester: json['semester'] as String? ?? '',
        title: json['title'] as String? ?? '',
        topic: json['topic'] as String? ?? '',
        summary: json['summary'] as String? ?? '',
        status: ActivityStatus.parse(json['status']),
        startDate: DateTime.tryParse(json['start_date'] as String? ?? ''),
        endDate: DateTime.tryParse(json['end_date'] as String? ?? ''),
        result: json['result'] as String? ?? '',
        tags: [for (final tag in json['tags'] as List? ?? const []) '$tag'],
        members: _parseList(json['members'], ActivityMemberInfo.fromJson),
        materialCount: json['material_count'] as int? ?? 0,
        stages: [
          for (final stage in json['stages'] as List? ?? const [])
            MaterialStage.parse(stage),
        ],
      );
}

class ActivityDetail {
  const ActivityDetail({
    required this.activity,
    this.description = '',
    this.teamName = '',
    this.location = '',
    this.materials = const [],
    this.canContribute = false,
  });

  final Activity activity;
  final String description;

  /// 대회에 나간 팀 이름.
  final String teamName;

  /// 행사 장소.
  final String location;
  final List<ActivityMaterial> materials;

  /// 이 활동에 자료를 올릴 수 있는지(참여자 중 정회원 이상·운영진).
  final bool canContribute;

  factory ActivityDetail.fromJson(Map<String, dynamic> json) => ActivityDetail(
        activity: Activity.fromJson(json),
        description: json['description'] as String? ?? '',
        teamName: json['team_name'] as String? ?? '',
        location: json['location'] as String? ?? '',
        materials: _parseList(json['materials'], ActivityMaterial.fromJson),
        canContribute: json['can_contribute'] as bool? ?? false,
      );
}

class ActivityListPage {
  const ActivityListPage({required this.activities, required this.hasMore});
  final List<Activity> activities;
  final bool hasMore;
}

/// 목록 화면의 거르기 선택지. 공개된 활동이 있는 학기(최신순)와 쓰이는 태그만 담긴다.
class ActivityFilters {
  const ActivityFilters({this.semesters = const [], this.tags = const []});
  final List<String> semesters;
  final List<String> tags;

  factory ActivityFilters.fromJson(Map<String, dynamic> json) =>
      ActivityFilters(
        semesters: [
          for (final s in json['semesters'] as List? ?? const []) '$s'
        ],
        tags: [for (final t in json['tags'] as List? ?? const []) '$t'],
      );
}
