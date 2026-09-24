#!/usr/bin/env python3
"""check_sword_glb.py -- validates a sword GLB against the game's mesh layout and the cartoon
material rule, without Blender.

    python3 tools/check_sword_glb.py assets/swords/*.glb

Layout (what EnemyCombat's weld and BossSwordTool.Grip assume; see tools/blender_boss_swords.py):
  * one mesh, one primitive, one material, one embedded image
  * length along Z exactly 1.0, bounding box centred: tip at z = -0.5, pommel at z = +0.5
  * bounding box symmetric in X (thickness) and Y (width) about the grip axis
  * the widest feature is the crossguard: the vertices at max |Y| lie in the guard band
    z 0.195..0.255 (a wider blade would put the hand beside the handle after Studio recentres)
  * under Roblox's 10,000-triangle / 21,000-vertex MeshPart limits
Material (docs/ART_DIRECTION.md: matte plastic, nothing baked):
  * metallicFactor 0, roughnessFactor 1, no normal / metallic-roughness / occlusion maps
Exit status 1 if any file fails a rule.
"""
import json
import pathlib
import struct
import sys

GUARD_Z = (0.195, 0.255)
GUARD_SLACK = 0.03   # a guard's own bevel/prongs may sit a little outside the nominal band


def read_glb(path):
    data = path.read_bytes()
    if data[:4] != b"glTF":
        raise ValueError("not a GLB")
    length = struct.unpack_from("<I", data, 8)[0]
    off, chunks = 12, {}
    while off < length:
        clen, ctype = struct.unpack_from("<I4s", data, off)
        chunks[ctype] = data[off + 8:off + 8 + clen]
        off += 8 + clen
    return json.loads(chunks[b"JSON"]), chunks[b"BIN\x00"]


def accessor(gltf, binary, index):
    acc = gltf["accessors"][index]
    view = gltf["bufferViews"][acc["bufferView"]]
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    ctype = {5126: ("f", 4), 5123: ("H", 2), 5125: ("I", 4), 5121: ("B", 1)}[acc["componentType"]]
    n = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[acc["type"]]
    fmt = "<" + ctype[0] * n
    stride = view.get("byteStride", ctype[1] * n)
    out = []
    for i in range(acc["count"]):
        out.append(struct.unpack_from(fmt, binary, start + i * stride))
    return out


def check(path):
    gltf, binary = read_glb(path)
    results = {}
    meshes = gltf.get("meshes", [])
    prims = meshes[0]["primitives"] if meshes else []
    results["one mesh, one primitive"] = len(meshes) == 1 and len(prims) == 1
    results["one material, one image"] = len(gltf.get("materials", [])) == 1 and len(gltf.get("images", [])) == 1
    mat = gltf["materials"][0] if gltf.get("materials") else {}
    pbr = mat.get("pbrMetallicRoughness", {})
    results["matte plastic (metallic 0, roughness 1)"] = pbr.get("metallicFactor", 1.0) == 0.0 and pbr.get("roughnessFactor", 1.0) == 1.0
    results["no baked PBR maps"] = not any(k in mat for k in ("normalTexture", "occlusionTexture")) and "metallicRoughnessTexture" not in pbr
    if not prims:
        return results, {}
    prim = prims[0]
    P = accessor(gltf, binary, prim["attributes"]["POSITION"])
    idx = accessor(gltf, binary, prim["indices"]) if "indices" in prim else None
    tris = (len(idx) if idx else len(P)) // 3
    xs, ys, zs = (sorted(p[i] for p in P) for i in range(3))
    mn, mx = (xs[0], ys[0], zs[0]), (xs[-1], ys[-1], zs[-1])
    widest = [p for p in P if abs(abs(p[1]) - max(abs(mn[1]), abs(mx[1]))) < 1e-4]
    results["tris<=10000"] = tris <= 10000
    results["verts<=21000"] = len(P) <= 21000
    results["length==1"] = abs((mx[2] - mn[2]) - 1.0) < 1e-4
    results["tip z=-0.5, pommel z=+0.5"] = abs(mn[2] + 0.5) < 1e-4 and abs(mx[2] - 0.5) < 1e-4
    results["x symmetric"] = abs(mx[0] + mn[0]) < 1e-3
    results["y symmetric"] = abs(mx[1] + mn[1]) < 1e-3
    results["guard is the widest feature"] = all(GUARD_Z[0] - GUARD_SLACK <= p[2] <= GUARD_Z[1] + GUARD_SLACK for p in widest)
    stats = {"tris": tris, "verts": len(P), "size": tuple(round(mx[i] - mn[i], 4) for i in range(3)),
             "half_span": round(max(abs(mn[1]), abs(mx[1])), 4)}
    return results, stats


def main(paths):
    bad = 0
    for arg in paths:
        path = pathlib.Path(arg)
        results, stats = check(path)
        failed = [k for k, ok in results.items() if not ok]
        state = "FAIL" if failed else "ok  "
        bad += bool(failed)
        print(f"{state} {path.name:28} tris={stats.get('tris', 0):5} verts={stats.get('verts', 0):5} "
              f"size={stats.get('size')} half_span={stats.get('half_span')}"
              + (f"  failed: {failed}" if failed else ""))
    return 1 if bad else 0


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    sys.exit(main(sys.argv[1:]))
