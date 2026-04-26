class CoachReport {
  final String status;
  final String? summary;
  final String? generatedAt;

  const CoachReport({required this.status, this.summary, this.generatedAt});

  factory CoachReport.fromJson(Map<String, dynamic> json) => CoachReport(
    status: json['status'] as String? ?? 'pending',
    summary: json['summary'] as String?,
    generatedAt: json['generatedAt'] as String?,
  );

  bool get isReady =>
      status == 'ready' && (summary?.trim().isNotEmpty ?? false);
}
