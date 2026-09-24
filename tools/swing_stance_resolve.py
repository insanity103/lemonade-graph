#!/usr/bin/env python3
"""Give hits 2-4 of the M1 chain a STANCE of their own, without moving their blades.

Why this exists. Four blind critics in a row said the same thing about the chain: "across all
six hits the hips, shoulders and feet NEVER CHANGE STANCE - only the right arm moves, so the
chain reads as one animation retriggered." The measurement agreed. tools/swing_chain_check.py
prints, per key, where each foot actually is; before this tool the two feet of every hit sat
within about half a stud of each other in every direction, in every key, and all of that came
from the pelvis YAW swinging both legs round together. The two upper-leg pitches were within a
few degrees of each other everywhere, so there was no lead foot in the chain at all, in any hit,
at any moment. An R15 stands with its feet 1.0 stud apart; a stance a camera can read is a
stagger or a spread of one and a half to three studs, and it has to point a different way per
hit or the hits look alike however different their blades are.

WHY THE FIRST ATTEMPT AT THIS FAILED, because it is the trap here. Joint rotations are in the
joint's own frame, and LowerTorso is the root: when the pelvis is yawed 74 degrees (hit 2's
coil is), "pitch the leg forward" swings that leg 74 degrees off the character's forward line,
and a hand-authored 30 degrees of lead-foot pitch arrives on camera as a foot out to the side.
Authoring leg DEGREES against a yawing pelvis cannot produce a stance you can see. So this
tool authors WHERE THE FEET ARE, in character space -- the thing the lens sees -- and solves
the eight leg angles and the root height that put them there, against whatever the pelvis is
doing. `solve_legs` below is that solve, and tools/swing_finisher_solve.py uses it too.

What this rewrites, and what it deliberately does not. Only the legs and the root translation
of hits 2-4. Every key's shoulder tilt `q` is then RE-SOLVED so the blade ends up exactly where
it already was: the same direction from the shoulder and the same blade axis, in character
space, at the arm's own radius. So every tip position, plane angle, contact frame and derived
hitbox survives the stance change untouched -- which is the point, because hits 2-4's blade
geometry was solved for the real grip (the sword runs out of the FRONT of the fist, down the
hand's -Z; see the header of Sword Attack Animation.luau) and is not being re-litigated here.
The wrist keys are never touched: `q` is a rotation at the SHOULDER, and the hand comes from
hit 1. The blade's ROLL about its own axis -- which edge leads -- is a separate pass,
tools/swing_edge_resolve.py, run after this one.

Root height is not authored either: it is whatever the foot solve puts it at, so a deeper
stance drops the pelvis by exactly as much as the legs have to fold to reach.

Usage:  python3 tools/swing_stance_resolve.py [--dry]
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

CHAIN_PATH = os.path.join(scc.GAME, "ReplicatedStorage", "SwingChain.luau")

FLOOR = -3.00
W_DIR = 0.6      # blade-axis error, per unit vector
W_STICK = 0.004  # pull toward the previous key's tilt, per degree: pins the roll about the
                 # shoulder-to-tip line, which the tip alone does not fix, and stops two
                 # neighbouring keys reaching the same blade by opposite routes.

# ── The stances ─────────────────────────────────────────────────────────────────────────
#
# Per key: root is {x, z} of the pelvis over the feet (y comes out of the foot solve), and
# lfoot / rfoot are where that foot is in CHARACTER space -- +X the character's right, +Y up,
# -Z forward, floor at -3.00. A foot above -3.00 is deliberately off the ground.
#
#   HIT 2  BACKHAND -- a RIGHT-LEAD PIVOT STEP. It coils over a planted LEFT foot with the
#          right leg peeled back and its heel up behind, swings that leg through, and PLANTS
#          THE RIGHT FOOT A STUD AND A HALF IN FRONT of the left under the cut. The opposite
#          lead foot to hit 1, arrived at by a step the camera can watch happen: the right foot
#          travels 3.2 studs between the held coil and contact.
#   HIT 3  RISING -- a WIDE SQUARE BASE that then EXTENDS. Out of hit 2's lunge both feet come
#          level and go WIDE -- 3.1 studs apart across the body, the widest base in the chain,
#          with the pelvis sunk under it -- and then both legs drive and the whole body stands
#          UP under the rising cut, the feet staying planted while the root climbs. Square
#          throughout: hit 3 is told apart from its neighbours by WIDTH and HEIGHT, not by a
#          lead foot, which is what stops it reading as another version of hit 2.
#   HIT 4  OVERHEAD -- FEET TOGETHER, THEN DROPPED. The feet gather to 0.8 studs apart and the
#          legs straighten for the lift (the tallest pelvis in the first four hits), then the
#          chop spreads them to 2.5 and the pelvis FALLS 0.35 studs with the blade into a square
#          brace. The only hit in the chain with no lead foot at all, on purpose: that is what
#          makes it read as a drop rather than a turn.
STANCE = {
    2: {
        0.0:   dict(root=[-0.20, -0.30], rooty=-0.30, lfoot=[-0.60, -3.00, -0.80], rfoot=[0.55, -3.00, 0.35]),
        0.055: dict(root=[-0.34, -0.16], rooty=-0.45, lfoot=[-0.62, -3.00, -0.90], rfoot=[0.90, -2.72, 0.70]),
        0.105: dict(root=[-0.38, -0.08], rooty=-0.50, lfoot=[-0.64, -3.00, -0.95], rfoot=[0.95, -2.68, 0.70]),
        0.135: dict(root=[-0.30, -0.06], rooty=-0.45, lfoot=[-0.64, -3.00, -0.95], rfoot=[1.00, -2.55, 0.35]),
        0.175: dict(root=[-0.10, -0.22], rooty=-0.25, lfoot=[-0.62, -3.00, -0.90], rfoot=[0.85, -2.42, -0.55]),
        0.232: dict(root=[0.16, -0.56], rooty=-0.62, lfoot=[-0.57, -3.00, -0.30], rfoot=[0.72, -3.00, -1.85]),
        0.275: dict(root=[0.24, -0.66], rooty=-0.72, lfoot=[-0.54, -3.00, -0.15], rfoot=[0.74, -3.00, -2.00]),
        0.33:  dict(root=[0.26, -0.62], rooty=-0.70, lfoot=[-0.54, -3.00, -0.15], rfoot=[0.74, -3.00, -1.95]),
        0.39:  dict(root=[0.18, -0.44], rooty=-0.52, lfoot=[-0.55, -3.00, -0.25], rfoot=[0.70, -3.00, -1.60]),
        0.43:  dict(root=[0.10, -0.24], rooty=-0.36, lfoot=[-0.55, -3.00, -0.30], rfoot=[0.64, -3.00, -1.10]),
        0.48:  dict(root=[0.02, -0.06], rooty=-0.18, lfoot=[-0.55, -3.00, -0.28], rfoot=[0.58, -3.00, -0.55]),
    },
    3: {
        # t=0 repeats hit 2's ArcEnd stance: the chain hands the feet on.
        0.0:   dict(root=[0.26, -0.62], rooty=-0.70, lfoot=[-0.54, -3.00, -0.15], rfoot=[0.74, -3.00, -1.95]),
        0.05:  dict(root=[0.10, -0.55], rooty=-0.58, lfoot=[-1.05, -3.00, -0.35], rfoot=[1.05, -3.00, -1.30]),
        0.1:   dict(root=[0.00, -0.50], rooty=-0.85, lfoot=[-1.50, -3.00, -0.45], rfoot=[1.50, -3.00, -0.85]),
        0.128: dict(root=[0.00, -0.44], rooty=-0.70, lfoot=[-1.42, -3.00, -0.45], rfoot=[1.42, -3.00, -0.80]),
        0.16:  dict(root=[-0.04, -0.36], rooty=-0.45, lfoot=[-1.15, -3.00, -0.40], rfoot=[1.15, -3.00, -0.65]),
        0.2:   dict(root=[-0.08, -0.30], rooty=-0.16, lfoot=[-0.62, -3.00, -0.35], rfoot=[0.62, -3.00, -0.50]),
        0.245: dict(root=[-0.12, -0.26], rooty=-0.15, lfoot=[-0.56, -3.00, -0.30], rfoot=[0.56, -3.00, -0.42]),
        0.32:  dict(root=[-0.14, -0.22], rooty=-0.15, lfoot=[-0.52, -3.00, -0.25], rfoot=[0.52, -3.00, -0.35]),
        0.38:  dict(root=[-0.10, -0.18], rooty=-0.18, lfoot=[-0.52, -3.00, -0.35], rfoot=[0.52, -3.00, -0.20]),
        0.425: dict(root=[-0.06, -0.10], rooty=-0.20, lfoot=[-0.54, -3.00, -0.50], rfoot=[0.54, -3.00, 0.05]),
        0.47:  dict(root=[-0.02, -0.04], rooty=-0.18, lfoot=[-0.55, -3.00, -0.60], rfoot=[0.55, -3.00, 0.25]),
    },
    4: {
        # t=0 repeats hit 3's ArcEnd stance.
        0.0:   dict(root=[-0.14, -0.22], rooty=-0.15, lfoot=[-0.52, -3.00, -0.25], rfoot=[0.52, -3.00, -0.35]),
        0.06:  dict(root=[-0.08, -0.06], rooty=-0.16, lfoot=[-0.44, -3.00, -0.20], rfoot=[0.44, -3.00, -0.25]),
        0.1:   dict(root=[-0.02, 0.06], rooty=-0.15, lfoot=[-0.40, -3.00, -0.15], rfoot=[0.40, -3.00, -0.18]),
        0.13:  dict(root=[0.00, 0.10], rooty=-0.15, lfoot=[-0.38, -3.00, -0.12], rfoot=[0.38, -3.00, -0.15]),
        0.152: dict(root=[0.00, 0.06], rooty=-0.15, lfoot=[-0.38, -3.00, -0.12], rfoot=[0.38, -3.00, -0.15]),
        0.182: dict(root=[-0.02, -0.14], rooty=-0.34, lfoot=[-0.80, -3.00, -0.25], rfoot=[0.80, -3.00, -0.28]),
        0.24:  dict(root=[-0.03, -0.22], rooty=-0.58, lfoot=[-1.05, -3.00, -0.30], rfoot=[1.05, -3.00, -0.32]),
        0.3:   dict(root=[-0.04, -0.26], rooty=-0.78, lfoot=[-1.30, -3.00, -0.32], rfoot=[1.30, -3.00, -0.34]),
        0.36:  dict(root=[-0.04, -0.24], rooty=-0.72, lfoot=[-1.25, -3.00, -0.32], rfoot=[1.25, -3.00, -0.34]),
        0.42:  dict(root=[-0.03, -0.18], rooty=-0.50, lfoot=[-1.00, -3.00, -0.28], rfoot=[1.00, -3.00, -0.30]),
        0.47:  dict(root=[-0.02, -0.10], rooty=-0.30, lfoot=[-0.75, -3.00, -0.22], rfoot=[0.75, -3.00, -0.24]),
        0.52:  dict(root=[-0.01, -0.04], rooty=-0.16, lfoot=[-0.56, -3.00, -0.18], rfoot=[0.56, -3.00, -0.20]),
    },
}


def unit(v):
    v = np.asarray(v, dtype=float)
    return v / np.linalg.norm(v)


def pose_for(key, q, arm):
    spec = dict(key)
    spec["q"] = list(q)
    keys, _ = scc.build_hit({"keys": [spec]}, arm, {})
    return keys[key["t"]]


def blade_of(pose):
    guard, tip = scc.blade_points(pose)
    d = tip - guard
    return tip, d / np.linalg.norm(d)


# ── the foot solve ──────────────────────────────────────────────────────────────────────

# v = [RUp, RUyaw, RUroll, RKnee, LUp, LUyaw, LUroll, LKnee, root_y]
LEG_LO = np.array([-85, -35, -35, -135, -85, -35, -35, -135, -1.60])
LEG_HI = np.array([85, 35, 35, 0, 85, 35, 35, 0, 0.30])
LEG_SEED = np.array([0, 0, 0, -18, 0, 0, 0, -18, -0.15], dtype=float)


def solve_legs(root_xz, root_rot, lfoot, rfoot, seed=None, rooty=None):
    """The eight leg angles and the root height that put each foot at its target, given where
    the pelvis is and how it is turned. Returns (legs[8], root_y, worst foot error).

    Tiny weights pull the turnout (yaw/roll) toward zero and the knees toward a natural bend, so
    that of the many leg triples reaching a foot the solver picks the one a person would stand
    in rather than a splayed one. LowerTorso's own rotation is passed in and not solved: the
    hips are the swing's, the feet are the stance's."""

    def pose_of(v):
        return {
            "LowerTorso": scc.CF([root_xz[0], v[8], root_xz[1]], root_rot),
            "RightUpperLeg": scc.rot(v[0], v[1], v[2]),
            "RightLowerLeg": scc.rot(v[3], 0, 0),
            "LeftUpperLeg": scc.rot(v[4], v[5], v[6]),
            "LeftLowerLeg": scc.rot(v[7], 0, 0),
        }

    def residual(v):
        pose = pose_of(v)
        l = scc.compose(pose, scc.LEG_CHAIN_L).p
        r = scc.compose(pose, scc.LEG_CHAIN_R).p
        return np.concatenate([
            l - np.asarray(lfoot, float),
            r - np.asarray(rfoot, float),
            0.012 * np.array([v[1], v[2], v[5], v[6]]),          # prefer no turnout
            0.006 * np.array([v[3] + 14, v[7] + 14]),            # prefer a natural knee bend
            # A foot may be lifted, never sunk: when a target is out of the leg's reach the
            # fit would otherwise buy the shortfall by pushing the other foot through the floor.
            4.0 * np.array([max(0.0, FLOOR - l[1]), max(0.0, FLOOR - r[1])]),
            # Where the pelvis sits is half the pose -- the crouch and the rise are this number
            # -- so it is a target too, weighted hard enough to win against a foot half a stud
            # out of reach and soft enough that the feet still land where they are asked.
            np.array([0.0] if rooty is None else [2.5 * (v[8] - rooty)]),
        ])

    best = None
    starts = [LEG_SEED if seed is None else np.asarray(seed, float), LEG_SEED,
              LEG_SEED + np.array([25, 0, 0, -20, -25, 0, 0, -20, -0.2]),
              LEG_SEED + np.array([-25, 0, 0, -20, 25, 0, 0, -20, -0.2]),
              LEG_SEED + np.array([0, 0, 0, -50, 0, 0, 0, -50, -0.4])]
    for s in starts:
        sol = least_squares(residual, np.clip(s, LEG_LO, LEG_HI), bounds=(LEG_LO, LEG_HI))
        if best is None or sol.cost < best.cost:
            best = sol
    pose = pose_of(best.x)
    err = max(float(np.linalg.norm(scc.compose(pose, scc.LEG_CHAIN_L).p - np.asarray(lfoot, float))),
              float(np.linalg.norm(scc.compose(pose, scc.LEG_CHAIN_R).p - np.asarray(rfoot, float))))
    legs = [float(x) for x in best.x[:8]]
    return legs, float(best.x[8]), err, best.x


def nearest(table, t):
    if not table:
        return None
    best = min(table, key=lambda k: abs(k - t))
    return table[best] if abs(best - t) < 1e-6 else None


def main():
    dry = "--dry" in sys.argv
    arm, _ = scc.read_hit1()
    specs = scc.read_chain_spec()

    text = open(CHAIN_PATH, encoding="utf-8").read()
    lines = text.split("\n")
    key_line_re = re.compile(
        r"^(\s*)\{ t = (%s), s = (%s), q = \{[^}]*\}, root = \{[^}]*\}, chest = \{([^}]*)\}, "
        r"head = \{([^}]*)\}, larm = \{([^}]*)\}, legs = \{[^}]*\}, ease = \"(\w+)\"(.*)\},\s*$"
        % (scc.NUM, scc.NUM))

    worst_tip, worst_dir, worst_foot = 0.0, 0.0, 0.0
    line_idx = 0
    for hit_no, spec in enumerate(specs, start=2):
        table = STANCE.get(hit_no)
        print("== hit %d %s ==" % (hit_no, spec["name"]))
        prev_q, seed = None, None
        for key in spec["keys"]:
            override = nearest(table, key["t"])
            if override is None:
                line_idx = rewrite(lines, line_idx, key, key["q"], key["root"], key["legs"], key_line_re, dry)
                prev_q = np.array(key["q"], dtype=float)
                continue

            # Where this key's blade is TODAY: direction from the shoulder and blade axis, in
            # character space. That is the thing being preserved across the stance change.
            old = pose_for(key, key["q"], arm)
            old_sh = scc.shoulder(old)
            old_tip, old_dir = blade_of(old)
            tip_dir = unit(old_tip - old_sh)
            reach = float(np.linalg.norm(old_tip - old_sh))

            root_rot = scc.angles(*[math.radians(v) for v in key["root"][3:6]])
            legs, root_y, ferr, seed = solve_legs(override["root"], root_rot,
                                                  override["lfoot"], override["rfoot"], seed,
                                                  override.get("rooty"))
            worst_foot = max(worst_foot, ferr)

            new = dict(key)
            new["legs"] = legs
            new["root"] = [override["root"][0], root_y, override["root"][1]] + list(key["root"][3:6])

            start = np.array(key["q"], dtype=float) if prev_q is None else prev_q

            def residual(q):
                pose = pose_for(new, q, arm)
                tip, d = blade_of(pose)
                sh = scc.shoulder(pose)
                return np.concatenate([(tip - sh) - reach * tip_dir, W_DIR * (d - old_dir),
                                       W_STICK * (q - start)])

            best = None
            for init in (start, np.array(key["q"], dtype=float), start + np.array([25.0, 0, 0]),
                         start + np.array([-25.0, 0, 0]), start + np.array([0, 25.0, 0]),
                         start + np.array([0, -25.0, 0])):
                sol = least_squares(residual, init, bounds=(-175, 175))
                if best is None or sol.cost < best.cost:
                    best = sol
            q = best.x

            pose = pose_for(new, q, arm)
            tip, d = blade_of(pose)
            sh = scc.shoulder(pose)
            err = float(np.linalg.norm((tip - sh) - reach * tip_dir))
            ang = math.degrees(math.acos(max(-1.0, min(1.0, float(np.dot(d, old_dir))))))
            worst_tip, worst_dir = max(worst_tip, err), max(worst_dir, ang)
            fl = scc.compose(pose, scc.LEG_CHAIN_L).p
            fr = scc.compose(pose, scc.LEG_CHAIN_R).p
            print("   t %4.0f  tip err %.3f  blade off %2.0f deg  foot err %.3f  root y %6.3f"
                  "  L(%5.2f %5.2f %5.2f) R(%5.2f %5.2f %5.2f)  stagger %+5.2f  spread %4.2f"
                  % (key["t"] * 1000, err, ang, ferr, root_y, *fl, *fr, fr[2] - fl[2], fr[0] - fl[0]))
            line_idx = rewrite(lines, line_idx, key, q, new["root"], new["legs"], key_line_re, dry)
            prev_q = np.array(q, dtype=float)

    print("worst tip error %.3f studs, worst blade-axis error %.0f deg, worst foot error %.3f studs"
          % (worst_tip, worst_dir, worst_foot))
    if not dry:
        open(CHAIN_PATH, "w", encoding="utf-8").write("\n".join(lines))
        print("SwingChain.luau rewritten")
    return 0


def rewrite(lines, line_idx, key, q, root, legs, key_line_re, dry):
    while line_idx < len(lines):
        m = key_line_re.match(lines[line_idx])
        if m and abs(float(m.group(2)) - key["t"]) < 1e-9:
            num = lambda xs: ", ".join(("%g" % round(float(v), 3)) for v in xs)
            lines[line_idx] = ("%s{ t = %g, s = %g, q = {%s}, root = {%s}, chest = {%s}, head = {%s},"
                               " larm = {%s}, legs = {%s}, ease = \"%s\"%s},"
                               % (m.group(1), key["t"], key["s"],
                                  ", ".join("%.3f" % float(v) for v in q), num(root),
                                  m.group(4).strip(), m.group(5).strip(), m.group(6).strip(),
                                  num(legs), m.group(7), m.group(8)))
            return line_idx + 1
        line_idx += 1
    sys.exit("could not find the line for key t=%s" % key["t"])


if __name__ == "__main__":
    sys.exit(main())
