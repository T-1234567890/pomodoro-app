<script lang="ts">
  import { onDestroy } from 'svelte';

  export let src = '/assets/sounds/focus.mp3';

  let audio: HTMLAudioElement | null = null;
  let volume = 1;

  const ensureAudio = () => {
    if (!audio) {
      audio = new Audio(src);
      audio.loop = true;
      audio.volume = volume;
    }
    if (audio.src !== src) {
      audio.src = src;
    }
  };

  export const play = () => {
    ensureAudio();
    void audio?.play();
  };

  export const pause = () => {
    audio?.pause();
  };

  export const stop = () => {
    if (!audio) {
      return;
    }
    audio.pause();
    audio.currentTime = 0;
  };

  export const setVolume = (value: number) => {
    const clamped = Math.min(1, Math.max(0, value));
    volume = clamped;
    if (audio) {
      audio.volume = clamped;
    }
  };

  onDestroy(() => {
    if (audio) {
      audio.pause();
      audio.src = '';
      audio.load();
      audio = null;
    }
  });
</script>
