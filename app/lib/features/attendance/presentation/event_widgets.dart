import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../api/exports.dart';
import '../../../core/format.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../team/team_providers.dart';
import '../data/events_repository.dart';

AttendanceStatusValue? statusValue(AttendanceStatus? s) => switch (s) {
  AttendanceStatusKnown(:final value) => value,
  _ => null,
};

/// (nhãn, nền, chữ) theo bản vẽ màn 18.
(String, Color, Color) attendanceStyle(AttendanceStatusValue? s) => switch (s) {
  AttendanceStatusValue.go => ('Đi', AppColors.lime.withValues(alpha: 0.16), AppColors.lime),
  AttendanceStatusValue.maybe => ('Chưa chắc', AppColors.trophy.withValues(alpha: 0.16), AppColors.trophy),
  AttendanceStatusValue.no => ('Vắng', AppColors.card.withValues(alpha: 0.16), AppColors.card),
  null => ('Chưa trả lời', AppColors.surfaceHigh, AppColors.textDim),
};

String eventKindLabel(EventKind k) => switch (k) {
  EventKindKnown(value: EventKindValue.match) => 'Trận',
  EventKindKnown(value: EventKindValue.internal) => 'Đá nội bộ',
  EventKindKnown(value: EventKindValue.other) => 'Sự kiện',
  EventKindUnknown(:final rawValue) => rawValue,
};

/// Điểm danh của chính mình, rồi làm mới danh sách (realtime cũng sẽ báo cho người khác).
Future<void> setMyAttendance(
  BuildContext context,
  WidgetRef ref,
  String teamId,
  String eventId,
  AttendanceStatusValue status,
) async {
  final ok = await runAction(
    context,
    () => ref.read(eventsRepositoryProvider).setAttendance(teamId, eventId, status),
  );
  if (ok) {
    ref.invalidate(upcomingEventsProvider(teamId));
    ref.invalidate(eventDetailProvider((teamId: teamId, eventId: eventId)));
  }
}

/// Ba nút Đi / Chưa chắc / Vắng.
class AttendanceChoice extends StatelessWidget {
  const AttendanceChoice({
    super.key,
    required this.selected,
    required this.onPick,
    this.enabled = true,
  });

  final AttendanceStatusValue? selected;
  final ValueChanged<AttendanceStatusValue> onPick;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final s in AttendanceStatusValue.values) ...[
          if (s != AttendanceStatusValue.values.first) const SizedBox(width: 8),
          Expanded(child: _choice(s)),
        ],
      ],
    );
  }

  Widget _choice(AttendanceStatusValue s) {
    final on = s == selected;
    final (label, bg, fg) = attendanceStyle(s);
    return Semantics(
      button: true,
      selected: on,
      child: GestureDetector(
        onTap: enabled ? () => onPick(s) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minHeight: AppSizes.tapTarget),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? bg : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: on ? fg : AppColors.pillBorder),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: on ? fg : AppColors.text,
            ),
          ),
        ),
      ),
    );
  }
}

/// Ô đếm Đi / Chưa chắc / Vắng trên nền xám.
class AttendanceCounts extends StatelessWidget {
  const AttendanceCounts(this.counts, {super.key});
  final AttendanceCountsDto counts;

  @override
  Widget build(BuildContext context) {
    Widget cell(int n, String label, Color color) => Expanded(
      child: Column(
        children: [
          Text(
            '$n',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        border: Border.all(color: AppColors.lineStrong),
      ),
      child: Row(
        children: [
          cell(counts.go, 'Đi', AppColors.lime),
          cell(counts.maybe, 'Chưa chắc', AppColors.trophy),
          cell(counts.no, 'Vắng', AppColors.card),
        ],
      ),
    );
  }
}

/// Dữ liệu hiển thị chung cho lịch (từ danh sách hoặc chi tiết).
class EventView {
  const EventView({
    required this.id,
    required this.kind,
    required this.title,
    required this.startAt,
    required this.endAt,
    required this.counts,
    this.location,
    this.note,
    this.minPlayers,
    this.myStatus,
  });

  factory EventView.summary(EventSummaryDto e) => EventView(
    id: e.id,
    kind: e.kind,
    title: e.title,
    startAt: e.startAt,
    endAt: e.endAt,
    counts: e.counts,
    location: e.location,
    note: e.note,
    minPlayers: e.minPlayers,
    myStatus: e.myStatus,
  );

  factory EventView.detail(EventDetailDto e) => EventView(
    id: e.id,
    kind: e.kind,
    title: e.title,
    startAt: e.startAt,
    endAt: e.endAt,
    counts: e.counts,
    location: e.location,
    note: e.note,
    minPlayers: e.minPlayers,
    myStatus: e.myStatus,
  );

  final String id;
  final EventKind kind;
  final String title;
  final DateTime startAt;
  final DateTime endAt;
  final AttendanceCountsDto counts;
  final String? location;
  final String? note;
  final int? minPlayers;
  final AttendanceStatus? myStatus;
}

/// Thẻ lịch chính (màn 18): đếm ngược, tiêu đề, giờ & địa điểm, tự điểm danh, số đếm.
class EventMainCard extends ConsumerWidget {
  const EventMainCard({super.key, required this.teamId, required this.event});

  final String teamId;
  final EventView event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = event.counts;
    final finished = event.endAt.isBefore(DateTime.now());
    final details = [Fmt.eventTime(event.startAt, event.endAt), ?event.location].join(' · ');
    final need = event.minPlayers;
    final footer = [
      if (need != null) 'Cần tối thiểu $need người',
      if (c.pending > 0) '${c.pending} người chưa trả lời',
    ].join(' · ');

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${eventKindLabel(event.kind)} · ${Fmt.countdown(event.startAt)}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
              if (need != null)
                c.go >= need
                    ? Tag('Đủ người', bg: AppColors.lime.withValues(alpha: 0.16), fg: AppColors.lime)
                    : Tag('Thiếu ${need - c.go}', bg: AppColors.card.withValues(alpha: 0.16), fg: AppColors.card),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            event.title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.4),
          ),
          const SizedBox(height: 6),
          Text(details, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          if (event.note != null) ...[
            const SizedBox(height: 4),
            Text(event.note!, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 14),
          const Text(
            'Bạn có đi không?',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          AttendanceChoice(
            selected: statusValue(event.myStatus),
            enabled: !finished,
            onPick: (s) => setMyAttendance(context, ref, teamId, event.id, s),
          ),
          const SizedBox(height: 12),
          AttendanceCounts(c),
          if (footer.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(footer, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }
}

/// Dòng trong danh sách "Sắp tới": ô ngày (thứ + ngày), tiêu đề, giờ · địa điểm, số người đi.
class EventRow extends StatelessWidget {
  const EventRow({super.key, required this.event, required this.onTap});
  final EventSummaryDto event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sub = [Fmt.time(event.startAt), ?event.location].join(' · ');
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: Column(
                children: [
                  Text(
                    Fmt.weekday(event.startAt),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.card,
                    ),
                  ),
                  Text(
                    '${Fmt.vn(event.startAt).day}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.1),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  Text(sub, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Tag('${event.counts.go} đi', bg: AppColors.lime.withValues(alpha: 0.16), fg: AppColors.lime),
          ],
        ),
      ),
    );
  }
}

/// Một dòng điểm danh của thành viên.
class AttendeeRow extends StatelessWidget {
  const AttendeeRow({super.key, required this.attendee, required this.isMe});
  final AttendeeDto attendee;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = attendanceStyle(statusValue(attendee.status));
    final note = attendee.note;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Row(
        children: [
          Avatar(name: attendee.name, url: attendee.avatarUrl, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: attendee.name,
                children: [
                  if (isMe)
                    const TextSpan(
                      text: ' (bạn)',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                ],
              ),
              style: const TextStyle(fontSize: 15),
            ),
          ),
          Tag(note != null && note.isNotEmpty ? '$label · $note' : label, bg: bg, fg: fg),
        ],
      ),
    );
  }
}
