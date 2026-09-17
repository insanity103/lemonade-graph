#!/usr/bin/env python3
"""convert_sword_glb.py -- turn an arbitrary sword GLB into a boss-sword-pipeline GLB.

The game's boss meshes (ServerStorage/BossSwordMeshes/<Archetype>, see CombatUtil.getSwordMesh
and tools/sword_forge.py) all share one layout so a single Grip/weld fits every sword:

- one mesh, one material, one embedded texture
- length along Z normalised to 1.0, bounding box centred on the origin
- blade toward -Z (tip at z = -0.5), grip toward +Z (pommel at z = +0.5)
- width along Y, thickness along X

Hand-modelled swords rarely arrive like that (several meshes, several flat materials, blade
along +Y). This script applies every node transform, merges all primitives into one, rotates
the model so its long axis becomes Z (blade end -> -Z), normalises and centres it, and bakes
each flat material colour into a swatch of one PNG atlas so the merged mesh keeps its colours
with a single material. It then reports the same pipeline checks sword_forge.py enforces and
updates assets/swords/manifest.json.

Usage:
  tools/convert_sword_glb.py <input.glb> <ArchetypeKey> [--blade-axis +y] [--out FILE]

--blade-axis is the input's long axis with the sign pointing toward the blade TIP
(default +y). --out defaults to assets/swords/<ArchetypeKey>.glb.

After running, import the output with Studio's 3D Importer (Avatar or Home tab), rename the
resulting MeshPart to the archetype key, and place it in ServerStorage/BossSwordMeshes.
"""
import argparse
import io
import json
import pathlib
import struct
import sys

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
ASSETS = ROOT / "assets" / "swords"

COMPONENT = {5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2), 5123: ("H", 2), 5125: ("I", 4), 5126: ("f", 4)}
COUNT = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}

# Pipeline constants mirrored from sword_forge.py.
GRIP_FRAC = 0.38
GUARD_HALF_SPAN_CAP = 0.13
MAX_TRIS, MAX_VERTS = 10000, 21000


# ── GLB reading ──────────────────────────────────────────────────────────────
def read_glb(path):
    data = path.read_bytes()
    magic, version, _ = struct.unpack("<4sII", data[:12])
    if magic != b"glTF" or version != 2:
        sys.exit(f"{path}: not a glTF 2.0 binary")
    offset = 12
    gltf, binary = None, b""
    while offset < len(data):
        length, kind = struct.unpack("<II", data[offset:offset + 8])
        chunk = data[offset + 8:offset + 8 + length]
        if kind == 0x4E4F534A:
            gltf = json.loads(chunk)
        elif kind == 0x004E4942:
            binary = chunk
        offset += 8 + length
    return gltf, binary


def accessor(gltf, binary, index):
    acc = gltf["accessors"][index]
    view = gltf["bufferViews"][acc["bufferView"]]
    fmt, size = COMPONENT[acc["componentType"]]
    n = COUNT[acc["type"]]
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    stride = view.get("byteStride", size * n)
    rows = []
    for k in range(acc["count"]):
        s = start + k * stride
        rows.append(struct.unpack("<" + fmt * n, binary[s:s + size * n]))
    return np.array(rows, dtype=np.float64 if fmt == "f" else np.int64)


def node_matrix(node):
    if "matrix" in node:
        return np.array(node["matrix"], dtype=float).reshape(4, 4).T
    t = node.get("translation", [0, 0, 0])
    x, y, z, w = node.get("rotation", [0, 0, 0, 1])
    s = node.get("scale", [1, 1, 1])
    rot = np.array([
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
    ])
    m = np.eye(4)
    m[:3, :3] = rot * np.array(s)
    m[:3, 3] = t
    return m


def world_matrices(gltf):
    nodes = gltf["nodes"]
    parent = {}
    for i, node in enumerate(nodes):
        for child in node.get("children", []):
            parent[child] = i
    cache = {}

    def world(i):
        if i in cache:
            return cache[i]
        m = node_matrix(nodes[i])
        p = parent.get(i)
        cache[i] = (world(p) @ m) if p is not None else m
        return cache[i]

    return {i: world(i) for i in range(len(nodes))}


# ── Geometry gathering ───────────────────────────────────────────────────────
def gather(gltf, binary):
    """Returns positions, normals, per-vertex material index, indices, and named part bounds."""
    mats = world_matrices(gltf)
    positions, normals, mat_ids, indices, parts = [], [], [], [], []
    base = 0
    for i, node in enumerate(gltf["nodes"]):
        if "mesh" not in node:
            continue
        m = mats[i]
        normal_m = np.linalg.inv(m[:3, :3]).T
        for prim in gltf["meshes"][node["mesh"]]["primitives"]:
            if prim.get("mode", 4) != 4:
                sys.exit(f"node {node.get('name')}: only triangle primitives are supported")
            pos = accessor(gltf, binary, prim["attributes"]["POSITION"])
            pos_w = (m @ np.c_[pos, np.ones(len(pos))].T).T[:, :3]
            if "NORMAL" in prim["attributes"]:
                nrm = accessor(gltf, binary, prim["attributes"]["NORMAL"]) @ normal_m.T
            else:
                nrm = np.zeros_like(pos_w)
            if "indices" in prim:
                idx = accessor(gltf, binary, prim["indices"]).reshape(-1)
            else:
                idx = np.arange(len(pos_w))
            if np.linalg.det(m[:3, :3]) < 0:
                idx = idx.reshape(-1, 3)[:, ::-1].reshape(-1)  # mirrored node: fix winding
            positions.append(pos_w)
            normals.append(nrm)
            mat_ids.append(np.full(len(pos_w), prim.get("material", 0)))
            indices.append(idx + base)
            parts.append((node.get("name", f"node{i}"), pos_w.min(0), pos_w.max(0)))
            base += len(pos_w)
    return (np.vstack(positions), np.vstack(normals), np.concatenate(mat_ids),
            np.concatenate(indices), parts)


# ── Orientation ──────────────────────────────────────────────────────────────
def rotation_for(blade_axis):
    """Proper rotation taking the input's blade axis to -Z (tip at -Z, grip at +Z)."""
    sign = -1 if blade_axis[0] == "-" else 1
    axis = blade_axis[-1].lower()
    # Row k of R is the input direction that becomes output axis k. Output Z = -(blade dir).
    blade = np.zeros(3)
    blade["xyz".index(axis)] = sign
    out_z = -blade
    # Pick the widest remaining input axis as output Y (width) later; here choose any
    # perpendicular pair that keeps the rotation proper (det = +1).
    others = [a for a in range(3) if a != "xyz".index(axis)]
    out_y = np.zeros(3)
    out_y[others[0]] = 1
    out_x = np.cross(out_y, out_z)
    return np.vstack([out_x, out_y, out_z])


def orient(positions, normals, parts, blade_axis):
    rot = rotation_for(blade_axis)
    assert abs(np.linalg.det(rot) - 1) < 1e-9, "rotation must be proper"
    p = positions @ rot.T
    n = normals @ rot.T
    # Width should be the wider of the two cross axes: swap X/Y if thickness came out wider.
    ext = p.max(0) - p.min(0)
    if ext[0] > ext[1]:
        swap = np.array([[0, 1, 0], [-1, 0, 0], [0, 0, 1]], dtype=float)  # 90 deg about Z, proper
        p, n = p @ swap.T, n @ swap.T
        rot = swap @ rot
    length = p[:, 2].max() - p[:, 2].min()
    scale = 1.0 / length
    p = p * scale
    centre = (p.max(0) + p.min(0)) / 2
    p = p - centre
    parts_out = []
    for name, lo, hi in parts:
        corners = np.array([[x, y, z] for x in (lo[0], hi[0]) for y in (lo[1], hi[1]) for z in (lo[2], hi[2])])
        c = corners @ rot.T * scale - centre
        parts_out.append((name, c.min(0), c.max(0)))
    return p, n, parts_out


# ── Material atlas ───────────────────────────────────────────────────────────
def linear_to_srgb(c):
    c = np.clip(np.asarray(c, dtype=float), 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(c, 1 / 2.4) - 0.055)


def build_atlas(materials):
    """One 32px swatch per material in a single row; returns PNG bytes and UV centres."""
    cell = 32
    count = max(len(materials), 1)
    width = cell * count
    img = Image.new("RGB", (width, cell))
    uvs = []
    for i, mat in enumerate(materials):
        pbr = mat.get("pbrMetallicRoughness", {})
        rgb = linear_to_srgb(pbr.get("baseColorFactor", [0.8, 0.8, 0.8, 1])[:3])
        colour = tuple(int(round(v * 255)) for v in rgb)
        img.paste(colour, (i * cell, 0, (i + 1) * cell, cell))
        uvs.append(((i + 0.5) / count, 0.5))
    buf = io.BytesIO()
    img.save(buf, format="PNG", optimize=True)
    return buf.getvalue(), uvs


# ── GLB writing ──────────────────────────────────────────────────────────────
def pad4(b, fill=b"\x00"):
    return b + fill * ((4 - len(b) % 4) % 4)


def write_glb(path, name, positions, normals, uvs, indices, png):
    positions = positions.astype(np.float32)
    normals = normals.astype(np.float32)
    uvs = uvs.astype(np.float32)
    idx_type = 5123 if positions.shape[0] <= 65535 else 5125
    indices = indices.astype(np.uint16 if idx_type == 5123 else np.uint32)

    blobs = [positions.tobytes(), normals.tobytes(), uvs.tobytes(), indices.tobytes(), png]
    views, offset, binary = [], 0, b""
    for blob in blobs:
        padded = pad4(blob)
        views.append({"buffer": 0, "byteOffset": offset, "byteLength": len(blob)})
        binary += padded
        offset += len(padded)

    gltf = {
        "asset": {"version": "2.0", "generator": "lemonade convert_sword_glb.py"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"name": name, "mesh": 0}],
        "meshes": [{"name": name, "primitives": [{
            "attributes": {"POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2},
            "indices": 3, "material": 0, "mode": 4}]}],
        "materials": [{"name": f"{name}_material", "doubleSided": False,
                       "pbrMetallicRoughness": {"baseColorTexture": {"index": 0},
                                                "metallicFactor": 0.25, "roughnessFactor": 0.5}}],
        "textures": [{"source": 0, "sampler": 0}],
        "samplers": [{"magFilter": 9728, "minFilter": 9728, "wrapS": 33071, "wrapT": 33071}],
        "images": [{"mimeType": "image/png", "bufferView": 4, "name": f"{name}_atlas"}],
        "accessors": [
            {"bufferView": 0, "componentType": 5126, "count": len(positions), "type": "VEC3",
             "min": positions.min(0).tolist(), "max": positions.max(0).tolist()},
            {"bufferView": 1, "componentType": 5126, "count": len(normals), "type": "VEC3"},
            {"bufferView": 2, "componentType": 5126, "count": len(uvs), "type": "VEC2"},
            {"bufferView": 3, "componentType": idx_type, "count": len(indices), "type": "SCALAR"},
        ],
        "bufferViews": views,
        "buffers": [{"byteLength": len(binary)}],
    }
    json_chunk = pad4(json.dumps(gltf, separators=(",", ":")).encode(), b" ")
    total = 12 + 8 + len(json_chunk) + 8 + len(binary)
    with open(path, "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, total))
        f.write(struct.pack("<II", len(json_chunk), 0x4E4F534A) + json_chunk)
        f.write(struct.pack("<II", len(binary), 0x004E4942) + binary)


# ── Pipeline checks ──────────────────────────────────────────────────────────
def analyse(positions, indices, parts):
    lo, hi = positions.min(0), positions.max(0)
    ext = hi - lo
    problems = []
    if abs(ext[2] - 1.0) > 1e-4:
        problems.append(f"length {ext[2]:.4f} != 1.0")
    if np.abs((lo + hi) / 2).max() > 1e-4:
        problems.append(f"bbox not centred: {((lo + hi) / 2).round(4).tolist()}")
    if abs(abs(lo[0]) - abs(hi[0])) > 0.02 or abs(abs(lo[1]) - abs(hi[1])) > 0.02:
        problems.append("silhouette not symmetric about the grip axis (hand would sit off-centre)")
    tris = len(indices) // 3
    if tris > MAX_TRIS or len(positions) > MAX_VERTS:
        problems.append(f"{tris} tris / {len(positions)} verts exceeds Roblox MeshPart limits")

    def band(pred):
        zs = [(p_lo[2], p_hi[2]) for name, p_lo, p_hi in parts if pred(name.lower())]
        return (min(z[0] for z in zs), max(z[1] for z in zs)) if zs else None

    handle = band(lambda n: n.startswith(("grip", "handle", "wrap")))
    guard = band(lambda n: n.startswith(("guard", "crossguard")))
    guard_half = float(max(abs(lo[1]), abs(hi[1])))
    if guard_half > GUARD_HALF_SPAN_CAP + 0.02:
        problems.append(f"guard half-span {guard_half:.3f} over the {GUARD_HALF_SPAN_CAP} cap (wide in the hand)")
    if handle and not (handle[0] - 0.02 <= GRIP_FRAC <= handle[1] + 0.02):
        problems.append(f"hand anchor z={GRIP_FRAC} misses the handle z[{handle[0]:.3f},{handle[1]:.3f}]")
    return {
        "meshSize": [round(float(ext[0]), 4), round(float(ext[1]), 4), round(float(ext[2]), 4)],
        "gripFrac": round(float((handle[0] + handle[1]) / 2), 3) if handle else None,
        "guardZ": [round(float(z), 3) for z in guard] if guard else None,
        "handleZ": [round(float(z), 3) for z in handle] if handle else None,
        "triangles": int(tris),
        "vertices": int(len(positions)),
        "problems": problems,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("input")
    ap.add_argument("archetype")
    ap.add_argument("--blade-axis", default="+y")
    ap.add_argument("--out")
    args = ap.parse_args()

    src = pathlib.Path(args.input)
    out = pathlib.Path(args.out) if args.out else ASSETS / f"{args.archetype}.glb"
    gltf, binary = read_glb(src)

    positions, normals, mat_ids, indices, parts = gather(gltf, binary)
    positions, normals, parts = orient(positions, normals, parts, args.blade_axis)
    lengths = np.linalg.norm(normals, axis=1, keepdims=True)
    normals = np.where(lengths > 1e-8, normals / np.maximum(lengths, 1e-8), 0)

    png, swatch_uv = build_atlas(gltf.get("materials", []))
    uvs = np.array([swatch_uv[m] if m < len(swatch_uv) else (0.5, 0.5) for m in mat_ids])

    write_glb(out, args.archetype, positions, normals, uvs, indices, png)
    report = analyse(positions, indices, parts)

    manifest_path = ASSETS / "manifest.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
    entry = manifest.get(args.archetype, {})
    entry.update({
        "file": out.name,
        "source": src.name,
        "bytes": out.stat().st_size,
        "triangles": report["triangles"],
        "vertices": report["vertices"],
        "meshSize": report["meshSize"],
        "gripFrac": report["gripFrac"],
        "guardZ": report["guardZ"],
        "handleZ": report["handleZ"],
        "checks": "all passed" if not report["problems"] else "; ".join(report["problems"]),
    })
    entry.setdefault("name", args.archetype)
    manifest[args.archetype] = entry
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")

    print(f"wrote {out} ({out.stat().st_size} bytes)")
    print(f"  tris {report['triangles']}  verts {report['vertices']}  meshSize {report['meshSize']}")
    print(f"  handleZ {report['handleZ']}  guardZ {report['guardZ']}  gripFrac {report['gripFrac']} (hand anchor {GRIP_FRAC})")
    if report["problems"]:
        print("  CHECKS:")
        for p in report["problems"]:
            print("   -", p)
    else:
        print("  checks: all passed")


if __name__ == "__main__":
    main()
