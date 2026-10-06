#!/usr/bin/env python3
"""What to set PixelOver's Frequency to, so a clip exports as 8 frames.

    tools/fps.py 8.83          -> seconds
    tools/fps.py 245f          -> frames at 30fps
    tools/fps.py 245 -s 24     -> frames at another source rate
    tools/fps.py 8.83 2.33 1.71   -> several at once
    tools/fps.py               -> prompts, and keeps prompting

PixelOver has no frame-count field. It samples the clip at a rate, so the number
to enter is frames wanted divided by the clip's length in seconds. Everything
exports at 8 frames whatever its length, so the strips match Katana Kitsune's and
the game can treat every character alike.
"""
import sys

FRAMES = 8
## Meshy writes its clips at 30fps, so a length given in frames converts at that
## rate unless told otherwise.
SOURCE_FPS = 30.0


def seconds_of(text, source_fps):
    """A clip length, given either as seconds or as '245f' frames."""
    text = text.strip().lower().rstrip("s")
    if text.endswith("f"):
        return float(text[:-1]) / source_fps
    return float(text)


def report(text, source_fps):
    secs = seconds_of(text, source_fps)
    if secs <= 0:
        print("  %-12s length must be above zero" % text)
        return
    ## Rounded UP, to two decimals. PixelOver truncates length x rate rather
    ## than rounding it, so 1.7083 x 4.68 = 7.995 exports as SEVEN frames. The
    ## nearest-value rate is one frame short on any clip where the product lands
    ## just under an integer.
    import math
    fps = math.ceil((FRAMES / secs) * 100.0) / 100.0
    ## A whole export is 8 frames across 8 directions. If PixelOver's progress
    ## dialog shows anything other than 64, the rate did not take and it is
    ## rendering every source frame instead.
    got = int(secs * fps)
    print("  %-12s %6.2f s  ->  Frequency %6.2f   gives %d frames%s"
          % (text, secs, fps, got, "" if got == FRAMES else "   <-- CHECK"))


def main():
    args = [a for a in sys.argv[1:]]
    source_fps = SOURCE_FPS
    if "-s" in args:
        i = args.index("-s")
        source_fps = float(args[i + 1])
        del args[i:i + 2]

    if args:
        for a in args:
            report(a, source_fps)
        return

    print("Clip length in seconds (8.83) or frames (245f). Blank line to stop.")
    while True:
        try:
            line = input("> ").strip()
        except EOFError:
            break
        if not line:
            break
        for part in line.replace(",", " ").split():
            try:
                report(part, source_fps)
            except ValueError:
                print("  %-12s not a number" % part)


main()
