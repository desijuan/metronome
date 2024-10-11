#include <alsa/asoundlib.h>
#include <stdio.h>
#include <stdlib.h>

#define WAV_HEADER_SIZE 44

snd_pcm_t *pcm_handle;
char *buffer;
snd_pcm_uframes_t frames;
size_t buffer_size;

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

    // Initialize ALSA
    snd_pcm_open(&pcm_handle, "default", SND_PCM_STREAM_PLAYBACK, 0);

    // Set hardware parameters
    snd_pcm_hw_params_t *hw_params;
    snd_pcm_hw_params_alloca(&hw_params);
    snd_pcm_hw_params_any(pcm_handle, hw_params);
    snd_pcm_hw_params_set_access(pcm_handle, hw_params,
                                 SND_PCM_ACCESS_RW_INTERLEAVED);
    snd_pcm_hw_params_set_format(pcm_handle, hw_params, SND_PCM_FORMAT_S16_LE);
    snd_pcm_hw_params_set_channels(pcm_handle, hw_params, channels);
    snd_pcm_hw_params_set_rate(pcm_handle, hw_params, sample_rate, 0);

    // Set period size to match 60 BPM (sample_rate samples per beat)
    snd_pcm_uframes_t period_size = sample_rate;
    int dir = 0;
    snd_pcm_hw_params_set_period_size_near(pcm_handle, hw_params, &period_size,
                                           &dir);

    snd_pcm_hw_params(pcm_handle, hw_params);

    frames = buffer_size / (channels * (bits_per_sample / 8));

    printf("Metronome started at 60 BPM. Press Ctrl+C to exit.\n");

    while (1) {
        snd_pcm_sframes_t frames_written =
            snd_pcm_writei(pcm_handle, buffer, frames);
        if (frames_written < 0) {
            frames_written = snd_pcm_recover(pcm_handle, frames_written, 0);
        }
        if (frames_written < 0) {
            printf("Error writing to PCM device: %s\n",
                   snd_strerror(frames_written));
            break;
        }
    }

    // Clean up
    snd_pcm_close(pcm_handle);
    free(buffer);

    return 0;
}
