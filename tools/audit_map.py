#!/usr/bin/env python3
"""Deeper map audit for one region model, on top of check_map_project.py's rules.

    python3 tools/audit_map.py /tmp/lemonade-map.rbxlx IronLowlands [--md]

Reports: property census, cross-model overlaps between collidable opaque parts (> 8 studs³),
props buried in cut faces, parts sunk > 0.6 into floors, floor seams and gaps, ramp grades,
collision fidelity, streaming mode, light budget, and collidable props inside the main lanes or
within 4 studs of a spawn. Everything is read from the built .rbxlx (same parser as the validator).
"""
from __future__ import annotations

import math
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_map_project import Node, aabb_distance_xz, inside, top_at, vertical_extent, xz_aabb  # noqa: E402

LIGHT_BUDGET = 20
LANES = {  # region → (x0, x1, z0, z1) corridors that must stay clear of collidable props (the open half
    # of each barricaded road segment counts, not the barricaded half)
    "IronLowlands": [(-12, 12, 104, 222), (-12, 32, 222, 231), (8, 32, 231, 262), (19, 32, 262, 296),
                     (-30, 30, 309, 317), (-32, -12, 316, 352), (-32, -12, 352, 362), (-30, 10, 362, 366),
                     (-12, 12, 366, 386)],
    # the trail from the gate through Frost Hollow, up the Great Ascent, round the Frozen Lake, up the
    # Gargoyle Stair and across the ridge to the ice bridge and the Revenant's plaza
    "FrostboundGlacier": [(-186, -104, -8, 10), (-228, -186, -10, 10), (-258, -228, -4, 38), (-302, -254, 28, 42),
                          (-322, -300, -46, 40), (-352, -310, -88, -72), (-366, -350, -86, -58),
                          (-392, -362, -62, -30), (-396, -384, -30, 12)],
}


def obb_overlap_volume(a, b, step=1.0):
    """Approximate intersection volume by sampling a's box on a grid and testing inside b."""
    sx, sy, sz = a.size
    nx, ny, nz = (max(1, int(s / step)) for s in (sx, sy, sz))
    hits = 0
    for i in range(nx):
        for j in range(ny):
            for k in range(nz):
                l = ((i + 0.5) / nx * sx - sx / 2, (j + 0.5) / ny * sy - sy / 2, (k + 0.5) / nz * sz - sz / 2)
                w = tuple(sum(a.rot[r][c] * l[c] for c in range(3)) + a.pos[r] for r in range(3))
                if inside(b, w):
                    hits += 1
    return hits / (nx * ny * nz) * sx * sy * sz


def model_of(node, region):
    """The sub-model a part belongs to; loose run chunks (Name_00, Name_00_cap) group by their run."""
    n = node
    while n.parent and n.parent.name != region:
        n = n.parent
    if n is node:
        m = re.match(r"(.+?)_\d\d", node.name or "")
        return m.group(1) if m else node
    return n


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    md = "--md" in sys.argv
    tree = ET.parse(args[0]).getroot()
    region = args[1] if len(args) > 1 else "IronLowlands"
    services = {n.name: n for n in (Node(i, None) for i in tree.findall("Item"))}
    lemap = services["Workspace"].find("LemonadeMap")
    reg = lemap.find(region)
    grounds = [p for p in lemap.find(f"Grounds_{region}").descendants() if p.is_part]
    all_grounds = [p for g in lemap.children if g.name.startswith("Grounds_") for p in g.descendants() if p.is_part]
    proxies = [p for p in lemap.find("Collision").descendants() if p.is_part]
    parts = [p for p in reg.descendants() if p.is_part]
    markers = lemap.find("Markers")
    spawns = [s for s in markers.find("EnemySpawns").children if s.is_part and s.attrs.get("Region") == region]
    for p in parts + grounds + proxies + all_grounds:
        p.box = xz_aabb(p)
    out = []

    def line(s=""):
        out.append(s)

    # 1. Census
    def count(items, pred):
        return sum(1 for i in items if pred(i))
    lights = [n for n in reg.descendants() if n.cls == "PointLight"]
    fires = [n for n in reg.descendants() if n.cls == "Fire"]
    smokes = [n for n in reg.descendants() if n.cls == "Smoke"]
    guis = [n for n in reg.descendants() if n.cls == "SurfaceGui"]
    classes = {}
    for p in parts:
        classes[p.cls] = classes.get(p.cls, 0) + 1
    region_box = (min(p.box[0] for p in grounds), max(p.box[1] for p in grounds), min(p.box[4] for p in grounds), max(p.box[5] for p in grounds))
    my_proxies = [p for p in proxies if region_box[0] - 20 <= p.pos[0] <= region_box[1] + 20 and region_box[2] - 20 <= p.pos[2] <= region_box[3] + 20]
    line(f"## Census — {region}")
    line()
    line("| Item | Value |")
    line("| --- | --- |")
    line(f"| Parts in `{region}` | {len(parts)} ({', '.join(f'{k} {v}' for k, v in sorted(classes.items()))}) |")
    line(f"| Floors in `Grounds_{region}` | {len(grounds)} |")
    line(f"| Wall proxies near the region | {len(my_proxies)} |")
    line(f"| Unanchored parts | {count(parts + grounds, lambda p: not p.anchored)} |")
    line(f"| Collidable / decorative | {count(parts, lambda p: p.collide)} / {count(parts, lambda p: not p.collide)} |")
    line(f"| PointLights | {len(lights)} (budget {LIGHT_BUDGET}) |")
    line(f"| Fire / Smoke / SurfaceGui | {len(fires)} / {len(smokes)} / {len(guis)} |")
    line(f"| Streaming mode | {reg.streaming} (Atomic only for the hub) |")
    line()

    # 2. Cross-model overlaps between collidable opaque parts.
    solids = [p for p in parts if p.collide and p.transparency < 0.9]
    hits = []
    for i, a in enumerate(solids):
        for b in solids[i + 1:]:
            if model_of(a, region) == model_of(b, region):
                continue
            ab, bb = a.box, b.box
            if ab[0] > bb[1] or bb[0] > ab[1] or ab[2] > bb[3] or bb[2] > ab[3] or ab[4] > bb[5] or bb[4] > ab[5]:
                continue
            v = obb_overlap_volume(a, b)
            if v > 8:
                hits.append((v, a, b))
    line("## Cross-model overlaps (collidable, > 8 studs³)")
    line()
    if hits:
        line("| Studs³ | A | B |")
        line("| ---: | --- | --- |")
        for v, a, b in sorted(hits, reverse=True, key=lambda h: h[0]):
            line(f"| {v:.0f} | {a.path().replace('Workspace.LemonadeMap.', '')} | {b.path().replace('Workspace.LemonadeMap.', '')} |")
    else:
        line("None.")
    line()

    # 3. Props buried in cut faces / cliff chunks; 4. sunk > 0.6 into floors.
    cliffs = [p for p in parts if ("Cliff" in (p.name or "") or "Face" in (p.name or "") or "Ridge" in (p.name or "")
                                  or "Pass" in (p.name or "") or "Rim" in (p.name or "") or "Mid" in (p.name or "") or "Pit" in (p.name or ""))
              and p.parent is reg and p.cls == "Part" and not p.collide or ("_Proxy" in (p.name or ""))]
    cliffs = [p for p in parts if p.parent is reg and any(k in (p.name or "") for k in ("West", "East", "North", "South", "Ridge", "Face"))]
    buried = []
    for p in parts:
        if p in cliffs or p.transparency >= 0.9 or any(k in (p.name or "") for k in ("Moss", "DrillHole", "Ledge")) or "Manacle" in p.path():
            continue
        if any(inside(c, p.pos) for c in cliffs):
            buried.append(p)
    line("## Props with their centre inside a cut face or cliff chunk")
    line()
    line("None." if not buried else "\n".join(f"- {p.path().replace('Workspace.LemonadeMap.', '')}" for p in buried))
    line()

    def floor_under(x, z):
        best = None
        for f in all_grounds:
            if aabb_distance_xz(f.box, x, z) > 0:
                continue
            y = top_at(f, x, z)
            if y is not None and (best is None or y > best):
                best = y
        return best
    sunk = []
    for p in parts:
        if p.transparency >= 0.9 or p in cliffs:
            continue
        bottom, top = vertical_extent(p)
        fy = floor_under(p.pos[0], p.pos[2])
        if fy is not None and fy - bottom > 0.6 and top > fy and (top - bottom) < 6:
            sunk.append((fy - bottom, p))
    line("## Small parts sunk more than 0.6 into a floor")
    line()
    if sunk:
        for d, p in sorted(sunk, reverse=True, key=lambda s: s[0])[:40]:
            line(f"- {d:.2f} studs: {p.path().replace('Workspace.LemonadeMap.', '')}")
        if len(sunk) > 40:
            line(f"- … {len(sunk) - 40} more")
    else:
        line("None.")
    line()

    # 5. Seams between floors: sample along each floor's edges, look for a neighbouring floor top within 0.05.
    line("## Floor seams and ramp grades")
    line()
    line("| Floor | Bottom Y | Top Y (min–max) | Grade | Rests on |")
    line("| --- | ---: | --- | ---: | --- |")
    for g in sorted(grounds, key=lambda g: g.name):
        ymin, ymax = g.box[2], g.box[3]
        r = g.rot
        grade = math.degrees(math.acos(min(1.0, abs(r[1][1])))) if g.shape != 2 else 0.0
        # top at the four corner columns
        tops = []
        for cx, cz in ((g.box[0] + 0.6, g.box[4] + 0.6), (g.box[1] - 0.6, g.box[4] + 0.6), (g.box[0] + 0.6, g.box[5] - 0.6),
                       (g.box[1] - 0.6, g.box[5] - 0.6), (g.pos[0], g.pos[2]), (g.pos[0], g.box[4] + 0.6), (g.pos[0], g.box[5] - 0.6)):
            t = top_at(g, cx, cz)
            if t is not None:
                tops.append(t)
        tops = tops or [g.box[3]]
        rests = "Baseplate" if ymin <= 0.05 else ""
        if not rests:  # another floor whose body reaches the underside (ramps sink into the lower bench)
            below = [f for f in all_grounds if f is not g and f.box[3] >= ymin - 0.3 and f.box[2] <= ymin
                     and aabb_distance_xz(f.box, g.pos[0], g.pos[2]) == 0]
            rests = ", ".join(f.name for f in below) or "**nothing**"
        line(f"| {g.name} | {ymin:.2f} | {min(tops):.2f}–{max(tops):.2f} | {grade:.1f}° | {rests} |")
    line()
    gaps = []
    for g in grounds:
        if g.shape == 2 or abs(g.rot[1][1]) < 0.999:
            continue
        x0, x1, _, _, z0, z1 = g.box
        top = g.box[3]
        for (px, pz, ox, oz) in ((x0 - 0.3, (z0 + z1) / 2, -1, 0), (x1 + 0.3, (z0 + z1) / 2, 1, 0), ((x0 + x1) / 2, z0 - 0.3, 0, -1), ((x0 + x1) / 2, z1 + 0.3, 0, 1)):
            fy = floor_under(px, pz)
            inside_pt = floor_under(px - ox * 0.6, pz - oz * 0.6)
            if fy is None:
                continue
            if abs(fy - top) < 0.05 or fy > top:
                continue
            if 0.05 < top - fy < 0.7:
                gaps.append((g.name, px, pz, top - fy))
    line("Edge steps between 0.05 and 0.7 studs (lips a player trips on):")
    line()
    line("None." if not gaps else "\n".join(f"- {n} at ({px:.0f}, {pz:.0f}): {d:.2f}" for n, px, pz, d in gaps))
    line()

    # 7. Collision fidelity.
    mesh = [p for p in parts + grounds if p.cls not in ("Part", "WedgePart")]
    deco_collide = [p for p in parts if p.collide and any(k in (p.name or "") for k in ("Rag", "Moss", "Rubble", "Lantern", "Banner", "Cloth", "Chain"))]
    line("## Collision fidelity")
    line()
    line(f"- Non-Part/WedgePart instances: {len(mesh)}")
    line(f"- Collidable decoration (rags, moss, rubble, lanterns, chains): {len(deco_collide)}"
         + ("" if not deco_collide else " — " + ", ".join(p.path().replace('Workspace.LemonadeMap.', '') for p in deco_collide)))
    line()

    # 9. Lanes and spawn clearance.
    lane_hits, spawn_hits = [], []
    for p in solids:
        for (x0, x1, z0, z1) in LANES.get(region, []):
            b = p.box
            if b[0] < x1 and b[1] > x0 and b[4] < z1 and b[5] > z0:
                fy = floor_under(p.pos[0], p.pos[2])
                lane_y = floor_under((x0 + x1) / 2, (z0 + z1) / 2)
                if fy is not None and lane_y is not None and abs(fy - lane_y) < 1.6 and b[3] > fy + 0.5:
                    lane_hits.append((p, (x0, x1, z0, z1)))
                    break
        for s in spawns:
            if aabb_distance_xz(p.box, s.pos[0], s.pos[2]) < 4 and p.box[3] > s.pos[1] + 0.3:
                spawn_hits.append((p, s))
    line("## Lanes and spawn clearance")
    line()
    line("Collidable parts inside a main lane: " + ("none." if not lane_hits else ", ".join(p.path().replace('Workspace.LemonadeMap.', '') for p, _ in lane_hits)))
    line()
    line("Collidable parts within 4 studs of a spawn: " + ("none." if not spawn_hits else ", ".join(f"{p.path().replace('Workspace.LemonadeMap.', '')} ({s.name})" for p, s in spawn_hits)))
    line()
    line("## Lights")
    line()
    for l in lights:
        line(f"- {l.parent.path().replace('Workspace.LemonadeMap.', '')}")
    print("\n".join(out))


if __name__ == "__main__":
    main()
