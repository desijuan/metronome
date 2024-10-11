#include <alsa/asoundlib.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define WAV_HEADER_SIZE 44

snd_pcm_t *pcm_handle;
char *buffer;
snd_pcm_uframes_t frames;
size_t buffer_size;

void play_sample() {
    snd_pcm_prepare(pcm_handle);
    snd_pcm_writei(pcm_handle, buffer, frames);
}

void timer_handler(int signum) { play_sample(); }

int main(int argc, char *argv[]) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <wav_file>\n", argv[0]);
        return 1;
    }

    // Open the WAV file
    FILE *file = fopen(argv[1], "rb");
    if (!file) {
        perror("Error opening file");
        return 1;
    }

    // Read WAV header
    char header[WAV_HEADER_SIZE];
    if (fread(header, 1, WAV_HEADER_SIZE, file) != WAV_HEADER_SIZE) {
        perror("Error reading WAV header");
        fclose(file);
        return 1;
    }

    // Parse WAV header (simplified, assumes 16-bit PCM)
    unsigned int sample_rate = *(unsigned int *)&header[24];
    unsigned short channels = *(unsigned short *)&header[22];
    unsigned short bits_per_sample = *(unsigned short *)&header[34];

    // Read WAV data
    fseek(file, 0, SEEK_END);
    buffer_size = ftell(file) - WAV_HEADER_SIZE;
    fseek(file, WAV_HEADER_SIZE, SEEK_SET);

    buffer = malloc(buffer_size);
    if (!buffer) {
        perror("Error allocating memory");
        fclose(file);
        return 1;
    }

    if (fread(buffer, 1, buffer_size, file) != buffer_size) {
        perror("Error reading WAV data");
        free(buffer);
        fclose(file);
        return 1;
    }

    fclose(file);

    // Initialize ALSA
    snd_pcm_open(&pcm_handle, "default", SND_PCM_STREAM_PLAYBACK, 0);
    snd_pcm_set_params(pcm_handle, SND_PCM_FORMAT_S16_LE,
                       SND_PCM_ACCESS_RW_INTERLEAVED, channels, sample_rate, 1,
                       500000);

    frames = buffer_size / (channels * (bits_per_sample / 8));

    // Set up timer
    struct sigaction sa;
    struct itimerspec timer_spec;
    timer_t timer_id;

    memset(&sa, 0, sizeof(sa));
    sa.sa_handler = &timer_handler;
    sigaction(SIGALRM, &sa, NULL);

    timer_create(CLOCK_REALTIME, NULL, &timer_id);

    timer_spec.it_interval.tv_sec = 1;
    timer_spec.it_interval.tv_nsec = 0;
    timer_spec.it_value.tv_sec = 1;
    timer_spec.it_value.tv_nsec = 0;

    timer_settime(timer_id, 0, &timer_spec, NULL);

    // Main loop
    printf("Metronome started at 60 BPM. Press Enter to exit.\n");
    getchar();

    // Clean up
    timer_delete(timer_id);
    snd_pcm_close(pcm_handle);
    free(buffer);

    return 0;
}
