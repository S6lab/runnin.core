class AlertSettings {
  final bool paceAlertEnabled;
  final bool heartRateAlertEnabled;
  final bool distanceMarkAlertEnabled;
  
  const AlertSettings({
    this.paceAlertEnabled = false,
    this.heartRateAlertEnabled = false,
    this.distanceMarkAlertEnabled = true,
  });
  
  factory AlertSettings.defaultSettings() => const AlertSettings();
  
  AlertSettings copyWith({
    bool? paceAlertEnabled,
    bool? heartRateAlertEnabled,
    bool? distanceMarkAlertEnabled,
  }) {
    return AlertSettings(
      paceAlertEnabled: paceAlertEnabled ?? this.paceAlertEnabled,
      heartRateAlertEnabled: heartRateAlertEnabled ?? this.heartRateAlertEnabled,
      distanceMarkAlertEnabled: distanceMarkAlertEnabled ?? this.distanceMarkAlertEnabled,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'paceAlertEnabled': paceAlertEnabled,
    'heartRateAlertEnabled': heartRateAlertEnabled,
    'distanceMarkAlertEnabled': distanceMarkAlertEnabled,
  };
  
  factory AlertSettings.fromJson(Map<String, dynamic> json) => AlertSettings(
    paceAlertEnabled: json['paceAlertEnabled'] as bool? ?? false,
    heartRateAlertEnabled: json['heartRateAlertEnabled'] as bool? ?? false,
    distanceMarkAlertEnabled: json['distanceMarkAlertEnabled'] as bool? ?? true,
  );
}
