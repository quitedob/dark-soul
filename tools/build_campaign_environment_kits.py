"""Author five modular campaign kits with Blender; no external assets required.

Run: blender --background --factory-startup --python-exit-code 1
     --python tools/build_campaign_environment_kits.py

All dimensions below are Godot meters (Y up). Vertices are converted to Blender
(x, -z, y) once; glTF Y-up export restores the original axes. Each part has an
identity root and one joined mesh per material, suitable for runtime MultiMesh.
"""
import json
import math
import random
import struct
import sys
from pathlib import Path

import bmesh
import bpy

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "game/assets/environment/campaign_kits"
EVIDENCE = ROOT / "build/temple-redesign-20260909"
PARTS = ("Floor", "Bridge", "Rail", "Column", "Gate", "Landmark", "Rock", "ArenaCover")
TAU = math.tau

STYLES = {
    "spirit_ruins": {
        "stone": (.29, .33, .31), "dark": (.105, .14, .145),
        "trim": (.40, .29, .13), "roof": (.065, .17, .17),
        "wood": (.25, .09, .055), "leaf": (.12, .24, .11), "glow": (.12, .56, .53),
        "rock_height": 22, "description": "Carved ruined temple, fluted columns, broken cornices and stratified cliffs",
    },
    "blood_iron": {
        "stone": (.27, .16, .12), "dark": (.075, .082, .085),
        "trim": (.29, .20, .12), "roof": (.16, .10, .075),
        "wood": (.18, .07, .035), "leaf": (.24, .11, .06), "glow": (1.0, .26, .025),
        "rock_height": 20, "description": "Staggered brick battlements, riveted iron braces, furnace and twin chimneys",
    },
    "jade_veil": {
        "stone": (.38, .43, .34), "dark": (.10, .21, .17),
        "trim": (.54, .42, .20), "roof": (.10, .32, .22),
        "wood": (.20, .12, .065), "leaf": (.14, .39, .19), "glow": (.23, .68, .38),
        "rock_height": 24, "description": "Jade garden moon gates, pierced circles, segmented bamboo and leaf sprays",
    },
    "celestial_fall": {
        "stone": (.58, .59, .48), "dark": (.19, .25, .29),
        "trim": (.63, .43, .14), "roof": (.10, .33, .34),
        "wood": (.35, .19, .075), "leaf": (.34, .52, .43), "glow": (.47, .78, .82),
        "rock_height": 27, "description": "Gold and jade cloud pagoda, stacked curved roofs, ringed columns and hanging bells",
    },
    "ember_abyss": {
        "stone": (.115, .12, .14), "dark": (.025, .031, .044),
        "trim": (.29, .145, .065), "roof": (.075, .063, .092),
        "wood": (.10, .045, .035), "leaf": (.20, .065, .035), "glow": (1.0, .18, .015),
        "rock_height": 30, "description": "Fractured obsidian, jagged volcanic ribs and an open ember furnace spire",
    },
}


class Part:
    """Accumulate actual bevel/ring/roof meshes directly, without thousands of bpy operators."""
    def __init__(self, name, style, rng):
        self.name, self.style, self.rng = name, style, rng
        self.meshes = {}

    def mesh(self, material, vertices, faces):
        verts, polys = self.meshes.setdefault(material, ([], []))
        offset = len(verts)
        verts.extend(vertices)
        polys.extend(tuple(offset + i for i in face) for face in faces)

    def block(self, x, y, z, sx, sy, sz, mat="stone", bevel=.05, yaw=0):
        # Four octagonal rings form chamfered vertical corners and upper/lower shoulders.
        b = min(bevel, sx * .18, sy * .22, sz * .18)
        points = [(-sx/2+b, -sz/2), (sx/2-b, -sz/2), (sx/2, -sz/2+b),
                  (sx/2, sz/2-b), (sx/2-b, sz/2), (-sx/2+b, sz/2),
                  (-sx/2, sz/2-b), (-sx/2, -sz/2+b)]
        verts = []
        for height, inset in ((y-sy/2, b), (y-sy/2+b, 0), (y+sy/2-b, 0), (y+sy/2, b)):
            for px, pz in points:
                px *= 1 - inset / max(sx/2, .01)
                pz *= 1 - inset / max(sz/2, .01)
                verts.append((x + px*math.cos(yaw)-pz*math.sin(yaw), height,
                              z + px*math.sin(yaw)+pz*math.cos(yaw)))
        faces = [tuple(reversed(range(8))), tuple(range(24, 32))]
        for ring in range(3):
            for i in range(8):
                faces.append((ring*8+i, ring*8+(i+1)%8, (ring+1)*8+(i+1)%8, (ring+1)*8+i))
        self.mesh(mat, verts, faces)

    def lathe(self, x, z, profile, mat="stone", sides=20, flute=0, twist=0):
        verts = []
        for ring, (y, radius) in enumerate(profile):
            for i in range(sides):
                angle = TAU*i/sides + twist*ring
                r = radius * (1 + flute * (1 if i % 2 else -1))
                verts.append((x+r*math.cos(angle), y, z+r*math.sin(angle)))
        faces = [tuple(reversed(range(sides)))]
        for ring in range(len(profile)-1):
            for i in range(sides):
                faces.append((ring*sides+i, ring*sides+(i+1)%sides,
                              (ring+1)*sides+(i+1)%sides, (ring+1)*sides+i))
        faces.append(tuple((len(profile)-1)*sides+i for i in range(sides)))
        self.mesh(mat, verts, faces)

    def torus(self, x, y, z, major, minor, mat="trim", vertical=False, sides=32):
        verts = []
        for i in range(sides):
            a = TAU*i/sides
            for j in range(6):
                b = TAU*j/6
                px, py, pz = (major+minor*math.cos(b))*math.cos(a), minor*math.sin(b), (major+minor*math.cos(b))*math.sin(a)
                if vertical:
                    py, pz = pz, py
                verts.append((x+px, y+py, z+pz))
        faces = []
        for i in range(sides):
            for j in range(6):
                faces.append((i*6+j, ((i+1)%sides)*6+j, ((i+1)%sides)*6+(j+1)%6, i*6+(j+1)%6))
        self.mesh(mat, verts, faces)

    def beam(self, a, b, radius, mat="trim", sides=8):
        from mathutils import Vector
        start, end = Vector(a), Vector(b)
        axis = (end-start).normalized()
        tangent = axis.cross(Vector((0, 1, 0)))
        if tangent.length < .01:
            tangent = axis.cross(Vector((1, 0, 0)))
        tangent.normalize()
        other = axis.cross(tangent).normalized()
        verts = []
        for p in (start, end):
            for i in range(sides):
                v = p + radius*(tangent*math.cos(TAU*i/sides)+other*math.sin(TAU*i/sides))
                verts.append(tuple(v))
        faces = [tuple(reversed(range(sides))), tuple(range(sides, sides*2))]
        faces += [(i, (i+1)%sides, sides+(i+1)%sides, sides+i) for i in range(sides)]
        self.mesh(mat, verts, faces)

    def roof(self, x, y, z, width, depth, rise, mat="roof"):
        # Broad curved gable slopes, upturned eaves, tile ribs and a modeled ridge.
        slices = 8
        for side in (-1, 1):
            verts = []
            for i in range(slices+1):
                t = i/slices
                h = y+rise*(1-t)**1.6 + rise*.22*t**7
                for px in (-width/2, width/2):
                    verts.append((x+px, h, z+side*depth*.5*t))
            faces = [(i*2, i*2+1, (i+1)*2+1, (i+1)*2) for i in range(slices)]
            self.mesh(mat, verts, faces)
            # Tile ribs follow the actual curved surface, not a flat box roof.
            for k in range(max(5, int(width/.48))+1):
                px = x-width/2 + width*k/max(5, int(width/.48))
                for i in range(slices):
                    t0, t1 = i/slices, (i+1)/slices
                    h0 = y+rise*(1-t0)**1.6+rise*.22*t0**7
                    h1 = y+rise*(1-t1)**1.6+rise*.22*t1**7
                    self.beam((px,h0,z+side*depth*.5*t0), (px,h1,z+side*depth*.5*t1), .036, mat, 6)
            self.beam((x-width/2,y+rise*.22,z+side*depth/2),
                      (x+width/2,y+rise*.22,z+side*depth/2), .08, "trim")
        self.beam((x-width/2,y+rise,z), (x+width/2,y+rise,z), .10, "trim")

    def bamboo(self, x, z, height, lean=.6):
        segments = int(height/.7)
        for i in range(segments):
            y0, y1 = height*i/segments, height*(i+1)/segments
            off0, off1 = lean*(i/segments)**1.5, lean*((i+1)/segments)**1.5
            self.beam((x+off0,y0,z), (x+off1,y1,z), .09, "leaf", 10)
            self.lathe(x+off1, z, [(y1-.035,.11),(y1+.035,.11)], "trim", 10)
            if i > segments//2 and i % 2 == 0:
                direction = -1 if i % 4 else 1
                end = (x+off1+direction*.8, y1+.35, z+.25)
                self.beam((x+off1,y1,z), end, .026, "leaf", 6)
                for j in range(4):
                    bx = x+off1+direction*(.25+j*.16)
                    yy = y1+.12+j*.06
                    # Folded four-sided leaves provide shape and facet lighting.
                    verts = [(bx,yy,z+.1),(bx+direction*.35,yy+.05,z-.12),
                             (bx+direction*.5,yy-.15,z+.12),(bx+direction*.23,yy+.035,z+.2)]
                    self.mesh("leaf", verts, [(0,1,3),(1,2,3)])

    def rock(self, x, z, radius, height, mat="stone", rings=8, sides=11):
        phase = self.rng.random()*TAU
        verts = []
        for ring in range(rings):
            t = ring/(rings-1)
            center_x = x+math.sin(t*3+phase)*radius*.16*t
            center_z = z+math.cos(t*4+phase)*radius*.13*t
            taper = max(.04, (1-t)**.42)
            for i in range(sides):
                angle = TAU*i/sides + (ring%2)*.09
                r = radius*taper*self.rng.uniform(.78,1.09)
                yy = height*t
                if 0 < ring < rings-1:
                    yy += self.rng.uniform(-.23,.23)
                verts.append((center_x+r*math.cos(angle), yy, center_z+r*math.sin(angle)))
        faces = [tuple(reversed(range(sides)))]
        for ring in range(rings-1):
            for i in range(sides):
                a,b = ring*sides+i, ring*sides+(i+1)%sides
                c,d = (ring+1)*sides+(i+1)%sides, (ring+1)*sides+i
                faces.extend([(a,b,c),(a,c,d)])
        faces.append(tuple((rings-1)*sides+i for i in range(sides)))
        self.mesh(mat, verts, faces)

    def fit(self, width=None, height=None, depth=None, bottom=0):
        points = [v for vertices,_ in self.meshes.values() for v in vertices]
        mins = [min(p[i] for p in points) for i in range(3)]
        maxs = [max(p[i] for p in points) for i in range(3)]
        scales = [size/(maxs[i]-mins[i]) if size is not None else 1 for i,size in enumerate((width,height,depth))]
        center = [(mins[0]+maxs[0])/2, mins[1], (mins[2]+maxs[2])/2]
        for mat,(verts,faces) in self.meshes.items():
            self.meshes[mat] = ([( (p[0]-center[0])*scales[0], (p[1]-center[1])*scales[1]+bottom,
                                   (p[2]-center[2])*scales[2]) for p in verts], faces)


def make_floor(p, bridge=False):
    if bridge:
        # Separate the visible layers: the old base, planks and rivet caps all
        # ended at .14m and fought for the same depth pixels across the deck.
        # Rivets retain the .14m collision datum; the walking deck is 2cm below
        # it, while the complete part remains exactly 6 x .28 x 6 metres.
        p.block(0,-.06,0,6,.16,6,"dark",.025)
        for i in range(10):
            p.block(0,.065,-2.7+i*.6,5.94,.11,.565,"wood" if p.style in ("jade_veil","blood_iron") else "stone",.025)
        for x in (-2.72,2.72):
            for z in (-2.7,-1.5,-.3,.9,2.1,2.7):
                p.lathe(x,z,[(.115,.07),(.14,.05)],"trim",8)
        p.fit(6,.28,6,-.14)
        return
    p.block(0,-.35,0,6,.5,6,"dark",.10)
    for row in range(4):
        for col in range(4):
            x,z = -2.25+col*1.5, -2.25+row*1.5
            # Inlays keep the Y=0 floor datum; recessed paving makes their
            # existing surfaces visible without coplanar gold/stone fragments.
            p.block(x,-.077,z,1.46,.13,1.46, "stone" if (row+col)%3 else "stone_light", .04)
    if p.style in ("spirit_ruins","jade_veil","celestial_fall"):
        p.torus(0,-.012,0,1.22,.012,"trim",sides=40)
        for angle in range(8):
            a=TAU*angle/8
            p.block(1.55*math.cos(a),-.012,1.55*math.sin(a),.33,.024,.10,"trim",.01,a)
    elif p.style == "blood_iron":
        for z in (-2.9,2.9):
            p.block(0,-.012,z,5.8,.024,.11,"trim",.01)
    else:
        # A six-sided horizontal beam reaches radius*sin(60deg) above its
        # center. Keep the original thin veins' highest vertices exactly at 0.
        vein_y=-.012*math.sin(TAU/6)
        for a,b in [((-2.5,vein_y,-2),(1,vein_y,.4)),((1,vein_y,.4),(2.7,vein_y,2.3)),((1,vein_y,.4),(-.2,vein_y,2.8))]:
            p.beam(a,b,.012,"glow",6)
    p.fit(6,.6,6,-.6)


def make_column(p, x=0, z=0, height=6):
    h = height/6
    if p.style == "blood_iron":
        for row in range(9):
            p.block(x,.35+row*.59,z,1.25 if row in (0,8) else .92,.70 if row==0 else .55,1.25 if row in (0,8) else .92,"stone_light" if row%3==0 else "stone",.06)
        for y in (1.0,2.7,4.4):
            p.block(x,y,z,1.02,.16,1.02,"dark",.03)
            for dx in (-.36,.36):
                p.beam((x+dx,y,z-.54),(x+dx,y,z-.49),.07,"trim")
        p.block(x,5.72,z,1.7,.56,1.7,"dark",.10)
    elif p.style == "ember_abyss":
        p.lathe(x,z,[(0,.95),(.25,1),(.48,.67),(4.7,.50),(5.1,.84),(5.65,.68),(6,.1)],"stone",10,.15,.07)
        for angle in range(5):
            a=TAU*angle/5
            p.beam((x+.7*math.cos(a),.6,z+.7*math.sin(a)),
                   (x+.50*math.cos(a+.3),4.7,z+.5*math.sin(a+.3)),.035,"glow",6)
    else:
        p.lathe(x,z,[(0,.91),(.18,.96),(.34,.78),(.51,.65),(.66,.51),
                     (4.9,.46),(5.03,.64),(5.25,.71),(5.39,.88),(5.68,.95),(6,.72)],
                "stone",24,.06 if p.style=="spirit_ruins" else .02)
        for y in (.6,1.1,4.55,5.30):
            p.torus(x,y,z,.54 if y<5 else .75,.055,"trim",sides=24)
        if p.style == "jade_veil":
            for y in (1.65,2.5,3.35,4.2):
                p.torus(x,y,z,.49,.045,"roof",sides=20)
        if p.style == "celestial_fall":
            for a in range(4):
                angle=TAU*a/4
                p.beam((x+.55*math.cos(angle),1.2,z+.55*math.sin(angle)),
                       (x+.50*math.cos(angle),4.45,z+.50*math.sin(angle)),.04,"trim",6)
    if height != 6:
        # Called only in isolated temporary parts; nested columns are merged below.
        p.fit(height=height)


def merge(dst, src, offset=(0,0,0), scale=1):
    for material,(vertices,faces) in src.meshes.items():
        dst.mesh(material, [(v[0]*scale+offset[0],v[1]*scale+offset[1],v[2]*scale+offset[2]) for v in vertices], faces)


def make_rail(p):
    for x in (-2.75,-.92,.92,2.75):
        p.lathe(x,0,[(0,.23),(.15,.24),(.26,.15),(1.2,.12),(1.31,.23),(1.4,.1)],"stone",12)
    if p.style == "blood_iron":
        for row in range(3):
            for i in range(7):
                p.block(-2.55+i*.85,.18+row*.29,0,.80,.26,.35,"stone",.035)
        for i in range(8):
            p.block(-2.65+i*.76,1.17,0,.38,.46,.47,"dark",.035)
    elif p.style == "ember_abyss":
        for i in range(9):
            p.lathe(-2.6+i*.65,0,[(.1,.20),(.95,.13),(1.4,.015)],"stone",5,0,.18)
            p.beam((-2.6+i*.65,.2,.2),(-2.6+i*.65,1.1,.09),.021,"glow",5)
    else:
        p.beam((-3,1.18,0),(3,1.18,0),.105,"trim",10)
        p.beam((-3,.3,0),(3,.3,0),.11,"stone",10)
        for x in (-1.83,0,1.83):
            if p.style == "jade_veil":
                p.torus(x,.74,0,.32,.065,"roof",True,24)
            elif p.style == "celestial_fall":
                for side in (-1,1):
                    p.beam((x-.7,.4,0),(x,.95,side*.06),.05,"trim")
                    p.beam((x,.95,side*.06),(x+.7,.4,0),.05,"trim")
            else:
                for dx in (-.45,-.15,.15,.45):
                    p.block(x+dx,.72,0,.10,.76,.16,"stone_light",.025)
    p.fit(width=6,height=1.4)


def make_gate(p):
    for x in (-4.8,4.8):
        column=Part("pillar",p.style,p.rng)
        make_column(column)
        merge(p,column,(x,0,0),1)
    p.block(0,6.1,0,12,.6,1.6,"wood" if p.style!="ember_abyss" else "dark",.09)
    if p.style == "blood_iron":
        p.block(0,6.63,0,12,.48,1.85,"stone",.09)
        for i in range(12):
            p.block(-5.5+i,7.24,0,.57,.78,1.9,"dark",.06)
        for x in (-4.8,4.8):
            p.block(x,7.60,0,1.5,.8,2,"stone_light",.10)
    elif p.style == "ember_abyss":
        for x in range(-5,6):
            height=.7+.45*(1-abs(x)/5)
            p.lathe(x,0,[(6.3,.45),(6.4+height*.65,.26),(6.4+height,.015)],"stone",6,0,.19)
        p.torus(0,6.7,-.86,.63,.085,"glow",True,28)
    else:
        p.roof(0,6.7,0,11.8,3.4,1.0)
        if p.style == "celestial_fall":
            p.roof(0,7.25,0,8.8,2.4,.58)
        for x in (-4.3,4.3):
            p.lathe(x,-1.25,[(5.55,.05),(5.72,.24),(6.1,.15)],"trim",14)
        p.torus(0,6.45,-.92,.34,.08,"trim",True,24)
    p.fit(width=12,height=8)


def make_landmark(p):
    style=p.style
    if style == "jade_veil":
        p.block(0,.22,0,10.8,.44,8.8,"stone",.12)
        p.torus(0,3.1,0,2.55,.40,"stone_light",True,48)
        for x in (-4,4):
            for j in range(4):
                p.bamboo(x+p.rng.uniform(-.65,.65),p.rng.uniform(-2.7,2.7),p.rng.uniform(6.7,10.3),p.rng.uniform(-.8,.8))
        p.roof(0,5.8,0,7.2,3.8,1.25)
        for x in (-3,3):
            p.rock(x,2,1.1,2.4,"dark",6,9)
    elif style == "blood_iron":
        for row in range(10):
            for x in range(6):
                for side in (-1,1):
                    px=-3.1+x*1.24
                    if side == -1 and abs(px) < 1.3 and row < 6:
                        continue  # The actual furnace mouth remains visible through the entrance.
                    p.block(px,.35+row*.52,side*3.2,1.16,.47,.7,"stone_light" if (row+x)%4==0 else "stone",.06)
            for x in (-3.3,3.3):
                for z in range(6):
                    p.block(x,.35+row*.52,-2.7+z*1.08,.7,.47,1.02,"stone",.06)
        # Joined side walls and a lintel slab carry the two heavy chimneys.
        p.block(0,5.15,0,7.8,.36,7.4,"dark",.09)
        for x in (-3.3,3.3):
            for y in (5.5,6.5,7.5,8.5,9.5,10.5,11.5):
                p.block(x,y,1.5,1.5,.94,1.5,"dark",.07)
            p.block(x,12.1,1.5,1.9,.4,1.9,"trim",.07)
        p.lathe(0,0,[(0,2.5),(.4,2.7),(1,2.2),(4.2,2.2),(5.1,1.7),(5.5,1.8)],"dark",16)
        for y in (.9,2.1,3.3):
            p.torus(0,y,0,2.24,.10,"trim",sides=24)
        p.torus(0,2.7,-2.05,1.0,.16,"glow",True,28)
        for i in range(5):
            x=-.66+i*.33
            p.beam((x,1.95,-2.2),(x,3.47,-2.2),.055,"trim")
        p.block(0,.25,0,10.5,.5,9.5,"stone",.14)
    elif style == "ember_abyss":
        p.lathe(0,0,[(0,4.5),(.5,4.8),(1.1,3.4),(4.1,2.8),(7.0,2.15),(8,2.5)],"dark",10,0,.12)
        for i in range(7):
            a=TAU*i/7
            p.rock(3.2*math.cos(a),3.2*math.sin(a),1.1,10+p.rng.random()*5,"stone",7,7)
            p.beam((3.2*math.cos(a),1,3.2*math.sin(a)),(1.7*math.cos(a+.2),7,1.7*math.sin(a+.2)),.075,"glow")
        p.lathe(0,0,[(1,1.6),(5,1.25),(9,.85),(13,.03)],"glow",9,0,.1)
        for y,r in ((1,3.6),(4.6,2.7),(7.2,2.3)):
            p.torus(0,y,0,r,.16,"trim",sides=18)
    else:
        p.block(0,.25,0,11.5,.5,10.5,"dark",.13)
        p.block(0,.67,0,10.4,.34,9.4,"stone_light",.12)
        tiers=3 if style=="celestial_fall" else 1
        for tier in range(tiers):
            scale=1-tier*.22
            base=.82+tier*4.5
            for x in (-3.55,3.55):
                for z in (-2.7,2.7):
                    col=Part("support",style,p.rng)
                    make_column(col)
                    merge(p,col,(x*scale,base,z*scale),.73*scale)
            p.roof(0,base+4.25*scale,0,11.0*scale,9.1*scale,1.75*scale)
            if tier<tiers-1:
                p.block(0,base+4.7,0,6.6*scale,.4,5.8*scale,"stone",.09)
        if style=="celestial_fall":
            p.lathe(0,0,[(13.0,.50),(14.0,.35),(14.35,.7),(14.6,.30),(16.0,.015)],"trim",18)
        else:
            # Ruined rear masonry and broken tablets distinguish it from an intact pagoda.
            for x in (-3,-1.5,0,1.5,3):
                for row in range(3+int((x+3)%3)):
                    p.block(x,1.15+row*.48,2.7,1.40,.43,.6,"stone",.06)
            p.lathe(0,0,[(.8,1.25),(1.15,1.35),(1.5,.7),(3.6,.8),(4.2,.2)],"stone_light",12,.08)
    # Preserve intended proportions; only reduce oversized leaves/roof ornaments.
    points=[v for vs,_ in p.meshes.values() for v in vs]
    width=max(v[0] for v in points)-min(v[0] for v in points)
    depth=max(v[2] for v in points)-min(v[2] for v in points)
    p.fit(width=min(width,12),depth=min(depth,12))


def make_rock(p):
    if p.style == "ember_abyss":
        for i in range(7):
            a=TAU*i/7
            p.rock(2.8*math.cos(a),2.8*math.sin(a),1.55,18+p.rng.random()*12,"dark" if i%2 else "stone",7,7)
        p.rock(0,0,2.7,30,"stone",9,8)
    elif p.style == "jade_veil":
        for x,z,h in ((0,0,24),(-2.8,1.8,19),(2.3,-1.3,16)):
            p.rock(x,z,2.2,h,"stone",10,13)
        for i in range(4):
            p.bamboo(-2+i*1.3,2.3,8+i*.7,.5)
    elif p.style == "celestial_fall":
        p.rock(0,0,3.8,27,"stone",12,13)
        for i in range(5):
            a=TAU*i/5
            p.rock(2.8*math.cos(a),2.8*math.sin(a),1.7,13+i*1.9,"stone_light",9,10)
        for y in (8,15,21):
            p.torus(0,y,0,3.0-(y/40),.14,"trim",sides=18)
    else:
        p.rock(0,0,4.2,22,"stone",11,13)
        for i in range(4):
            a=TAU*i/4
            p.rock(3*math.cos(a),3*math.sin(a),1.8,8+i*2.3,"dark",8,10)
        if p.style=="spirit_ruins":
            for y in (3,6,9,12):
                p.lathe(0,0,[(y,3.5-y*.12),(y+.18,3.65-y*.12)],"stone_light",13)
    p.fit(10,STYLES[p.style]["rock_height"],10)


def make_cover(p):
    p.lathe(0,0,[(0,.94),(.22,1),(.44,.75),(.62,.64),(2.28,.54),(2.45,.77),(2.67,.94),(3,.74)],"stone",16,.05)
    if p.style=="blood_iron":
        for y in (.55,1.4,2.3):
            p.torus(0,y,0,.67,.06,"trim",sides=16)
    elif p.style=="ember_abyss":
        for i in range(5):
            a=TAU*i/5
            p.beam((.65*math.cos(a),.6,.65*math.sin(a)),(.6*math.cos(a+.2),2.3,.6*math.sin(a+.2)),.025,"glow",6)
    else:
        for i in range(4):
            a=TAU*i/4
            p.torus(.59*math.cos(a),1.45,.59*math.sin(a),.19,.035,"roof",True,16)
    p.fit(2,3,2)


def srgb_to_linear(value):
    """Palette numbers are artist-facing display RGB; Blender/glTF factors are linear."""
    return value / 12.92 if value <= .04045 else ((value + .055) / 1.055) ** 2.4


def materials(style):
    palette=STYLES[style]
    result={}
    for name in ("stone","stone_light","dark","trim","roof","wood","leaf","glow"):
        color=tuple(min(1,c*1.15) for c in palette["stone"]) if name=="stone_light" else palette[name]
        color=tuple(srgb_to_linear(c) for c in color)
        material=bpy.data.materials.new(style+"_"+name)
        material.diffuse_color=(*color,1)
        material.use_nodes=True
        bs=material.node_tree.nodes.get("Principled BSDF")
        bs.inputs["Base Color"].default_value=(*color,1)
        bs.inputs["Roughness"].default_value=.48 if name in ("roof","trim") else .88
        bs.inputs["Metallic"].default_value=.62 if name=="trim" else .08 if name=="roof" else 0
        if name=="glow":
            bs.inputs["Emission Color"].default_value=(*color,1)
            bs.inputs["Emission Strength"].default_value=1.25
        material.use_backface_culling=False
        result[name]=material
    return result


def realize(part, scene, mats):
    root=bpy.data.objects.new(part.name,None)
    scene.collection.objects.link(root)
    root["kit_part"]=part.name
    root["meters"]=True
    points=[]
    triangles=0
    for name,(verts,faces) in part.meshes.items():
        points.extend(verts)
        mesh=bpy.data.meshes.new(part.name+"_"+name)
        mesh.from_pydata([(x,-z,y) for x,y,z in verts],[],faces)
        mesh.materials.append(mats[name])
        mesh.update()
        bm=bmesh.new()
        bm.from_mesh(mesh)
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        bm.to_mesh(mesh)
        bm.free()
        mesh.calc_loop_triangles()
        triangles+=len(mesh.loop_triangles)
        obj=bpy.data.objects.new(part.name+"_"+name,mesh)
        scene.collection.objects.link(obj)
        obj.parent=root
    lower=[round(min(p[i] for p in points),5) for i in range(3)]
    upper=[round(max(p[i] for p in points),5) for i in range(3)]
    return {"min":lower,"max":upper,"size":[round(upper[i]-lower[i],5) for i in range(3)],
            "triangles":triangles,"mesh_count":len(part.meshes),"vertices":len(points)}


def inspect_glb(path):
    raw=path.read_bytes()
    assert raw[:4]==b"glTF", "Not a GLB"
    length,kind=struct.unpack_from("<II",raw,12)
    assert kind==0x4E4F534A
    doc=json.loads(raw[20:20+length])
    roots=doc["scenes"][doc.get("scene",0)]["nodes"]
    names=[doc["nodes"][i]["name"] for i in roots]
    assert set(names)==set(PARTS), (path,names)
    assert not doc.get("animations"), "Environment kit must not carry animation clips"
    assert not any("Cube"==node.get("name") for node in doc["nodes"])
    exported_bounds={}
    bridge_material_y_ranges={}
    floor_material_y_ranges={}
    for index in roots:
        root=doc["nodes"][index]
        for key,identity in (("translation",[0,0,0]),("rotation",[0,0,0,1]),("scale",[1,1,1])):
            assert all(abs(a-b)<1e-6 for a,b in zip(root.get(key,identity),identity)), (root["name"],key)
        positions=[]
        for child_index in root.get("children",[]):
            child=doc["nodes"][child_index]
            assert "mesh" in child and not child.get("children"), "Part children must be joined material meshes"
            assert not any(key in child for key in ("matrix","translation","rotation","scale")), child
            for primitive in doc["meshes"][child["mesh"]]["primitives"]:
                accessor=doc["accessors"][primitive["attributes"]["POSITION"]]
                positions.extend((accessor["min"],accessor["max"]))
                if root["name"]=="Bridge":
                    material=doc["materials"][primitive["material"]]["name"].removeprefix(path.stem+"_")
                    bridge_material_y_ranges[material]=[accessor["min"][1],accessor["max"][1]]
                elif root["name"]=="Floor":
                    material=doc["materials"][primitive["material"]]["name"].removeprefix(path.stem+"_")
                    floor_material_y_ranges[material]=[accessor["min"][1],accessor["max"][1]]
        exported_bounds[root["name"]]={"min":[min(p[i] for p in positions) for i in range(3)],
                                        "max":[max(p[i] for p in positions) for i in range(3)]}
    # Check the exported GLB, not just Python inputs: distinct visible surface
    # heights prevent the whole-deck z-fighting observed in actual Chrome.
    deck="wood" if path.stem in ("jade_veil","blood_iron") else "stone"
    for material,wanted in {"dark":(-.14,.02),deck:(.01,.12),"trim":(.115,.14)}.items():
        assert all(abs(a-b)<.00001 for a,b in zip(bridge_material_y_ranges[material],wanted)), (path,material,bridge_material_y_ranges)
    assert bridge_material_y_ranges[deck][1]-bridge_material_y_ranges["dark"][1]>.09
    assert bridge_material_y_ranges["trim"][1]-bridge_material_y_ranges[deck][1]>.019
    for material,wanted in {"dark":(-.6,-.1),"stone":(-.142,-.012),"stone_light":(-.142,-.012)}.items():
        assert all(abs(a-b)<.00001 for a,b in zip(floor_material_y_ranges[material],wanted)), (path,material,floor_material_y_ranges)
    inlay="glow" if path.stem=="ember_abyss" else "trim"
    assert abs(floor_material_y_ranges[inlay][1])<.00001, (path,floor_material_y_ranges)
    assert floor_material_y_ranges[inlay][1]-floor_material_y_ranges["stone"][1]>.011
    return {"root_parts":names,"glb_meshes":len(doc.get("meshes",[])),"bytes":len(raw),
            "exported_y_up_bounds":exported_bounds,"bridge_material_y_ranges":bridge_material_y_ranges,
            "floor_material_y_ranges":floor_material_y_ranges}


def verify_dimensions(name, bounds, style):
    expected={"Floor":(6,.6,6),"Bridge":(6,.28,6),"Rail":(6,1.4,None),
              "Column":(None,6,None),"Gate":(12,8,None),
              "Rock":(10,STYLES[style]["rock_height"],10),"ArenaCover":(2,3,2)}
    bottom=-.6 if name=="Floor" else -.14 if name=="Bridge" else 0
    assert abs(bounds["min"][1]-bottom)<.0001, (style,name,"ground contact",bounds)
    for actual,wanted in zip(bounds["size"],expected.get(name,(None,None,None))):
        assert wanted is None or abs(actual-wanted)<.0001, (style,name,"dimensions",bounds)
    if name=="Landmark":
        assert bounds["size"][0]<=12.0001 and bounds["size"][2]<=12.0001
    assert bounds["triangles"]>200 and bounds["mesh_count"]>=2, (style,name,"modeled detail")


def prepare_preview(scene, style):
    """Studio layout lives only in the .blend, after identity-root GLB export."""
    from mathutils import Vector
    layout={"Floor":(-13,-14),"Bridge":(0,-14),"Rail":(13,-14),"Column":(-14,0),
            "Gate":(0,0),"ArenaCover":(14,0),"Landmark":(-11,15),"Rock":(13,18)}
    for obj in scene.objects:
        if obj.get("kit_part") in layout:
            x,z=layout[obj["kit_part"]]
            obj.location=(x,-z,0)
    camera_data=bpy.data.cameras.new(style+"_PreviewCamera")
    camera=bpy.data.objects.new(style+"_PreviewCamera",camera_data)
    scene.collection.objects.link(camera)
    camera.location=(43,53,42)
    camera.rotation_euler=(Vector((0,-2,7))-camera.location).to_track_quat('-Z','Y').to_euler()
    camera_data.type='ORTHO'
    camera_data.ortho_scale=72
    scene.camera=camera
    world=bpy.data.worlds.new(style+"_PreviewWorld")
    world.use_nodes=True
    world.node_tree.nodes["Background"].inputs["Color"].default_value=(.22,.25,.29,1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value=.7
    scene.world=world
    for name,location,energy,size in (("Key",(5,22,37),6500,22),("Fill",(-25,-3,22),4400,26)):
        light_data=bpy.data.lights.new(style+name,'AREA')
        light_data.energy=energy
        light_data.shape='DISK'
        light_data.size=size
        light=bpy.data.objects.new(style+name,light_data)
        scene.collection.objects.link(light)
        light.location=location
        light.rotation_euler=(Vector((0,-2,3))-light.location).to_track_quat('-Z','Y').to_euler()
    sun_data=bpy.data.lights.new(style+"Sun",'SUN')
    sun_data.energy=2.4
    sun_data.angle=.35
    sun=bpy.data.objects.new(style+"Sun",sun_data)
    scene.collection.objects.link(sun)
    sun.rotation_euler=(.45,-.3,-.5)
    scene.render.engine='BLENDER_EEVEE'
    scene.render.resolution_x=1600
    scene.render.resolution_y=1100
    scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG'
    scene.render.filepath=str(EVIDENCE/(style+"-kit-preview.png"))
    scene.view_settings.view_transform='Standard'
    scene.render.film_transparent=False


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    EVIDENCE.mkdir(parents=True,exist_ok=True)
    report={"schema_version":1,"coordinates":"Godot Y-up meters; all part roots identity",
            "palette_encoding":"Artist display sRGB converted to linear BSDF, diffuse and glTF factors",
            "parts":list(PARTS),"themes":{}}
    initial_scenes=list(bpy.data.scenes)
    for index,style in enumerate(STYLES):
        scene=bpy.data.scenes.new("CampaignKit_"+style)
        bpy.context.window.scene=scene
        scene.unit_settings.system="METRIC"
        scene.unit_settings.scale_length=1
        mats=materials(style)
        rng=random.Random(290909+index)
        entry={"description":STYLES[style]["description"],"parts":{}}
        for name in PARTS:
            part=Part(name,style,rng)
            if name=="Floor": make_floor(part)
            elif name=="Bridge": make_floor(part,True)
            elif name=="Rail": make_rail(part)
            elif name=="Column": make_column(part)
            elif name=="Gate": make_gate(part)
            elif name=="Landmark": make_landmark(part)
            elif name=="Rock": make_rock(part)
            elif name=="ArenaCover": make_cover(part)
            entry["parts"][name]=realize(part,scene,mats)
            verify_dimensions(name,entry["parts"][name],style)
        path=OUT/(style+".glb")
        bpy.ops.export_scene.gltf(filepath=str(path),export_format="GLB",use_active_scene=True,
                                 export_animations=False,export_yup=True,export_apply=True,export_extras=True)
        entry.update(inspect_glb(path))
        for name, bounds in entry["exported_y_up_bounds"].items():
            for edge in ("min","max"):
                assert all(abs(a-b)<.0001 for a,b in zip(bounds[edge],entry["parts"][name][edge])), (style,name,edge)
        report["themes"][style]=entry
        # Keep all five scenes in the .blend while freeing canonical part names
        # for the next GLB. Exported roots remain exactly Floor/Bridge/etc.
        for obj in scene.objects:
            obj.name=style+"_"+obj.name
        prepare_preview(scene,style)
        print("CAMPAIGN_KIT_MODELED "+style+" "+json.dumps(entry),flush=True)
    for scene in initial_scenes:
        bpy.data.scenes.remove(scene)
    bpy.ops.wm.save_as_mainfile(filepath=str(EVIDENCE/"campaign-kits.blend"))
    (EVIDENCE/"campaign-kits-report.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
    print("CAMPAIGN_ENVIRONMENT_KITS_OK themes=5 parts=40",flush=True)
    if "--render-previews" in sys.argv:
        for scene in bpy.data.scenes:
            bpy.context.window.scene=scene
            bpy.ops.render.render(write_still=True)
            print("CAMPAIGN_KIT_PREVIEW_OK "+scene.name,flush=True)


if __name__=="__main__":
    main()
