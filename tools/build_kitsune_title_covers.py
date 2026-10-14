#!/usr/bin/env python3
"""Import the per-aspect title covers for Kitsune.

The twelve GPT-generated variants of the Kitsune title cover (one per power
state, her hair and skirt in that aspect's colours) live outside the repository
as 1672x941 masters. This reduces each to 768x432 with Lanczos - the same
treatment as the neutral `title_cover_kitsune.png` - and writes it with its
`.import` sidecar to assets/sprites/ui/title_covers_kitsune/<state id>.png,
where PowerState.cover_path() picks it up for the title screen, character
select and pause menu. Existing UIDs are kept across re-runs.

    python3 tools/build_kitsune_title_covers.py            # dry run
    python3 tools/build_kitsune_title_covers.py --apply
"""
import hashlib
import re
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_kitsune_character import IMPORT_TEMPLATE, Uids  # noqa: E402

GAME = Path(__file__).resolve().parent.parent
MASTERS = Path("/home/emanzi/Godot/KatanaKitsune_WIP/KatanaKitsune-Isometric-/assets/sprites/ui/title_variants")
OUT_DIR = GAME / "assets/sprites/ui/title_covers_kitsune"
OUT_RES = "res://assets/sprites/ui/title_covers_kitsune"
POWER_STATE_GD = GAME / "scripts/system/PowerState.gd"
SIZE = (768, 432)


def state_ids() -> list:
    text = POWER_STATE_GD.read_text()
    ids = re.findall(r'\{"id": "(\d\d_[A-Za-z_]+)"', text)
    if len(ids) != 12:
        raise SystemExit(f"expected 12 states in PowerState.gd, found {len(ids)}")
    return ids


def master_for(state: str) -> Path:
    """01_Wood_JadeDragon -> 01_wood_jade_dragon.png (snake-cased master)."""
    number, element, name = state.split("_", 2)
    name = re.sub(r"(?<!^)(?=[A-Z])", "_", name).lower()
    path = MASTERS / f"{number}_{element.lower()}_{name}.png"
    if not path.exists():
        raise SystemExit(f"missing master {path}")
    return path


def import_sidecar(png: Path, res: str, uids: Uids) -> None:
    sidecar = png.parent / (png.name + ".import")
    uid = None
    if sidecar.exists():
        m = re.search(r'^uid="(uid://[a-z0-9]+)"', sidecar.read_text(), re.M)
        uid = m.group(1) if m else None
    md5 = hashlib.md5(res.encode()).hexdigest()
    sidecar.write_text(IMPORT_TEMPLATE.format(uid=uid or uids.new(), name=png.name, md5=md5, res=res))


def main() -> None:
    apply = "--apply" in sys.argv
    uids = Uids()
    for state in state_ids():
        src = master_for(state)
        dst = OUT_DIR / f"{state}.png"
        print(f"{src.name} -> {dst.relative_to(GAME)}")
        if apply:
            dst.parent.mkdir(parents=True, exist_ok=True)
            Image.open(src).convert("RGB").resize(SIZE, Image.LANCZOS).save(dst, "PNG", optimize=True)
            import_sidecar(dst, f"{OUT_RES}/{state}.png", uids)
    print("APPLIED" if apply else "DRY RUN - re-run with --apply")


if __name__ == "__main__":
    main()
