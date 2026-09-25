#!/usr/bin/env python3
"""check_glacier_glb.py -- validates the Frostbound Glacier kit's GLBs, without Blender.

    python3 tools/check_glacier_glb.py            # every assets/glacier/*.glb against kit.json
    python3 tools/check_glacier_glb.py a.glb ...  # just these

What MeshSlots.server.luau and the import assume (tools/blender_glacier_kit.py, docs/map/GLACIER.md):
  * one mesh, one primitive, one material, one embedded image (the swatch atlas)
  * matte plastic: metallicFactor 0, roughnessFactor 1, no normal / occlusion / metallic-roughness map
  * under Roblox's 10,000-triangle / 21,000-vertex MeshPart limits
  * the file's key is a piece of tools/glacier_kit.py, and its size and centre match kit.json
    (map_forge places each slot's mesh from kit.json's centre; a stale kit.json would misplace it)
  * the piece's foot is on the ground: its lowest point within a few studs of y = 0
Exit status 1 if any file fails a rule.
"""
import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from check_sword_glb import accessor, read_glb  # noqa: E402
import glacier_kit  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
KIT = ROOT / "assets" / "glacier"


def check(path, kit):
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
    key = path.stem
    results["a kit piece"] = key in glacier_kit.KEYS
    if not prims:
        return results, {}
    P = accessor(gltf, binary, prims[0]["attributes"]["POSITION"])
    idx = accessor(gltf, binary, prims[0]["indices"]) if "indices" in prims[0] else None
    tris = (len(idx) if idx else len(P)) // 3
    mn = [min(p[i] for p in P) for i in range(3)]
    mx = [max(p[i] for p in P) for i in range(3)]
    # glTF (x, y, z) is Roblox (x, y, z) before Studio's turn: the kit's own frame
    size = [mx[i] - mn[i] for i in range(3)]
    centre = [(mx[i] + mn[i]) / 2 for i in range(3)]
    results["tris<=10000"] = tris <= 10000
    results["verts<=21000"] = len(P) <= 21000
    entry = kit.get(key)
    results["in kit.json, size and centre match"] = bool(entry) and all(
        abs(size[i] - entry["size"][i]) < 0.05 and abs(centre[i] - entry["centre"][i]) < 0.05 for i in range(3))
    results["foot on the ground"] = -4.5 < mn[1] < 1.0 or key == "IceBridge"  # the bridge hangs from its deck
    return results, {"tris": tris, "verts": len(P), "size": tuple(round(v, 2) for v in size)}


def main(paths):
    kit = json.loads((KIT / "kit.json").read_text())
    paths = [pathlib.Path(p) for p in paths] or sorted(KIT.glob("*.glb"))
    bad = 0
    for path in paths:
        results, stats = check(path, kit)
        failed = [k for k, ok in results.items() if not ok]
        bad += bool(failed)
        print(f"{'FAIL' if failed else 'ok  '} {path.name:24} tris={stats.get('tris', 0):5} verts={stats.get('verts', 0):5} "
              f"size={stats.get('size')}" + (f"  failed: {failed}" if failed else ""))
    missing = [k for k in glacier_kit.KEYS if not (KIT / f"{k}.glb").exists()]
    if missing:
        bad += 1
        print(f"FAIL missing GLBs: {', '.join(missing)}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
