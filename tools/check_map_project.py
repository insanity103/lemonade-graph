#!/usr/bin/env python3
"""Validate the built map project (Rojo output), not a running Studio session.

    rojo build map.project.json -o /tmp/lemonade-map.rbxlx
    python3 tools/check_map_project.py /tmp/lemonade-map.rbxlx [--report docs/map/VALIDATION.md]

Checks the marker schema, that gameplay markers stand on real floors with clearance, that safe
zones and combat spawns do not overlap, that arrivals sit outside aggro range, camera clearance
above combat and arrival points, and walk distances from spawn over a 2-stud navigation grid.
It also confirms map.project.json extends default.project.json without altering its mappings.
"""
from __future__ import annotations

import base64
import heapq
import json
import math
import re
import struct
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WALK_SPEED, RUN_SPEED = 16, 26  # RunController.client.luau
CELL = 2.0

failures: list[str] = []
notes: list[str] = []


def fail(msg: str):
    failures.append(msg)


# ── rbxlx parsing ─────────────────────────────────────────────────────────────
def decode_attributes(blob: str) -> dict:
    data = base64.b64decode(blob or "")
    if not data:
        return {}
    out, i = {}, 4
    (count,) = struct.unpack_from("<I", data, 0)
    for _ in range(count):
        (klen,) = struct.unpack_from("<I", data, i)
        i += 4
        key = data[i:i + klen].decode()
        i += klen
        kind = data[i]
        i += 1
        if kind == 0x02:
            (vlen,) = struct.unpack_from("<I", data, i)
            i += 4
            out[key] = data[i:i + vlen].decode()
            i += vlen
        elif kind == 0x03:
            out[key] = bool(data[i])
            i += 1
        elif kind == 0x05:
            (out[key],) = struct.unpack_from("<f", data, i)
            i += 4
        elif kind == 0x06:
            (out[key],) = struct.unpack_from("<d", data, i)
            i += 8
        else:
            raise ValueError(f"unsupported attribute type {kind} for {key}")
    return out


class Node:
    def __init__(self, item, parent):
        self.cls = item.attrib["class"]
        props = item.find("Properties")
        self.name = props.findtext("string[@name='Name']")
        self.parent = parent
        self.children: list[Node] = []
        self.attrs = decode_attributes(props.findtext("BinaryString[@name='AttributesSerialize']") or "")
        cf = props.find("CoordinateFrame[@name='CFrame']")
        self.cframe = None
        if cf is not None:
            v = {c.tag: float(c.text) for c in cf}
            self.pos = (v["X"], v["Y"], v["Z"])
            self.rot = [[v["R00"], v["R01"], v["R02"]], [v["R10"], v["R11"], v["R12"]], [v["R20"], v["R21"], v["R22"]]]
            self.cframe = True
        size = props.find("Vector3[@name='size']")
        self.size = tuple(float(size.findtext(a)) for a in "XYZ") if size is not None else None

        def boolean(prop, default):
            text = props.findtext(f"bool[@name='{prop}']")
            return default if text is None else text == "true"

        self.collide = boolean("CanCollide", True)
        self.query = boolean("CanQuery", True)
        self.touch = boolean("CanTouch", True)
        self.anchored = boolean("Anchored", False)
        self.transparency = float(props.findtext("float[@name='Transparency']") or 0)
        self.shape = int(props.findtext("token[@name='shape']") or 1)  # 0 Ball, 1 Block, 2 Cylinder
        mode = props.findtext("token[@name='ModelStreamingMode']")
        self.streaming = {None: "Default", "0": "Default", "1": "Atomic", "2": "Persistent", "3": "PersistentPerPlayer",
                          "4": "Nonatomic"}.get(mode, mode)
        for child in item.findall("Item"):
            self.children.append(Node(child, self))

    def find(self, name):
        return next((c for c in self.children if c.name == name), None)

    def descendants(self):
        for c in self.children:
            yield c
            yield from c.descendants()

    @property
    def is_part(self):
        return self.size is not None and self.cframe

    def path(self):
        parts, node = [], self
        while node:
            parts.append(node.name or "?")
            node = node.parent
        return ".".join(reversed(parts))


# ── Geometry ──────────────────────────────────────────────────────────────────
def to_local(node, p):
    d = [p[i] - node.pos[i] for i in range(3)]
    r = node.rot
    return tuple(r[0][j] * d[0] + r[1][j] * d[1] + r[2][j] * d[2] for j in range(3))


def inside(node, p, inflate=0.0):
    lx, ly, lz = to_local(node, p)
    sx, sy, sz = node.size
    return abs(lx) <= sx / 2 + inflate and abs(ly) <= sy / 2 + inflate and abs(lz) <= sz / 2 + inflate


def top_at(node, x, z):
    """World Y of the part's top face above (x, z), or None if (x, z) is outside its footprint."""
    r = node.rot
    if node.shape == 2 and abs(r[1][0]) > 0.99:  # disc: cylinder axis (local X) vertical
        if math.hypot(x - node.pos[0], z - node.pos[2]) <= node.size[1] / 2:
            return node.pos[1] + node.size[0] / 2
        return None
    if abs(r[1][1]) < 0.2:
        return None
    sx, sy, sz = node.size
    dx, dz = x - node.pos[0], z - node.pos[2]
    y = node.pos[1] + (sy / 2 - r[0][1] * dx - r[2][1] * dz) / r[1][1]
    lx, _, lz = to_local(node, (x, y, z))
    if abs(lx) <= sx / 2 + 1e-6 and abs(lz) <= sz / 2 + 1e-6:
        return y
    return None


def vertical_extent(node):
    """(bottom, top) world Y of the part on the vertical line through its centre. For rotated boxes
    the ray leaves through whichever face it meets first, so a tilted beam's 'bottom' is its
    underside, not its lowest corner."""
    r = node.rot
    if node.shape == 0:  # ball
        h = node.size[0] / 2
    elif node.shape == 2 and abs(r[1][0]) > 0.99:  # disc
        h = node.size[0] / 2
    else:
        h = min(node.size[k] / (2 * abs(r[1][k])) for k in range(3) if abs(r[1][k]) > 1e-6)
        if node.shape == 2:  # cylinder radius bounds the vertical extent
            h = min(h, max(node.size[1], node.size[2]) / 2) if abs(r[1][0]) < 0.99 else h
    return node.pos[1] - h, node.pos[1] + h


def bottom_at(node, x, z):
    """World Y of the part's bottom face below (x, z), or None outside its footprint."""
    r = node.rot
    if node.shape == 2 and abs(r[1][0]) > 0.99:
        if math.hypot(x - node.pos[0], z - node.pos[2]) <= node.size[1] / 2:
            return node.pos[1] - node.size[0] / 2
        return None
    if abs(r[1][1]) < 0.2:
        return None
    sx, sy, sz = node.size
    dx, dz = x - node.pos[0], z - node.pos[2]
    y = node.pos[1] + (-sy / 2 - r[0][1] * dx - r[2][1] * dz) / r[1][1]
    lx, _, lz = to_local(node, (x, y, z))
    if abs(lx) <= sx / 2 + 1e-6 and abs(lz) <= sz / 2 + 1e-6:
        return y
    return None


def sample_points(node):
    """Centre, 8 corners, 12 edge midpoints and 6 face centres in world space."""
    sx, sy, sz = node.size
    pts = []
    for ix in (-1, 0, 1):
        for iy in (-1, 0, 1):
            for iz in (-1, 0, 1):
                l = (ix * sx / 2, iy * sy / 2, iz * sz / 2)
                pts.append(tuple(sum(node.rot[i][k] * l[k] for k in range(3)) + node.pos[i] for i in range(3)))
    return pts


def touches(a, b, inflate=0.12):
    """True when a sample point of either part lies inside the other (inflated a little, so parts
    butted against each other with a hairline gap still count as attached)."""
    if getattr(a, "pts", None) is None:
        a.pts = sample_points(a)
    if getattr(b, "pts", None) is None:
        b.pts = sample_points(b)
    return any(inside(b, p, inflate) for p in a.pts) or any(inside(a, p, inflate) for p in b.pts)


def xz_aabb(node):
    sx, sy, sz = node.size
    xs, ys, zs = [], [], []
    for cx in (-1, 1):
        for cy in (-1, 1):
            for cz in (-1, 1):
                l = (cx * sx / 2, cy * sy / 2, cz * sz / 2)
                w = [sum(node.rot[i][k] * l[k] for k in range(3)) + node.pos[i] for i in range(3)]
                xs.append(w[0]); ys.append(w[1]); zs.append(w[2])
    return min(xs), max(xs), min(ys), max(ys), min(zs), max(zs)


def aabb_distance_xz(box, x, z):
    x0, x1, _, _, z0, z1 = box
    dx = max(x0 - x, 0, x - x1)
    dz = max(z0 - z, 0, z - z1)
    return math.hypot(dx, dz)


# ── Load everything ───────────────────────────────────────────────────────────
def main():
    args = sys.argv[1:]
    report_path = None
    if "--report" in args:
        report_path = Path(args[args.index("--report") + 1])
        args = [a for a in args if a not in ("--report", str(report_path))]
    tree = ET.parse(args[0]).getroot()
    services = {n.name: n for n in (Node(i, None) for i in tree.findall("Item"))}

    check_projects()
    archetypes = parse_archetypes()
    zones = set(re.findall(r'Name = "(\w+)"', (ROOT / "lemonade-game/Gameplay/WorldLayout.luau").read_text()))

    ws = services.get("Workspace")
    if not ws:
        fail("Workspace not packaged")
        return finish(report_path)
    lemap = ws.find("LemonadeMap")
    if not lemap:
        fail("Workspace.LemonadeMap missing")
        return finish(report_path)
    markers = lemap.find("Markers")
    grounds = [p for g in lemap.children if g.name.startswith("Grounds_") for p in g.descendants() if p.is_part]
    collision = lemap.find("Collision")
    for folder in ("NPCs", "SafeZones", "Regions", "EnemySpawns", "Waypoints", "Gates"):
        if not markers or not markers.find(folder):
            fail(f"Markers/{folder} missing")
    if failures:
        return finish(report_path)
    if not grounds:
        fail("No Grounds_* floors")
    if not collision or not collision.children:
        fail("Collision proxies missing")

    ground_ids = {id(p) for p in grounds}
    all_parts = [p for p in lemap.descendants() if p.is_part]
    marker_parts = {id(p) for p in markers.descendants() if p.is_part}
    solids = [p for p in all_parts if p.collide and id(p) not in ground_ids and id(p) not in marker_parts]
    visual_parts = [p for p in all_parts if id(p) not in marker_parts]
    notes.append(f"{len(all_parts)} parts: {len(grounds)} floor, {len(solids)} collidable solids, "
                 f"{len(collision.children)} wall proxies, {len(marker_parts)} markers/volumes")

    # Every part anchored; markers invisible and inert; floors collidable.
    for p in all_parts:
        if not p.anchored:
            fail(f"Unanchored part {p.path()}")
    for m in markers.descendants():
        if m.is_part and (m.collide or m.query or m.touch or m.transparency < 1):
            fail(f"Marker {m.path()} must be invisible, non-colliding, non-query, non-touch")
    for g in grounds:
        if not g.collide:
            fail(f"Floor {g.path()} does not collide")

    def floor_y(x, z, near_y=None):
        best = None
        for g in grounds:
            y = top_at(g, x, z)
            if y is None:
                continue
            if near_y is None or abs(y - near_y) <= 1.6:
                best = y if best is None else max(best, y)
        return best

    def blocked_near(x, y, z, radius, height=6.0):
        for s in solids:
            box = s.box
            if aabb_distance_xz(box, x, z) > radius + 0.5 or box[3] < y + 0.3 or box[2] > y + height:
                continue
            for hy in (0.8, 2.5, 4.5):
                for ox, oz in ((0, 0), (radius, 0), (-radius, 0), (0, radius), (0, -radius)):
                    if inside(s, (x + ox, y + hy, z + oz), 0.1):
                        return s
        return None

    for s in solids:
        s.box = xz_aabb(s)

    # NPC markers.
    npcs = markers.find("NPCs")
    for required in ("QuestMaster", "Merchant", "SkillTrainer", "RebirthKeeper", "Vaultkeeper"):
        n = npcs.find(required)
        if not n:
            fail(f"NPC marker {required} missing")
            continue
        fy = floor_y(n.pos[0], n.pos[2], n.pos[1])
        if fy is None:
            fail(f"NPC {required} is not on a floor at {n.pos}")
        hit = blocked_near(n.pos[0], n.pos[1], n.pos[2], 1.5)
        if hit:
            fail(f"NPC {required} overlaps {hit.path()}")

    # Safe zones.
    safe = [z for z in markers.find("SafeZones").children if z.is_part]
    if not safe:
        fail("No safe zones")

    def in_safe(p):
        return any(inside(z, p) for z in safe)

    def safe_distance(x, z):
        return min(aabb_distance_xz(xz_aabb(s), x, z) for s in safe)

    # Enemy spawns.
    spawns = [s for s in markers.find("EnemySpawns").children if s.is_part]
    if not spawns:
        fail("No enemy spawns")
    for s in spawns:
        a = s.attrs
        arch = archetypes.get(a.get("Archetype"))
        if not arch:
            fail(f"Spawn {s.name}: unknown archetype {a.get('Archetype')}")
            continue
        if a.get("Zone") not in zones:
            fail(f"Spawn {s.name}: zone {a.get('Zone')} is not in WorldLayout.ZONES")
        if a.get("Role") not in ("minion", "elite", "boss"):
            fail(f"Spawn {s.name}: bad role {a.get('Role')}")
        if not isinstance(a.get("Level"), float) or a["Level"] < 1 or a["Level"] != int(a["Level"]):
            fail(f"Spawn {s.name}: bad level {a.get('Level')}")
        if not isinstance(a.get("LeashRadius"), float) or a["LeashRadius"] < 8:
            fail(f"Spawn {s.name}: bad LeashRadius {a.get('LeashRadius')}")
        fy = floor_y(s.pos[0], s.pos[2], s.pos[1])
        if fy is None:
            fail(f"Spawn {s.name} not on a floor at {s.pos}")
        hit = blocked_near(s.pos[0], s.pos[1], s.pos[2], 3.0 * max(1.0, arch["scale"]))
        if hit:
            fail(f"Spawn {s.name} overlaps solid {hit.path()}")
        if in_safe(s.pos):
            fail(f"Spawn {s.name} is inside a safe zone")
        reach = arch["aggroRange"] + arch["patrolRadius"]
        d = safe_distance(s.pos[0], s.pos[2])
        if d < arch["patrolRadius"] + 6:
            fail(f"Spawn {s.name} patrols into a safe zone ({d:.1f} studs from its edge)")
        s.reach = reach
        s.arch = arch

    # Waypoints and waystones.
    waypoints = {w.name: w for w in markers.find("Waypoints").children if w.is_part}
    for wid, w in waypoints.items():
        if not w.attrs.get("DisplayName") or not w.attrs.get("Region"):
            fail(f"Waypoint {wid} missing DisplayName/Region")
        if floor_y(w.pos[0], w.pos[2], w.pos[1]) is None:
            fail(f"Waypoint {wid} arrival not on a floor")
        hit = blocked_near(w.pos[0], w.pos[1], w.pos[2], 2.0)
        if hit:
            fail(f"Waypoint {wid} arrival overlaps {hit.path()}")
        for s in spawns:
            if not hasattr(s, "reach"):
                continue
            d = math.dist((w.pos[0], w.pos[2]), (s.pos[0], s.pos[2]))
            if d < s.reach:
                fail(f"Waypoint {wid} is inside {s.name}'s aggro+patrol reach ({d:.1f} < {s.reach:.0f})")
    stones = [n for n in lemap.descendants() if n.attrs.get("Waystone")]
    linked = set()
    for st in stones:
        wid = st.attrs.get("WaypointId")
        w = waypoints.get(wid)
        obelisk = (next((c for c in st.children if c.name == "PromptAnchor"), None)
                   or next((c for c in st.children if c.name == "Core"), None))
        if not w or not obelisk:
            fail(f"Waystone {st.path()} links to unknown waypoint {wid}")
            continue
        linked.add(wid)
        if math.dist(obelisk.pos, w.pos) > 20:
            fail(f"Waystone for {wid} is {math.dist(obelisk.pos, w.pos):.1f} studs from its arrival point")
    for wid in waypoints:
        if wid not in linked:
            fail(f"Waypoint {wid} has no waystone")
    if "HubSpawn" not in waypoints:
        fail("HubSpawn waypoint missing (Return to Hub target)")

    spawn_location = markers.find("PlayerSpawn")
    if not spawn_location or spawn_location.cls != "SpawnLocation":
        fail("Markers/PlayerSpawn SpawnLocation missing")
    elif not in_safe(spawn_location.pos):
        fail("Player spawn is outside every safe zone")

    # Gates: sealed gates must be physically closed.
    for g in markers.find("Gates").children:
        if g.attrs.get("Sealed"):
            near = [p for p in collision.descendants() if p.is_part] + [p for p in solids if p.name == "SealProxy"]
            if not any(p.name == "SealProxy" and math.dist((p.pos[0], p.pos[2]), (g.pos[0], g.pos[2])) < 6 for p in near):
                if not any(p.name == "VoidVeil" and p.collide and math.dist((p.pos[0], p.pos[2]), (g.pos[0], g.pos[2])) < 6
                           for p in solids):
                    fail(f"Sealed gate {g.name} has no blocker")

    # Regions cover every spawn and waypoint.
    regions = [r for r in markers.find("Regions").children if r.is_part]
    for thing in spawns + list(waypoints.values()):
        if not any(inside(r, thing.pos) for r in regions):
            fail(f"{thing.name} is outside every Region volume")

    # Camera clearance: nothing solid or opaque 8–28 studs above combat and arrival points.
    for thing in spawns + list(waypoints.values()):
        fy = floor_y(thing.pos[0], thing.pos[2], thing.pos[1]) or thing.pos[1]
        radius = 12 if thing in spawns else 8
        for p in visual_parts:
            if p.transparency >= 0.9 and not p.collide:
                continue
            box = getattr(p, "box", None) or xz_aabb(p)
            p.box = box
            if aabb_distance_xz(box, thing.pos[0], thing.pos[2]) <= radius and fy + 8 < box[2] < fy + 28 and box[3] > fy + 8:
                fail(f"Camera clearance: {p.path()} hangs over {thing.name}")
                break

    check_coplanar_tops(visual_parts)
    check_support([p for p in visual_parts if id(p) not in ground_ids and p not in collision.descendants()], grounds)

    travel = navigate(grounds, solids, spawn_location, spawns, waypoints, lemap, markers)
    finish(report_path, travel)


def check_support(parts, grounds, tol_float=0.4):
    """Every visible part must stand on a floor, rest on / hang from / be attached to another part.
    Reports floating parts (nothing within reach) and buried ones (entirely inside a floor)."""
    floors = list(grounds)
    for f in floors:
        f.box = getattr(f, "box", None) or xz_aabb(f)
    # FloatShard pieces orbit the waystones by design (HubAmbience animates them).
    opaque = [p for p in parts if p.transparency < 0.9 and not p.name.startswith("FloatShard")]
    for p in opaque:
        p.box = getattr(p, "box", None) or xz_aabb(p)
    # coarse XZ grid for neighbour lookup
    cell = 16.0
    grid = {}
    for p in opaque:
        x0, x1, _, _, z0, z1 = p.box
        for i in range(int(x0 // cell), int(x1 // cell) + 1):
            for j in range(int(z0 // cell), int(z1 // cell) + 1):
                grid.setdefault((i, j), []).append(p)

    def floor_under(x, z):
        best = None
        for f in floors:
            if aabb_distance_xz(f.box, x, z) > 0:
                continue
            y = top_at(f, x, z)
            if y is not None and (best is None or y > best):
                best = y
        return best

    floating, buried = [], []
    for p in opaque:
        bottom, top = vertical_extent(p)
        cx, cz = p.pos[0], p.pos[2]
        fy = floor_under(cx, cz)
        if fy is not None and top <= fy + 0.05:
            buried.append((p, fy))
            continue
        if fy is not None and bottom - fy <= tol_float:
            continue  # on the floor (or sunk into it)
        # lowest corner on a floor (tilted posts, ladders, curb logs)
        _, _, ymin, _, _, _ = p.box
        low = min(p.pts if getattr(p, "pts", None) else sample_points(p), key=lambda q: q[1])
        p.pts = p.pts if getattr(p, "pts", None) else sample_points(p)
        fyc = floor_under(low[0], low[2])
        if fyc is not None and low[1] - fyc <= tol_float:
            continue
        # resting on, hanging from, or attached to another part
        x0, x1, _, _, z0, z1 = p.box
        supported = False
        seen = set()
        for i in range(int(x0 // cell), int(x1 // cell) + 1):
            for j in range(int(z0 // cell), int(z1 // cell) + 1):
                for q in grid.get((i, j), ()):
                    if q is p or id(q) in seen:
                        continue
                    seen.add(id(q))
                    qb = q.box
                    if qb[0] > x1 + 0.5 or qb[1] < x0 - 0.5 or qb[4] > z1 + 0.5 or qb[5] < z0 - 0.5:
                        continue
                    if qb[3] < bottom - 0.5 or qb[2] > top + 0.5:
                        continue
                    qt = top_at(q, cx, cz)
                    if qt is not None and abs(bottom - qt) <= tol_float:
                        supported = True
                        break
                    qb_y = bottom_at(q, cx, cz)
                    if qb_y is not None and abs(top - qb_y) <= tol_float:
                        supported = True
                        break
                    if touches(p, q):
                        supported = True
                        break
                if supported:
                    break
            if supported:
                break
        if not supported:
            floating.append((p, bottom, fy))
    for p, bottom, fy in floating:
        gap = "no floor" if fy is None else f"{bottom - fy:.2f} above floor y={fy:.2f}"
        fail(f"Floating: {p.path()} bottom y={bottom:.2f}, {gap}, touching nothing")
    for p, fy in buried:
        fail(f"Buried: {p.path()} lies entirely under floor y={fy:.2f}")
    notes.append(f"support rule: {len(opaque)} visible parts checked, {len(floating)} floating, {len(buried)} buried")


def check_coplanar_tops(parts):
    """Visible horizontal top faces at the same height must not overlap: coplanar overlaps
    z-fight, which reads in-game as floor textures crawling while the camera moves."""
    buckets = {}
    for p in parts:
        if p.transparency >= 0.9 or p.cls == "WedgePart" or p.shape == 0:  # balls have no flat top
            continue
        r = p.rot
        if p.shape == 2 and abs(r[1][0]) > 0.99:
            top = p.pos[1] + p.size[0] / 2
        elif abs(abs(r[1][1]) - 1) < 1e-3:
            top = p.pos[1] + p.size[1] / 2
        else:
            continue
        p.box = getattr(p, "box", None) or xz_aabb(p)
        buckets.setdefault(round(top * 20), []).append(p)
    seen = set()
    for key, group in buckets.items():
        group = group + buckets.get(key + 1, [])
        for i, a in enumerate(group):
            for b in group[i + 1:]:
                pair = tuple(sorted((id(a), id(b))))
                if pair in seen:
                    continue
                seen.add(pair)
                ax0, ax1, _, _, az0, az1 = a.box
                bx0, bx1, _, _, bz0, bz1 = b.box
                ox, oz = min(ax1, bx1) - max(ax0, bx0), min(az1, bz1) - max(az0, bz0)
                if ox <= 0.05 or oz <= 0.05 or ox * oz < 1.5:  # slivers under trim are not visible
                    continue
                # confirm with a sample point inside both footprints
                cx, cz = (max(ax0, bx0) + min(ax1, bx1)) / 2, (max(az0, bz0) + min(az1, bz1)) / 2
                ya, yb = top_at(a, cx, cz), top_at(b, cx, cz)
                if ya is not None and yb is not None and abs(ya - yb) < 0.05:
                    fail(f"Coplanar overlapping tops (z-fighting): {a.path()} and {b.path()} at y={ya:.2f}")


def navigate(grounds, solids, spawn_location, spawns, waypoints, lemap, markers):
    """2-stud grid: walkable where a floor exists and no solid occupies body height above it."""
    x0, x1, z0, z1 = -176, 150, -104, 960
    nx, nz = int((x1 - x0) / CELL), int((z1 - z0) / CELL)
    height = [[None] * nz for _ in range(nx)]
    for g in grounds:
        bx0, bx1, _, _, bz0, bz1 = xz_aabb(g)
        for i in range(max(0, int((bx0 - x0) / CELL)), min(nx, int((bx1 - x0) / CELL) + 1)):
            for j in range(max(0, int((bz0 - z0) / CELL)), min(nz, int((bz1 - z0) / CELL) + 1)):
                cx, cz = x0 + (i + 0.5) * CELL, z0 + (j + 0.5) * CELL
                y = top_at(g, cx, cz)
                if y is not None and (height[i][j] is None or y > height[i][j]):
                    height[i][j] = y
    blocked = [[False] * nz for _ in range(nx)]
    for s in solids:
        bx0, bx1, by0, by1, bz0, bz1 = s.box
        for i in range(max(0, int((bx0 - 1 - x0) / CELL)), min(nx, int((bx1 + 1 - x0) / CELL) + 1)):
            for j in range(max(0, int((bz0 - 1 - z0) / CELL)), min(nz, int((bz1 + 1 - z0) / CELL) + 1)):
                h = height[i][j]
                if h is None or blocked[i][j] or by1 < h + 0.5 or by0 > h + 5.5:
                    continue
                cx, cz = x0 + (i + 0.5) * CELL, z0 + (j + 0.5) * CELL
                if any(inside(s, (cx, h + hy, cz), 0.9) for hy in (1.0, 3.0, 5.0)):
                    blocked[i][j] = True

    def cell(p):
        return int((p[0] - x0) / CELL), int((p[2] - z0) / CELL)

    def dijkstra(start):
        dist = {start: 0.0}
        heap = [(0.0, start)]
        while heap:
            d, (i, j) = heapq.heappop(heap)
            if d > dist[(i, j)]:
                continue
            h = height[i][j]
            for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)):
                a, b = i + di, j + dj
                if not (0 <= a < nx and 0 <= b < nz) or blocked[a][b] or height[a][b] is None:
                    continue
                step = height[a][b] - h
                if step > 1.25 or step < -12:
                    continue
                if di and dj and (blocked[i + di][j] or blocked[i][j + dj]):
                    continue
                nd = d + CELL * (1.4142 if di and dj else 1.0)
                if nd < dist.get((a, b), 1e18):
                    dist[(a, b)] = nd
                    heapq.heappush(heap, (nd, (a, b)))
        return dist

    start = cell(spawn_location.pos)
    if blocked[start[0]][start[1]] or height[start[0]][start[1]] is None:
        fail("Player spawn cell is not walkable")
        return []
    from_spawn = dijkstra(start)

    def reach(dist, p, radius=3):
        ci, cj = cell(p)
        best = None
        for i in range(ci - radius, ci + radius + 1):
            for j in range(cj - radius, cj + radius + 1):
                if (i, j) in dist and (best is None or dist[(i, j)] < best):
                    best = dist[(i, j)]
        return best

    rows = []
    gate = next((g for g in markers.find("Gates").children if g.name == "IronLowlands"), None)
    targets = []
    if gate:
        targets.append(("Iron Lowlands gate", (gate.pos[0], gate.pos[1], gate.pos[2] + 3)))
    npcs = markers.find("NPCs")
    for n in npcs.children:
        targets.append((f"NPC {n.name}", n.pos))
    for w in waypoints.values():
        targets.append((f"Waypoint {w.name}", w.pos))
    for s in sorted(spawns, key=lambda s: s.pos[2]):
        targets.append((f"{s.name} ({s.attrs.get('Archetype')} L{int(s.attrs.get('Level', 0))})", s.pos))
    for label, p in targets:
        d = reach(from_spawn, p)
        if d is None:
            fail(f"Unreachable from spawn: {label}")
            rows.append((label, None))
        else:
            rows.append((label, d))

    # Encounter spacing: walking distance from each minion to its nearest other spawn.
    spacing = []
    for s in spawns:
        if s.attrs.get("Role") == "boss":
            continue
        dist = dijkstra(cell(s.pos))
        others = [(reach(dist, o.pos), o.name) for o in spawns if o is not s]
        others = [(d, n) for d, n in others if d is not None]
        if others:
            d, n = min(others)
            spacing.append((s.name, n, d))
    return rows, spacing


def check_projects():
    default = json.loads((ROOT / "default.project.json").read_text())["tree"]
    mapped = json.loads((ROOT / "map.project.json").read_text())["tree"]
    allowed_extra = {("Workspace",), ("ServerScriptService", "MapMarkers"), ("ServerScriptService", "MapTravel"),
                     ("StarterPlayer", "StarterPlayerScripts", "MapClient"),
                     ("StarterPlayer", "StarterPlayerScripts", "HubAmbience"),
                     # The world look (lighting and day cycle, sculpted terrain, far horizon) lives with the map.
                     ("ServerScriptService", "WorldLook"), ("ServerScriptService", "WorldTerrain"),
                     ("StarterPlayer", "StarterPlayerScripts", "WorldShowcase"),
                     ("StarterPlayer", "StarterPlayerScripts", "WorldHorizon"),
                     # Studio-only capture stage for the sword roster (inert outside Studio).
                     ("ServerScriptService", "SwordGalleryStage")}

    def walk(d, m, path=()):
        for key, value in d.items():
            if key not in m:
                fail(f"map.project.json drops {'/'.join(path + (key,))}")
            elif isinstance(value, dict):
                walk(value, m[key], path + (key,))
            elif value != m[key]:
                fail(f"map.project.json changes {'/'.join(path + (key,))}: {value!r} -> {m[key]!r}")
        for key in m:
            if key not in d and path + (key,) not in allowed_extra:
                fail(f"map.project.json adds unexpected {'/'.join(path + (key,))}")

    walk(default, mapped)
    for forbidden in ("Lighting", "ServerStorage", "Terrain"):
        if forbidden in mapped or forbidden in mapped.get("Workspace", {}):
            fail(f"map.project.json maps {forbidden}")


def parse_archetypes():
    src = (ROOT / "lemonade-game/ServerScriptService/EnemyCombat.server.luau").read_text()
    body = src[src.index("local ENEMY_ARCHETYPES = {"):src.index("local function getEnemyMaxHealth")]
    out = {}
    for m in re.finditer(r"\n\t(\w+) = \{(.*?)\n\t\}|\n\t(\w+) = \{(.*?)\},\n", body, re.S):
        key = m.group(1) or m.group(3)
        text = m.group(2) or m.group(4)
        nums = dict((k, float(v)) for k, v in re.findall(r"(\w+) = ([\d.]+)", text))
        out[key] = {"aggroRange": nums.get("aggroRange", 24), "patrolRadius": nums.get("patrolRadius", 12),
                    "scale": nums.get("scale", 1.0)}
    return out


def finish(report_path, travel=None):
    lines = ["# Map validation", ""]
    lines += [f"- {n}" for n in notes]
    if travel:
        rows, spacing = travel
        lines += ["", "## Walk distance from player spawn", "",
                  "| Target | Studs | Walk (16) | Run (26) |", "| --- | ---: | ---: | ---: |"]
        for label, d in rows:
            lines.append(f"| {label} | unreachable | | |" if d is None else
                         f"| {label} | {d:.0f} | {d / WALK_SPEED:.1f} s | {d / RUN_SPEED:.1f} s |")
        lines += ["", "## Encounter spacing (walk to nearest other spawn)", "",
                  "| Spawn | Nearest | Studs | Walk |", "| --- | --- | ---: | ---: |"]
        for a, b, d in sorted(spacing, key=lambda r: r[0]):
            lines.append(f"| {a} | {b} | {d:.0f} | {d / WALK_SPEED:.1f} s |")
    lines += ["", "## Result", ""]
    lines += [f"- FAIL: {f}" for f in failures] or ["- PASS: all map checks"]
    text = "\n".join(lines) + "\n"
    print(text)
    if report_path:
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(text)
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
