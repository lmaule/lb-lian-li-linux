import type { RGB } from "@/types";

const BRIGHTNESS_LEVELS = [0.3, 0.5, 0.7, 0.85, 1];
const RAINBOW_MODES = new Set(["Rainbow", "RainbowMorph", "ColorCycle", "Kaleidoscope", "ColorsMorph", "ColorfulStarryNight"]);

function css([r, g, b]: RGB): string {
  return `rgb(${r}, ${g}, ${b})`;
}

function hue(degrees: number): string {
  return `hsl(${((degrees % 360) + 360) % 360}, 95%, 60%)`;
}

/**
 * One frame of an effect for the static preview. It shows the effect's colors and
 * shape, not the device's exact animation, which the firmware or daemon renders.
 */
export function previewLed(
  mode: string,
  colors: RGB[],
  brightness: number,
  index: number,
  count: number,
  group: number,
): { color: string; opacity: number } {
  const level = BRIGHTNESS_LEVELS[Math.min(Math.max(brightness, 0), 4)] ?? 1;
  const palette = colors.length ? colors : ([[255, 255, 255]] as RGB[]);
  const base = css(palette[0]);
  const pick = (i: number) => css(palette[i % palette.length]);

  if (mode === "Off") return { color: "#2a2a32", opacity: 1 };
  if (RAINBOW_MODES.has(mode)) {
    const shift = mode === "Rainbow" ? (index / count) * 360 : 0;
    return { color: hue(shift + group * 70), opacity: level };
  }
  let opacity = 1;
  let color = base;
  switch (mode) {
    case "Breathing":
      opacity = [1, 0.6, 0.3, 0.8][group % 4];
      color = pick(group);
      break;
    case "Meteor":
    case "MeteorShower":
    case "TailChasing":
    case "Racing": {
      const head = (group * 5) % count;
      const distance = (head - index + count) % count;
      opacity = distance < 7 ? 1 - distance * 0.13 : 0.06;
      break;
    }
    case "Runway":
    case "Staggered":
    case "Stack":
    case "StackMulti":
      color = pick(Math.floor((index + group) / 2));
      break;
    case "Wave":
    case "Tide":
    case "Ripple":
      opacity = 0.25 + 0.75 * Math.abs(Math.sin((index / count) * Math.PI * 2 + group));
      color = pick(index < count / 2 ? 0 : 1);
      break;
    case "PingPong":
    case "Collide": {
      const center = (group * 4 + Math.floor(count / 3)) % count;
      opacity = Math.abs(index - center) < 3 ? 1 : 0.08;
      break;
    }
    case "Twinkle":
    case "Lottery":
      opacity = (index * 7 + group * 3) % 5 === 0 ? 1 : 0.15;
      break;
    default:
      color = pick(Math.floor((index / count) * palette.length));
  }
  return { color, opacity: Math.max(0.05, opacity * level) };
}
