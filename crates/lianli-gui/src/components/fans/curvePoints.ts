export type CurvePoint = [number, number];

export const CURVE_TEMP_MIN = 20;
export const CURVE_TEMP_MAX = 100;

export function sortCurve(points: CurvePoint[]): CurvePoint[] {
  return [...points].sort((a, b) => a[0] - b[0]);
}

export function speedAt(points: CurvePoint[], temp: number): number {
  const sorted = sortCurve(points);
  if (!sorted.length) return 100;
  if (temp <= sorted[0][0]) return sorted[0][1];
  for (let i = 1; i < sorted.length; i++) {
    const [t1, s1] = sorted[i - 1];
    const [t2, s2] = sorted[i];
    if (temp <= t2) return t2 === t1 ? s2 : s1 + ((temp - t1) / (t2 - t1)) * (s2 - s1);
  }
  return sorted[sorted.length - 1][1];
}

/** Adds a point in the middle of the widest temperature gap, on the existing line. */
export function insertCurvePoint(points: CurvePoint[]): CurvePoint[] {
  const sorted = sortCurve(points);
  const temps = sorted.map(([temp]) => temp);
  const bounds = [CURVE_TEMP_MIN, ...temps, CURVE_TEMP_MAX];
  let gapStart = CURVE_TEMP_MIN;
  let gapWidth = -1;
  for (let i = 1; i < bounds.length; i++) {
    const width = bounds[i] - bounds[i - 1];
    if (width > gapWidth) {
      gapWidth = width;
      gapStart = bounds[i - 1];
    }
  }
  const temp = Math.round((gapStart + gapWidth / 2) * 10) / 10;
  const speed = Math.round(speedAt(sorted, temp));
  return sortCurve([...sorted, [temp, speed]]);
}
