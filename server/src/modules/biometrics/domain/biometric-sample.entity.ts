/**
 * Sample biométrico individual (1 leitura). Origina de Apple HealthKit,
 * Google Health Connect, wearable OAuth ou input manual.
 */
export type BiometricSampleType =
  | 'bpm'              // batimentos cardíacos (instantâneo)
  | 'resting_bpm'      // BPM em repouso (média do dia)
  | 'max_bpm'          // BPM máximo (medido ou estimado)
  | 'hrv'              // heart rate variability (ms, RMSSD ou SDNN)
  | 'sleep_hours'      // horas de sono na noite (total — Apple só envia em iOS<16)
  | 'sleep_deep'       // horas em sono profundo
  | 'sleep_rem'        // horas em sono REM
  | 'sleep_light'      // horas em sono light (combinada com deep+rem = total moderno)
  | 'sleep_in_bed'     // horas na cama (fallback p/ Watch SE / modos sem stages)
  | 'sleep_awake'      // horas acordado na cama (usado pra calcular inBed - awake)
  | 'steps'            // passos no período
  | 'spo2'             // saturação de oxigênio (%)
  | 'weight'           // peso (kg)
  | 'calories_burned'  // kcal queimadas (energia ativa)
  | 'calories_basal'   // kcal queimadas em repouso (BMR)
  | 'vo2max'           // VO2 max estimado
  | 'respiratory_rate'
  | 'bp_systolic'      // pressão sistólica (mmHg)
  | 'bp_diastolic'     // pressão diastólica (mmHg)
  | 'body_temperature' // temperatura corporal (°C)
  | 'ecg'              // eletrocardiograma (classification — sinusal/afib/etc)
  // Atividade completa
  | 'distance_walking_running' // m percorridos andando/correndo no dia
  | 'distance_cycling'         // m pedalando
  | 'flights_climbed'          // lances de escada
  | 'exercise_time'            // min de exercício (Apple anel)
  | 'apple_move_time'          // min do anel Move
  | 'apple_stand_time'         // min de pé (Stand)
  // Mobilidade
  | 'walking_speed'            // velocidade média de caminhada (m/s)
  | 'walking_bpm'              // BPM durante caminhada
  // Medidas corporais
  | 'height'                   // altura (m)
  | 'body_fat_pct'             // % gordura corporal
  | 'bmi'                      // body mass index (kg/m²)
  | 'lean_body_mass'           // massa magra (kg)
  | 'waist_circumference'      // cintura (m)
  // Sinais vitais avançados
  | 'hrv_rmssd'                // HRV RMSSD (ms) — complementar ao SDNN
  | 'high_hr_event'            // evento FC alta em repouso
  | 'low_hr_event'             // evento FC baixa
  | 'irregular_hr_event'       // ritmo irregular detectado
  | 'afib_burden'              // % do tempo em fibrilação atrial
  | 'skin_temperature'         // temperatura da pele (Apple Watch Series 8+)
  // Nutrição/hidratação
  | 'water';                   // água ingerida (litros) — comparável à prescrição do plano

export type BiometricSource =
  | 'apple_health'
  | 'health_connect'    // Google Health Connect (Android)
  | 'garmin'
  | 'manual'            // input manual no app
  | 'terra'             // aggregator opcional (fase 2)
  | 'seed';             // dados de teste/seed

export interface BiometricSample {
  id: string;                  // uuid
  userId: string;
  type: BiometricSampleType;
  value: number;
  unit: string;                // 'bpm' | 'hours' | 'count' | 'ms' | '%' | 'kg' | 'kcal'
  source: BiometricSource;
  recordedAt: string;          // ISO — quando o sample aconteceu
  receivedAt: string;          // ISO — quando o server registrou
  context?: Record<string, unknown>; // opcional (ex: sleep stages)
}
