export interface Zone {
  zone: 'Z1' | 'Z2' | 'Z3' | 'Z4' | 'Z5';
  name: string;
  bpmMin: number;
  bpmMax: number;
  percentTime?: number;
}
