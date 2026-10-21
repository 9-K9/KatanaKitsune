# Katana Kitsune Audio Style Guide

## Observed identity

The current game is an isometric, pixel-art Japanese fantasy action game with agile katana combat, stealth, yokai enemies, shrine architecture, elemental character aspects, procedural interiors/exteriors, weather, wildlife, progression, and co-op. Combat animations are detailed and readable; the audio should reinforce their timing without overpowering the pixel-scale presentation.

## Proposed sonic identity

### Signature

Build the identity around **steel, breath, paper, wood, and spirit**:

- Steel: close, precise katana transients rather than oversized cinematic swords.
- Breath: controlled effort and yokai vocal texture communicate living combatants.
- Paper/wood: menus, scrolls, shoji, shrines, and pickups share tactile material language.
- Spirit: a short pitched air/bell motif marks powers, revival, and progression.
- Signature interval: an original compact two-note “fox step” motif can recur in the title, wave clear, revive, and online start cues.

### Music

Blend koto, shamisen, shakuhachi, shinobue, taiko, temple bells, and sparse noh-like textures with restrained analog synths and modern percussion. Traditional instruments should carry articulation and place; modern elements should carry momentum and supernatural energy. Avoid generic “Asian” ornamentation, copyrighted references, and wall-to-wall taiko.

Exploration should leave room for environment and positional threats. Combat should raise rhythmic density without crushing hit transients. A boss cue may be larger, but “Yokai Lord is a formal boss” remains a partial inference pending design confirmation.

### Combat

- Fast attacks: dry, narrow, close transients.
- Charged attacks: longer low-mid body plus a controlled spirit layer.
- Parries: brightest transient in ordinary combat; unmistakable but not louder than safe peak.
- Hits: separate motion from contact so misses still sound intentional.
- Enemy cues: attacks need anticipation/release distinction where animations allow it.
- Use 3–8 variations and ±2–4% pitch for repeated one-shots; never randomize signature UI pitch broadly.

### Environment

Beds should be calm, sparse, seamless, and non-fatiguing. Avoid constant prominent birds or tonal whistles. Crossfade a biome bed with independent weather; use positional pond/fire emitters. Indoor filtering should reduce weather brightness rather than abruptly mute it.

### Voices

All playable characters, including Katana Kitsune and the legacy Karma Geisha, are female. Their vocalizations must be unmistakably feminine, brief, agile, and nonverbal. Jorogumo, Kasha, Nina Ninja, and Yuki Onna are also female; preserve a distinct feminine identity beneath each species texture. Other enemy voices should reflect species material—wet kappa, feathered karasu/tengu, heavy oni—without caricature. Do not generate spoken taunts until dialogue ownership is corrected.

### UI

Dry wooden ticks, brush/paper movement, small bells, and spirit glints. Confirmation rises or resolves; errors fall without harsh buzzers. UI should remain consistent across keyboard, gamepad, and web.

## Spatial and mix rules

- World one-shots: positional 2D with conservative attenuation and a practical max distance.
- Local UI/HUD/music: non-positional.
- Music/ambience: stereo; most combat SFX should remain narrow or mono-compatible.
- Proposed buses: Master, Music, Ambience, SFX, UI, Voice.
- Headroom: target Master peaks below -1 dBTP; preserve at least 6 dB mix headroom during ordinary combat.
- Starting loudness targets (verify by ear): music around -18 to -16 LUFS integrated per track; ambience -28 to -22 LUFS; one-shots normalized consistently by family, not maximized.
- Duck music 1–2 dB on critical parry/hurt cues; duck ambience lightly under dialogue.
- Use one small shrine/interior reverb send sparingly. Do not bake long reverb into common SFX.

## Copy-ready prompt examples

**Katana slash:** “Fast close katana swing, precise bright steel air cut, agile rather than massive, 0.45 seconds, dry game-ready one-shot, no impact, no music, no voice, no long reverb.”

**Perfect parry:** “Crisp katana deflection, hard steel transient followed by a short clear ring and tiny supernatural sparkle, 0.7 seconds, triumphant but not musical, dry game-ready one-shot, no dialogue.”

**Bamboo ambience:** “Seamless 30-second bamboo woodland night ambience, gentle leaves, occasional hollow bamboo creak, sparse distant birds and insects, calm Japanese shrine atmosphere, no melody, no voices, no sudden foreground event.”

**Kappa alert:** “Small hostile kappa yokai alert, wet amphibious croak with a sharp inhale and shell movement, 0.9 seconds, threatening but compact, no words, no music, dry positional game sound.”

**Main theme:** “Original instrumental Japanese-fantasy action-game main theme, memorable compact foxlike motif, koto and breathy flute over warm analog pulse and restrained taiko, mysterious, agile, hopeful, seamless 150-second loop, no vocals, no copyrighted melody.”

## Review checklist

Approve assets in gameplay, not in isolation. Check transient timing, repetition fatigue, mono compatibility, web decoding, overlap at four-player density, and whether every cue communicates a distinct event. Keep source masters and generation metadata even when the runtime file is OGG.
