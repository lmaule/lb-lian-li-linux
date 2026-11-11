<script setup lang="ts">
import { computed } from "vue";
import type { RGB, RgbDeviceCapabilities, RgbDeviceConfig, RgbEffect } from "@/types";
import { BRIGHTNESS_OFF } from "@/constants";
import { previewLed } from "./previewColors";
import { useTranslate } from "@/i18n";

const props = defineProps<{
  cap: RgbDeviceCapabilities;
  config: RgbDeviceConfig;
  mbSync: boolean;
}>();

const t = useTranslate();

const MAX_RING_LEDS = 24;
const MAX_STRIP_LEDS = 30;
const RING = 140;
const RADIUS = 56;

function effectFor(index: number): RgbEffect | null {
  const regions = props.config.regions;
  if (regions?.length) return regions[Math.min(index, regions.length - 1)].effect;
  const zones = props.config.zones;
  if (!zones.length) return null;
  return zones[Math.min(index, zones.length - 1)].effect;
}

function ledStyle(effect: RgbEffect | null, i: number, n: number, group: number) {
  if (props.mbSync || !effect || effect.disabled || effect.brightness === BRIGHTNESS_OFF) {
    return { color: "#2a2a32", opacity: 1, glow: false };
  }
  const led = previewLed(effect.mode, effect.colors as RGB[], effect.brightness, i, n, group);
  return { color: led.color, opacity: led.opacity, glow: led.opacity > 0.3 };
}

const profile = computed(() => props.cap.render_profile ?? null);
const showRings = computed(() => !!profile.value && profile.value.family !== "Strimer" && profile.value.fan_count > 0);

const rings = computed(() => {
  if (!showRings.value || !profile.value) return [];
  const count = Math.min(profile.value.fan_count, 6);
  const n = Math.min(Math.max(profile.value.led_count, 8), MAX_RING_LEDS);
  return Array.from({ length: count }, (_, group) => {
    const effect = effectFor(group);
    const clockwise = effect?.direction !== "CounterClockwise";
    const leds = Array.from({ length: n }, (_, i) => {
      const angle = (clockwise ? 1 : -1) * (i / n) * Math.PI * 2 - Math.PI / 2;
      const style = ledStyle(effect, i, n, group);
      return { x: RING / 2 + RADIUS * Math.cos(angle) - 5, y: RING / 2 + RADIUS * Math.sin(angle) - 5, ...style };
    });
    return { leds, label: t("rgb.preview.fan", { index: group + 1 }) };
  });
});

const strips = computed(() => {
  if (showRings.value) return [];
  return props.cap.zones.slice(0, 8).map((zone, index) => {
    const effect = effectFor(index);
    const n = Math.min(Math.max(zone.led_count, 1), MAX_STRIP_LEDS);
    const leds = Array.from({ length: n }, (_, i) => ledStyle(effect, i, n, index));
    return { leds, label: zone.name };
  });
});
</script>

<template>
  <div class="preview" role="img" :aria-label="t('rgb.preview.label')">
    <span class="caption">{{ mbSync ? t("rgb.preview.mbSync") : t("rgb.preview.caption") }}</span>
    <div v-if="showRings" class="rings">
      <div v-for="(ring, r) in rings" :key="r" class="ring-wrap">
        <div class="ring">
          <span
            v-for="(led, i) in ring.leds"
            :key="i"
            class="led"
            :class="{ glow: led.glow }"
            :style="{ left: `${led.x}px`, top: `${led.y}px`, background: led.color, opacity: led.opacity, color: led.color }"
          />
        </div>
        <span class="ring-label">{{ ring.label }}</span>
      </div>
    </div>
    <div v-else class="strips">
      <div v-for="(strip, s) in strips" :key="s" class="strip-row">
        <span class="strip-label">{{ strip.label }}</span>
        <div class="strip">
          <span
            v-for="(led, i) in strip.leds"
            :key="i"
            class="led inline"
            :class="{ glow: led.glow }"
            :style="{ background: led.color, opacity: led.opacity, color: led.color }"
          />
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.preview {
  position: relative;
  display: flex;
  justify-content: center;
  padding: 44px var(--space-6) var(--space-6);
  border-radius: 24px;
  background: #0b0b10;
  color: #e8e8ee;
}
.caption {
  position: absolute;
  top: 14px;
  left: 16px;
  padding: 4px 12px;
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.09);
  font-size: var(--font-size-xs);
  font-weight: 600;
}
.rings {
  display: flex;
  flex-wrap: wrap;
  justify-content: center;
  gap: var(--space-6);
}
.ring-wrap {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: var(--space-2);
}
.ring {
  position: relative;
  width: 140px;
  height: 140px;
  border-radius: 50%;
  background: #15151b;
  box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.06);
}
.ring-label,
.strip-label {
  font-size: var(--font-size-xs);
  font-weight: 600;
  color: #b9b9c4;
}
.led {
  position: absolute;
  width: 10px;
  height: 10px;
  border-radius: 50%;
}
.led.inline {
  position: static;
  flex-shrink: 0;
}
.led.glow {
  box-shadow: 0 0 10px 2px currentColor;
}
.strips {
  display: flex;
  flex-direction: column;
  gap: var(--space-3);
  max-width: 100%;
}
.strip-row {
  display: flex;
  align-items: center;
  gap: var(--space-3);
  min-width: 0;
}
.strip-label {
  width: 80px;
  flex-shrink: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.strip {
  display: flex;
  gap: 6px;
  overflow: hidden;
}
</style>
