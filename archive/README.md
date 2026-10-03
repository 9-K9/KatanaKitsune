# archive

Code that is no longer reachable, kept rather than deleted.

**Nothing in here runs.** The `.gdignore` beside this file makes Godot skip the
whole directory — scripts are not parsed, `class_name` is not registered, and
nothing can accidentally reference them. Moving a file out of here is all it
takes to bring it back.

Each entry below records what it was, why it stopped being reachable, and what
replaced it, so re-enabling is a decision rather than an excavation.

---

## scripts/stateMachine/playerState/sittingFloor.gd

A player state for resting on the floor.

**Why archived.** No inbound transition. Every `change_state("…")` literal in
the project was enumerated and none targets it; it is not the FSM's initial
state (`KatanaKitsune.tscn` starts on `idle`); and it is not reachable through
the one dynamic transition in the FSM (`katanaSeath.gd`, whose `_next` is only
ever `"stealthWalk"` or `"walk"`).

**What replaced it.** Resting moved to the chair — `idle.gd:45` goes to
`sittingChair`.

**Left in place deliberately.** The eight `sittingFloor_*` SpriteFrames clips
and their AnimationPlayer tracks are still in `KatanaKitsune.tscn`. That is
art, not code, and removing it is a separate and riskier job. The art costs
nothing while unused, and leaving it means restoring this state is just a
matter of putting the node back.

**To re-enable.** Move the script back, re-add the `sittingFloor` node under
`FiniteStateMachine` in `KatanaKitsune.tscn`, and add a `change_state` into it
from wherever resting should begin.

## scenes/characters/stateDummy.gd

The editor's state-machine script template, pasted in as a real node
(`_stateDummy`).

**Why archived.** All eight methods are `pass`. Never a `change_state` target.
It was scaffolding for authoring new states, and it lived under `scenes/`
rather than `scripts/`, which was the tell.

**To re-enable.** Nothing depends on it. If you want a template for new states,
prefer `script_templates/StateMachineState/state_machine_state.gd`, which is
what the editor offers when you add a state script.

---

## Also removed from KatanaKitsune.tscn (no file to archive)

**`characterState` node.** Attached the abstract base `playerStateClass.gd`
(`PlayerClass`) as if it were a state. The *script* is very much alive — every
player state extends it — but it is resolved through `class_name`, not through
the scene, so this node was pure scaffolding.

**`_stateDummy` node.** The host for `stateDummy.gd` above.

---

## Not archived, on purpose

**`scripts/stateMachine/enemyState/enemyIdle.gd`** looks superseded by `alert`
and is not. `idle` is the unaware/roaming state; `alert` is the lost-sight
search state. Both monster scenes wire it as their initial state, and
`enemyAlert.gd:32` transitions *into* it when a monster gives up. It was very
nearly archived on that wrong assumption.

**`MazeDemo.gd`'s themed-floor branch** (the block guarded by each theme's
`"floor"` entry) never executes, because all 64 `THEMES` entries have `"floor":
""`. That is dead by *data*, not by code — one non-empty string switches it
back on. It reads as a feature mid-flight, so it stays.
