enum ParticipationStatus { active, completed, excellent, withdrawn }

class Participant {
  const Participant({required this.name, required this.status});
  final String name;
  final ParticipationStatus status;

  factory Participant.fromJson(Map<String, dynamic> json) => Participant(
    name: json['member_name'] as String? ?? '',
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
    leader: json['leader_name'] as String? ?? '-',
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
