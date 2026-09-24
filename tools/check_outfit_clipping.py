#!/usr/bin/env python3
"""Count intersecting piece pairs in an exported enemy rig.

Usage: python3 tools/check_outfit_clipping.py RBXMX [RBXMX ...]

Reads the real EnemyOutfits export (one .rbxmx per archetype, written by
tools/check_outfits.luau) and rebuilds every part's world-space ORIENTED box, then
separates the pairs with a proper separating-axis test, so a piece that is merely
rotated is not flagged for the size of its axis-aligned bounding box.

Two kinds of contact are legitimate on a clothed rig and everything else is a clip:

  * two boxes that merely touch (deepest penetration <= TOUCH), and
  * one box wholly inside another, or inside the infinite prism the other sweeps
    along its own vertical axis - which is what a limb through a sleeve, a head out
    of a collar or a leg out of a boot actually looks like.

A partial interpenetration - two solids sharing a volume with neither contained -
is a clip, and the count of those pairs must be zero.

Parts at Transparency >= 0.95 are skipped: an invisible part cannot visibly clip,
and an outfit is allowed to hide a rig part and rebuild that volume as garment.
"""
import sys
import xml.etree.ElementTree as ET

import numpy as np

TOUCH = 0.02
BODY = {
    'HumanoidRootPart': (2, 2, 1),
    'Torso': (2, 2, 1),
    'Head': (1.5, 1.5, 1.5),  # 1.2 cube x the 1.25 built-in head mesh scale
    'Left Arm': (1, 2, 1), 'Right Arm': (1, 2, 1),
    'Left Leg': (1, 2, 1), 'Right Leg': (1, 2, 1),
}
CORNERS = np.array([[sx, sy, sz] for sx in (-.5, .5) for sy in (-.5, .5) for sz in (-.5, .5)])


def parts(path):
    out = []
    for item in ET.parse(path).iter('Item'):
        if item.get('class') not in ('Part', 'WedgePart'):
            continue
        p = item.find('Properties')
        name = next(n.text for n in p if n.get('name') == 'Name')
        if name == 'HumanoidRootPart':
            continue
        alpha = next((n for n in p if n.get('name') == 'Transparency'), None)
        if alpha is not None and float(alpha.text) >= .95:
            continue
        size = np.array([float(next(n for n in p if n.get('name') in ('size', 'Size')).findtext(a))
                         for a in 'XYZ'])
        if name == 'Head':
            size = size * 1.25
        cf = p.find("CoordinateFrame[@name='CFrame']")
        pos = np.array([float(cf.findtext(a)) for a in 'XYZ'])
        rot = np.array([[float(cf.findtext(f'R{i}{j}')) for j in range(3)] for i in range(3)])
        out.append((name, name in BODY, pos, rot, size))
    return out


def penetration(a, b):
    """Deepest overlap over the 15 separating axes; negative means the boxes are apart."""
    axes = [a[3][:, i] for i in range(3)] + [b[3][:, i] for i in range(3)]
    for i in range(3):
        for j in range(3):
            cross = np.cross(a[3][:, i], b[3][:, j])
            if np.linalg.norm(cross) > 1e-6:
                axes.append(cross / np.linalg.norm(cross))
    best = float('inf')
    ca = (a[3] @ (CORNERS * a[4]).T).T + a[2]
    cb = (b[3] @ (CORNERS * b[4]).T).T + b[2]
    for axis in axes:
        pa, pb = ca @ axis, cb @ axis
        gap = min(pa.max(), pb.max()) - max(pa.min(), pb.min())
        if gap < best:
            best = gap
    return best


def inside(a, b, axes=(0, 1, 2)):
    """Every corner of a lies within b's half-extents on `axes` of b's own frame."""
    local = (a[3] @ (CORNERS * a[4]).T).T + a[2] - b[2]
    local = local @ b[3]
    return all(np.all(np.abs(local[:, i]) <= b[4][i] * .5 + TOUCH) for i in axes)


def check(path):
    items = parts(path)
    acc = [i for i in items if not i[1]]
    clips = []
    for x in range(len(items)):
        for y in range(x + 1, len(items)):
            a, b = items[x], items[y]
            if a[1] and b[1]:
                continue  # the rig's own parts are flush by construction
            depth = penetration(a, b)
            if depth <= TOUCH:
                continue
            if inside(a, b) or inside(b, a):
                continue
            # A column through a ring - a limb in a sleeve, a leg out of a boot, a
            # head out of a collar - leaves through the flat ends of the piece around
            # it, so it only has to sit inside that piece's own vertical prism.
            if inside(a, b, (0, 2)) or inside(b, a, (0, 2)):
                continue
            clips.append((a[0], b[0], round(float(depth), 3)))
    return acc, clips


def main():
    bad = 0
    for path in sys.argv[1:]:
        acc, clips = check(path)
        bad += len(clips)
        print(f'{path.rsplit("/", 1)[-1]:32s} accessories={len(acc):3d}  intersecting pairs={len(clips)}')
        for a, b, d in clips:
            print(f'    CLIP {a} x {b}  penetration {d}')
    print(f'TOTAL intersecting pairs: {bad}')
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
