#include <alsa/asoundlib.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>

#define PCM_DEVICE "default"

snd_pcm_t *pcm_handle;
snd_timer_t *timer_handle;
int should_stop = 0;

void timer_callback(union sigval sv) {
    if (should_stop) return;

    // Generate a simple tick sound
    short buf[1024];
    for (int i = 0; i < 1024; i++) {
        buf[i] = (i < 512) ? 32767 : -32767; // Simple square wave
    }

    snd_pcm_writei(pcm_handle, buf, 1024);
}

void signal_handler(int signum) { should_stop = 1; }

int main() {
    int err;
    snd_pcm_hw_params_t *hw_params;
    struct sigevent sev;
    struct itimerspec its;
    timer_t timer_id;

    // Open PCM device for playback
    err = snd_pcm_open(&pcm_handle, PCM_DEVICE, SND_PCM_STREAM_PLAYBACK, 0);
    if (err < 0) {
        fprintf(stderr, "Cannot open PCM device: %s\n", snd_strerror(err));
        return 1;
    }

    // Allocate hardware parameters object
    snd_pcm_hw_params_alloca(&hw_params);

    // Fill it with default values
    snd_pcm_hw_params_any(pcm_handle, hw_params);

    // Set parameters
    err = snd_pcm_hw_params_set_access(pcm_handle, hw_params,
                                       SND_PCM_ACCESS_RW_INTERLEAVED);
    err |= snd_pcm_hw_params_set_format(pcm_handle, hw_params,
                                        SND_PCM_FORMAT_S16_LE);
    err |= snd_pcm_hw_params_set_channels(pcm_handle, hw_params, 1);
    err |= snd_pcm_hw_params_set_rate(pcm_handle, hw_params, 44100, 0);

    // Write parameters
    err = snd_pcm_hw_params(pcm_handle, hw_params);
    if (err < 0) {
        fprintf(stderr, "Cannot set PCM hardware parameters: %s\n",
                snd_strerror(err));
        return 1;
    }

    // Set up timer
    sev.sigev_notify = SIGEV_THREAD;
    sev.sigev_notify_function = timer_callback;
    sev.sigev_value.sival_ptr = &timer_id;
    sev.sigev_notify_attributes = NULL;

    timer_create(CLOCK_REALTIME, &sev, &timer_id);

    its.it_value.tv_sec = 1;
    its.it_value.tv_nsec = 0;
    its.it_interval.tv_sec = 1;
    its.it_interval.tv_nsec = 0;

    timer_settime(timer_id, 0, &its, NULL);

    // Set up signal handler for graceful termination
    signal(SIGINT, signal_handler);

    printf("Generating tick sound at 60 BPM. Press Ctrl+C to stop.\n");

    // Main loop
    while (!should_stop) {
        pause();
    }

    // Clean up
    timer_delete(timer_id);
    snd_pcm_close(pcm_handle);

    return 0;
}
