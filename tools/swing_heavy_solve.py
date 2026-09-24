#!/usr/bin/env python3
"""Re-aim the charged heavy's blade, key by key, and re-solve the shoulder tilt `q` for it.

WHY THIS EXISTS. The heavy's two clips (ReplicatedStorage/SwingHeavy) were authored against the
M1 as it stood before the combo_chain piece re-solved hit 1. Hit 1 grew: its arc now spans 11.79
studs. The heavy's spanned 11.18 -- tools/swing_chain_check.py had started printing "the charged
heavy is not bigger or not faster than the light swing", which is the one thing this piece is
judged on. The cause is geometry, not timing: the heavy cocked the blade nearly STRAIGHT UP
(elevation 74-78 degrees, azimuth swinging uselessly either side of the spine) at the SHORTEST
radius on hit 1's arm circle (s ~= 0.22, reach 4.75), and finished LEVEL with the body (elevation
-1) instead of down near the floor. A blade pointing straight up is also the one direction that
reads the same from every lens on the ground, so the charge lost its silhouette as well.

WHAT THIS DOES. Exactly what tools/swing_finisher_solve.py does for hit 5, and for the same
reason -- the arm is not authored by hand, it is read out of hit 1 at a place `s` on its circle
and steered by one rotation `q` at the shoulder. Each key below states:

    s      where on hit 1's circle to borrow the arm (and therefore the RADIUS -- hit 1's reach
           runs 3.7 to 5.4 studs across its clip, so `s` is the lever on how long the swing is)
    el/az  where the blade TIP should point from the shoulder: elevation in degrees above the
           horizontal, azimuth 0 straight ahead, +90 out to the character's left, 180 behind
    roll   how far the blade's own axis is turned off the tip direction, kept from the key it
           replaces unless stated, so the flat of the steel does not spin

and `q` is the bounded least-squares rotation that puts the REAL blade (real grip: out of the
FRONT of the fist along the hand's -Z, see the header of Sword Attack Animation.luau) there. The
radius is taken from the arm at `s`, so every target is reachable by construction. Root height is
then nudged until the lower foot sits on the floor, the way the finisher solver does it.

Everything else in each key -- root x/z and angles, chest, head, left arm, legs, easing, timing --
is read from the file and passed through untouched. This only ever rewrites `q = {...}`, `s = ...`
and the root's y.

Usage:  python3 tools/swing_heavy_solve.py [--write]
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

HEAVY_PATH = os.path.join(scc.GAME, "ReplicatedStorage", "SwingHeavy.luau")
FLOOR = -3.00
W_DIR = 0.6
W_Q = 0.004

# ── where the blade goes ────────────────────────────────────────────────────────────────
#
# THE CHARGE cocks up and BACK over the right shoulder -- behind the head, not over it -- at the
# long end of hit 1's arm circle (s = 0.56, reach 5.38, hit 1's longest). Azimuth stays within a
# few degrees of 180 through the whole strain, so the held pose is a diagonal seen from any side
# lens instead of a post standing up out of the fist; the strain cycle breathes it between 58 and
# 67 degrees of elevation rather than between two azimuths nobody can see the difference in.
#
# THE RELEASE takes that back-and-up blade over the top, through the target on a nearly LEVEL
# line (elevation 5 rather than 23, so the cut crosses a standing body instead of clipping its
# shoulder) and then down to within a hand of the floor on the far side. The tip is held to -3.0
# in root space, which is where the feet are: the blade ends AT the ground, never through it.
#
# {key t: (s, elevation, azimuth)} -- keys not listed keep the file's own q, s and root.
CHARGE_AIM = {
    0.045: (0.30, 28.0, 52.0),    # off the guard, out to the right at chest height
    0.095: (0.42, 34.0, 116.0),   # swinging back past the right shoulder
    0.150: (0.52, 38.0, 134.0),   # climbing behind the head
    0.200: (0.56, 42.0, 140.0),   # THE COIL IS FORMED. The loop point, and the bottom of the strain.
    0.300: (0.56, 54.0, 158.0),   # strain: drawing deeper
    0.400: (0.56, 66.0, 176.0),   # strain: deeper still, crossing the spine
    0.470: (0.56, 74.0, -156.0),  # THE PEAK. The strike's first key is this key.
    0.545: (0.56, 58.0, 166.0),   # the breath giving a little back -- a body cannot hold its max
    0.620: (0.56, 42.0, 140.0),   # the 200 ms key restated, so the loop has no seam
}
STRIKE_AIM = {
    0.000: (0.56, 74.0, -156.0),  # the charge's peak, value for value
    0.070: (0.56, 78.0, -146.0),  # THE LAST LOAD: higher and further round, still going AWAY
    0.130: (0.56, 72.0, -170.0),  # THE HIPS FIRE and the blade has barely moved
    0.158: (0.56, 62.0, 178.0),   # the chest brings it over the top; last frame before contact
    0.185: (0.375, 5.0, -24.0),   # CONTACT, level through the target
    0.250: (0.375, -16.0, -60.0), # follow-through 1, driven DOWN to the floor line
    0.330: (0.375, -19.0, -91.5), # follow-through 2, out past the left hip a hand off the ground
    0.430: (0.38, 4.0, -118.0),   # ArcEnd, coming back up as it wraps left
}


def unit(v):
    v = np.asarray(v, dtype=float)
    return v / np.linalg.norm(v)


def from_el_az(el, az, r=1.0):
    el, az = math.radians(el), math.radians(az)
    return np.array([r * math.cos(el) * math.sin(az), r * math.sin(el),
                     -r * math.cos(el) * math.cos(az)])


def pose_for(key, q, arm):
    spec = dict(key)
    spec["q"] = list(q)
    keys, _ = scc.build_hit({"keys": [spec]}, arm, {})
    return keys[key["t"]]


def blade_of(pose):
    guard, tip = scc.blade_points(pose)
    d = tip - guard
    return tip, d / np.linalg.norm(d)


def level_feet(key, q, arm):
    for _ in range(4):
        pose = pose_for(key, q, arm)
        feet = min(scc.foot_y(pose, "L"), scc.foot_y(pose, "R"))
        key["root"][1] += FLOOR - feet
    return key


def solve_block(name, keys, aim, arm):
    out = []
    prev_q = np.array(keys[0]["q"], dtype=float)
    for key in keys:
        key = {k: (list(v) if isinstance(v, list) else v) for k, v in key.items()}
        target = aim.get(round(key["t"], 3))
        if target is None:
            q = np.array(key["q"], dtype=float)
        else:
            new_s, el, az = target
            # The blade's own roll: keep the angle the current key holds between the steel and
            # the shoulder-to-tip line, so re-aiming never spins the flat of the blade.
            here = pose_for(key, key["q"], arm)
            sh = scc.shoulder(here)
            tip_now, dir_now = blade_of(here)
            out_now = unit(tip_now - sh)
            want_out = unit(from_el_az(el, az))
            # rotation taking the old tip direction onto the new one, applied to the blade axis
            v = np.cross(out_now, want_out)
            c = float(np.dot(out_now, want_out))
            if np.linalg.norm(v) < 1e-9:
                rot = np.eye(3)
            else:
                k = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
                rot = np.eye(3) + k + k @ k * (1.0 / (1.0 + c))
            target_dir = unit(rot @ dir_now)

            key["s"] = new_s
            base = pose_for(key, [0, 0, 0], arm)
            tip0, _ = blade_of(base)
            reach = float(np.linalg.norm(tip0 - sh))
            target_tip = sh + reach * want_out

            def residual(qq):
                pose = pose_for(key, qq, arm)
                tip, d = blade_of(pose)
                return np.concatenate([tip - target_tip, W_DIR * (d - target_dir),
                                       W_Q * (qq - prev_q)])

            best = None
            for init in (prev_q, np.zeros(3), np.array([40.0, 0, 0]), np.array([-40.0, 0, 0]),
                         np.array([0, 40.0, 0]), np.array([0, -40.0, 0]),
                         np.array([0, 0, 40.0]), np.array([0, 0, -40.0]),
                         np.array([80.0, -40.0, 80.0])):
                sol = least_squares(residual, init, bounds=(-175, 175))
                if best is None or sol.cost < best.cost:
                    best = sol
            q = best.x
            pose = pose_for(key, q, arm)
            tip, d = blade_of(pose)
            err = float(np.linalg.norm(tip - target_tip))
            ang = math.degrees(math.acos(max(-1.0, min(1.0, float(np.dot(d, target_dir))))))
            print("%s t %4.0f  s %.3f  tip (%5.2f %5.2f %5.2f) err %.2f  blade off %3.0f deg"
                  % (name, key["t"] * 1000, key["s"], tip[0], tip[1], tip[2], err, ang),
                  file=sys.stderr)
        key = level_feet(key, q, arm)
        prev_q = np.array(q, dtype=float)
        key["q"] = [float(v) for v in q]
        out.append(key)
    return out


def rewrite(text, block_name, keys):
    """Replace the q, s and root columns of each key line of one block, in file order."""
    block = re.search(r"(SwingHeavy\.%s\s*=\s*\{.*?\n\}\n)" % block_name, text, re.S)
    if not block:
        raise SystemExit("could not find SwingHeavy.%s" % block_name)
    body = block.group(1)
    it = iter(keys)

    def sub(m):
        key = next(it)
        fmt = lambda xs: ", ".join(("%g" % round(float(v), 3)) for v in xs)
        return ("{ t = %g, s = %g, q = {%s}, root = {%s}"
                % (key["t"], key["s"], ", ".join("%.3f" % float(v) for v in key["q"]),
                   fmt(key["root"])))

    new_body = re.sub(r"\{ t = %s, s = %s, q = \{[^}]*\}, root = \{[^}]*\}" % (scc.NUM, scc.NUM),
                      sub, body)
    return text.replace(body, new_body)


def main():
    arm, _ = scc.read_hit1()
    spec = dict(scc.read_heavy_spec())
    charge = solve_block("CHARGE", spec["CHARGE"], CHARGE_AIM, arm)
    strike = solve_block("STRIKE", spec["STRIKE"], STRIKE_AIM, arm)
    # SwingHeavy asserts that the strike's first key IS the charge's peak, value for value, so
    # that letting go of the button cannot pop the arm. Both are solved from the same target and
    # the same body, but they are solved with different neighbours pulling on them, so copy
    # rather than trust two least-squares runs to land on the same three decimals.
    peak = next(k for k in charge if round(k["t"], 3) == 0.470)
    strike[0]["s"] = peak["s"]
    strike[0]["q"] = list(peak["q"])
    strike[0]["root"] = list(peak["root"])
    if "--write" not in sys.argv:
        print("(dry run; pass --write to rewrite SwingHeavy.luau)", file=sys.stderr)
        return 0
    text = open(HEAVY_PATH, encoding="utf-8").read()
    text = rewrite(text, "CHARGE", charge)
    text = rewrite(text, "STRIKE", strike)
    open(HEAVY_PATH, "w", encoding="utf-8").write(text)
    print("wrote %s" % HEAVY_PATH, file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
