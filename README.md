# zdm-ffmpeg

A minimal, **LGPL** build of [FFmpeg](https://ffmpeg.org) for ZDM (Zap Download Manager), built in public by GitHub Actions.
ZDM runs this `ffmpeg.exe` as a separate program to join a video and an audio file (no re-encoding), to make MP3 files and to join downloaded HLS pieces. Nothing else.

This repository exists so that anyone who receives that `ffmpeg.exe` can get **the exact corresponding source** and **rebuild it** (LGPL 2.1 section 6).

## What is in a release
| File | What it is |
|---|---|
| `ffmpeg.exe` | the program (Windows, x86-64, static, no DLLs) |
| `SHA256SUMS` | hashes of `ffmpeg.exe`, the source tarballs, `VERSIONS.env` and `build.sh` |
| `ffmpeg-sources-and-build-script.zip` | the exact FFmpeg and LAME source tarballs, `VERSIONS.env`, `build.sh`, the licenses |
| `ffmpeg-buildconf.txt` | the configure line, read from the program |
| `REPRODUCIBLE.txt` | whether two builds in the same run gave the same `ffmpeg.exe` |
| license files | LGPL 2.1 (FFmpeg), FFmpeg's `LICENSE.md`, LAME's LGPL |

Each `ffmpeg.exe` also has a GitHub build attestation (provenance): `gh attestation verify ffmpeg.exe --repo MohamadTemsah/zdm-ffmpeg`.

## What is switched on
Configured with `--disable-everything` and only what ZDM needs: protocols `file,pipe,crypto,data`; demuxers `mov,matroska,mpegts,aac,mp3,ogg,flac,hls,concat,wav`;
muxers `mp4,ipod,matroska,mp3,adts`; decoders `aac,aac_latm,mp3,opus,vorbis,flac,pcm` and the picture decoders `h264,hevc,vp8,vp9,av1` (ffmpeg needs one to learn the size of a picture inside MPEG-TS pieces; nothing is decoded when joining); the encoder `libmp3lame` (LAME 3.100); parsers and bitstream filters for H.264/H.265/AV1/VP9/AAC/Opus;
filters `aresample,aformat`. No network, no GPL parts (`--enable-gpl`, `--enable-version3` and `--enable-nonfree` are not used), no ffplay, no ffprobe.
If ZDM needs one more component, it is added to `build.sh` and the build number is raised; nothing is worked around.

## Rebuild it yourself
On Ubuntu 24.04: `sudo apt-get install gcc-mingw-w64-x86-64-posix binutils-mingw-w64-x86-64 nasm xz-utils gnupg make curl`, then `bash build.sh out`.
The script downloads FFmpeg 9.0.2 and LAME 3.100 from their official addresses, checks the SHA-256 written in `VERSIONS.env`, checks the FFmpeg signature against the release key
(fingerprint `FCF986EA15E6E293A5644F10B4322F04D67658D8`), and builds. Compare `out/ffmpeg.exe` with the release's (the hash in `SHA256SUMS`).

## Patents
LAME's MP3 encoder: the MP3 patents have expired. Decoding AAC (used for the MP3 path of AAC sources) may fall under patent licences in some countries, as in every free media player.
Copy-only paths do not decode. This is not legal advice.

## Licenses
FFmpeg: LGPL 2.1 or later (`licenses/FFmpeg-COPYING.LGPLv2.1.txt`). LAME: LGPL (`licenses/LAME-COPYING.txt`). The files written for this repository (`build.sh`, the workflow) are under the MIT license (`LICENSE`).
This is an unofficial build; FFmpeg is a trademark of Fabrice Bellard.
