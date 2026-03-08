## Technical Observations & Considerations:

- Async-Signal Safety: The alrm_handler calls alsa.play(sound_A), which eventually calls
  snd_pcm_writei. Most ALSA functions are not async-signal-safe. While it might work in practice for
  this simple case, it can lead to deadlocks or undefined behavior if the signal interrupts another
  ALSA call or a memory allocation. A more robust approach would be using timerfd with an event loop
  or a dedicated audio thread.
- Timing Precision: setitimer can suffer from jitter under system load. For a metronome, where
  micro-timing matters, timerfd or a high-priority thread using nanosleep might provide better
  stability.
