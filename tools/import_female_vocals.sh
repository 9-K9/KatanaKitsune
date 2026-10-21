#!/usr/bin/env bash
# Map the approved ElevenLabs female-vocal generations into canonical game assets.
set -euo pipefail

DOWNLOADS="${1:-/mnt/K-DRIVE/Downloads}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RAW="$ROOT/assets/audio/generated/raw"
FINAL="$ROOT/assets/audio/generated/final"

master_voice() {
	local source="$1" target="$2" channels="$3" max_duration="$4"
	ffmpeg -y -hide_banner -loglevel error -i "$source" \
		-af "silenceremove=start_periods=1:start_duration=0.01:start_threshold=-50dB:stop_periods=-1:stop_duration=0.04:stop_threshold=-50dB:window=0.01,atrim=end=$max_duration,loudnorm=I=-20:LRA=7:TP=-1" \
		-ar 48000 -ac "$channels" -c:a pcm_s16le "$target"
}

install_family() {
	local prefix="$1" count="$2" extension="$3" channels="$4" max_duration="$5"
	shift 5
	local sources=("$@")
	if (( ${#sources[@]} < count )); then
		echo "Not enough sources for $prefix: need $count, found ${#sources[@]}" >&2
		exit 1
	fi
	for ((i=1; i<=count; i++)); do
		local stem
		stem="${prefix}_$(printf '%02d' "$i")"
		rm -f "$RAW/$stem.mp3" "$RAW/$stem.mp3.import"
		cp "${sources[$((i - 1))]}" "$RAW/$stem.wav"
		if [[ "$extension" == "ogg" ]]; then
			ffmpeg -y -hide_banner -loglevel error -i "$RAW/$stem.wav" \
				-af "atrim=end=$max_duration,loudnorm=I=-24:LRA=12:TP=-2" -ar 48000 -ac "$channels" \
				-c:a libvorbis -q:a 5 "$FINAL/$stem.ogg"
		else
			master_voice "$RAW/$stem.wav" "$FINAL/$stem.wav" "$channels" "$max_duration"
		fi
	done
}

shopt -s nullglob

player_attack_a=("$DOWNLOADS"/Young_adult_female_J_#1-1792586468216.wav "$DOWNLOADS"/Young_adult_female_J_#1-1792586468216\ \(1\).wav "$DOWNLOADS"/Young_adult_female_J_#1-1792586468216\ \(2\).wav "$DOWNLOADS"/Young_adult_female_J_#1-1792586468216\ \(3\).wav)
player_attack_b=("$DOWNLOADS"/PLAYER_ATTACK_B._You_#1-1792586624909.wav "$DOWNLOADS"/PLAYER_ATTACK_B._You_#1-1792586624909\ \(1\).wav "$DOWNLOADS"/PLAYER_ATTACK_B._You_#1-1792586624909\ \(2\).wav "$DOWNLOADS"/PLAYER_ATTACK_B._You_#1-1792586624909\ \(3\).wav)
install_family vox_kitsune_attack 8 wav 1 0.5 "${player_attack_a[@]}" "${player_attack_b[@]}"

install_family vox_kitsune_heavy 5 wav 1 0.8 "$DOWNLOADS"/PLAYER_HEAVY_A._Youn_#1-1792586644367*.wav
install_family vox_kitsune_hurt 6 wav 1 0.55 "$DOWNLOADS"/PLAYER_HURT_A._Young_#1-1792586683900*.wav "$DOWNLOADS"/PLAYER_HURT_B._Young_#1-1792586708458*.wav
install_family vox_kitsune_downed 4 wav 1 1.3 "$DOWNLOADS"/PLAYER_DOWNED._Young_#1-1792586724846*.wav
install_family vox_kitsune_exhausted 3 ogg 2 1.8 "$DOWNLOADS"/PLAYER_EXHAUSTED._Yo_#1-1792586749524*.wav

install_family sfx_enemy_jor_alert 3 wav 1 0.9 "$DOWNLOADS"/JOROGUMO_ALERT._Adul_#1-1792586767219*.wav
install_family sfx_enemy_jor_attack 4 wav 1 0.8 "$DOWNLOADS"/JOROGUMO_ATTACK._Adu_#1-1792586790478*.wav
install_family sfx_enemy_jor_hurtdeath 5 wav 1 1.0 "$DOWNLOADS"/JOROGUMO_HURT_A._Adu_#1-1792586808721*.wav "$DOWNLOADS"/JOROGUMO_HURT_B._Adu_#1-1792586825197*.wav

install_family sfx_enemy_kas_alert 3 wav 1 0.9 "$DOWNLOADS"/KASHA_ALERT._Adult_f_#1-1792586849470*.wav
install_family sfx_enemy_kas_attack 4 wav 1 0.8 "$DOWNLOADS"/KASHA_ATTACK._Adult__#1-1792586866122*.wav
install_family sfx_enemy_kas_hurtdeath 5 wav 1 1.0 "$DOWNLOADS"/KASHA_HURT_A._Adult__#1-1792586883614*.wav "$DOWNLOADS"/KASHA_HURT_B._Adult__#1-1792586907829*.wav

install_family sfx_enemy_nin_alert 3 wav 1 0.9 "$DOWNLOADS"/NINA_ALERT._Young_ad_#1-1792586925036*.wav
install_family sfx_enemy_nin_attack 4 wav 1 0.8 "$DOWNLOADS"/NINA_ATTACK._Young_a_#1-1792586941110*.wav
install_family sfx_enemy_nin_hurtdeath 5 wav 1 1.0 "$DOWNLOADS"/NINA_HURT_A._Young_a_#1-1792586966050*.wav "$DOWNLOADS"/NINA_HURT_B._Young_a_#1-1792586982686*.wav

install_family sfx_enemy_yuk_alert 3 wav 1 0.9 "$DOWNLOADS"/YUKI_ONNA_ALERT._Adu_#1-1792587000358*.wav
install_family sfx_enemy_yuk_attack 4 wav 1 0.8 "$DOWNLOADS"/YUKI_ONNA_ATTACK._Ad_#1-1792587023956*.wav
install_family sfx_enemy_yuk_hurtdeath 5 wav 1 1.0 "$DOWNLOADS"/YUKI_ONNA_HURT_A._Ad_#1-1792587041211*.wav "$DOWNLOADS"/YUKI_ONNA_HURT_B._Ad_#1-1792587058389*.wav

echo "Imported and mastered 74 female vocal assets."
