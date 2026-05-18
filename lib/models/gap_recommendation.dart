
enum GapQuality { peak, good, light }

extension GapQualityExtension on GapQuality {
  String get label {
    switch (this) {
      case GapQuality.peak:
        return 'Peak Focus Window';
      case GapQuality.good:
        return 'Good Study Time';
      case GapQuality.light:
        return 'Light Study Time';
    }
  }

  String get emoji {
    switch (this) {
      case GapQuality.peak:
        return '🔥';
      case GapQuality.good:
        return '✅';
      case GapQuality.light:
        return '📖';
    }
  }
}

class GapRecommendation {
  final DateTime startTime;
  final DateTime endTime;
  final Duration duration;
  final GapQuality quality;
  final String suggestion;
  final String? relatedDeadlineTitle;
  final int? dueNodeCount; // SM2 nodes due for review

  GapRecommendation({
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.quality,
    required this.suggestion,
    this.relatedDeadlineTitle,
    this.dueNodeCount,
  });

  String get formattedTime {
    final startH = startTime.hour.toString().padLeft(2, '0');
    final startM = startTime.minute.toString().padLeft(2, '0');
    final endH = endTime.hour.toString().padLeft(2, '0');
    final endM = endTime.minute.toString().padLeft(2, '0');
    return '$startH:$startM – $endH:$endM';
  }

  String get formattedDuration {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h';
    return '${minutes}m';
  }

  get emoji => null;
}