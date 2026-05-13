class AssessmentData {
  String level;
  String name;
  String birthDate;
  String weight;
  String height;
  final Set<String> medicalConditions;
  String medicalOther;
  int frequency;
  String goal;
  String paceTarget;
  String preferredRunTime;
  String wakeUpTime;
  String sleepTime;
  bool hasWearable;

  AssessmentData({
    this.level = 'iniciante',
    this.name = '',
    this.birthDate = '',
    this.weight = '70',
    this.height = '175',
    Set<String>? medicalConditions,
    this.medicalOther = '',
    this.frequency = 4,
    this.goal = 'Completar 10K',
    this.paceTarget = '',
    this.preferredRunTime = '',
    this.wakeUpTime = '07:00',
    this.sleepTime = '22:00',
    this.hasWearable = false,
  }) : medicalConditions = medicalConditions ?? {};
}
