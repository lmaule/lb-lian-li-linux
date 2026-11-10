<script setup lang="ts">
import { computed } from "vue";
import { useDevicesStore, type DisplaySwitchError } from "@/stores/devices";
import DeviceCard from "@/components/devices/DeviceCard.vue";
import { Cpu, Fan, Monitor, Palette, PlugZap, Thermometer } from "lucide-vue-next";
import { useDaemonStore } from "@/stores/daemon";
import { useThermalStore } from "@/stores/thermal";
import { useTranslate } from "@/i18n";

const devices = useDevicesStore();
const daemon = useDaemonStore();
const thermal = useThermalStore();
const t = useTranslate();

const empty = computed(() => devices.displayCards.length === 0);

const counts = computed(() => {
  const list = devices.displayCards;
  return {
    total: list.length,
    cooling: list.filter((d) => d.has_fan || d.has_pump).length,
    lighting: list.filter((d) => d.has_rgb).length,
    screens: list.filter((d) => d.has_lcd).length,
  };
});

function tempTone(celsius: number): string {
  if (celsius < 60) return "cool";
  if (celsius < 80) return "warm";
  return "hot";
}

// Readings exist only while thermal alerts poll sensors; the page adds no sensor polling of its own.
const temps = computed(() =>
  [
    { id: "cpu", label: t("devices.hero.cpu"), value: thermal.cpuTemp, icon: Cpu },
    { id: "gpu", label: t("devices.hero.gpu"), value: thermal.gpuTemp, icon: Thermometer },
  ].filter((temp): temp is typeof temp & { value: number } => temp.value !== null),
);

function switchErrorText(error: DisplaySwitchError): string {
  return "message" in error ? error.message : t("devices.page.switchTimeout", { name: error.timedOutDevice });
}

async function refresh() {
  await daemon.refresh();
}
</script>

<template>
  <div class="page devices-page">
    <n-alert v-for="(error, id) in devices.displaySwitchErrors" :key="id" type="error" closable @close="delete devices.displaySwitchErrors[id]">{{ switchErrorText(error) }}</n-alert>

    <section class="hero">
      <div class="hero-main">
        <span class="eyebrow">{{ t("devices.hero.eyebrow") }}</span>
        <div class="hero-count">
          <span class="count">{{ counts.total }}</span>
          <span class="count-label">{{ t("devices.hero.connected") }}</span>
        </div>
        <p class="hero-summary">{{ devices.summary }}</p>
      </div>
      <div v-if="temps.length" class="hero-stats">
        <div v-for="temp in temps" :key="temp.id" class="temp-tile">
          <span class="tile-label"><component :is="temp.icon" :size="15" />{{ temp.label }}</span>
          <span class="tile-value">{{ Math.round(temp.value) }}<small>°C</small></span>
          <span class="tone" :class="`tone-${tempTone(temp.value)}`" />
        </div>
      </div>
    </section>

    <div class="cap-row">
      <div class="cap-tile cap-cooling">
        <Fan :size="20" />
        <span class="cap-value">{{ counts.cooling }}</span>
        <span class="cap-label">{{ t("devices.hero.cooling") }}</span>
      </div>
      <div class="cap-tile cap-lighting">
        <Palette :size="20" />
        <span class="cap-value">{{ counts.lighting }}</span>
        <span class="cap-label">{{ t("devices.hero.lighting") }}</span>
      </div>
      <div class="cap-tile cap-screens">
        <Monitor :size="20" />
        <span class="cap-value">{{ counts.screens }}</span>
        <span class="cap-label">{{ t("devices.hero.screens") }}</span>
      </div>
    </div>

    <div v-if="empty" class="card empty-state">
      <PlugZap :size="48" :stroke-width="1.4" />
      <div class="empty-title">{{ t("devices.page.noDevicesFound") }}</div>
      <div class="empty-sub">{{ t("devices.page.daemonRunning") }}</div>
      <n-button secondary @click="refresh">{{ t("common.retry") }}</n-button>
    </div>

    <template v-else>
      <h2 class="section-title list-title">{{ t("devices.hero.hardware") }}</h2>
      <div class="device-list">
        <DeviceCard
          v-for="d in devices.displayCards"
          :key="d.device_id"
          :device="d"
        />
      </div>
    </template>
  </div>
</template>

<style scoped>
.page {
  width: 100%;
  display: flex;
  flex-direction: column;
  gap: var(--space-4);
}
.hero {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-6);
  padding: 28px 32px;
  border-radius: 32px;
  background: var(--md-primary-container);
  color: var(--md-on-primary-container);
}
.hero-main {
  display: flex;
  flex-direction: column;
  gap: var(--space-2);
  min-width: 0;
}
.eyebrow {
  align-self: flex-start;
  padding: 4px 12px;
  border-radius: 12px;
  background: var(--md-on-primary-container);
  color: var(--md-primary-container);
  font-size: var(--font-size-xs);
  font-weight: 700;
  letter-spacing: 0.8px;
  text-transform: uppercase;
}
.hero-count {
  display: flex;
  align-items: baseline;
  gap: var(--space-3);
}
.count {
  font-family: var(--font-display);
  font-size: 56px;
  font-weight: 600;
  line-height: 1;
}
.count-label {
  font-family: var(--font-display);
  font-size: 22px;
  font-weight: 500;
}
.hero-summary {
  margin: 0;
  font-size: 15px;
  opacity: 0.85;
}
.hero-stats {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-3);
}
.temp-tile {
  position: relative;
  display: flex;
  flex-direction: column;
  gap: var(--space-1);
  min-width: 132px;
  padding: var(--space-4) 20px var(--space-4) var(--space-4);
  border-radius: 22px;
  background: var(--md-surface);
  color: var(--md-on-surface);
}
.tile-label {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: var(--font-size-sm);
  font-weight: 600;
  color: var(--md-on-surface-variant);
}
.tile-value {
  font-family: var(--font-display);
  font-size: 36px;
  font-weight: 600;
  line-height: 1.05;
}
.tile-value small {
  font-size: 15px;
  font-weight: 500;
  margin-left: 2px;
  color: var(--md-on-surface-variant);
}
.tone {
  position: absolute;
  top: var(--space-4);
  right: var(--space-4);
  width: 10px;
  height: 10px;
  border-radius: 50%;
  background: var(--md-outline-variant);
}
.tone-cool { background: var(--temp-cool); }
.tone-warm { background: var(--temp-warm); }
.tone-hot { background: var(--temp-hot); }
.cap-row {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  gap: var(--space-3);
}
.cap-tile {
  display: grid;
  grid-template-columns: auto 1fr;
  grid-template-rows: auto auto;
  align-items: center;
  column-gap: var(--space-3);
  padding: var(--space-4) 20px;
  border-radius: 24px;
}
.cap-tile svg {
  grid-row: 1 / 3;
}
.cap-value {
  font-family: var(--font-display);
  font-size: 28px;
  font-weight: 600;
  line-height: 1.1;
}
.cap-label {
  font-size: var(--font-size-sm);
  font-weight: 600;
  opacity: 0.85;
}
.cap-cooling {
  background: var(--md-secondary-container);
  color: var(--md-on-secondary-container);
}
.cap-lighting {
  background: var(--md-tertiary-container);
  color: var(--md-on-tertiary-container);
}
.cap-screens {
  background: var(--md-surface-container-high);
  color: var(--md-on-surface);
}
.list-title {
  margin: var(--space-4) 0 0;
}
.device-list {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(min(100%, 440px), 1fr));
  gap: var(--space-4);
}
.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: var(--space-2);
  padding: var(--space-8);
  color: var(--md-on-surface-variant);
}
.empty-title {
  font-family: var(--font-display);
  font-size: var(--font-size-xl);
  color: var(--md-on-surface);
  margin-top: var(--space-2);
}
.empty-sub {
  font-size: var(--font-size-sm);
  margin-bottom: var(--space-2);
}
</style>
