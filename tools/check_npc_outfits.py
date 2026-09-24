"""Check the tailored native R15 NPC files without requiring Studio.

This validates the rig contract and every generated outfit weld. It cannot
simulate Humanoid motion or verify the final appearance in Roblox Studio.
"""
from pathlib import Path
import math
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
MODELS = ROOT / 'lemonade-game/ReplicatedStorage/NpcModels'
BODY = {'HumanoidRootPart', 'Head', 'UpperTorso', 'LowerTorso'} | {
    side + segment for side in ('Left', 'Right')
    for segment in ('UpperArm', 'LowerArm', 'Hand', 'UpperLeg', 'LowerLeg', 'Foot')
}


def frame(properties, name):
    node = properties.find(f"CoordinateFrame[@name='{name}']")
    assert node is not None, name
    position = [float(node.find(axis).text) for axis in 'XYZ']
    rotation = [[float(node.find(f'R{i}{j}').text) for j in range(3)] for i in range(3)]
    return position, rotation


def compose(a, b):
    pa, ra = a
    pb, rb = b
    position = [pa[i] + sum(ra[i][k] * pb[k] for k in range(3)) for i in range(3)]
    rotation = [[sum(ra[i][k] * rb[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
    return position, rotation


def aligned(a, b):
    return max(abs(x-y) for x, y in zip(a[0], b[0])) < 1e-4 and all(
        abs(a[1][i][j] - b[1][i][j]) < 1e-4 for i in range(3) for j in range(3)
    )


def check(path):
    tree = ET.parse(path)
    items = list(tree.iter('Item'))
    refs = {item.get('referent'): item for item in items}
    assert len(items) == len(refs), (path.name, 'duplicate referent')
    for ref in tree.iter('Ref'):
        assert ref.text in refs, (path.name, 'dangling ref', ref.text)
    parts = {item.findtext("Properties/string[@name='Name']"): item
             for item in items if item.get('class') == 'Part'}
    assert BODY <= parts.keys(), (path.name, 'missing R15 part')
    assert sum(item.get('class') == 'Humanoid' for item in items) == 1
    assert sum(item.get('class') == 'Animator' for item in items) == 1
    assert sum(item.get('class') == 'Motor6D' for item in items) == 15
    assert tree.find(".//token[@name='RigType']").text == '1'
    assert not any(item.get('class') in ('Script', 'LocalScript', 'ModuleScript') for item in items)
    generated = [name for name in parts if name.startswith('GL_')]
    assert generated, (path.name, 'missing tailoring')
    generated_refs = {parts[name].get('referent') for name in generated}
    bound_refs = {item.find("Properties/Ref[@name='Part1']").text for item in items
                  if item.get('class') == 'Weld' and item.get('referent', '').startswith('W_GL_')}
    assert generated_refs == bound_refs, (path.name, 'unbound tailoring')
    for item in items:
        if item.get('class') != 'Motor6D' and not (
            item.get('class') == 'Weld' and item.get('referent', '').startswith('W_GL_')
        ):
            continue
        properties = item.find('Properties')
        a = refs[properties.find("Ref[@name='Part0']").text]
        b = refs[properties.find("Ref[@name='Part1']").text]
        left = compose(frame(a.find('Properties'), 'CFrame'), frame(properties, 'C0'))
        right = compose(frame(b.find('Properties'), 'CFrame'), frame(properties, 'C1'))
        assert aligned(left, right), (path.name, 'misaligned joint', item.get('referent'))
    for name in generated:
        properties = parts[name].find('Properties')
        assert properties.find("bool[@name='Anchored']").text == 'false'
        assert properties.find("bool[@name='Massless']").text == 'true'
        for flag in ('CanCollide', 'CanQuery', 'CanTouch'):
            assert properties.find(f"bool[@name='{flag}']").text == 'false'
        assert all(math.isfinite(float(node.text)) and float(node.text) > 0
                   for node in properties.find("Vector3[@name='size']"))
    print('PASS', path.stem, len(generated), 'tailored pieces')


if __name__ == '__main__':
    paths = sorted(MODELS.glob('*_R15.rbxmx'))
    assert len(paths) == 9, len(paths)
    for model in paths:
        check(model)
