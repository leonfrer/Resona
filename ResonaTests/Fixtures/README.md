# Audio fixtures

These fixtures are generated from a 440 Hz sine wave and contain no third-party
audio content. The supported samples are intentionally short to keep the test
bundle small.

Generation uses the local `ffmpeg` command-line tool:

```sh
ffmpeg -f lavfi -i 'sine=frequency=440:duration=0.25' -ar 44100 -ac 1 <codec options> <output>
```

- `supported.mp3`: MP3 audio (`libmp3lame`)
- `supported-aac.m4a`: AAC audio with title, artist, and album metadata
- `supported-alac.m4a`: Apple Lossless audio
- `supported.wav`: 16-bit PCM WAV
- `supported.aiff`: 16-bit PCM AIFF
- `unsupported-codec.wav`: mu-law audio in a WAV container
- `video-only.mp4`: MPEG-4 video with no audio track
- `unsupported.flac`: FLAC, which is outside the first-release container policy
- `corrupt.mp3`: non-audio bytes with a supported filename extension

Regenerate the files with a current local `ffmpeg` build when fixture changes
are required. Fixtures live only in the test target.
