#!/usr/bin/env python3
"""Roll every swing's blade so the EDGE leads the cut, not the flat.

The bug, in the owner's words after watching a filmstrip: "the sword is swung with the flat side
out, that makes no sense." Measured, hit 1 was the worst case in the game -- on its contact
frame the component of the blade's sweep along the flat's normal was 0.99 and along the edge
0.12, which is a sword being used as a cricket bat. Hits 3 and 4 were 0.38 and 0.60.

Where it came from. Round 5 of the arc piece re-solved every wrist key for the real grip using
"the smallest rotation taking the hand's -Z to each key's designed blade direction". A
shortest-arc solve fixes where the blade POINTS and says nothing at all about the twist ABOUT
that axis -- that degree of freedom is free, and it landed wherever the shortest arc happened to
leave it. Nothing in the pipeline had ever constrained it, so nothing had ever been right except
by luck (the charged heavy was lucky at 1.00; hits 1, 3 and 4 were not).

WHICH AXIS IS THE EDGE. The player's sword is built by ServerScriptService/RuntimeBootstrap out
of parts welded down the Handle's -Z: Blade is Vector3.new(0.22, 0.60, 2.60) -- 2.60 long in Z,
0.60 across Y, 0.22 thick in X -- and its point is two WedgeParts at y = +/-0.15, one turned 180
degrees about Z, so the taper is in Y. The blade is a plate whose BROAD FACES look along +/-X
and whose two EDGES are at +/-Y. In handle space: blade axis -Z, EDGE NORMAL +/-Y, FLAT NORMAL
+/-X. RightGrip's C0 and Tool.Grip cancel, so those are the HAND's axes too, and the twist to
solve is a rotation of the hand about its own Z. (It is double-edged, so a roll and that roll
plus 180 degrees are the same sword; this takes whichever is nearer the previous key.)

The rule, per key: take the direction the BLADE AXIS is sweeping and roll the hand until the
edge lies along it. That target is applied in proportion to how fast the blade is actually
moving -- full weight from 2.2 studs of tip per rendered frame upward (the drive and the
follow-through, contact included), none below 0.8 (a windup, a held coil, a plant), and the roll
simply holds where it was in between -- and the last stretch of every clip ramps it back to zero
so the sword ends at the guard's carry angle (see `unwind`, and the flick that exists to stop).

TWO THINGS THAT HAD TO BE GOT RIGHT, each of which cost a solve that looked fine and was not:

  * The target is measured on a ROLL-FREE TWIN of the clip (swing_chain_check.strip_rolls), not
    on the clip itself. A roll cannot move the blade AT a key -- it is a rotation about the
    blade's own axis -- but the runtime SLERPS between keys, and a key's twist does bend the
    interpolated blade axis either side of it. Solved against the rolled clip the answer depends
    on itself: it oscillated between two answers 64 degrees apart, pass after pass, and settled
    at neither. Against the twin it is one pass, deterministic and idempotent.

  * Rolling the sword in the fist SWINGS THE HAND. The wrist joint sits a third of a stud off
    the blade's axis (RightHand's C1 is 0.175 up the forearm, the grip attachment another
    0.158), so the tip does move -- up to 0.6 studs on the keys carrying the biggest roll, which
    is why the contact tips in the check's report shifted when this first ran. That is the sword
    being HELD differently, not the swing being changed, and it is unavoidable: the blade is
    welded to the hand.

Hit 1 has no `roll` column -- it is the clip every other swing borrows its arm from (SwingChain
and SwingHeavy both read it through `armAt`), so its roll is baked into its own RightHand keys
and read back out of them with `split_roll`, which is what makes this idempotent on hit 1 too.
Everything else carries a `roll` column holding only what it adds ON TOP of the arm it borrows.
That is why hit 1 is solved FIRST and re-read by the other two.

Usage:  python3 tools/swing_edge_resolve.py [--dry]
Then:   python3 tools/swing_chain_check.py   (its report prints the edge normal on every contact
        frame, and the worst edge alignment over every key where the blade is cutting)
"""

import math
import os
import re
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import swing_chain_check as scc  # noqa: E402

split_roll, with_roll = scc.split_roll, scc.with_roll

BASE_PATH = os.path.join(scc.ANIMS, "Sword Attack Animation.luau")
CHAIN_PATH = os.path.join(scc.GAME, "ReplicatedStorage", "SwingChain.luau")
HEAVY_PATH = os.path.join(scc.GAME, "ReplicatedStorage", "SwingHeavy.luau")

SPEED_LO, SPEED_HI = 0.8, 2.2   # studs of tip per rendered frame at 60 fps
FRAME = 1.0 / 60.0


def euler_xyz(m):
    """The (x, y, z) degrees such that CFrame.Angles(x, y, z) == m. Angles() is Rx*Ry*Rz."""
    y = math.asin(max(-1.0, min(1.0, m[0, 2])))
    if abs(m[0, 2]) < 0.9999:
        x = math.atan2(-m[1, 2], m[2, 2])
        z = math.atan2(-m[0, 1], m[0, 0])
    else:                                   # gimbal lock: fold the roll into x
        x = math.atan2(m[2, 1], m[1, 1])
        z = 0.0
    return [math.degrees(v) for v in (x, y, z)]


def edge_roll(ref, easing, t, prev):
    """The ABSOLUTE roll this key should end up at, in degrees, measured on the roll-free twin
    `ref`. Returns (roll, speed, weight); a weight of None means the blade is turning about its
    own line here and has no direction to lead with, so the roll just carries."""
    h = scc.handle_cf(scc.sample(ref, easing, t))
    flat, edge, axis = h.r[:, 0], h.r[:, 1], -h.r[:, 2]

    times = sorted(ref)
    lo, hi = max(times[0], t - FRAME / 2), min(times[-1], t + FRAME / 2)
    a = scc.blade_points(scc.sample(ref, easing, lo))[1]
    b = scc.blade_points(scc.sample(ref, easing, hi))[1]
    speed = float(np.linalg.norm(b - a)) * FRAME / max(hi - lo, 1e-6)
    u = scc.sweep_dir(ref, easing, t, axis)
    if u is None:
        return prev, speed, None

    # Rolling by theta about the hand's Z takes the edge to -sin(theta)*flat + cos(theta)*edge.
    target = math.degrees(math.atan2(-float(np.dot(u, flat)), float(np.dot(u, edge))))
    while target - prev > 90:               # double-edged: the same sword, by the nearer route
        target -= 180
    while target - prev < -90:
        target += 180
    w = max(0.0, min(1.0, (speed - SPEED_LO) / (SPEED_HI - SPEED_LO)))
    return prev + w * (target - prev), speed, w


def unwind(rolls):
    """Bring the roll back to the guard's zero across the clip's return to guard.

    A cut leaves the sword turned in the hand; every clip in the game ends at the same pose --
    hit 1's T_END, which is what `Sword Guard Hold` holds and what the next swing fades in from
    -- and that pose carries no roll. Left to carry, hit 1 finished 131 degrees twisted out of
    guard and the sword FLICKED back to true at the end of every single M1, which is the one
    seam a player sees after every swing they ever throw.

    So the last stretch of each clip ramps the roll linearly, in time, to zero: the final two
    key segments, or three if two of them come to less than 120 ms (a 131-degree unwind inside
    65 ms is the same flick moved one key earlier). That stretch is the draw back in across the
    chest, so turning the sword back to its carry angle is what the hand is doing there anyway
    -- and in the finisher it is exactly the 280 ms rise off the plant, which is why the blade
    keeps its edge down through the whole 550 ms it stands in the ground."""
    n = len(rolls)
    if n < 3:
        return rolls
    k = 2
    while k + 1 < n and rolls[-1][0] - rolls[n - 1 - k][0] < 0.12:
        k += 1
    t0, r0 = rolls[n - 1 - k][0], rolls[n - 1 - k][1]
    t1 = rolls[-1][0]
    out = list(rolls[:n - k])
    for t, roll, speed, w in rolls[n - k:]:
        a = (t - t0) / (t1 - t0) if t1 > t0 else 1.0
        out.append((t, r0 * (1 - a), speed, w))
    return out


def solve(ref, easing, times, do_unwind=True, seed=0.0):
    prev, rolls = seed, []
    for t in times:
        roll, speed, w = edge_roll(ref, easing, t, prev)
        rolls.append((t, roll, speed, w))
        prev = roll
    return unwind(rolls) if do_unwind else rolls


def report(rolls):
    for t, roll, speed, w in rolls:
        print("   t %4.0f  %6.1f deg   tip %4.1f st/frame  weight %s"
              % (t * 1000, roll, speed, "-" if w is None else "%.2f" % w))


# ── hit 1: the roll is baked into its own wrist keys ────────────────────────────────────


def do_base(dry):
    keys, easing = scc.read_hit1()
    times = sorted(keys)
    rolls = solve(scc.strip_rolls(keys), easing, times)
    out = {t: roll for t, roll, _, _ in rolls}
    print("== hit 1 (baked into its RightHand keys) ==")
    report(rolls)

    lines = open(BASE_PATH, encoding="utf-8").read().split("\n")
    hand_re = re.compile(r'^(\s*\["RightHand"\]\s*=\s*)rot\(([^)]*)\),.*$')
    idx, n = 0, 0
    for t in times:
        while idx < len(lines) and not hand_re.match(lines[idx]):
            idx += 1
        if idx >= len(lines):
            sys.exit("ran out of RightHand keys in Sword Attack Animation.luau")
        m = hand_re.match(lines[idx])
        old = scc.angles(*[math.radians(float(v)) for v in m.group(2).split(",")])
        r = with_roll(split_roll(old)[0], out[t])
        lines[idx] = "%srot(%s),   -- blade roll %.1f deg (tools/swing_edge_resolve.py)" % (
            m.group(1), ", ".join("%.1f" % v for v in euler_xyz(r)), out[t])
        idx += 1
        n += 1
    if n != len(times):
        sys.exit("rewrote %d RightHand keys for %d timestamps" % (n, len(times)))
    if not dry:
        open(BASE_PATH, "w", encoding="utf-8").write("\n".join(lines))
        print("   Sword Attack Animation.luau: %d wrist keys rolled" % n)


# ── everything that borrows hit 1's arm: a `roll` column ────────────────────────────────


def column(keys, spec_keys, rolls):
    """What each key's `roll` has to be, given that the arm it borrows from hit 1 already turns
    the sword some amount of its own: the absolute roll wanted, minus the inherited one."""
    out = []
    for key, (t, roll, _, _) in zip(spec_keys, rolls):
        inherited = split_roll(keys[t]["RightHand"].r)[1] - key.get("roll", 0.0)
        out.append((t, roll - inherited))
    return out


def append_roll(path, blocks, dry):
    """blocks: [(a line substring marking where the block starts, [(t, roll), ...])]."""
    lines = open(path, encoding="utf-8").read().split("\n")
    for marker, rolls in blocks:
        idx = next(i for i, l in enumerate(lines) if marker in l)
        for t, roll in rolls:
            pat = re.compile(r'^(\s*\{ t = %g, s = .*ease = "\w+")(?:, roll = %s)?( \},)\s*$'
                             % (t, scc.NUM))
            while idx < len(lines) and not pat.match(lines[idx]):
                idx += 1
            if idx >= len(lines):
                sys.exit("could not find %s key t=%g in %s" % (marker, t, path))
            m = pat.match(lines[idx])
            lines[idx] = "%s, roll = %.1f%s" % (m.group(1), roll, m.group(2))
            idx += 1
    if not dry:
        open(path, "w", encoding="utf-8").write("\n".join(lines))


def endlag():
    """ComboConfig.ENDLAG: how long after hit N's input hit N+1 may be thrown, which is the
    moment hit N's clip is cut off and hit N+1 fades in over it."""
    path = os.path.join(scc.GAME, "ReplicatedStorage", "Config", "ComboConfig.luau")
    text = scc.strip_comments(open(path, encoding="utf-8").read())
    m = re.search(r"ENDLAG\s*=\s*\{([^}]*)\}", text)
    return [float(v) for v in m.group(1).replace(" ", "").split(",") if v]


def do_chain(dry):
    arm, arm_easing = scc.read_hit1()
    lag = endlag()
    blocks = []
    # Each hit is SEEDED with the roll the previous clip is carrying at the moment the chain
    # cuts to it. Without that every hit started from zero while the one before it was 90
    # degrees round, and the fade-in twisted the sword back to true at every link of the combo
    # -- the same flick `unwind` removes from the end of a clip, four more times.
    prev_clip, prev_easing = arm, arm_easing
    for hit_no, spec in enumerate(scc.read_chain_spec(), start=2):
        keys, easing = scc.build_hit(spec, arm, arm_easing)
        handover = scc.sample(prev_clip, prev_easing, lag[hit_no - 2])
        seed = split_roll(handover["RightHand"].r)[1]
        rolls = solve(scc.strip_rolls(keys), easing, [k["t"] for k in spec["keys"]], seed=seed)
        prev_clip, prev_easing = keys, easing
        print("== hit %d %s ==  (seeded at %.1f deg from hit %d at %.0f ms)"
              % (hit_no, spec["name"], seed, hit_no - 1, lag[hit_no - 2] * 1000))
        report(rolls)
        blocks.append(('Clip = "%s"' % spec["name"], column(keys, spec["keys"], rolls)))
    append_roll(CHAIN_PATH, blocks, dry)
    if not dry:
        print("   SwingChain.luau: roll written for hits 2-5")


def do_heavy(dry):
    arm, arm_easing = scc.read_hit1()
    blocks = []
    for name, spec_keys in scc.read_heavy_spec():
        keys, easing = scc.build_hit({"keys": spec_keys}, arm, arm_easing)
        # The CHARGE is not unwound: it LOOPS, and it never cuts -- nothing in it moves fast
        # enough to take a roll at all -- so ramping it to zero would only fight its own seam.
        rolls = solve(scc.strip_rolls(keys), easing, [k["t"] for k in spec_keys],
                      do_unwind=(name != "CHARGE"))
        print("== heavy %s ==" % name)
        report(rolls)
        blocks.append(("SwingHeavy.%s = {" % name, column(keys, spec_keys, rolls)))

    # Two seams SwingHeavy checks for itself, which the roll has to respect as well or it
    # reintroduces exactly the pop those checks exist to catch:
    #   * the charge LOOPS from 200 ms and its last key (620 ms) restates the 200 ms key, so
    #     their rolls have to be the same number or the sword flicks on every loop;
    #   * the strike's first key IS the charge's peak (470 ms), so a charge released at any
    #     moment hands the strike the wrist it already had.
    charge = dict(blocks[0][1])
    blocks[0] = (blocks[0][0], [(t, charge[0.2] if t == 0.62 else r) for t, r in blocks[0][1]])
    blocks[1] = (blocks[1][0], [(t, charge[0.47] if t == 0.0 else r) for t, r in blocks[1][1]])
    append_roll(HEAVY_PATH, blocks, dry)
    if not dry:
        print("   SwingHeavy.luau: roll written for the charge and the strike")


def main():
    # One pass each: every target is measured on a roll-free twin, so nothing here depends on
    # its own output. Hit 1 goes FIRST and is re-read by the other two, because they borrow its
    # arm and add their roll on top of whatever it ends up with.
    dry = "--dry" in sys.argv
    do_base(dry)
    do_chain(dry)
    do_heavy(dry)
    return 0


if __name__ == "__main__":
    sys.exit(main())
