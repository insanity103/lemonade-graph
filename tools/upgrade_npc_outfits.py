"""Tailor the nine native R15 NPC outfits, retaining rig and signature props.

Plan: preserve the existing profession palette and all body/joint/prop records;
replace only explicitly listed crude clothing panels; build fitted collars,
layered hems, sleeves, boots and profession-specific tailoring.  Every added
piece has a deterministic GL_ name and a rigid offset weld to one R15 segment.
Split skirts at the hip and knee so animation remains articulated. Rebuilding
removes only our GL_ pieces, then recreates them, making output byte-idempotent.

Coordinates below are X right, Y up and Z toward the face, in the unscaled rig.
No downloaded clothing/mesh assets or external texture dependencies are used.
"""
from pathlib import Path
import argparse
import math
import xml.etree.ElementTree as ET

IDENTITY = ((1, 0, 0), (0, 1, 0), (0, 0, 1))
ROOT = Path(__file__).resolve().parents[1]
PALETTES = {
    'blacksmith': (0x45301f, 0x6d4b30, 0xb6a075),
    'farmer': (0x5d7146, 0x7b5c42, 0xd9bb72),
    'quest_giver': (0x59395c, 0x41607e, 0xc9a33c),
    'sage_priest': (0xe0d5bb, 0x41607e, 0xc9a33c),
    'storekeeper': (0x6d4b30, 0x45301f, 0xc9a33c),
    'swordsman': (0xb4bac1, 0x41607e, 0xc9a33c),
    'villager_baker': (0xe0d5bb, 0x9b4a3a, 0x8a6640),
    'villager_elder': (0x5d7146, 0x6d4b30, 0xc9a33c),
    'villager_market_woman': (0x9b4a3a, 0x41607e, 0xe0d5bb),
}
REPLACE = {
    'blacksmith': ['apron_bib', 'apron', 'apron_skirt_', 'apron_rivet_', 'shoulder_l', 'bandana', 'beard'],
    'farmer': ['collar', 'patch'],
    'quest_giver': ['cape', 'jacket_trim_'],
    'sage_priest': ['stole_', 'robe_trim_'],
    'storekeeper': ['vest_panel_', 'vest_back'],
    'swordsman': ['breastplate', 'plate_ridge', 'pauldron_'],
    'villager_baker': ['apron', 'flour_'],
    'villager_elder': ['shawl'],
    'villager_market_woman': ['bodice_lace', 'apron_skirt_', 'apron'],
}


def prop(parent, tag, name, value):
    ET.SubElement(parent, tag, name=name).text = str(value).lower() if isinstance(value, bool) else str(value)


def vec(parent, name, value):
    el = ET.SubElement(parent, 'Vector3', name=name)
    for axis, v in zip('XYZ', value):
        ET.SubElement(el, axis).text = '%.8g' % v


def cf(parent, name, pos, rot=IDENTITY):
    el = ET.SubElement(parent, 'CoordinateFrame', name=name)
    for axis, v in zip('XYZ', pos):
        ET.SubElement(el, axis).text = '%.8g' % v
    for i in range(3):
        for j in range(3):
            ET.SubElement(el, 'R%d%d' % (i, j)).text = '%.8g' % rot[i][j]


def shade(color, factor):
    rgb = [(color >> s) & 255 for s in (16, 8, 0)]
    return sum(min(255, round(v * factor)) << s for v, s in zip(rgb, (16, 8, 0)))


def rz(angle):
    a = math.radians(angle)
    return ((math.cos(a), -math.sin(a), 0), (math.sin(a), math.cos(a), 0), (0, 0, 1))


class Tailor:
    def __init__(self, path):
        self.path = path
        self.key = path.stem.removesuffix('_R15')
        self.scale = .94 if self.key == 'villager_elder' else 1
        self.tree = ET.parse(path)
        self.model = self.tree.getroot().find('Item')
        for item in list(self.model.findall('Item')):
            name = item.findtext('Properties/string[@name="Name"]', '')
            if name.startswith('GL_') or any(name.startswith(p) for p in REPLACE[self.key]):
                self.model.remove(item)
        self.nodes = {i.findtext('Properties/string[@name="Name"]'): i for i in self.model.findall('Item')}
        self.count = 0
        self.main, self.accent, self.trim = PALETTES[self.key]

    def add(self, name, pos, size, color, bind='UpperTorso', angle=0, shape=1, metal=False, rot=None):
        name = 'GL_' + name
        obj = ET.SubElement(self.model, 'Item', {'class': 'Part', 'referent': 'P_' + name})
        p = ET.SubElement(obj, 'Properties')
        for tag, field, value in [('string', 'Name', name), ('bool', 'Anchored', False),
                ('bool', 'CanCollide', False), ('bool', 'CanTouch', False), ('bool', 'CanQuery', False),
                ('bool', 'Massless', True), ('int', 'RootPriority', 0), ('float', 'Transparency', 0),
                ('token', 'shape', shape), ('token', 'Material', 1088 if metal else 256),
                ('Color3uint8', 'Color3uint8', 0xff000000 | color)]:
            prop(p, tag, field, value)
        vec(p, 'size', [v * self.scale for v in size])
        pos = [pos[0] * self.scale, pos[1] * self.scale, -pos[2] * self.scale]
        rot = rot or rz(angle)
        signs = (1, 1, -1)
        rot = [[rot[i][j] * signs[i] * signs[j] for j in range(3)] for i in range(3)]
        cf(p, 'CFrame', pos, rot)
        for surface in ('Top', 'Bottom', 'Left', 'Right', 'Front', 'Back'):
            prop(p, 'token', surface + 'Surface', 0)
        target = self.nodes[bind]
        target_cf = target.find('Properties/CoordinateFrame[@name="CFrame"]')
        target_pos = [float(target_cf.find(a).text) for a in 'XYZ']
        w = ET.SubElement(obj, 'Item', {'class': 'Weld', 'referent': 'W_' + name})
        wp = ET.SubElement(w, 'Properties')
        prop(wp, 'string', 'Name', 'TailoringWeld')
        prop(wp, 'Ref', 'Part0', target.get('referent'))
        prop(wp, 'Ref', 'Part1', obj.get('referent'))
        cf(wp, 'C0', [pos[i] - target_pos[i] for i in range(3)], rot)
        cf(wp, 'C1', (0, 0, 0))
        self.count += 1
        return obj

    def line(self, name, a, b, width, color, bind='UpperTorso', depth=.045, metal=False):
        d = [b[i] - a[i] for i in range(3)]
        length = math.sqrt(sum(v*v for v in d))
        # These front/back ribbons lie in the XY plane, so local Y is their length.
        angle = -math.degrees(math.atan2(d[0], d[1]))
        return self.add(name, [(a[i]+b[i])/2 for i in range(3)], (width, length, depth), color, bind, angle, metal=metal)

    def triangle(self, name, pos, width, height, color, side=1, bind='UpperTorso', invert=False):
        # Native wedge: local thin X faces forward; its Y/Z slope becomes XY.
        rot = ((0, 0, side), (0, -1 if invert else 1, 0), (side if invert else -side, 0, 0))
        obj = self.add(name, pos, (.08, height, width), color, bind, rot=rot)
        mesh = ET.SubElement(obj, 'Item', {'class': 'SpecialMesh', 'referent': 'M_GL_' + name})
        p = ET.SubElement(mesh, 'Properties')
        prop(p, 'string', 'Name', 'TailoredWedge')
        prop(p, 'token', 'MeshType', 2)
        vec(p, 'Scale', (1, 1, 1))
        vec(p, 'Offset', (0, 0, 0))
        return obj

    def common(self):
        formal = self.key in ('quest_giver', 'storekeeper', 'sage_priest', 'swordsman')
        # Shoes and cuffs are separate articulated pieces, never rigid tubes across joints.
        for side, x in [('Left', -.5), ('Right', .5)]:
            self.add('boot_shaft_' + side, (x, .70, 0), (.96, .64, .95), 0x45301f, side+'LowerLeg')
            self.add('boot_cuff_' + side, (x, 1.01, 0), (1.015, .14, 1.00), self.accent, side+'LowerLeg')
            self.add('boot_sole_' + side, (x, .035, .10), (1.00, .09, 1.23), 0x2b2320, side+'Foot')
            self.add('boot_toe_' + side, (x, .22, .44), (.96, .15, .56), 0x45301f, side+'Foot')
            if formal:
                self.add('boot_buckle_' + side, (x+.28, .83, .505), (.16, .13, .055), self.trim, side+'LowerLeg', metal=True)
        # Fitted sleeve ends and lower-arm guards provide a second material boundary.
        for side, x in [('Left', -1.48), ('Right', 1.48)]:
            if formal:
                sleeve = 0xe0d5bb if self.key in ('storekeeper', 'sage_priest') else self.main
                if self.key == 'swordsman':
                    sleeve = 0x566473
                self.add('lower_sleeve_'+side, (x, 2.70, 0), (.895, .59, .895), sleeve, side+'LowerArm')
            self.add('sleeve_binding_'+side, (x, 3.12, 0), (.93, .13, .96), self.accent, side+'UpperArm')
            self.add('wrist_binding_'+side, (x, 2.38, 0), (.90, .13, .91), self.accent, side+'LowerArm')
        if self.key != 'villager_market_woman':
            self.add('collar_back', (0, 3.92, -.43), (1.22, .26, .16), self.accent)
            for side in (-1, 1):
                self.triangle('collar_'+str(side), (side*.29, 3.80, .57), .45, .33, self.accent, side)

    def coat(self, color, facing, long=False):
        for sign, side in [(-1, 'Left'), (1, 'Right')]:
            x = sign*.63
            self.add('coat_front_'+side, (x, 3.22, .542), (.64, 1.1, .1), color)
            self.triangle('lapel_'+side, (sign*.39, 3.59, .622), .38, .65, facing, sign)
            self.line('lapel_piping_'+side, (sign*.24, 3.88, .67), (sign*.57, 3.30, .67), .038, self.trim)
            self.add('coat_side_'+side, (sign*.98, 3.19, -.06), (.14, 1.12, .98), color)
            self.add('coat_skirt_'+side, (sign*.63, 1.77, -.25), (.89, .81 if long else .49, 1.03), color, side+'UpperLeg', angle=sign*6)
            self.add('skirt_front_'+side, (sign*.77, 1.79, .565), (.60, .76 if long else .45, .10), facing, side+'UpperLeg', angle=sign*6)
            self.line('skirt_edge_'+side, (sign*.53, 2.13, .635), (sign*.64, 1.42 if long else 1.59, .635), .04, self.trim, side+'UpperLeg')
            self.triangle('skirt_tail_'+side, (sign*.87, 1.37 if long else 1.52, .565), .51, .24, facing, sign, side+'UpperLeg')
        self.add('coat_back', (0, 3.19, -.54), (1.98, 1.17, .11), color)
        self.add('back_waist_seam', (0, 2.78, -.613), (1.78, .045, .045), facing)

    def apron(self, leather=False):
        c = self.main
        edging = shade(c, 1.30) if leather else 0xb9aa8c
        self.add('apron_bib', (0, 3.24, .56), (1.30, 1.02, .10), c)
        for sign in (-1, 1):
            self.line('apron_strap_'+str(sign), (sign*.49, 3.89, .56), (sign*.39, 3.43, .64), .115, self.accent)
            self.line('apron_edge_'+str(sign), (sign*.62, 3.68, .625), (sign*.62, 2.82, .625), .032, edging)
            self.add('strap_rivet_'+str(sign), (sign*.4, 3.48, .666), (.075, .075, .035), self.trim, shape=0, metal=leather)
        self.add('apron_waist', (0, 2.46, .57), (1.77, .37, .13), c, 'LowerTorso')
        for x, side in [(-.46, 'Left'), (.46, 'Right')]:
            self.add('apron_flap_'+side, (x, 1.74, .56), (.85, .81, .105), c, side+'UpperLeg', angle=-3 if x<0 else 3)
            self.add('apron_hem_'+side, (x, 1.37, .622), (.78, .055, .04), edging, side+'UpperLeg')
        self.add('apron_pocket', (.20, 3.01, .637), (.68, .31, .055), shade(c,.86))
        self.add('pocket_binding', (.20, 3.17, .67), (.69, .05, .038), edging)
        for sign in (-1,1):
            self.triangle('bib_shaped_shoulder_'+str(sign), (sign*.71, 3.54, .56), .17, .44, c, sign, invert=True)
            self.add('pocket_stitch_'+str(sign), (.20+sign*.30, 3.0, .675), (.025, .24, .025), edging)
        self.add('pocket_lower_seam', (.20, 2.865, .675), (.57, .025, .025), edging)

    def build(self):
        self.common()
        k = self.key
        if k in ('quest_giver', 'storekeeper'):
            self.coat(self.main, self.accent, long=k=='quest_giver')
            for i in range(3):
                self.add('waistcoat_button_'+str(i), (0, 3.45-i*.22, .58), (.085, .085, .065), self.trim, shape=0, metal=True)
            if k == 'quest_giver':
                for s in (-1, 1):
                    self.add('mantle_shoulder_'+str(s), (s*.92, 3.87, -.23), (.63, .20, 1.07), self.accent, angle=s*12)
                    self.add('cape_panel_'+str(s), (s*.54, 3.0, -.68), (1.08, 1.72, .10), self.accent, angle=s*5)
                    self.line('cape_border_'+str(s), (s*1.02, 3.77, -.75), (s*1.15, 2.16, -.75), .045, self.trim)
                self.add('guild_brooch', (-.63, 3.57, .71), (.23, .27, .075), self.trim, angle=45, metal=True)
                self.triangle('hat_plume_outer', (.68, 5.98, -.01), .27, .68, 0xe0d5bb, 1, 'Head')
                self.triangle('hat_plume_inner', (.51, 6.02, .025), .16, .62, 0xf0e5cc, -1, 'Head')
            else:
                self.add('breast_pocket', (-.66, 3.32, .626), (.44, .28, .06), shade(self.main,.8))
                self.add('pocket_lip', (-.66, 3.46, .66), (.46, .045, .04), self.trim)
                self.line('watch_chain_a', (-.72, 2.98, .67), (-.32, 2.84, .67), .026, self.trim, metal=True)
                self.line('watch_chain_b', (-.32, 2.84, .67), (-.05, 3.02, .67), .026, self.trim, metal=True)
        elif k in ('blacksmith', 'villager_baker'):
            self.apron(leather=k=='blacksmith')
            if k=='blacksmith':
                # Fitted cloth wrap follows the head; knot/tails and tapered beard
                # are costume geometry, leaving the R15 Head and face intact.
                self.add('bandana_crown', (0, 5.22, -.01), (1.65, .30, 1.38), 0x9b4a3a, 'Head', shape=0)
                for sign in (-1,1):
                    self.add('bandana_side_'+str(sign), (sign*.778, 5.16, 0), (.065, .21, 1.20), 0x9b4a3a, 'Head')
                    self.add('bandana_front_'+str(sign), (sign*.38, 5.16, .625), (.79, .21, .06), 0x9b4a3a, 'Head', angle=sign*3)
                self.add('bandana_knot', (.79, 5.14, -.48), (.26, .24, .24), shade(0x9b4a3a,.8), 'Head', shape=0)
                self.triangle('bandana_tail_a', (.84, 4.92, -.49), .20, .45, 0x9b4a3a, 1, 'Head', invert=True)
                self.triangle('bandana_tail_b', (.69, 4.85, -.61), .22, .49, shade(0x9b4a3a,.88), -1, 'Head', invert=True)
                self.add('beard_upper', (0, 4.14, .59), (.83, .18, .20), 0x2b2320, 'Head')
                for sign in (-1,1):
                    self.triangle('beard_taper_'+str(sign), (sign*.205, 3.97, .67), .41, .34, 0x2b2320, -sign, 'Head', invert=True)
                    self.line('beard_lock_'+str(sign), (sign*.18, 4.18, .728), (sign*.10, 3.99, .728), .038, 0x45382e, 'Head')
                self.add('shoulder_leather', (-1.48, 3.89, 0), (1.00, .22, 1.02), self.accent, 'LeftUpperArm')
                for i in range(2):
                    self.add('shoulder_plate_'+str(i), (-1.48, 3.72-i*.18, .485), (.92-i*.08, .26, .10), shade(self.accent,1.10-i*.12), 'LeftUpperArm')
                self.add('smith_bracer', (-1.48, 2.68, .43), (.77, .55, .10), self.main, 'LeftLowerArm')
                for x in (-.64, -.30):
                    self.add('tool_loop_'+str(x), (x, 2.45, .72), (.18, .28, .11), self.trim, 'LowerTorso')
                self.add('seam_back', (0, 3.33, -.535), (.06, 1.03, .045), self.accent)
            else:
                self.add('neckerchief', (0, 3.75, .59), (.45, .24, .12), self.accent, angle=45)
                self.line('neckerchief_tail', (0, 3.66, .64), (.22, 3.36, .64), .15, self.accent)
                for i in range(3):
                    self.add('cap_pleat_'+str(i), ((i-1)*.35, 5.40, .51), (.07, .24, .06), 0xc4b79e, 'Head')
        elif k=='farmer':
            self.coat(0x7b5c42, 0x5d7146)
            self.add('neck_scarf', (0, 3.78, .56), (.68, .20, .10), 0x9b4a3a)
            self.add('scarf_tail', (.25, 3.49, .62), (.22, .49, .07), 0x9b4a3a, angle=-12)
            self.add('seed_pouch', (-.86, 2.22, .53), (.47, .47, .25), 0x6d4b30, 'LowerTorso')
            self.add('seed_pouch_flap', (-.86, 2.42, .68), (.49, .15, .06), 0x45301f, 'LowerTorso')
            self.add('pouch_button', (-.86, 2.34, .725), (.075, .075, .04), 0xd9bb72, 'LowerTorso', shape=0)
        elif k=='sage_priest':
            for sign, side in [(-1,'Left'), (1,'Right')]:
                self.add('stole_chest_'+side, (sign*.62, 3.30, .57), (.30, 1.12, .12), self.accent)
                self.add('stole_waist_'+side, (sign*.62, 2.44, .60), (.30, .47, .13), self.accent, 'LowerTorso')
                self.add('stole_skirt_'+side, (sign*.66, 1.67, .605), (.34, .91, .11), self.accent, side+'UpperLeg')
                self.add('stole_hem_'+side, (sign*.66, .67, .65), (.35, .80, .12), self.accent, side+'LowerLeg')
                self.add('gold_stole_line_'+side, (sign*.64, 3.3, .645), (.038, 1.10, .035), self.trim)
                self.add('stole_sigill_'+side, (sign*.66, .48, .73), (.16, .16, .035), self.trim, side+'LowerLeg', angle=45, metal=True)
                self.add('robe_hem_'+side, (sign*.53, .31, 0), (1.10, .12, 1.22), self.trim, side+'LowerLeg')
                self.add('shoulder_yoke_'+side, (sign*1.21, 3.91, 0), (.58, .17, 1.05), self.accent, side+'UpperArm', angle=sign*8)
            self.add('chest_medallion', (0, 3.43, .64), (.24, .31, .10), self.trim, angle=45, metal=True)
            self.add('medallion_stone', (0, 3.43, .711), (.12, .17, .05), self.accent, angle=45)
        elif k=='swordsman':
            self.add('plate_liner', (0, 3.31, .57), (1.83, 1.14, .16), 0x566473)
            for sign, side in [(-1,'Left'),(1,'Right')]:
                self.add('cuirass_'+side, (sign*.43, 3.35, .67), (.80, .87, .15), self.main, angle=-sign*5, metal=True)
                self.line('chest_edge_'+side, (sign*.80, 3.78, .77), (sign*.69, 2.94, .77), .05, self.trim, metal=True)
                self.add('pauldron_'+side, (sign*1.49, 3.88, 0), (1.04, .28, 1.08), self.main, side+'UpperArm', angle=sign*10, metal=True)
                self.add('pauldron_rim_'+side, (sign*1.49, 3.74, .535), (1.04, .09, .07), self.trim, side+'UpperArm', angle=sign*10, metal=True)
                self.add('arm_guard_'+side, (sign*1.48, 2.70, .45), (.76, .49, .13), 0x7b828a, side+'LowerArm', metal=True)
                self.add('tabard_'+side, (sign*.49, 1.72, .60), (.80, .90, .11), self.accent, side+'UpperLeg')
                self.add('tabard_hem_'+side, (sign*.49, 1.30, .668), (.78, .05, .04), self.trim, side+'UpperLeg')
                self.add('knee_plate_'+side, (sign*.50, 1.02, .49), (.57, .30, .12), self.main, side+'LowerLeg', angle=45, metal=True)
            self.add('gorget', (0, 3.82, .60), (1.35, .16, .17), 0x7b828a, metal=True)
            self.add('guild_crest', (0, 3.44, .80), (.29, .39, .055), self.trim, angle=45, metal=True)
            self.add('waist_guard', (0, 2.80, .63), (1.70, .18, .12), 0x7b828a, metal=True)
        elif k=='villager_elder':
            self.coat(self.accent, self.main, long=True)
            for sign in (-1,1):
                self.add('shawl_shoulder_'+str(sign), (sign*.89, 3.84, -.01), (.64, .25, 1.15), self.main, angle=sign*13)
                self.add('shawl_front_'+str(sign), (sign*.69, 3.35, .65), (.47, 1.08, .10), self.main, angle=sign*12)
                self.line('shawl_edge_'+str(sign), (sign*.38, 3.83, .724), (sign*.60, 2.85, .724), .048, 0x9ba17c)
            self.add('shawl_back', (0, 3.46, -.65), (2.12, .92, .15), self.main)
            self.add('shawl_brooch', (-.54, 3.49, .76), (.18, .23, .065), self.trim, angle=45, metal=True)
        else:
            # Basket contains 80 preserved components; use broad tailoring here.
            self.add('bodice', (0, 3.18, .56), (1.71, .94, .10), shade(self.main,.72))
            for sign in (-1,1):
                self.triangle('neckline_'+str(sign), (sign*.40, 3.64, .64), .59, .29, self.trim, sign)
                self.line('bodice_lacing_'+str(sign), (sign*.18, 3.50, .65), (-sign*.18, 3.12, .65), .036, self.trim)
            self.add('apron_waist', (0, 2.44, .64), (1.52, .41, .08), self.trim, 'LowerTorso')
            for x, side in [(-.40,'Left'),(.40,'Right')]:
                self.add('apron_skirt_'+side, (x, 1.66, .64), (.69, .91, .07), self.trim, side+'UpperLeg')
                self.add('apron_hem_'+side, (x, .70, .67), (.73, .80, .07), self.trim, side+'LowerLeg')
                self.add('apron_border_'+side, (x, .38, .72), (.73, .065, .035), self.accent, side+'LowerLeg')
            self.add('apron_pocket', (.19, 1.80, .70), (.35, .31, .04), 0xbfb294, 'RightUpperLeg')
        return self

    def save(self):
        parts = [i for i in self.tree.iter('Item') if i.get('class') == 'Part']
        assert len(parts) <= 160, (self.key, len(parts))
        refs = [i.get('referent') for i in self.tree.iter('Item')]
        assert len(refs) == len(set(refs)), self.key
        ET.indent(self.tree, space='  ')
        self.tree.write(self.path, encoding='utf-8', xml_declaration=True)
        return {'model': self.key, 'generated': self.count, 'total_parts': len(parts)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--models', type=Path, default=ROOT/'lemonade-game/ReplicatedStorage/NpcModels')
    args = parser.parse_args()
    for path in sorted(args.models.glob('*_R15.rbxmx')):
        if path.stem.removesuffix('_R15') in PALETTES:
            print(Tailor(path).build().save())


if __name__ == '__main__':
    main()
