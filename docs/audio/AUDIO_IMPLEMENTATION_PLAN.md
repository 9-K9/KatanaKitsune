# Godot Audio Implementation Plan

No runtime implementation is part of this audit. This plan is the recommended next engineering phase.

## Minimal architecture

1. Add a small `AudioManager` autoload, matching the project's existing autoload convention.
2. Add `AudioEvent` resources (or one typed dictionary registry initially) mapping stable Asset ID to streams, bus, variation, pitch range, gain, concurrency group, and spatial mode.
3. Create buses: Master, Music, Ambience, SFX, UI, Voice. Add only a limiter on Master initially; add a subtle environment send after listening tests.
4. Give the manager pooled non-positional players and pooled `AudioStreamPlayer2D` emitters. Avoid creating a node for every repeated footstep.
5. Add a simple MusicController and AmbienceController only when the first music/ambience files exist. They may be children of AudioManager rather than more autoloads.

## Event integration order

### Milestone 1 hooks

- Animation/state events: footstep, roll, draw, sheathe, slash motion, charge release, kick.
- Damage pipeline: hit contact, guard, parry, hurt, death, enemy defeat.
- `SpikeTrap._set_phase/_strike`: warning and strike.
- `Pickup` collection, `read_scroll`, breakables, sliding-door break.
- Core menu focus/confirm/back/error.
- Revival channel start/cancel/complete.
- Wave clear, stairs reveal, descend, game-over countdown.

Prefer animation call-method tracks for frame-critical contacts. Use state-entry hooks for cues that begin with the state. Centralize impact choice in the authoritative damage result, not in every overlapping hitbox.

### Environment and music hooks

- Map `LevelTheme.Id` to one biome ambience.
- Map `ExteriorBiome.Weather` to a separately crossfaded weather layer.
- Spawn pooled local emitters for ponds and fire only within hearing range.
- Music state inputs: screen/scene, whether enemies actively hunt a player, wave clear, party wipe. Start with simple crossfades; defer adaptive stems.

## Multiplayer-safe ownership

| Event | Playback source |
|---|---|
| Local menu navigation, lobby error, own selection | Immediate local UI |
| Player input motion (swing whoosh) | Local prediction for own avatar; remote peers from replicated state transition |
| Damage, parry, death, projectile hit, breakable, trap hit | Authoritative server result/world event |
| Remote footsteps/attacks | Replicated actor state with transition/frame guard |
| Join/leave/start/end | Lobby/session signals, once locally per snapshot delta |
| Music/ambience | Local state derived from synchronized theme/session |

Add monotonically increasing event IDs for discrete authoritative events that snapshots alone cannot represent safely. Cache recent IDs briefly on clients. Do not emit both when an RPC is requested and when its authoritative result returns. For looped states, reconcile start/stop from current state instead of replaying on every snapshot.

## Variation and concurrency

- Avoid immediate repeats within a family.
- Footsteps: max 4–6 simultaneous per listener; collapse distant party/enemy steps.
- Enemy vocals: per-entity cooldown plus a global cap of 3.
- Impacts: cap by family and favor closest/highest-priority events.
- UI: one per action; never spatial.
- Pitch randomization: footsteps/impacts ±2–4%; voices ±1–2%; none on music/signature UI.

## Memory and web

- Stream OGG music and ambience; do not preload all long tracks.
- Keep short one-shots as WAV masters; compare Godot import compression by ear and package size.
- Load event banks per scene/theme and release previous banks after crossfade.
- The Web export has no thread support: avoid synchronous loading of a complete library during a scene transition.
- Unlock browser audio on the first user gesture, show a muted indicator if context remains suspended, and pause/duck on focus loss.
- Test Chrome, Firefox, and mobile browser limits. Profile decoded memory, not only compressed file size.

## Settings and persistence

Add sliders for Master, Music, SFX, Ambience, Voice, plus mute. Persist alongside existing settings conventions. Sliders should operate in decibels with a logarithmic mapping and a true silent endpoint.

## Validation

1. Unit-check registry IDs, files, bus names, and variation arrays.
2. Verify every P0 event fires once at the correct frame.
3. Stress four-player combat and large waves; count active players and dropped/capped events.
4. Verify no double playback across client/server.
5. Test join/leave, reconnection, descent, wipe, pause, and browser focus.
6. Measure web package size, first-audio latency, decoded memory, and peak voices.
7. Mix-review with music, rain, four players, and many enemies simultaneously.

