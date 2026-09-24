#!/usr/bin/env python3
"""Offline geometry check for the player's M1 chain.

The five swings in ReplicatedStorage/Animations are procedural keyframe tables. Their arm
angles are not readable by eye: a shoulder/elbow/wrist triple says nothing about where the
blade ends up. This reproduces, in Python, exactly what the game does with them --

    AnimationController.segmentAt / :Lerp   (key search, per-segment easing, quaternion slerp)
    Motor6D composition down HumanoidRootPart -> LowerTorso -> UpperTorso -> RightUpperArm
        -> RightLowerArm -> RightHand
    the tool's grip weld, and the blade down the handle's -Z

-- using the real R15 joint offsets (read out of ReplicatedStorage/NpcModels/swordsman_R15.rbxmx,
which PrebuiltNpcRig builds at stock R15 dimensions) and the real sword built by
RuntimeBootstrap. It then prints, for every key of every hit: where the blade's tip is in
character space, how far it is from the shoulder, the plane angle of the cut, and how fast the
tip is travelling per rendered frame at 60 fps.

That is enough to tell, without Studio, whether a swing is a wide circle or an arm folding up,
whether the blade is in front of the character when the hitbox fires, whether two hits in the
chain are actually different swings, and whether the finisher is bigger than the first hit.

Usage:  python3 tools/swing_chain_check.py
"""

import math
import os
import re
import sys
import xml.etree.ElementTree as ET

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAME = os.path.join(ROOT, "lemonade-game")
ANIMS = os.path.join(GAME, "ReplicatedStorage", "Animations")
RIG_FILE = os.path.join(GAME, "ReplicatedStorage", "NpcModels", "swordsman_R15.rbxmx")

# The sword RuntimeBootstrap builds: the blade runs down the handle's -Z, and the tip wedges sit
# at z = -3.64 with a half-depth of 0.25, so the steel ends at -3.89.
BLADE_REACH = -3.89
BLADE_NEAR, BLADE_FAR = 0.12, 1.00  # the span SwingBlade calls "the blade", as a fraction
# Roblox welds a Tool to the hand with RightGrip: C0 = RightGripAttachment.CFrame, which on the
# R15 rig is CFrame.new(0, -0.158, 0) * Angles(-90, 0, 0) (measured in Studio on
# Players:CreateHumanoidModelFromDescription), and C1 = Tool.Grip = Angles(-90, 0, 0)
# (RuntimeBootstrap). Handle = hand * C0 * C1:Inverse(): the two rotations CANCEL, so the
# Handle's axes are the hand's axes and the blade (down the Handle's -Z) runs out of the FRONT of
# the fist. This used to model C0 as a bare translation, which put the blade up the hand's +Y --
# the same wrong assumption hit 1's wrist keys were first solved on (see that clip's header).
GRIP_C0 = np.array([0.0, -0.158, 0.0])
GRIP_C0_ANGLE_X = -math.pi / 2  # RightGripAttachment's rotation
GRIP_ANGLE_X = -math.pi / 2     # Tool.Grip = CFrame.Angles(-pi/2, 0, 0)

CHAIN = [
    ("LowerTorso", "HumanoidRootPart"),
    ("UpperTorso", "LowerTorso"),
    ("RightUpperArm", "UpperTorso"),
    ("RightLowerArm", "RightUpperArm"),
    ("RightHand", "RightLowerArm"),
]
LEG_CHAIN_L = [("LowerTorso", None), ("LeftUpperLeg", None), ("LeftLowerLeg", None), ("LeftFoot", None)]
LEG_CHAIN_R = [("LowerTorso", None), ("RightUpperLeg", None), ("RightLowerLeg", None), ("RightFoot", None)]


# ── CFrame, the small part of it this needs ─────────────────────────────────────────────


class CF:
    __slots__ = ("p", "r")

    def __init__(self, p=None, r=None):
        self.p = np.zeros(3) if p is None else np.asarray(p, dtype=float)
        self.r = np.eye(3) if r is None else np.asarray(r, dtype=float)

    def __mul__(self, other):
        if isinstance(other, CF):
            return CF(self.p + self.r @ other.p, self.r @ other.r)
        return self.p + self.r @ np.asarray(other, dtype=float)

    def inv(self):
        rt = self.r.T
        return CF(-(rt @ self.p), rt)

    def lerp(self, other, a):
        """Roblox CFrame:Lerp -- position lerped, rotation slerped on the shorter arc."""
        q0, q1 = mat_to_quat(self.r), mat_to_quat(other.r)
        return CF(self.p + (other.p - self.p) * a, quat_to_mat(slerp(q0, q1, a)))


def angles(x, y, z):
    """CFrame.Angles(x, y, z) -- intrinsic X then Y then Z, in radians."""
    cx, sx, cy, sy, cz, sz = math.cos(x), math.sin(x), math.cos(y), math.sin(y), math.cos(z), math.sin(z)
    rx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])
    ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    rz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    return rx @ ry @ rz


def mat_to_quat(m):
    t = m[0, 0] + m[1, 1] + m[2, 2]
    if t > 0:
        s = math.sqrt(t + 1.0) * 2
        q = np.array([0.25 * s, (m[2, 1] - m[1, 2]) / s, (m[0, 2] - m[2, 0]) / s, (m[1, 0] - m[0, 1]) / s])
    elif m[0, 0] > m[1, 1] and m[0, 0] > m[2, 2]:
        s = math.sqrt(1.0 + m[0, 0] - m[1, 1] - m[2, 2]) * 2
        q = np.array([(m[2, 1] - m[1, 2]) / s, 0.25 * s, (m[0, 1] + m[1, 0]) / s, (m[0, 2] + m[2, 0]) / s])
    elif m[1, 1] > m[2, 2]:
        s = math.sqrt(1.0 + m[1, 1] - m[0, 0] - m[2, 2]) * 2
        q = np.array([(m[0, 2] - m[2, 0]) / s, (m[0, 1] + m[1, 0]) / s, 0.25 * s, (m[1, 2] + m[2, 1]) / s])
    else:
        s = math.sqrt(1.0 + m[2, 2] - m[0, 0] - m[1, 1]) * 2
        q = np.array([(m[1, 0] - m[0, 1]) / s, (m[0, 2] + m[2, 0]) / s, (m[1, 2] + m[2, 1]) / s, 0.25 * s])
    return q / np.linalg.norm(q)


def quat_to_mat(q):
    w, x, y, z = q
    return np.array([
        [1 - 2 * (y * y + z * z), 2 * (x * y - w * z), 2 * (x * z + w * y)],
        [2 * (x * y + w * z), 1 - 2 * (x * x + z * z), 2 * (y * z - w * x)],
        [2 * (x * z - w * y), 2 * (y * z + w * x), 1 - 2 * (x * x + y * y)],
    ])


def slerp(q0, q1, a):
    d = float(np.dot(q0, q1))
    if d < 0:
        q1, d = -q1, -d
    if d > 0.9995:
        q = q0 + (q1 - q0) * a
        return q / np.linalg.norm(q)
    th0 = math.acos(max(-1.0, min(1.0, d)))
    th = th0 * a
    q2 = q1 - q0 * d
    q2 /= np.linalg.norm(q2)
    return q0 * math.cos(th) + q2 * math.sin(th)


# ── the easing table AnimationController ships ──────────────────────────────────────────

EASING = {
    "Linear": lambda a: a,
    "InQuad": lambda a: a * a,
    "OutQuad": lambda a: 1 - (1 - a) ** 2,
    "InOutQuad": lambda a: 2 * a * a if a < 0.5 else 1 - ((-2 * a + 2) ** 2) / 2,
    "InCubic": lambda a: a ** 3,
    "OutCubic": lambda a: 1 - (1 - a) ** 3,
    "InOutCubic": lambda a: 4 * a ** 3 if a < 0.5 else 1 - ((-2 * a + 2) ** 3) / 2,
    "InQuart": lambda a: a ** 4,
    "OutQuart": lambda a: 1 - (1 - a) ** 4,
    "InBack": lambda a: 2.70158 * a ** 3 - 1.70158 * a * a,
    "OutBack": lambda a: 1 + 2.70158 * (a - 1) ** 3 + 1.70158 * (a - 1) ** 2,
}


def sample(keys, easing, t):
    """AnimationController.segmentAt + the per-part lerp, i.e. SampleClip."""
    times = sorted(keys)
    t = max(times[0], min(times[-1], t))
    lo, hi = times[0], times[-1]
    for i in range(len(times) - 1):
        if times[i] <= t <= times[i + 1]:
            lo, hi = times[i], times[i + 1]
            break
    if hi <= lo:
        return dict(keys[lo])
    a = (t - lo) / (hi - lo)
    a = EASING.get(easing.get(lo, "Linear"), EASING["Linear"])(a)
    a = max(0.0, min(1.0, a))
    out = {}
    for part, cf in keys[lo].items():
        out[part] = cf.lerp(keys[hi].get(part, cf), a)
    return out


# ── the rig ─────────────────────────────────────────────────────────────────────────────


def load_rig():
    tree = ET.parse(RIG_FILE)
    root = tree.getroot()
    names = {}
    for item in root.iter("Item"):
        props = item.find("Properties")
        if props is None:
            continue
        nm = props.find("string[@name='Name']")
        if nm is not None:
            names[item.get("referent")] = nm.text
    joints = {}
    for item in root.iter("Item"):
        if item.get("class") != "Motor6D":
            continue
        props = item.find("Properties")

        def cf(tag):
            el = props.find("CoordinateFrame[@name='%s']" % tag)
            if el is None:
                return CF()
            g = lambda n: float(el.find(n).text)
            return CF([g("X"), g("Y"), g("Z")],
                      [[g("R00"), g("R01"), g("R02")], [g("R10"), g("R11"), g("R12")], [g("R20"), g("R21"), g("R22")]])

        p1 = props.find("Ref[@name='Part1']")
        joints[names.get(p1.text)] = (cf("C0"), cf("C1"))
    return joints


RIG = load_rig()


def compose(pose, chain):
    cf = CF()
    for part, _ in chain:
        c0, c1 = RIG[part]
        cf = cf * c0 * pose.get(part, CF()) * c1.inv()
    return cf


def handle_cf(pose):
    hand = compose(pose, CHAIN)
    return hand * CF(GRIP_C0, angles(GRIP_C0_ANGLE_X, 0, 0)) * CF(r=angles(GRIP_ANGLE_X, 0, 0)).inv()


def blade_points(pose):
    h = handle_cf(pose)
    return h * np.array([0, 0, BLADE_REACH * BLADE_NEAR]), h * np.array([0, 0, BLADE_REACH * BLADE_FAR])


def shortest_arc(a, b):
    """The rotation of least angle taking unit vector `a` to unit vector `b`."""
    v = np.cross(a, b)
    c = float(np.dot(a, b))
    if np.linalg.norm(v) < 1e-9:
        return np.eye(3) if c > 0 else -np.eye(3) + 2 * np.outer(a, a)
    k = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
    return np.eye(3) + k + k @ k / (1 + c)


def split_roll(r):
    """A wrist rotation, split into (the canonical no-twist rotation, the roll in degrees).

    "No twist" needs no reference clip: it is the SHORTEST rotation taking the hand's -Z to the
    blade direction this key already has, which is exactly the rule the round-5 wrist solve
    used -- and the missing constraint that left the flat of the blade leading the cut. Whatever
    is left over after that is the blade's roll about its own axis."""
    d = r @ np.array([0.0, 0.0, -1.0])
    base = shortest_arc(np.array([0.0, 0.0, -1.0]), d)
    z = base.T @ r
    return base, math.degrees(math.atan2(z[1, 0], z[0, 0]))


def with_roll(base, roll):
    return base @ angles(0, 0, math.radians(roll))


def strip_rolls(keys):
    """The same clip with every blade roll taken out of the wrist: the poses the swing would
    have if nobody had ever twisted the sword in the fist. The blade goes exactly where it goes
    in the real clip -- a roll about the blade's own axis cannot move it -- so this is the clip
    to measure the DIRECTION OF THE CUT on, free of the twist that is being solved for."""
    out = {}
    for t, pose in keys.items():
        p = dict(pose)
        p["RightHand"] = CF(r=with_roll(split_roll(pose["RightHand"].r)[0], 0.0))
        out[t] = p
    return out


def sweep_dir(keys, easing, t, axis):
    """Which way the BLADE SWEEPS at time `t`: the handle's angular velocity crossed into the
    blade's own axis, normalised. This is the direction the edge has to face.

    Measure it on `strip_rolls(keys)`, not on the clip itself. It is deliberately NOT the tip's
    velocity. Turning the sword in the fist swings the hand as
    well -- the wrist joint sits a third of a stud off the blade's axis -- so the tip's own path
    moves when the roll moves, and solving a roll against it chases its own tail: it oscillated
    between two answers 60 degrees apart and settled at neither. The blade AXIS is the -Z column
    of the handle's rotation, and rolling the sword about that axis does not touch that column,
    so the direction the axis is sweeping is the one target here that does not move when the
    answer does. (The two agree on what a cut is: the tip is 3.9 studs down this axis.)"""
    times = sorted(keys)
    dt = 1.0 / 120.0
    lo, hi = max(times[0], t - dt), min(times[-1], t + dt)
    a0 = -handle_cf(sample(keys, easing, lo)).r[:, 2]
    a1 = -handle_cf(sample(keys, easing, hi)).r[:, 2]
    v = a1 - a0
    v = v - float(np.dot(v, axis)) * axis
    n = np.linalg.norm(v)
    return v / n if n > 1e-6 else None


def shoulder(pose):
    cf = CF()
    for part, _ in CHAIN[:2]:
        c0, c1 = RIG[part]
        cf = cf * c0 * pose.get(part, CF()) * c1.inv()
    c0, _ = RIG["RightUpperArm"]
    return (cf * c0).p


def foot_y(pose, side):
    chain = LEG_CHAIN_L if side == "L" else LEG_CHAIN_R
    return compose(pose, chain).p[1]


def foot_z(pose, side):
    """How far FORWARD a foot is (character space; -Z is forward, so smaller is further ahead).
    The difference between the two is the stance's lead foot, which is what tells a chain of
    swings apart on film as much as the blade does."""
    chain = LEG_CHAIN_L if side == "L" else LEG_CHAIN_R
    return compose(pose, chain).p[2]


def root_yaw(pose):
    """The pelvis' own yaw, in degrees: +left, -right. The hip line."""
    r = pose.get("LowerTorso", CF()).r
    return math.degrees(math.atan2(r[0, 2], r[2, 2]))


# ── the Luau side: a small reader for the clip tables ───────────────────────────────────


def strip_comments(text):
    out = []
    for line in text.splitlines():
        cut = None
        in_str = False
        i = 0
        while i < len(line) - 1:
            if line[i] == '"':
                in_str = not in_str
            elif not in_str and line[i] == "-" and line[i + 1] == "-":
                cut = i
                break
            i += 1
        out.append(line if cut is None else line[:cut])
    return "\n".join(out)


NUM = r"-?\d+(?:\.\d+)?"


def read_hit1():
    """Hit 1's clip, as {time: {part: CF}} plus its easing map. Parsed rather than restated so
    the circle checked here is literally the circle the game plays."""
    text = strip_comments(open(os.path.join(ANIMS, "Sword Attack Animation.luau"), encoding="utf-8").read())
    consts = {}
    for name, value in re.findall(r"local (T_\w+)\s*=\s*(%s)" % NUM, text):
        consts[name] = float(value)
    for name, field in re.findall(r"local (T_\w+)\s*=\s*SwingTiming\.(\w+)", text):
        consts[name] = {"WINDUP": 0.170, "CONTACT": 0.252, "SWING_END": 0.440, "RECOVERY_END": 0.660}[field]

    easing = {}
    block = re.search(r"Easing\s*=\s*\{(.*?)\n\t\}", text, re.S)
    for key, style in re.findall(r"\[(T_\w+)\]\s*=\s*\"(\w+)\"", block.group(1)):
        easing[consts[key]] = style

    keys = {}
    body = text[text.index("Timestamps"):]
    for frame in re.finditer(r"\[(T_\w+)\]\s*=\s*\{(.*?)\n\t\t\}", body, re.S):
        pose = {}
        for part, args in re.findall(r'\["(\w+)"\]\s*=\s*(?:rot|root)\(([^)]*)\)', frame.group(2)):
            nums = [float(v) for v in args.replace(" ", "").split(",")]
            if len(nums) == 3:
                pose[part] = CF(r=angles(*[math.radians(v) for v in nums]))
            else:
                pose[part] = CF(nums[:3], angles(*[math.radians(v) for v in nums[3:]]))
        keys[consts[frame.group(1)]] = pose
    return keys, easing


def read_chain_spec():
    """The four chained hits, read out of ReplicatedStorage/SwingChain.luau. The spec there is
    deliberately one key per table line so this can read it without a Lua interpreter."""
    path = os.path.join(GAME, "ReplicatedStorage", "SwingChain.luau")
    text = strip_comments(open(path, encoding="utf-8").read())
    hits = []
    for hit in re.finditer(r"\{ Name = \"([^\"]+)\", Clip = \"([^\"]+)\", Windup = (%s), "
                           r"Contact = (%s), ArcEnd = (%s), Length = (%s), FadeIn = (%s),(.*?)\n\t\t\},"
                           % (NUM, NUM, NUM, NUM, NUM), text, re.S):
        name, body = hit.group(2), hit.group(8)
        phases = dict(windup=float(hit.group(3)), contact=float(hit.group(4)),
                      arcend=float(hit.group(5)), length=float(hit.group(6)))
        keys = _keys_in(body)
        if keys:
            hits.append(dict(name=name, keys=keys, **phases))
    return hits


# `roll` is optional and comes last: the blade's twist about its own axis, in degrees, added at
# the wrist. Keys written before the edge pass existed simply do not carry it.
KEY_RE = (r"\{\s*t\s*=\s*(%s),\s*s\s*=\s*(%s),\s*q\s*=\s*\{([^}]*)\},\s*"
          r"root\s*=\s*\{([^}]*)\},\s*chest\s*=\s*\{([^}]*)\},\s*"
          r"head\s*=\s*\{([^}]*)\},\s*larm\s*=\s*\{([^}]*)\},\s*"
          r"legs\s*=\s*\{([^}]*)\},\s*ease\s*=\s*\"(\w+)\"(?:,\s*roll\s*=\s*(%s))?"
          % (NUM, NUM, NUM))


def _keys_in(body):
    keys = []
    for line in re.finditer(KEY_RE, body, re.S):
        g = line.groups()
        nums = lambda i: [float(v) for v in g[i].replace(" ", "").replace("\n", "").replace("\t", "").split(",") if v]
        keys.append({
            "t": float(g[0]), "s": float(g[1]), "q": nums(2), "root": nums(3),
            "chest": nums(4), "head": nums(5), "larm": nums(6), "legs": nums(7), "ease": g[8],
            "roll": float(g[9]) if g[9] else 0.0,
        })
    return keys


def read_heavy_spec():
    """The charged heavy's two clips, read out of ReplicatedStorage/SwingHeavy.luau. Same
    one-key-per-line spec as SwingChain, so the same reader shape works."""
    path = os.path.join(GAME, "ReplicatedStorage", "SwingHeavy.luau")
    text = strip_comments(open(path, encoding="utf-8").read())
    out = []
    for name in ("CHARGE", "STRIKE"):
        block = re.search(r"SwingHeavy\.%s\s*=\s*\{(.*?)\n\}" % name, text, re.S)
        if not block:
            continue
        keys = _keys_in(block.group(1))
        if keys:
            out.append((name, keys))
    return out


# ── building a hit's pose table the way SwingChain.luau does ────────────────────────────


def rot(x, y, z):
    return CF(r=angles(math.radians(x), math.radians(y), math.radians(z)))


def build_hit(spec, arm_keys, arm_easing):
    keys, easing = {}, {}
    for k in spec["keys"]:
        # LINEAR between hit 1's keys, with hit 1's easing ignored -- which is exactly what
        # SwingChain.armAt and SwingHeavy.armAt do in Luau, and why: hit 1's easing is its own
        # timing, so reading `s` through it would make `s` a moment rather than a place on the
        # circle. (This used to pass arm_easing, so the tool was reading the chain's arm through a
        # curve the game does not apply. The shipped clips are unchanged; only this report was.)
        arm = sample(arm_keys, {}, k["s"])
        q = rot(*k["q"])
        r = k["root"]
        le = k["legs"]
        pose = {
            "LowerTorso": CF([r[0], r[1], r[2]], angles(*[math.radians(v) for v in r[3:6]])),
            "UpperTorso": rot(*k["chest"]),
            "Head": rot(*k["head"]),
            "RightUpperArm": q * arm["RightUpperArm"],
            "RightLowerArm": arm["RightLowerArm"],
            # The blade's ROLL about its own long axis, at the wrist: which way the EDGE
            # faces. Post-multiplied, so it turns the sword in the fist and moves neither the
            # tip nor the blade's direction. See tools/swing_edge_resolve.py.
            "RightHand": arm["RightHand"] * rot(0, 0, k.get("roll", 0.0)),
            "LeftUpperArm": rot(*k["larm"][0:3]),
            "LeftLowerArm": rot(k["larm"][3], 0, 0),
            "LeftHand": rot(0, 0, k["larm"][4]),
            "RightUpperLeg": rot(*le[0:3]),
            "RightLowerLeg": rot(le[3], 0, 0),
            "LeftUpperLeg": rot(*le[4:7]),
            "LeftLowerLeg": rot(le[7], 0, 0),
        }
        keys[k["t"]] = pose
        easing[k["t"]] = k["ease"]
    return keys, easing


# ── the report ──────────────────────────────────────────────────────────────────────────


def plane_angle(tip, sh):
    """Where the blade is around the body, in degrees: 0 straight ahead (-Z), +90 out to the
    character's left, -90 out to its right. This is the 'plane angle' the clips' comments use."""
    v = tip - sh
    return math.degrees(math.atan2(v[0], -v[2]))


def report(name, keys, easing, contact=None):
    times = sorted(keys)
    print("\n== %s ==  %d keys, %.0f ms" % (name, len(times), times[-1] * 1000))
    print("   %6s %8s %8s %8s %8s %7s %7s %7s %7s %7s %7s" % ("t ms", "tipX", "tipY", "tipZ", "reach",
          "plane", "travel", "footL", "footR", "yaw", "stagger"))
    prev = None
    for t in times:
        pose = sample(keys, easing, t)
        _, tip = blade_points(pose)
        sh = shoulder(pose)
        travel = 0.0 if prev is None else float(np.linalg.norm(tip - prev))
        prev = tip
        fl, fr = foot_z(pose, "L"), foot_z(pose, "R")
        print("   %6.0f %8.2f %8.2f %8.2f %8.2f %7.0f %7.2f %7.2f %7.2f %7.0f %7.2f"
              % (t * 1000, tip[0], tip[1], tip[2], np.linalg.norm(tip - sh), plane_angle(tip, sh), travel,
                 foot_y(pose, "L"), foot_y(pose, "R"), root_yaw(pose), fr - fl))

    # Per rendered frame at 60 fps: the shape of the pass is the thing that has to read.
    step = 1.0 / 60.0
    fastest, fast_t, tips = 0.0, 0.0, []
    t = 0.0
    prev = None
    while t <= times[-1] + 1e-9:
        pose = sample(keys, easing, t)
        _, tip = blade_points(pose)
        if prev is not None:
            d = float(np.linalg.norm(tip - prev))
            tips.append(d)
            if d > fastest:
                fastest, fast_t = d, t
        prev = tip
        t += step
    span = max(np.linalg.norm(a - b) for a in [blade_points(sample(keys, easing, x))[1] for x in times]
               for b in [blade_points(sample(keys, easing, x))[1] for x in times])
    print("   fastest rendered frame %.2f studs at %.0f ms; arc spans %.2f studs; per-frame: %s"
          % (fastest, fast_t * 1000, span, " ".join("%.1f" % d for d in tips)))
    # The EDGE has to lead every fast frame, not only the contact one. Worst case over the keys
    # where the blade is actually cutting (2 studs of tip or more in a rendered frame).
    ref = strip_rolls(keys)
    worst, worst_t = None, None
    for t in times:
        pose = sample(keys, easing, t)
        h = handle_cf(pose)
        a = blade_points(sample(keys, easing, max(times[0], t - 1 / 120)))[1]
        b = blade_points(sample(keys, easing, min(times[-1], t + 1 / 120)))[1]
        if np.linalg.norm(b - a) / 2 < 2.0:
            continue
        vp = sweep_dir(ref, easing, t, -h.r[:, 2])
        if vp is None:
            continue
        lead = abs(float(np.dot(h.r[:, 1], vp)))
        if worst is None or lead < worst:
            worst, worst_t = lead, t
    if worst is not None:
        print("   edge leads the sweep: worst %.2f of the cutting keys, at %.0f ms%s"
              % (worst, worst_t * 1000, "" if worst > 0.80 else "   !! THE FLAT LEADS"))

    if contact is not None:
        pose = sample(keys, easing, contact)
        guard, tip = blade_points(pose)
        print("   CONTACT %.0f ms: guard (%.2f, %.2f, %.2f) tip (%.2f, %.2f, %.2f) plane %.0f deg"
              % (contact * 1000, guard[0], guard[1], guard[2], tip[0], tip[1], tip[2],
                 plane_angle(tip, shoulder(pose))))
        if tip[2] > -0.5 and guard[2] > -0.5:
            print("   !! the blade is not in front of the character on the contact frame")
        h = handle_cf(pose)
        flat, edge, axis = h.r[:, 0], h.r[:, 1], -h.r[:, 2]
        vp = sweep_dir(strip_rolls(keys), easing, contact, axis)
        if vp is not None:
            lead = abs(float(np.dot(edge, vp)))
            print("            blade axis (%5.2f %5.2f %5.2f)  EDGE normal (%5.2f %5.2f %5.2f)"
                  "  flat normal (%5.2f %5.2f %5.2f)  sweep (%5.2f %5.2f %5.2f)"
                  % (*axis, *edge, *flat, *vp))
            print("            edge.sweep %.2f vs flat.sweep %.2f -- %s"
                  % (lead, abs(float(np.dot(flat, vp))),
                     "the EDGE leads" if lead > 0.80 else "!! THE FLAT LEADS THE CUT"))
    return {"fastest": fastest, "span": span}


def main():
    arm_keys, arm_easing = read_hit1()
    stats = {}
    stats["Hit 1"] = report("Hit 1 — Sword Attack Animation (right diagonal)", arm_keys, arm_easing, 0.252)

    try:
        specs = read_chain_spec()
    except FileNotFoundError:
        print("\nSwingChain.luau not written yet; only hit 1 checked.")
        return 0
    if not specs:
        print("\n!! SwingChain.luau parsed to zero hits — the spec format drifted from this reader.")
        return 1
    for i, spec in enumerate(specs, start=2):
        keys, easing = build_hit(spec, arm_keys, arm_easing)
        stats["Hit %d" % i] = report("Hit %d — %s" % (i, spec["name"]), keys, easing, spec["contact"])

    # ── the charged heavy ───────────────────────────────────────────────────────────────
    try:
        heavy = read_heavy_spec()
    except FileNotFoundError:
        heavy = []
    for name, keys in heavy:
        built, easing = build_hit({"keys": keys}, arm_keys, arm_easing)
        contact = 0.185 if name == "STRIKE" else None
        stats["Heavy " + name] = report("Heavy %s — the charged attack" % name.lower(), built, easing, contact)

    print("\n== chain ==")
    first, last = stats.get("Hit 1"), stats.get("Hit 5")
    if first and last:
        print("   hit 5 arc spans %.2f studs against hit 1's %.2f (%.0f%%); fastest frame %.2f vs %.2f"
              % (last["span"], first["span"], 100 * last["span"] / first["span"],
                 last["fastest"], first["fastest"]))
        if last["span"] < first["span"]:
            print("   !! the finisher's arc is SMALLER than the first hit's")
    strike = stats.get("Heavy STRIKE")
    if first and strike:
        print("   HEAVY release arc spans %.2f studs against hit 1's %.2f (%.0f%%); fastest frame"
              " %.2f vs %.2f (%.0f%%)"
              % (strike["span"], first["span"], 100 * strike["span"] / first["span"],
                 strike["fastest"], first["fastest"], 100 * strike["fastest"] / first["fastest"]))
        if strike["span"] <= first["span"] or strike["fastest"] <= first["fastest"]:
            print("   !! the charged heavy is not bigger or not faster than the light swing")
    return 0


if __name__ == "__main__":
    sys.exit(main())
