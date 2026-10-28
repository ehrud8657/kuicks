import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api_client.dart';
import '../format.dart';
import '../models.dart';
import '../routes.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// 활동 아카이브. 프로젝트·대회·행사를 학기별로 모아 보여준다.
class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key, this.kind, this.semester, this.tag});

  /// 주소의 ?kind=·?semester=·?tag= 값. 없으면 전체.
  final ActivityKind? kind;
  final String? semester;
  final String? tag;

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  late ActivityKind? kind = widget.kind;
  late String? semester = widget.semester;
  late String? tag = widget.tag;

  ActivityFilters filters = const ActivityFilters();
  final List<Activity> activities = [];
  int page = 1;
  bool hasMore = false;
  bool loading = true;
  bool loadingMore = false;
  bool failed = false;

  @override
  void initState() {
    super.initState();
    _loadFilters();
    _load();
  }

  /// 거르기 선택지는 실패해도 목록은 보이게, 목록과 따로 불러온다.
  Future<void> _loadFilters() async {
    try {
      final result = await ApiClient.instance.fetchActivityFilters();
      if (mounted) setState(() => filters = result);
    } on Object {
      // 선택지 없이도 전체 목록은 볼 수 있다.
    }
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      failed = false;
    });
    try {
      final result = await ApiClient.instance.fetchActivities(
        kind: kind,
        semester: semester,
        tag: tag,
      );
      if (!mounted) return;
      setState(() {
        activities
          ..clear()
          ..addAll(result.activities);
        page = 1;
        hasMore = result.hasMore;
        loading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        loading = false;
        failed = true;
      });
    }
  }

  Future<void> _loadMore() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => loadingMore = true);
    try {
      final result = await ApiClient.instance.fetchActivities(
        kind: kind,
        semester: semester,
        tag: tag,
        page: page + 1,
      );
      if (!mounted) return;
      setState(() {
        activities.addAll(result.activities);
        page += 1;
        hasMore = result.hasMore;
        loadingMore = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() => loadingMore = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('활동을 더 불러오지 못했습니다.')),
      );
    }
  }

  @override
  void didUpdateWidget(ActivityPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 브라우저 뒤로가기 등으로 주소의 선택이 바뀐 경우
    final changed =
        widget.kind != kind || widget.semester != semester || widget.tag != tag;
    final fromAddress = widget.kind != oldWidget.kind ||
        widget.semester != oldWidget.semester ||
        widget.tag != oldWidget.tag;
    if (changed && fromAddress) {
      setState(() {
        kind = widget.kind;
        semester = widget.semester;
        tag = widget.tag;
      });
      _load();
    }
  }

  void _select({
    required ActivityKind? kind,
    required String? semester,
    required String? tag,
  }) {
    if (kind == this.kind && semester == this.semester && tag == this.tag) {
      return;
    }
    setState(() {
      this.kind = kind;
      this.semester = semester;
      this.tag = tag;
    });
    _load();
    // 선택을 주소에 남기되 방문 기록은 늘리지 않는다.
    replaceLocation(
      context,
      AppRoutes.activityOf(kind: kind, semester: semester, tag: tag),
    );
  }

  String get _emptyMessage => switch (kind) {
        _ when semester != null || tag != null => '조건에 맞는 활동이 없습니다.',
        ActivityKind.project => '아직 등록된 프로젝트가 없습니다.',
        ActivityKind.contest => '아직 등록된 대회 기록이 없습니다.',
        ActivityKind.event => '아직 등록된 행사 기록이 없습니다.',
        null => '아직 등록된 활동이 없습니다.',
      };

  Widget _chipRow(List<Widget> chips) =>
      Wrap(spacing: 8, runSpacing: 8, children: chips);

  /// 학기가 바뀌는 곳마다 학기 제목을 끼워 넣는다. 서버가 최신 학기부터 준다.
  List<Widget> _grouped() {
    final children = <Widget>[];
    String? current;
    for (final activity in activities) {
      if (activity.semester != current) {
        current = activity.semester;
        children.add(
          Padding(
            padding:
                EdgeInsets.only(top: children.isEmpty ? 0 : 16, bottom: 10),
            child: Text(
              current,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textBody,
              ),
            ),
          ),
        );
      }
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ActivityCard(activity: activity, showKind: kind == null),
        ),
      );
    }
    return children;
  }

  @override
  Widget build(BuildContext context) => PageFrame(
        key: const ValueKey('activity'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PageHeader(
              eyebrow: 'ACTIVITY',
              title: '우리의 활동 기록',
              subtitle: '프로젝트·대회·행사의 중간 결과물과 최종 결과물을 학기별로 모아 둡니다.',
            ),
            const SizedBox(height: 28),
            _chipRow([
              for (final value in [null, ...ActivityKind.values])
                ChoiceChip(
                  label: Text(value?.label ?? '전체'),
                  selected: kind == value,
                  onSelected: (_) =>
                      _select(kind: value, semester: semester, tag: tag),
                ),
            ]),
            if (filters.semesters.isNotEmpty) ...[
              const SizedBox(height: 12),
              _chipRow([
                for (final value in [null, ...filters.semesters])
                  ChoiceChip(
                    label: Text(value ?? '모든 학기'),
                    selected: semester == value,
                    onSelected: (_) =>
                        _select(kind: kind, semester: value, tag: tag),
                  ),
              ]),
            ],
            if (filters.tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              _chipRow([
                for (final value in filters.tags)
                  FilterChip(
                    label: Text('#$value'),
                    selected: tag == value,
                    // 같은 태그를 다시 누르면 거르기를 푼다.
                    onSelected: (selected) => _select(
                      kind: kind,
                      semester: semester,
                      tag: selected ? value : null,
                    ),
                  ),
              ]),
            ],
            const SizedBox(height: 24),
            if (loading)
              const LoadingView()
            else if (failed)
              LoadError(onRetry: _load)
            else if (activities.isEmpty)
              EmptyState(
                message: _emptyMessage,
                icon: Icons.emoji_events_outlined,
              )
            else ...[
              ..._grouped(),
              if (hasMore)
                Center(
                  child: OutlinedButton(
                    onPressed: loadingMore ? null : _loadMore,
                    child: Text(loadingMore ? '불러오는 중…' : '더 보기'),
                  ),
                ),
            ],
          ],
        ),
      );
}

/// 활동의 상태 배지 색.
BadgeTone activityStatusTone(ActivityStatus status) => switch (status) {
      ActivityStatus.planning => BadgeTone.warning,
      ActivityStatus.ongoing => BadgeTone.info,
      ActivityStatus.done => BadgeTone.success,
      ActivityStatus.archived => BadgeTone.neutral,
    };

/// 이름 아래에 붙는 한 줄. 프로젝트는 주제, 대회는 결과.
String activityHeadline(Activity activity) => switch (activity.kind) {
      ActivityKind.project =>
        activity.topic.isEmpty ? '주제 선정 중' : activity.topic,
      ActivityKind.contest => activity.result,
      ActivityKind.event => '',
    };

/// 기간. 예: 2026.09.01 – 2026.12.15
String? activityPeriod(Activity activity) {
  final start = activity.startDate;
  final end = activity.endDate;
  if (start == null && end == null) return null;
  if (start == null) return formatDate(end!);
  if (end == null || end == start) return formatDate(start);
  return '${formatDate(start)} – ${formatDate(end)}';
}

class ActivityCard extends StatelessWidget {
  const ActivityCard({
    super.key,
    required this.activity,
    this.showKind = true,
  });

  final Activity activity;

  /// 전체 탭처럼 여러 종류가 섞여 있을 때 종류 배지를 붙인다.
  final bool showKind;

  static const _progressStages = [
    MaterialStage.proposal,
    MaterialStage.interim,
    MaterialStage.finalReport,
  ];

  @override
  Widget build(BuildContext context) {
    final headline = activityHeadline(activity);
    final leaders = activity.leaderNames;
    final period = activityPeriod(activity);
    final meta = [
      if (leaders.isNotEmpty) '팀장 ${leaders.join(', ')}',
      if (activity.members.isNotEmpty) '${activity.members.length}명',
      if (period != null) period,
    ].join(' · ');
    return SoftCard(
      accent: true,
      child: InkWell(
        onTap: () => GoRouter.maybeOf(context)
            ?.go(AppRoutes.activityDetail(activity.kind, activity.id)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (showKind) StatusBadge(label: activity.kind.label),
                  if (activity.kind == ActivityKind.project)
                    StatusBadge(
                      label: activity.status.label,
                      tone: activityStatusTone(activity.status),
                    ),
                  for (final tag in activity.tags)
                    StatusBadge(label: '#$tag', tone: BadgeTone.danger),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                activity.title,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              if (headline.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  headline,
                  style: const TextStyle(
                    color: AppColors.textBody,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (activity.summary.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  activity.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 14,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (meta.isNotEmpty)
                    Text(
                      meta,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  if (activity.kind == ActivityKind.project)
                    // 제안 ✓ 중간 ✓ 최종 – 처럼 결과물이 어디까지 올라왔는지 보여준다.
                    for (final stage in _progressStages)
                      _StageMark(
                        stage: stage,
                        done: activity.stages.contains(stage),
                      )
                  else
                    IconStat(
                      icon: Icons.folder_outlined,
                      label: '자료 ${activity.materialCount}개',
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StageMark extends StatelessWidget {
  const _StageMark({required this.stage, required this.done});
  final MaterialStage stage;
  final bool done;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 15,
            color: done ? AppColors.success : AppColors.textSubtle,
          ),
          const SizedBox(width: 4),
          Text(
            stage.label,
            style: TextStyle(
              fontSize: 13,
              color: done ? AppColors.textBody : AppColors.textSubtle,
              fontWeight: done ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ],
      );
}
