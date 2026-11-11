#!/usr/bin/env bash
# Builds a minimal, LGPL ffmpeg.exe for Windows (x86-64) with the MP3 encoder (LAME), cross-compiled with mingw-w64 on Linux.
#   ./build.sh [outdir]       needs: curl gpg make gcc-mingw-w64-x86-64 (posix threads) xz-utils nasm
# Run on a clean Ubuntu (the workflow does). It writes outdir/ffmpeg.exe, SHA256SUMS, ffmpeg-version.txt, ffmpeg-buildconf.txt and the exact sources.
# No --enable-gpl, no --enable-version3, no --enable-nonfree: the result is LGPL 2.1 or later and says so in `ffmpeg -version`.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
out="$(realpath -m "${1:-$here/out}")"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
# shellcheck source=VERSIONS.env
. "$here/VERSIONS.env"
export SOURCE_DATE_EPOCH TZ=UTC LC_ALL=C
mkdir -p "$out/source"

fetch() {  # fetch <url> <sha256> <file>
  curl --fail --silent --show-error --location --retry 3 --output "$3" "$1"
  echo "$2  $3" | sha256sum --check --strict
}

echo "== the sources, checked =="
cd "$out/source"
fetch "$FFMPEG_URL" "$FFMPEG_SHA256" "ffmpeg-$FFMPEG_VERSION.tar.xz"
fetch "$LAME_URL" "$LAME_SHA256" "lame-$LAME_VERSION.tar.gz"
curl --fail --silent --show-error --location --retry 3 --output "ffmpeg-$FFMPEG_VERSION.tar.xz.asc" "$FFMPEG_SIG_URL"
export GNUPGHOME="$work/gnupg"; mkdir -m 700 "$GNUPGHOME"
gpg --batch --quiet --import "$here/keys/ffmpeg-devel.asc"
gpg --batch --with-colons --fingerprint | grep -q "^fpr:::::::::$FFMPEG_KEY_FPR:" || { echo "the FFmpeg key in keys/ is not the pinned one"; exit 1; }
gpg --batch --status-fd 1 --verify "ffmpeg-$FFMPEG_VERSION.tar.xz.asc" "ffmpeg-$FFMPEG_VERSION.tar.xz" | grep -q "^\[GNUPG:\] VALIDSIG $FFMPEG_KEY_FPR " \
  || { echo "the signature of the FFmpeg source is not the release key's"; exit 1; }
echo "signature of the FFmpeg source: good (key $FFMPEG_KEY_FPR)"

host=x86_64-w64-mingw32
prefix="$work/prefix"
cd "$work"
tar xzf "$out/source/lame-$LAME_VERSION.tar.gz"
tar xJf "$out/source/ffmpeg-$FFMPEG_VERSION.tar.xz"

echo "== LAME (static, the library only) =="
cd "$work/lame-$LAME_VERSION"
./configure --host="$host" --prefix="$prefix" --disable-shared --enable-static --disable-frontend --disable-decoder --disable-gtktest \
  CFLAGS="-O2 -ffile-prefix-map=$work=."
make -j"$(nproc)"
make install

echo "== FFmpeg =="
cd "$work/ffmpeg-$FFMPEG_VERSION"
./configure \
  --arch=x86_64 --target-os=mingw32 --cross-prefix="$host-" \
  --prefix="$work/ffinstall" \
  --disable-everything --disable-autodetect --disable-network --disable-doc --disable-debug \
  --disable-ffplay --disable-ffprobe --disable-avdevice --disable-swscale --disable-postproc \
  --enable-static --disable-shared \
  --enable-libmp3lame \
  --enable-protocol=file,pipe,crypto,data \
  --enable-demuxer=mov,matroska,mpegts,aac,mp3,ogg,flac,hls,concat,wav \
  --enable-muxer=mp4,ipod,matroska,mp3,adts \
  --enable-decoder=aac,aac_latm,mp3,mp3float,opus,vorbis,flac,pcm_s16le \
  --enable-encoder=libmp3lame \
  --enable-parser=h264,hevc,av1,vp9,aac,aac_latm,opus,vorbis,mpegaudio,flac \
  --enable-bsf=aac_adtstoasc,h264_mp4toannexb,hevc_mp4toannexb,extract_extradata,vp9_superframe,av1_frame_merge,null \
  --enable-filter=aresample,aformat,anull,atrim,asetpts,null \
  --extra-cflags="-I$prefix/include -O2 -fno-ident -ffile-prefix-map=$work=." \
  --extra-ldflags="-L$prefix/lib -static -Wl,--no-insert-timestamp" \
  --extra-libs="-lpthread"   || { echo "== configure failed; its own log =="; tail -40 ffbuild/config.log; echo "== the options this FFmpeg knows =="; ./configure --help; exit 1; }
make -j"$(nproc)" ffmpeg.exe
"$host-strip" --strip-all ffmpeg.exe
cp ffmpeg.exe "$out/ffmpeg.exe"

echo "== what came out =="
cd "$out"
# the program's own idea of what it is (run with wine in the workflow when there is one; the configuration line is in the binary anyway)
strings -a ffmpeg.exe | grep -m1 -- "--disable-everything" > ffmpeg-buildconf.txt || true
cp "$here/licenses/"* . 2>/dev/null || true
cp "$here/VERSIONS.env" "$here/build.sh" .
( cd "$out" && sha256sum ffmpeg.exe source/* VERSIONS.env build.sh > SHA256SUMS )
echo "== done: $(stat -c %s ffmpeg.exe) bytes =="
cat SHA256SUMS
