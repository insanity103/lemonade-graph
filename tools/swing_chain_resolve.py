#!/usr/bin/env python3
"""Re-solve the shoulder tilt `q` of every key of hits 2-5 in ReplicatedStorage/SwingChain.luau.

Why this exists. Hits 2-5 read their right arm out of hit 1 (SwingChain.armAt) and steer it
with one rotation at the shoulder, `q`, that was solved to put the blade TIP where each key's
comment says. Those solves were made when the sword was believed to run up the hand's +Y. It
does not: RightGrip's C0 and Tool.Grip cancel and the blade runs out of the FRONT of the fist
(see the header of Sword Attack Animation.luau, round 5 of the arc piece). Hit 1's wrist keys
were re-solved for the real grip, and because hits 2-5 borrow hit 1's arm, their blade now
follows hit 1's real circle -- but every `q` was still compensating for the old, wrong blade,
so every contact landed 2.5-3 studs higher than designed and hit 2's level backhand had become
a rainbow over the head.

What this does. For each key of each chained hit it takes the tip and blade direction the key
was DESIGNED to have (computed from the pre-fix hit 1 clip under the pre-fix grip model, which
is what the original solver was aiming at), and finds the `q` that puts the REAL blade there:
a bounded least-squares over the three shoulder angles with the tip error weighted 1 per stud,
the blade-direction error 1 per unit vector (about 0.5 stud for 30 degrees) and a whisper of
pull toward the original `q` (0.005 per degree) to pin the one degree of freedom the tip does
not fix -- the roll about the shoulder-to-tip line. Everything else in the key (root, chest,
head, legs, s, timing) is untouched. Then it rewrites the `q = {...}` column in place.

Usage:  python3 tools/swing_chain_resolve.py <pre-fix "Sword Attack Animation.luau">
Then:   python3 tools/swing_chain_check.py     (the geometry report)
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

W_DIR = 1.0
W_Q = 0.005

# One deliberate change of target on top of the re-solve: the FINISHER is cocked HIGHER and
# follows through LOWER than it was designed. {hit: {key time: degrees}} -- each listed key's
# target tip (and blade direction) is turned by that many degrees of elevation about the
# shoulder, azimuth unchanged, so it is still exactly reachable by a shoulder tilt. Why: with
# the real grip hit 1 sweeps a full diagonal -- 11.8 studs between its furthest two keys, across
# all three axes -- and a LEVEL 360 at the arm's own radius spans 11.2 at most, so the finisher
# had become the smaller swing on the one number the check prints. Now the held coil stands the
# tip 4.6 studs above the root over the right shoulder (hit 1 cocks to 4.2), the sweep goes
# through level at the hip and carries on DOWN and round behind to 2.5 below the root, a stud
# off the floor: a descending spiral, not a flat one. Span 11.9 against hit 1's 11.8, contact
# travel 8.1 studs in 27 ms. The held beat (330-380) is lifted the most and the key before
# contact a little less, so the drop starts before the turn does.
LIFT = {5: {0.19: 12.0, 0.27: 22.0, 0.33: 28.0, 0.38: 30.0, 0.435: 26.0,
            0.5: -8.0, 0.545: -18.0, 0.615: -28.0, 0.7: -22.0}}


def lift_about(point, direction, shoulder, degrees):
    """Raise `point`'s elevation about `shoulder` by `degrees`, keeping its azimuth, and rotate
    `direction` by the same rotation."""
    v = point - shoulder
    flat = np.array([v[0], 0.0, v[2]])
    if np.linalg.norm(flat) < 1e-6:
        return point, direction
    axis = np.cross(np.array([0.0, 1.0, 0.0]), flat / np.linalg.norm(flat))  # horizontal, tangent
    axis /= np.linalg.norm(axis)
    a = math.radians(degrees)
    k = axis

    def rotate(u):
        return u * math.cos(a) + np.cross(k, u) * math.sin(a) + k * float(np.dot(k, u)) * (1 - math.cos(a))

    lifted = rotate(v)
    # positive degrees raise the tip (toward +Y), negative lower it: pick the sign that does
    if (lifted[1] - v[1]) * degrees < 0:
        a = -a
        lifted = rotate(v)
    return shoulder + lifted, rotate(direction)


def old_model_handle(pose):
    """The grip the chain was first solved against: a bare translation, blade up the hand's +Y."""
    hand = scc.compose(pose, scc.CHAIN)
    return hand * scc.CF([0.0, -0.175, 0.0]) * scc.CF(r=scc.angles(-math.pi / 2, 0, 0)).inv()


def blade_of(handle):
    guard = handle * np.array([0, 0, scc.BLADE_REACH * scc.BLADE_NEAR])
    tip = handle * np.array([0, 0, scc.BLADE_REACH * scc.BLADE_FAR])
    d = tip - guard
    return tip, d / np.linalg.norm(d)


def pose_for(key, q, arm_keys):
    spec = dict(key)
    spec["q"] = list(q)
    keys, _ = scc.build_hit({"keys": [spec]}, arm_keys, {})
    return keys[key["t"]]


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    old_clip = sys.argv[1]

    # The design targets: the old arm through the old grip model.
    saved = scc.ANIMS
    scc.ANIMS = os.path.dirname(os.path.abspath(old_clip))
    old_name = os.path.basename(old_clip)
    if old_name != "Sword Attack Animation.luau":
        sys.exit("pass the pre-fix clip saved under its own name, 'Sword Attack Animation.luau'")
    old_arm, _ = scc.read_hit1()
    scc.ANIMS = saved
    new_arm, _ = scc.read_hit1()

    specs = scc.read_chain_spec()
    text = open(CHAIN_PATH, encoding="utf-8").read()
    lines = text.split("\n")

    # Walk the file's key lines in order, hit by hit, so the rewrite touches exactly the keys read.
    key_line_re = re.compile(r"^(\s*\{ t = %s, s = %s, q = \{)([^}]*)(\}.*)$" % (scc.NUM, scc.NUM))
    line_idx = 0
    worst = 0.0
    for hit_no, spec in enumerate(specs, start=2):
        print("== hit %d %s ==" % (hit_no, spec["name"]))
        prev_q = None
        q_arcend = None
        last_q0 = np.array(spec["keys"][-1]["q"], dtype=float)
        for key in spec["keys"]:
            q0 = np.array(key["q"], dtype=float)
            if key["t"] > spec["arcend"] + 1e-9:
                # RECOVERY. The old model's targets here are the one place it was wrong on its own
                # terms: they end at the old model's idea of guard (blade up and behind), whereas
                # the real guard -- Sword Guard Hold and the next hit's first frame -- is hit 1's
                # own re-solved T_END, i.e. the borrowed arm with no tilt. So the tilt is not solved
                # here; it UNWINDS, linearly in time, from the solved tilt at ArcEnd to the small
                # tilt the last key was authored with, while the borrowed arm does hit 1's own
                # recoil, draw-in and return to guard.
                alpha = (key["t"] - spec["arcend"]) / (spec["length"] - spec["arcend"])
                q = q_arcend * (1 - alpha) + last_q0 * alpha
                pose = pose_for(key, q, new_arm)
                tip, _ = blade_of(scc.handle_cf(pose))
                print("   t %4.0f  recovery, tilt unwound %.0f%%          tip (%5.2f %5.2f %5.2f)  q %s -> %s"
                      % (key["t"] * 1000, alpha * 100, *tip,
                         tuple(round(v, 1) for v in q0), tuple(round(v, 1) for v in q)))
            else:
                # design target from the old model
                old_pose = pose_for(key, key["q"], old_arm)
                target_tip, target_dir = blade_of(old_model_handle(old_pose))
                lift = LIFT.get(hit_no, {}).get(key["t"])
                if lift:
                    target_tip, target_dir = lift_about(target_tip, target_dir, scc.shoulder(old_pose), lift)

                def residual(q):
                    pose = pose_for(key, q, new_arm)
                    tip, d = blade_of(scc.handle_cf(pose))
                    return np.concatenate([tip - target_tip, W_DIR * (d - target_dir), W_Q * (q - q0)])

                start = q0 if prev_q is None else prev_q
                best = None
                for init in (start, q0, q0 + np.array([20, 0, 0]), q0 + np.array([-20, 0, 0]),
                             q0 + np.array([0, 20, 0]), q0 + np.array([0, -20, 0])):
                    sol = least_squares(residual, init, bounds=(q0 - 120, q0 + 120))
                    if best is None or sol.cost < best.cost:
                        best = sol
                q = best.x
                pose = pose_for(key, q, new_arm)
                tip, d = blade_of(scc.handle_cf(pose))
                err = float(np.linalg.norm(tip - target_tip))
                ang = math.degrees(math.acos(max(-1.0, min(1.0, float(np.dot(d, target_dir))))))
                worst = max(worst, err)
                print("   t %4.0f  target (%5.2f %5.2f %5.2f)  got (%5.2f %5.2f %5.2f)  tip err %.2f  dir err %3.0f deg"
                      "  q %s -> %s" % (key["t"] * 1000, *target_tip, *tip, err, ang,
                                        tuple(round(float(v), 1) for v in q0), tuple(round(float(v), 1) for v in q)))
                q_arcend = q
            prev_q = q

            # rewrite that key's q in the file
            while line_idx < len(lines):
                m = key_line_re.match(lines[line_idx])
                if m and float(re.match(r"\s*\{ t = (%s)" % scc.NUM, lines[line_idx]).group(1)) == key["t"]:
                    lines[line_idx] = "%s%s%s" % (m.group(1), ", ".join("%.3f" % v for v in q), m.group(3))
                    line_idx += 1
                    break
                line_idx += 1
            else:
                sys.exit("could not find the line for hit %d key t=%s" % (hit_no, key["t"]))

    open(CHAIN_PATH, "w", encoding="utf-8").write("\n".join(lines))
    print("worst tip error %.2f studs; SwingChain.luau rewritten" % worst)


if __name__ == "__main__":
    main()
