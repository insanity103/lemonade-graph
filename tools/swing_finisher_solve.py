#!/usr/bin/env python3
"""Solve the FINISHER (hit 5 of the M1 chain) from a posture-and-target spec.

The finisher is a two-handed OVERHEAD GROUND SLAM, and it is the BIGGEST POSE IN THE CHAIN on
every number the check tool prints -- which is the whole reason it exists. Four blind critics
running said the opposite of the versions before it ("our finisher is the SMALLEST pose in the
chain - escalation is carried by the damage number instead of by the body"), so this is not a
matter of taste: hit 5 has to measure bigger than hit 1, not merely differently.

The move. The blade is drawn out right and UP and BACK over the trailing shoulder until the tip
is nearly six studs above the root and four behind the spine -- higher and further back than
anything else in the chain reaches -- while the body stands to its FULL HEIGHT on a straight
back leg with the pelvis counter-rotated away from the target, the front foot light, and the
gaze held on the target over the leading shoulder. It is HELD there for 160 ms: the telegraph,
and the only still frame in the chain. Then the hips fire 55 degrees in 45 ms, the blade comes
over the top and down the centreline in one 80 ms pass (against 150-190 ms for hits 1-4, so
contact is a two-frame smear) and drives into the floor, and the WHOLE BODY goes with it -- the
front foot is thrown three studs forward into a lunge, the pelvis falls nearly a stud and drives
a stud forward, and the finisher HOLDS that plant for 550 ms, longer than any other hit's entire
clip, so what the chain leaves on screen is the slam and not a character back at guard.

Like tools/swing_stance_resolve.py this authors nothing by hand that a camera can see wrong.
Each key states:
  * `s`, a place on hit 1's solved arm circle, which fixes the arm's radius and the wrist;
  * `tip` and `blade`, WHERE THE BLADE SHOULD POINT from the shoulder and which way the blade
    should lie, as unit directions in character space (+X right, +Y up, -Z forward). The
    shoulder tilt `q` is the bounded least-squares solution that puts the REAL blade (real grip:
    out of the FRONT of the fist, down the hand's -Z) there. The arm's own radius at `s` is
    kept, so every target is reachable by construction;
  * `lfoot` / `rfoot` / `root` / `rooty`, the stance -- where each foot is in character space
    and where the pelvis sits over them. The eight leg angles come out of the same foot solve
    hits 2-4 use (swing_stance_resolve.solve_legs), because authoring leg DEGREES against a
    yawing pelvis does not produce a stance anyone can see (that module's header explains why).

The blade's ROLL about its own axis -- which edge leads the cut -- is a separate pass,
tools/swing_edge_resolve.py, run after this one.

Usage:  python3 tools/swing_finisher_solve.py [--write]
        --write rewrites hit 5's key lines in ReplicatedStorage/SwingChain.luau in place;
        without it the lines are printed for inspection.
Then:   python3 tools/swing_chain_check.py
"""

import math
import os
import re
import sys

import numpy as np
from scipy.optimize import least_squares

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import swing_chain_check as scc  # noqa: E402
import swing_stance_resolve as ssr  # noqa: E402

FLOOR = -3.00
W_DIR = 0.6
W_Q = 0.002


def unit(v):
    v = np.asarray(v, dtype=float)
    return v / np.linalg.norm(v)


# t, s, the stance (root {x, z} + rooty + the two feet in character space), chest / head / larm
# in degrees, ease, and the blade's target (tip direction from the shoulder, blade axis).
# `tip`/`blade` None: the key is authored, not solved -- q is given in `q`. `stick` is the weight
# pulling q toward the previous key's, per degree: the HELD keys use a strong one so the tilt
# cannot swap to a different solution with the same tip, which would twirl the blade mid-hold.
KEYS = [
    # 0: what hit 4 leaves the body in at the frame hit 5 is allowed (its 240 ms key): the chop
    # spent, blade low in front, the body folded over it in hit 4's square two-footed brace.
    dict(t=0.00, s=0.30, rot=[-9.071, 1.362, 0], q=[-31.833, 6.671, 1.052], root=[-0.03, -0.22], rooty=-0.508,
         lfoot=[-1.05, -3.00, -0.30], rfoot=[1.05, -3.00, -0.32],
         chest=[-18.239, -17.581, -8.187], head=[-6, 2, 0], larm=[-2, 10, -16, 34, 2],
         ease="OutQuad", tip=None, blade=None),
    # 1: the blade is swept OUT to the right and starts to climb, and the weight rocks BACK onto
    # the right foot. Three keys carry the draw instead of one: a single key put 11 studs of tip
    # into 100 ms, which made the anticipation the fastest frame in the clip -- an anticipation
    # that outruns its own strike reads as a second swing, not as a load.
    dict(t=0.07, s=0.33, rot=[2, -14, 0], root=[0.04, 0.06], rooty=-0.40,
         lfoot=[-0.70, -3.00, -0.60], rfoot=[0.80, -3.00, 0.55],
         chest=[-4, -10, 10], head=[-2, 18, -1], larm=[-14, 18, -26, 48, 4], ease="InOutQuad",
         tip=[0.86, 0.15, -0.49], blade=[0.80, 0.20, -0.57]),
    # 2: climbing past the right shoulder, and the body is STANDING UP under it -- the pelvis
    # climbs 0.18 studs here and another 0.10 into the coil, so the fall that follows is a fall
    # from full height rather than a squat that was already there. The front foot goes light.
    dict(t=0.14, s=0.32, rot=[8, -31, 0], root=[0.08, 0.20], rooty=-0.22,
         lfoot=[-0.62, -2.88, -0.95], rfoot=[0.85, -3.00, 0.85],
         chest=[6, -13, 18], head=[-4, 34, -2], larm=[-30, 8, -30, 62, 7], ease="OutQuad",
         tip=[0.55, 0.66, 0.51], blade=[0.50, 0.60, 0.62]),
    # 3: THE COIL, and the biggest silhouette in the chain. The tip stands 5.9 studs above the
    # root and 4.2 behind the spine, the pelvis is counter-rotated 43 degrees away from the
    # target on a straight back leg, the chest is rolled 22 onto its right so the shoulder line
    # is steeply off horizontal under the cocked blade, the front foot is 2.0 studs ahead and
    # LIFTED off the floor, and the body is at its full height -- the tallest pelvis anywhere in
    # the chain. The gaze stays on the target over the leading shoulder.
    dict(t=0.20, s=0.56, rot=[14, -43, 0], root=[0.10, 0.44], rooty=-0.12,
         lfoot=[-0.60, -2.72, -1.00], rfoot=[0.90, -3.00, 1.00],
         chest=[14, -14, 22], head=[-8, 48, -3], larm=[-46, -2, -33, 78, 9], ease="OutQuad",
         tip=[0.16, 0.80, 0.58], blade=[0.14, 0.74, 0.66]),
    # 4: HELD, 160 ms, the release frame, and the only still frame in the chain -- the rhythm
    # break the last four rounds of critics asked for, shown by the BODY. The coil creeps a
    # degree deeper and sinks 0.04 studs across the hold: dead still to the eye, loaded rather
    # than frozen. "Swing" fires here.
    dict(t=0.36, s=0.56, rot=[15, -45, 0], root=[0.11, 0.45], rooty=-0.16,
         lfoot=[-0.60, -2.76, -1.00], rfoot=[0.90, -3.00, 1.02],
         chest=[15, -15, 23], head=[-8, 50, -3], larm=[-48, -2, -34, 80, 9], ease="InQuart",
         tip=[0.15, 0.81, 0.57], blade=[0.13, 0.75, 0.65], stick=0.15),
    # 5: THE HIPS FIRE. 57 degrees of pelvis in 45 ms with the chest still 25 behind them: the
    # pelvis leads and the hands are dragged over the top after it. The blade is coming down and
    # the front leg is already thrown forward, in the air, hunting for the plant.
    dict(t=0.405, s=0.42, rot=[-2, 14, 0], root=[0.06, 0.04], rooty=-0.30,
         lfoot=[-0.66, -2.62, -1.45], rfoot=[0.85, -3.00, 0.95],
         chest=[-8, -26, 10], head=[0, 12, 0], larm=[-30, 0, -27, 64, 7], ease="Linear",
         tip=[0.08, 0.72, -0.69], blade=[0.04, 0.62, -0.78]),
    # 6: CONTACT, 80 ms after the release -- against 150-190 ms for hits 1-4's passes, so the
    # pass through the target is one smeared frame. The blade is driven down the centreline at
    # the furthest reach in the chain, the chest is folded 24 degrees over it, and the FRONT FOOT
    # HAS LANDED three studs in front of the back one: the deepest, widest stance in the chain,
    # arrived at in 35 ms.
    dict(t=0.44, s=0.252, rot=[-16, 4, 0], root=[-0.05, -0.70], rooty=-0.78,
         lfoot=[-0.70, -3.00, -2.10], rfoot=[0.80, -3.00, 0.75],
         chest=[-26, -6, -6], head=[6, -2, 0], larm=[-6, -4, -18, 34, 2], ease="Linear",
         tip=[-0.14, -0.24, -0.94], blade=[0.02, -0.88, -0.47]),
    # 7: OVERSHOOT, the tip still driving at the floor, the body still falling.
    dict(t=0.46, s=0.29, rot=[-20, 2, 0], root=[-0.05, -0.85], rooty=-0.90,
         lfoot=[-0.70, -3.00, -2.20], rfoot=[0.80, -3.00, 0.70],
         chest=[-30, -2, -8], head=[2, 0, 0], larm=[2, -6, -14, 26, 1], ease="OutQuad",
         tip=[-0.12, -0.62, -0.78], blade=[-0.02, -0.95, -0.31]),
    # 8: ArcEnd. The tip reaches the FLOOR. The slam's ground burst is lit on this marker.
    dict(t=0.48, s=0.31, rot=[-19, 2, 0], root=[-0.05, -0.95], rooty=-1.00,
         lfoot=[-0.70, -3.00, -2.25], rfoot=[0.80, -3.00, 0.65],
         chest=[-28, 2, -8], head=[-2, 2, 0], larm=[4, -8, -12, 24, 1], ease="OutQuad",
         tip=[-0.08, -0.83, -0.55], tipy=-2.92, stick=0.03),
    # 9: THE PLANT (570 ms). The lowest the body gets anywhere in the chain -- the pelvis has
    # fallen 0.96 studs from the coil and driven 1.40 forward -- braced over a blade stood in
    # the ground, front foot three studs ahead of the back one. This is the pose the finisher
    # is LEFT in. It is not a guard.
    dict(t=0.57, s=0.31, rot=[-16, 7, 0], root=[-0.05, -1.02], rooty=-1.08,
         lfoot=[-0.72, -3.00, -2.30], rfoot=[0.82, -3.00, 0.62],
         chest=[-22, 8, -8], head=[-6, 8, 0], larm=[8, -10, -10, 22, 0], ease="OutQuad",
         tip=[-0.06, -0.86, -0.51], tipy=-2.98, stick=0.03),
    # 10: held low, the recoil absorbed, settling a hair further.
    dict(t=0.77, s=0.31, rot=[-15, 9, 0], root=[-0.05, -1.00], rooty=-1.06,
         lfoot=[-0.72, -3.00, -2.28], rfoot=[0.82, -3.00, 0.62],
         chest=[-21, 9, -8], head=[-6, 8, 0], larm=[8, -10, -10, 22, 0], ease="InOutQuad",
         tip=[-0.06, -0.85, -0.52], tipy=-2.98, stick=0.03),
    # 11: STILL PLANTED at 1.03 s. The finisher holds its plant for 550 ms -- longer than any
    # other hit's whole clip -- so what the chain leaves on screen is the slam and not a
    # character back at guard. Only a player who does not swing again sees past this.
    dict(t=1.03, s=0.31, rot=[-14, 10, 0], root=[-0.05, -0.98], rooty=-1.04,
         lfoot=[-0.72, -3.00, -2.26], rfoot=[0.82, -3.00, 0.62],
         chest=[-20, 10, -8], head=[-6, 8, 0], larm=[7, -9, -10, 22, 0], ease="InOutQuad",
         tip=[-0.06, -0.84, -0.53], tipy=-2.98, stick=0.03),
    # 12: rising, half way back up and half way back over the feet.
    dict(t=1.18, s=0.56, rot=[-8, 5, 0], q="half", root=[-0.04, -0.50], rooty=-0.50,
         lfoot=[-0.62, -3.00, -1.30], rfoot=[0.68, -3.00, 0.45],
         chest=[-9, 5, -4], head=[-1, 4, 0], larm=[3, -5, -7, 16, 0], ease="InOutQuad",
         tip=None, blade=None),
    # 13: guard, hit 1's own T_END pose with no tilt (what Sword Guard Hold and hit 1 start from).
    dict(t=1.31, s=0.66, rot=[0.314, 2.125, 0], q=[0.0, 0.0, 8.466], root=[-0.02, 0.0], rooty=-0.147,
         lfoot=[-0.55, -3.00, -0.15], rfoot=[0.55, -3.00, -0.15],
         chest=[0.521, -0.032, -4.158], head=[0, -6, 0], larm=[0, 0, -5, 12, 0],
         ease="InOutQuad", tip=None, blade=None),
]


def pose_for(key, q, arm):
    spec = dict(key)
    spec["q"] = list(q)
    keys, _ = scc.build_hit({"keys": [spec]}, arm, {})
    return keys[key["t"]]


def blade_of(pose):
    guard, tip = scc.blade_points(pose)
    d = tip - guard
    return tip, d / np.linalg.norm(d)


def main():
    write = "--write" in sys.argv
    arm, _ = scc.read_hit1()
    out = []
    prev_q = np.array([0.0, 0.0, 0.0])
    solved = {}
    seed = None
    for key in KEYS:
        key = dict(key)
        root_rot = scc.angles(*[math.radians(v) for v in key["rot"]])
        legs, root_y, ferr, seed = ssr.solve_legs(key["root"], root_rot, key["lfoot"], key["rfoot"],
                                                  seed, key.get("rooty"))
        key["legs"] = legs
        key["root"] = [key["root"][0], root_y, key["root"][1]] + list(key["rot"])

        if key["tip"] is None:
            q = 0.5 * solved[1.03] if key.get("q") == "half" else np.array(key["q"], dtype=float)
        else:
            # radius from the arm at s, direction from the spec: reachable by construction
            base = pose_for(key, [0, 0, 0], arm)
            sh = scc.shoulder(base)
            tip0, _ = blade_of(base)
            reach = float(np.linalg.norm(tip0 - sh))
            direction = unit(key["tip"])
            if key.get("tipy") is not None:
                # An absolute tip HEIGHT, for the keys where the blade is in the ground: the
                # authored direction gives the bearing and the elevation is whatever puts the tip
                # ON the floor from wherever the shoulder has fallen to. Aiming those keys by
                # direction alone buried the tip 1.7 studs under the map, because the slam drops
                # the shoulder the better part of a stud while the blade still points down at it.
                b = max(-1.0, min(1.0, (key["tipy"] - sh[1]) / reach))
                flat = np.array([direction[0], 0.0, direction[2]])
                flat = flat / np.linalg.norm(flat) * math.sqrt(max(0.0, 1 - b * b))
                direction = np.array([flat[0], b, flat[2]])
            target_tip = sh + reach * direction
            # A blade stood in the ground lies along the line from the hand to the tip; only the
            # keys still in flight state an axis of their own.
            target_dir = unit(key["blade"]) if key.get("blade") else unit(target_tip - sh)

            def residual(q):
                pose = pose_for(key, q, arm)
                tip, d = blade_of(pose)
                return np.concatenate([tip - target_tip, W_DIR * (d - target_dir),
                                       key.get("stick", W_Q) * (q - prev_q)])

            best = None
            for init in (prev_q, np.zeros(3), np.array([40, 0, 0]), np.array([-40, 0, 0]),
                         np.array([0, 40, 0]), np.array([0, -40, 0]), np.array([0, 0, 40]),
                         np.array([0, 0, -40])):
                sol = least_squares(residual, init, bounds=(-175, 175))
                if best is None or sol.cost < best.cost:
                    best = sol
            q = best.x

        pose = pose_for(key, q, arm)
        tip, d = blade_of(pose)
        fl = scc.compose(pose, scc.LEG_CHAIN_L).p
        fr = scc.compose(pose, scc.LEG_CHAIN_R).p
        print("t %4.0f  tip (%5.2f %5.2f %5.2f)  foot err %.3f  root y %6.3f  L(%5.2f %5.2f %5.2f)"
              "  R(%5.2f %5.2f %5.2f)  stagger %+5.2f"
              % (key["t"] * 1000, *tip, ferr, key["root"][1], *fl, *fr, fr[2] - fl[2]), file=sys.stderr)
        solved[key["t"]] = np.array(q, dtype=float)
        prev_q = np.array(q, dtype=float)
        fmt = lambda xs: ", ".join(("%g" % round(float(v), 3)) for v in xs)
        out.append((key, "{ t = %g, s = %g, q = {%s}, root = {%s}, chest = {%s}, head = {%s},"
                         " larm = {%s}, legs = {%s}, ease = \"%s\" }," %
                    (key["t"], key["s"], ", ".join("%.3f" % float(v) for v in q), fmt(key["root"]),
                     fmt(key["chest"]), fmt(key["head"]), fmt(key["larm"]), fmt(key["legs"]),
                     key["ease"])))

    if not write:
        print("\n".join("\t\t\t\t" + line for _, line in out))
        return 0

    path = os.path.join(scc.GAME, "ReplicatedStorage", "SwingChain.luau")
    lines = open(path, encoding="utf-8").read().split("\n")
    # The finisher is the last hit in the table; rewrite its key lines by t, in order, from the
    # line its block starts on so no other hit can be matched by accident.
    start = next(i for i, l in enumerate(lines) if "Name = \"Finisher\"" in l)
    idx = start
    for key, line in out:
        pat = re.compile(r"^(\s*)\{ t = %g," % key["t"])
        while idx < len(lines) and not pat.match(lines[idx]):
            idx += 1
        if idx >= len(lines):
            sys.exit("could not find the finisher's key line for t=%s" % key["t"])
        lines[idx] = pat.match(lines[idx]).group(1) + line
        idx += 1
    open(path, "w", encoding="utf-8").write("\n".join(lines))
    print("hit 5 rewritten in SwingChain.luau")
    return 0


if __name__ == "__main__":
    sys.exit(main())
