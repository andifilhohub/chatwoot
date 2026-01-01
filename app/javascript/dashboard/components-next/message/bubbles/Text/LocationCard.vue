<script setup>
import { computed } from 'vue';
import Icon from 'next/icon/Icon.vue';

const props = defineProps({
  content: {
    type: String,
    required: true,
  },
});

const locationData = computed(() => {
  const lines = props.content.split('\n').filter(line => line.trim());

  let latitude = null;
  let longitude = null;
  let name = 'Localização compartilhada';

  lines.forEach(line => {
    const latMatch = line.match(/\*Latitud[e]?:\*\s*(-?\d+\.?\d*)/i);
    if (latMatch) {
      latitude = parseFloat(latMatch[1]);
    }

    const longMatch = line.match(/\*Longitud[e]?:\*\s*(-?\d+\.?\d*)/i);
    if (longMatch) {
      longitude = parseFloat(longMatch[1]);
    }

    const urlMatch = line.match(/\*URL:\*\s*(.+)/i);
    if (urlMatch) {
      // URL pode conter o nome da localização, mas vamos usar o padrão
    }
  });

  return { latitude, longitude, name };
});

const googleMapsUrl = computed(() => {
  if (!locationData.value.latitude || !locationData.value.longitude) {
    return '';
  }
  return `https://maps.google.com/?q=${locationData.value.latitude},${locationData.value.longitude}`;
});

const staticMapUrl = computed(() => {
  if (!locationData.value.latitude || !locationData.value.longitude) {
    return '';
  }
  const { latitude, longitude } = locationData.value;
  const zoom = 15;
  const size = '400x200';
  const marker = `color:red|${latitude},${longitude}`;
  
  return `https://maps.googleapis.com/maps/api/staticmap?center=${latitude},${longitude}&zoom=${zoom}&size=${size}&markers=${marker}&key=YOUR_API_KEY`;
});

const hasValidCoordinates = computed(() => {
  return locationData.value.latitude !== null && locationData.value.longitude !== null;
});
</script>

<template>
  <div class="inline-block max-w-sm">
    <div
      class="rounded-2xl border-2 border-slate-200/60 dark:border-slate-700/60 bg-white/50 dark:bg-slate-800/50 backdrop-blur-sm overflow-hidden shadow-sm"
    >
      <!-- Map Preview Section -->
      <div class="relative h-40 bg-slate-100 dark:bg-slate-800 overflow-hidden">
        <div
          v-if="hasValidCoordinates"
          class="absolute inset-0"
        >
          <!-- Simulated map grid background -->
          <div class="absolute inset-0 opacity-20">
            <svg class="w-full h-full" xmlns="http://www.w3.org/2000/svg">
              <defs>
                <pattern id="grid" width="40" height="40" patternUnits="userSpaceOnUse">
                  <path d="M 40 0 L 0 0 0 40" fill="none" stroke="currentColor" stroke-width="0.5" class="text-slate-400"/>
                </pattern>
              </defs>
              <rect width="100%" height="100%" fill="url(#grid)" />
            </svg>
          </div>
          
          <!-- Map pin indicator -->
          <div class="absolute inset-0 flex items-center justify-center">
            <div class="relative">
              <!-- Ping animation circle -->
              <div class="absolute inset-0 flex items-center justify-center">
                <div class="size-20 rounded-full bg-green-500/20 animate-ping"></div>
              </div>
              <!-- Pin icon -->
              <div class="relative z-10 flex flex-col items-center">
                <Icon
                  icon="i-lucide-map-pin"
                  class="size-12 text-green-600 dark:text-green-500 drop-shadow-lg"
                  style="filter: drop-shadow(0 2px 4px rgba(0,0,0,0.2))"
                />
                
              </div>
            </div>
          </div>
        </div>
        <div v-else class="absolute inset-0 flex items-center justify-center">
          <Icon
            icon="i-lucide-map-pin-off"
            class="size-12 text-slate-400 dark:text-slate-600"
          />
        </div>
      </div>

      <!-- Location Info Section -->
      <div class="p-4">
        <div class="flex items-start gap-3">
          <div
            class="flex-shrink-0 size-10 rounded-full bg-green-600 dark:bg-green-600 flex items-center justify-center text-white shadow-md"
          >
            <Icon icon="i-lucide-navigation" class="size-5" />
          </div>

          <div class="flex-1 min-w-0 pt-0.5">
            <div class="flex items-center gap-2 mb-1">
              <span
                class="font-semibold text-slate-900 dark:text-slate-100 text-base"
              >
                {{ locationData.name }}
              </span>
            </div>

            <div v-if="hasValidCoordinates" class="text-sm text-slate-600 dark:text-slate-400">
              Clique para visualizar no mapa
            </div>
          </div>
        </div>
      </div>

      <!-- Action Button -->
      <div class="border-t border-slate-200/60 dark:border-slate-700/60">
        <a
          v-if="hasValidCoordinates"
          :href="googleMapsUrl"
          target="_blank"
          rel="noopener noreferrer"
          class="flex items-center justify-center gap-2 w-full px-4 py-3 text-sm font-medium text-woot-600 dark:text-woot-400 hover:bg-slate-100/80 dark:hover:bg-slate-700/50 transition-colors"
        >
          <Icon icon="i-lucide-external-link" class="size-4" />
          <span>Abrir no Google Maps</span>
        </a>
        <button
          v-else
          type="button"
          disabled
          class="flex items-center justify-center gap-2 w-full px-4 py-3 text-sm font-medium text-slate-400 dark:text-slate-600 cursor-not-allowed"
        >
          <Icon icon="i-lucide-map-pin-off" class="size-4" />
          <span>Coordenadas inválidas</span>
        </button>
      </div>
    </div>
  </div>
</template>
