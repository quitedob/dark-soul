"""Build authored story architecture for the 29 campaign locations.

Blender: --background --factory-startup --python-exit-code 1 --python this_file
Optional --render-previews writes one catalog plate per chapter to build/.
Plain Python: python tools/build_campaign_story_props.py --check

The existing kit module is import-safe (its generator is guarded by __main__).
Only its mesh construction helpers are reused; no existing model is modified.
All exported roots are identity, Godot Y-up, foot at zero and front towards -Z.
"""
import argparse
import importlib.util
import json
import math
import random
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "game/assets/environment/story_props"
EVIDENCE = ROOT / "build/temple-redesign-20260909/story-props"
TAU = math.tau

# Dimensions are actual exported envelopes: X, Y, Z. Open buildings use local
# solid navigation proxies, never a full enclosing box over their doorways.
CATALOG = {
    "spirit_ruins": {
        "MuralWall": (6, 4, .9), "AwakeningBier": (2, 1.2, 3.6),
        "KneelingStatue": (2.4, 3.2, 2.4), "CryptWall": (6, 4, 1),
        "Sarcophagus": (1.7, 1.3, 3.2), "WatchBrazier": (2, 3.5, 2),
    },
    "blood_iron": {
        "PrisonCage": (4, 3.5, 4), "CommandTent": (8, 5, 8),
        "WarTable": (3, 1.5, 2.3), "WarBanner": (2.5, 5, 1),
        "SiegeWagon": (3.4, 3, 5), "Barricade": (6, 2.1, 1.4),
        "BeaconTower": (8, 14, 8),
    },
    "jade_veil": {
        "BambooGrove": (6, 9, 6), "WeddingLantern": (1.4, 4, 1.4),
        "Palanquin": (3.5, 3.8, 5), "MemoryMirror": (3, 4.2, 1.2),
        "LakePavilion": (10, 7, 10), "IllusionTree": (6, 7, 6),
        "HedgeWall": (6, 3, 1.6), "LakeSurface": (18, .08, 18),
    },
    "celestial_fall": {
        "ArchiveShelf": (5, 7, 1.4), "BronzeCauldron": (5, 5, 5),
        "CelestialSpire": (5, 12, 5), "BrokenArch": (8, 8, 2),
        "Orrery": (6, 6, 6), "RitualDesk": (3, 1.4, 2),
    },
    "ember_abyss": {
        "AshShore": (16, .3, 10), "SoulRib": (7, 7, 3),
        "Throne": (5, 7, 5), "ChainAnchor": (3, 5, 5),
        "LivingSealTorchDragon": (3, 3, 3), "LivingSealCloudWanderer": (3, 3, 3),
        "LivingSealSilenceBringer": (3, 3, 3), "BellTower": (16, 15, 16),
        "DecoyBell": (1.4, 2.8, 1.4), "DecoyBellBroken": (1.4, 2.8, 1.4),
        "MemorialStarForger": (3, 4.5, 4), "MemorialThoughtBreaker": (3, 4.5, 4),
        "MemorialDustReturner": (3, 4.5, 4), "MemorialFateWeaver": (3, 4.5, 4),
        "MemorialGateKeeper": (3, 4.5, 4), "MemorialSinMeasurer": (3, 4.5, 4),
        "MemorialLampLighter": (3, 4.5, 4), "MemorialSoulPacifier": (3, 4.5, 4),
        "MemorialCycleTurner": (3, 4.5, 4),
    },
}

SOURCES = {
    "spirit_ruins": "docs/chapters/01-spirit-awakening/levels/01-levels-detail.md:6-157",
    "blood_iron": "docs/chapters/02-blood-iron/chapter-overview.md:25-93",
    "jade_veil": "docs/chapters/03-jade-veil/chapter-overview.md:25-99",
    "celestial_fall": "docs/chapters/04-celestial-fall/chapter-overview.md:25-109",
    "ember_abyss": "docs/chapters/05-throne-of-ashes/chapter-overview.md:25-140; docs/story/lore.md:54-72; docs/bestiary/boss-blind-bell-hearer.md:12-88",
}


def read_glb(path):
    raw = path.read_bytes()
    assert raw[:4] == b"glTF"
    length, kind = struct.unpack_from("<II", raw, 12)
    assert kind == 0x4E4F534A
    return json.loads(raw[20:20 + length])


def check_assets():
    manifest = json.loads((OUT / "manifest.json").read_text(encoding="utf-8"))
    checked = 0
    fingerprints = set()
    for theme, catalog in CATALOG.items():
        doc = read_glb(OUT / (theme + ".glb"))
        nodes = doc["nodes"]
        roots = doc["scenes"][doc.get("scene", 0)]["nodes"]
        assert {nodes[i]["name"] for i in roots} == set(catalog), theme
        assert not doc.get("skins") and not doc.get("animations")
        for index in roots:
            node = nodes[index]
            name = node["name"]
            definition = manifest["parts"][name]
            for key, identity in (("translation", [0, 0, 0]), ("rotation", [0, 0, 0, 1]), ("scale", [1, 1, 1])):
                assert all(abs(a-b) < 1e-5 for a, b in zip(node.get(key, identity), identity)), (name, key)
            bounds = []
            counts = []
            materials = set()
            for ci in node.get("children", []):
                child = nodes[ci]
                assert "mesh" in child and not child.get("children"), name
                assert not any(key in child for key in ("translation", "rotation", "scale", "matrix")), name
                for primitive in doc["meshes"][child["mesh"]]["primitives"]:
                    assert primitive.get("mode", 4) == 4
                    accessor = doc["accessors"][primitive["attributes"]["POSITION"]]
                    bounds.extend((accessor["min"], accessor["max"]))
                    counts.append(doc["accessors"][primitive["indices"]]["count"])
                    materials.add(primitive["material"])
            lower = [min(b[i] for b in bounds) for i in range(3)]
            upper = [max(b[i] for b in bounds) for i in range(3)]
            assert abs(lower[1]) < 1e-4, (name, "foot", lower)
            assert all(abs(upper[i]-lower[i]-catalog[name][i]) < 1e-4 for i in range(3)), name
            assert all(abs(lower[i]-definition["bounds"]["min"][i]) < 1e-4 for i in range(3)), name
            assert sum(counts) > 600 and len(materials) >= 2, (name, "missing modeled detail")
            fingerprint = tuple(counts)
            assert fingerprint not in fingerprints, (name, "duplicate topology catalog entry")
            fingerprints.add(fingerprint)
            for box in definition["navigation_boxes"]:
                assert all(v > 0 for v in box["size"]), name
                assert all(lower[i]-.001 <= box["center"][i]-box["size"][i]/2 and
                           box["center"][i]+box["size"][i]/2 <= upper[i]+.001 for i in range(3)), (name, box)
            checked += 1
    assert checked == 46 and len(manifest["parts"]) == checked
    assert len([n for n in manifest["parts"] if n.startswith("Memorial")]) == 9
    assert len([n for n in manifest["parts"] if n.startswith("LivingSeal")]) == 3
    print(f"CAMPAIGN_STORY_PROPS_OK themes=5 parts={checked} identity_roots=46 distinct_topologies=46 fallen_memorials=9 living_seals=3")


def build_assets(render_previews=False):
    import bpy
    from mathutils import Vector
    module_spec = importlib.util.spec_from_file_location("campaign_kit_helpers", ROOT / "tools/build_campaign_environment_kits.py")
    kit = importlib.util.module_from_spec(module_spec)
    module_spec.loader.exec_module(kit)
    OUT.mkdir(parents=True, exist_ok=True)
    EVIDENCE.mkdir(parents=True, exist_ok=True)

    class StoryPart(kit.Part):
        def __init__(self, name, style, rng):
            super().__init__(name, style, rng)
            self.navigation_boxes = []
            self.passability = "solid prop; place outside reserved routes"

        def solid(self, center, size):
            self.navigation_boxes.append({"center": list(center), "size": list(size)})

        def arch(self, x, y, z, radius, thickness, depth, mat="stone", segments=16):
            # Separate wedge stones form a real open arch, not a covered doorway.
            for i in range(segments):
                a0, a1 = math.pi*i/segments+.018, math.pi*(i+1)/segments-.018
                vertices = []
                for zz in (z-depth/2, z+depth/2):
                    for rr, a in ((radius, a0), (radius+thickness, a0), (radius+thickness, a1), (radius, a1)):
                        vertices.append((x+rr*math.cos(a), y+rr*math.sin(a), zz))
                self.mesh(mat, vertices, [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])

        def orb(self, x, y, z, radius, mat="stone", squash=1, facets=12, rings=8):
            profile = [(y+radius*squash*math.cos(math.pi*i/rings), max(.015, radius*math.sin(math.pi*i/rings))) for i in range(rings+1)]
            self.lathe(x, z, list(reversed(profile)), mat, facets, flute=.06, twist=.03)

        def leaf_cloud(self, x, y, z, radius, mat="leaf"):
            # Irregular lobes and hanging petals give the crown a branching silhouette.
            for i in range(7):
                a = TAU*i/7
                self.orb(x+math.cos(a)*radius*.48, y+self.rng.uniform(-.2,.3)*radius,
                         z+math.sin(a)*radius*.48, radius*self.rng.uniform(.5,.76), mat, .62, 11, 5)

        def cloth(self, x, y, z, width, height, mat="cloth", wave=.15):
            verts = []
            for j in range(6):
                for i in range(9):
                    t, v = i/8, j/5
                    verts.append((x+width*(t-.5), y-height*v + (.13 if j == 5 and i % 2 else 0),
                                  z+wave*math.sin(t*TAU*1.5+v*2)*v))
            self.mesh(mat, verts, [(j*9+i,j*9+i+1,(j+1)*9+i+1,(j+1)*9+i) for j in range(5) for i in range(8)])

        def normalize(self, size):
            points = [v for vertices, _ in self.meshes.values() for v in vertices]
            lo = [min(v[i] for v in points) for i in range(3)]
            hi = [max(v[i] for v in points) for i in range(3)]
            factors = [size[i]/(hi[i]-lo[i]) for i in range(3)]
            origin = [(lo[0]+hi[0])/2, lo[1], (lo[2]+hi[2])/2]
            for material, (vertices, faces) in self.meshes.items():
                self.meshes[material] = ([tuple((v[i]-origin[i])*factors[i] for i in range(3)) for v in vertices], faces)
            # Clamp tiny conservative margins to the exported envelope.
            for box in self.navigation_boxes:
                lower = [max(lo[i], box["center"][i]-box["size"][i]/2) for i in range(3)]
                upper = [min(hi[i], box["center"][i]+box["size"][i]/2) for i in range(3)]
                box["center"] = [round(((lower[i]+upper[i])/2-origin[i])*factors[i], 5) for i in range(3)]
                box["size"] = [round((upper[i]-lower[i])*factors[i], 5) for i in range(3)]

    def pedestal(p, sx=2, sz=2, height=.5):
        p.block(0,height*.18,0,sx,height*.36,sz,"dark",.09)
        p.block(0,height*.56,0,sx*.9,height*.40,sz*.9,"stone",.08)
        p.block(0,height*.9,0,sx,height*.20,sz,"trim",.035)

    def glyph(p, x, y, z, radius=.6, mode=0, mat="trim"):
        # Geometry symbols, not misleading pseudo-text; each memorial has a distinct emblem.
        if mode % 3 == 0:
            p.torus(x,y,z,radius,.045,mat,True,24)
        for i in range(3+mode):
            a = TAU*i/(3+mode)
            p.beam((x+math.cos(a)*radius*.25,y+math.sin(a)*radius*.25,z),
                   (x+math.cos(a)*radius,y+math.sin(a)*radius,z),.04,mat,6)

    def bell(p, x=0, z=0, y=.55, broken=False, size=1):
        profile = [(y, .49*size),(y+.12*size,.51*size),(y+.20*size,.4*size),
                   (y+.66*size,.31*size),(y+.86*size,.20*size),(y+.93*size,.08*size)]
        # Revolved shell with an actual hollow mouth and optional missing fragments.
        seg = 28
        verts = []
        for yy, r in profile:
            for i in range(seg):
                a=TAU*i/seg
                verts.append((x+r*math.cos(a), yy, z+r*math.sin(a)))
        faces=[]
        for j in range(len(profile)-1):
            for i in range(seg):
                if broken and ((j == 0 and i < 6) or (j == 1 and i in (1,2,3))):
                    continue
                faces.append((j*seg+i,j*seg+(i+1)%seg,(j+1)*seg+(i+1)%seg,(j+1)*seg+i))
        p.mesh("trim",verts,faces)
        p.torus(x,y+.23*size,z,.385*size,.025*size,"dark",False,28)
        p.torus(x,y+.68*size,z,.295*size,.025*size,"dark",False,28)
        p.beam((x,y+.82*size,z),(x,y+.10*size,z),.04*size,"dark")
        p.orb(x,y+.09*size,z,.105*size,"dark",1,10,5)
        if broken:
            for i in range(3):
                p.block(x-.3+i*.25,.05,z-.3,.18,.10,.23,"trim",.025,yaw=.4*i)

    def make_spirit(p):
        n=p.name
        if n in ("MuralWall","CryptWall"):
            for row in range(5):
                for col in range(8):
                    p.block((col-3.5)*.73,row*.69+.38,0,.70,.65,.62,"stone" if (row+col)%3 else "stone_light",.06)
            p.block(0,.12,0,6,.24,.9,"dark",.04)
            p.block(0,3.76,0,6,.25,.85,"trim",.04)
            if n=="MuralWall":
                p.torus(0,2,-.36,1.15,.065,"trim",True)
                for i in range(6):
                    a=TAU*i/6
                    xx,yy=math.cos(a)*1.05,2+math.sin(a)*1.05
                    p.orb(xx,yy,-.44,.15,"trim",1,8,5)
                    p.beam((xx,yy-.2,-.44),(xx*.8,yy-.53,-.44),.07,"trim")
                for xx in (-2.25,2.25): glyph(p,xx,2,-.39,.42,2)
            else:
                for xx in (-1.85,0,1.85):
                    p.arch(xx,1.4,-.37,.60,.22,.24)
                    p.block(xx,1.05,-.39,1.10,.7,.08,"dark",.03)
                    p.lathe(xx,-.48,[(.75,.27),(1.4,.23),(1.6,.13)],"trim",12)
            p.solid((0,1.9,0),(5.8,3.8,.7))
        elif n in ("AwakeningBier","Sarcophagus"):
            pedestal(p,1.8,3.4,.45)
            for side in (-1,1):
                p.block(side*.75,.76,0,.20,.55,2.95,"stone",.06)
            for zz in (-1.38,1.38): p.block(0,.76,zz,1.6,.55,.2,"stone",.06)
            p.block(0,.51,0,1.25,.12,2.65,"dark",.04)
            if n=="Sarcophagus":
                p.block(.07,1.05,0,1.64,.30,3.12,"stone_light",.10,yaw=.03)
                for zz in (-.8,0,.8): glyph(p,0,1.06,-1.59,.16,int((zz+.8)*3))
                p.block(0,1.22,0,.65,.11,1.95,"trim",.045)
            else:
                p.block(0,.66,-1.05,.75,.14,.35,"cloth",.035)
                for i in range(7): p.block((i-3)*.19,.59,0,.14,.04,2.1,"cloth",.012)
                for xx in (-.7,.7): p.lathe(xx,1.15,[(.9,.10),(1.12,.07),(1.16,.025)],"trim",12)
            p.solid((0,.5,0),(1.8,1,3.25))
        elif n=="KneelingStatue":
            pedestal(p,2.2,2.2,.5)
            p.lathe(0,0,[(.48,.65),(.8,.7),(1.5,.48),(2.12,.6),(2.35,.28)],"stone",18,flute=.10)
            p.orb(0,2.63,-.13,.33,"stone_light",1.16)
            for side in (-1,1):
                p.orb(side*.53,.74,-.48,.37,"stone",.75)
                p.beam((side*.46,2.05,0),(side*.27,1.48,-.65),.15,"stone",10)
                p.beam((side*.27,1.48,-.65),(0,1.9,-.60),.12,"stone_light",10)
            for i in range(7):
                a=math.pi+i*math.pi/6
                p.beam((math.cos(a)*.5,.7,math.sin(a)*.5),(.0,2.18,.10),.035,"dark",6)
            p.solid((0,1.25,0),(1.6,2.5,1.6))
        else:
            pedestal(p,1.7,1.7,.45)
            p.lathe(0,0,[(.45,.47),(.7,.33),(1.7,.23),(1.95,.44),(2.02,.60),(2.2,.75),(2.4,.66),(2.34,.58),(2.13,.5)],"trim",24,flute=.06)
            for i in range(8):
                a=TAU*i/8
                p.beam((math.cos(a)*.45,1.96,math.sin(a)*.45),(math.cos(a)*.83,2.72,math.sin(a)*.83),.065,"dark")
            for i in range(5):
                a=TAU*i/5
                p.lathe(math.cos(a)*.22,math.sin(a)*.22,[(2.16,.14),(2.55,.20),(2.85+i*.07,.09),(3.3-i*.05,.01)],"glow",7,twist=.23)
            p.solid((0,1,0),(1.25,2,1.25))

    def make_blood(p):
        n=p.name
        if n=="PrisonCage":
            p.passability="open front doorway and interior; bars, back and side walls block"
            for side in (-1,1): p.block(side*1.9,.10,0,.2,.20,4,"wood",.04)
            p.block(0,.10,1.9,4,.20,.2,"wood",.04)
            for side in (-1,1): p.block(side*1.5,.10,-1.9,1,.20,.2,"wood",.04)
            for yy in (.38,3.1):
                for side in (-1,1):
                    p.block(side*1.9,yy,0,.16,.17,4,"trim",.025)
                    if side==1 or yy>1:
                        p.block(0,yy,side*1.9,4,.17,.16,"trim",.025)
                    else:
                        for xx in (-1.5,1.5): p.block(xx,yy,-1.9,1,.17,.16,"trim",.025)
            for i in range(11):
                t=-1.85+i*.37
                for side in (-1,1): p.beam((side*1.9,.2,t),(side*1.9,3.15,t),.055,"dark")
                p.beam((t,.2,1.9),(t,3.15,1.9),.055,"dark")
                if abs(t)>1.0: p.beam((t,.2,-1.9),(t,3.15,-1.9),.055,"dark")
                p.beam((t,3.15,-1.9),(t,3.15,1.9),.055,"dark")
            for side in (-1,1): p.solid((side*1.88,1.65,0),(.18,3.1,3.9))
            p.solid((0,1.65,1.88),(3.9,3.1,.18))
            for side in (-1,1): p.solid((side*1.5,1.65,-1.88),(.85,3.1,.18))
            p.torus(1.12,1.5,-1.96,.11,.035,"trim",True,16)
        elif n=="CommandTent":
            p.passability="open front and walkable center; fabric side/back surfaces block"
            for side in (-1,1):
                p.block(side*3.35,1.3,.1,.10,2.6,6.5,"cloth",.008)
                p.beam((side*3.5,0,-3.3),(side*3.5,3,-3.3),.10,"wood")
                p.solid((side*3.35,1.3,.1),(.12,2.6,6.5))
            p.block(0,1.3,3.35,6.8,2.6,.1,"cloth",.008)
            p.solid((0,1.3,3.35),(6.8,2.6,.12))
            for side in (-1,1):
                verts=[(0,4.7,-3.7),(0,4.7,3.7),(side*3.7,2.45,3.7),(side*3.7,2.45,-3.7)]
                p.mesh("cloth",verts,[(0,1,2,3)])
                for zz in (-3.65,-1.8,0,1.8,3.65):
                    p.beam((0,4.72,zz),(side*3.72,2.46,zz),.045,"trim")
            p.beam((0,0,3.25),(0,5,3.25),.13,"wood")
            p.cloth(-2.75,2.55,-3.5,1.0,2.1,"cloth",.23)
            p.cloth(2.75,2.55,-3.5,1.0,2.1,"cloth",.23)
        elif n=="WarTable":
            for xx in (-1.12,1.12):
                for zz in (-.7,.7): p.block(xx,.6,zz,.18,1.2,.18,"wood",.035)
            p.block(0,1.2,0,3,.18,2.25,"wood",.04)
            p.block(0,1.30,0,2.4,.025,1.6,"paper",.008)
            for i in range(12):
                x,z=p.rng.uniform(-1.1,1.1),p.rng.uniform(-.7,.7)
                p.lathe(x,z,[(1.33,.08),(1.46,.045),(1.5,.085)],"trim" if i%2 else "dark",8)
            for i in range(5): p.beam((-.9+i*.32,1.324,-.65),(-.8+i*.36,1.324,.6),.008,"dark",4)
            p.solid((0,.65,0),(2.8,1.3,2.1))
        elif n=="WarBanner":
            pedestal(p,1,1,.25)
            p.beam((0,.2,0),(0,4.7,0),.06,"trim")
            p.beam((-1.15,4.1,0),(1.15,4.1,0),.065,"wood")
            p.cloth(0,4.03,-.04,2.2,2.4,"cloth",.2)
            glyph(p,0,3.0,-.24,.55,3)
            p.lathe(0,0,[(4.5,.08),(4.72,.17),(5,.01)],"trim",8)
            p.solid((0,.5,0),(.9,1,.9))
        elif n=="SiegeWagon":
            p.block(0,.9,0,2.65,.3,3.4,"wood",.06)
            for side in (-1,1):
                for zz in (-1.1,1.1):
                    # Wheel torus originally lies XY; turn around Y into the YZ axle plane.
                    start={k:len(v[0]) for k,v in p.meshes.items()}
                    p.torus(0,.8,0,.69,.095,"dark",True,24)
                    for i in range(10):
                        a=TAU*i/10
                        p.beam((0,.8,0),(math.cos(a)*.65,.8+math.sin(a)*.65,0),.043,"wood")
                    for mat,(vertices,faces) in p.meshes.items():
                        for j in range(start.get(mat,0),len(vertices)):
                            x,y,z=vertices[j];vertices[j]=(side*1.53+z,y,zz+x)
                for row in range(4): p.block(side*1.23,1.2+row*.3,0,.16,.25,3.5,"wood",.03)
            for row in range(4): p.block(0,1.2+row*.3,1.6,2.6,.25,.16,"wood",.03)
            for xx in (-.85,.85): p.beam((xx,.7,-1.4),(xx,.35,-3.0),.08,"wood")
            for i in range(5): p.block((i-2)*.38,1.6,.25,.27,1.4,1.8,"cloth",.08,yaw=.12*(i-2))
            p.solid((0,1.2,0),(2.7,2.4,3.45))
        elif n=="Barricade":
            for i in range(9):
                xx=(i-4)*.62
                p.lathe(xx,0,[(0,.17),(1.65,.16),(2.1,.01)],"wood",8)
                p.beam((xx-.24,0,-.55),(xx+.15,1.6,.4),.11,"wood")
                for yy in (.6,1.35): p.torus(xx,yy,0,.19,.025,"trim",False,8)
            for yy in (.6,1.3): p.block(0,yy,0,5.95,.15,.17,"dark",.025)
            p.solid((0,.95,0),(5.8,1.9,.8))
        else:
            p.passability="external signal tower, hollow central bay; solid corners and rear masonry"
            pedestal(p,7.8,7.8,.35)
            for side in (-1,1):
                for zz in (-2.65,2.65):
                    p.block(side*2.65,5,zz,1.3,10,1.3,"stone",.12)
                    p.solid((side*2.65,5,zz),(1.3,10,1.3))
            for floor in (3.3,6.6,10):
                for side in (-1,1):
                    p.block(side*2.6,floor,0,.45,.32,6.3,"trim",.04)
                    p.block(0,floor,side*2.6,6.3,.32,.45,"trim",.04)
            for row in range(13):
                for col in range(7): p.block((col-3)*.82,.4+row*.72,2.8,.78,.67,.65,"stone" if col%2 else "stone_light",.07)
            p.solid((0,4.8,2.8),(6.1,9.6,.65))
            for i in range(7):
                p.block(-2.1+i*.68,10.8,-2.95,.44,1.25,.65,"stone",.06)
                p.block(-2.1+i*.68,10.8,2.95,.44,1.25,.65,"stone",.06)
            p.lathe(0,0,[(10,.7),(10.5,.8),(11.2,1.4),(11.7,1.2),(11.55,1.05)],"trim",24)
            for i in range(7):
                a=TAU*i/7
                p.lathe(math.cos(a)*.5,math.sin(a)*.5,[(11.1,.2),(12,.4),(13.4+i*.08,.04)],"glow",7,twist=.32)

    def make_jade(p):
        n=p.name
        if n=="BambooGrove":
            for i in range(13):
                a=TAU*i/13;rr=.5+(i%4)*.48
                p.bamboo(math.cos(a)*rr,math.sin(a)*rr,5.5+(i%5)*.65,.3+.12*(i%3))
            for i in range(7):
                a=TAU*i/7
                p.leaf_cloud(math.cos(a)*1.5,5.5+i%3,math.sin(a)*1.5,.95)
            p.solid((0,2.5,0),(3.1,5,3.1))
        elif n=="WeddingLantern":
            pedestal(p,.85,.85,.25)
            p.beam((0,.25,0),(0,3.8,0),.065,"wood")
            p.beam((0,3.78,0),(.4,3.78,0),.06,"wood")
            p.lathe(.35,0,[(2.1,.22),(2.3,.42),(2.8,.47),(3.2,.32),(3.3,.18)],"paper",20)
            for i in range(10):
                a=TAU*i/10
                p.beam((.35+math.cos(a)*.18,3.3,math.sin(a)*.18),(.35+math.cos(a)*.47,2.7,math.sin(a)*.47),.018,"cloth",5)
                p.beam((.35+math.cos(a)*.47,2.7,math.sin(a)*.47),(.35+math.cos(a)*.22,2.1,math.sin(a)*.22),.018,"cloth",5)
            for yy,rr in ((2.1,.22),(3.25,.21)): p.torus(.35,yy,0,rr,.04,"trim")
            p.beam((.35,2.15,0),(.35,1.67,0),.035,"cloth")
            p.orb(.35,2.65,0,.2,"glow",1.2)
            p.solid((0,.7,0),(.65,1.4,.65))
        elif n=="Palanquin":
            p.block(0,.7,0,2.5,.35,2.8,"wood",.08)
            for side in (-1,1):
                p.beam((side*.9,.75,-2.5),(side*.9,.75,2.5),.09,"wood")
                for zz in (-1,1): p.beam((side, .8,zz),(side,2.75,zz),.10,"wood")
                p.block(side*1.01,1.82,0,.035,1.65,1.95,"cloth",.006)
                for zz in (-.75,-.25,.25,.75):
                    p.beam((side*1.04,1.05,zz),(side*1.04,2.65,zz),.018,"trim",5)
            p.roof(0,2.7,0,3.3,3.2,.9)
            p.cloth(0,2.62,-1.04,1.8,1.7,"cloth",.18)
            for xx in (-.8,.8): glyph(p,xx,2.25,-1.12,.15,2)
            p.solid((0,1.5,0),(2.4,3,2.7))
        elif n=="MemoryMirror":
            pedestal(p,2.7,1.1,.5)
            for xx in (-1.02,1.02):
                p.lathe(xx,0,[(.5,.16),(2.8,.12),(3,.22)],"wood",12,flute=.08)
                p.solid((xx,1.7,0),(.32,2.4,.6))
            p.torus(0,2.5,0,1.15,.12,"trim",True,40)
            # Dark polished bronze disk with raised concentric etching, not emissive glass.
            verts=[(0,2.5,-.035)]+[(math.cos(TAU*i/48)*1.08,2.5+math.sin(TAU*i/48)*1.08,-.035) for i in range(48)]
            p.mesh("mirror",verts,[(0,i+1,(i+1)%48+1) for i in range(48)])
            for radius in (.83,1.0): p.torus(0,2.5,-.06,radius,.012,"trim",True,40)
            for i in range(16):
                a=TAU*i/16
                p.orb(math.cos(a)*1.16,2.5+math.sin(a)*1.16,-.09,.06,"jade",1,8,4)
            p.solid((0,2.5,0),(2.25,2.25,.25))
        elif n=="LakePavilion":
            p.passability="eight open bays; no filled deck; central bridge stays clear at Y0; only column footings obstruct paths"
            columns=[(3.35,2.2),(2.2,3.35),(-2.2,3.35),(-3.35,2.2),
                     (-3.35,-2.2),(-2.2,-3.35),(2.2,-3.35),(3.35,-2.2)]
            for i in range(8):
                xx,zz=columns[i]
                p.lathe(xx,zz,[(0,.48),(.18,.48),(.22,.38),(.35,.38)],"stone",8)
                p.lathe(xx,zz,[(.35,.3),(.65,.38),(.85,.23),(4.15,.20),(4.45,.4)],"wood",12,flute=.08)
                p.solid((xx,2.22,zz),(.96,4.44,.96))
                nx,nz=columns[(i+1)%8]
                p.beam((xx,4.2,zz),(nx,4.2,nz),.14,"trim")
            # Eight curved roof facets, with radial tile ribs and upswept eaves.
            for side in range(8):
                verts=[]
                a0=TAU*side/8+math.pi/8;a1=TAU*(side+1)/8+math.pi/8
                for ring in range(9):
                    t=ring/8;r=.2+4.6*t;y=6.55-2.1*t**.65+.38*t**7
                    for a in (a0,a1): verts.append((math.cos(a)*r,y,math.sin(a)*r))
                p.mesh("roof",verts,[(i*2,i*2+1,(i+1)*2+1,(i+1)*2) for i in range(8)])
                for rib in range(5):
                    a=a0+(a1-a0)*rib/4
                    for i in range(8):
                        t,u=i/8,(i+1)/8
                        p.beam((math.cos(a)*(.2+4.6*t),6.55-2.1*t**.65+.38*t**7,math.sin(a)*(.2+4.6*t)),
                               (math.cos(a)*(.2+4.6*u),6.55-2.1*u**.65+.38*u**7,math.sin(a)*(.2+4.6*u)),.025,"trim" if rib in (0,4) else "roof",5)
            p.lathe(0,0,[(6.5,.18),(6.7,.24),(7,.015)],"trim",12)
        elif n=="IllusionTree":
            p.lathe(0,0,[(0,.45),(.3,.5),(2,.27),(3.2,.18),(4.3,.10)],"wood",13,flute=.15,twist=.09)
            for i in range(9):
                a=TAU*i/9;rr=1.3+(i%3)*.34;yy=3.8+(i%4)*.48
                end=(math.cos(a)*rr,yy,math.sin(a)*rr)
                p.beam((0,1.8+i*.17,0),end,.12,"wood",9)
                p.leaf_cloud(*end,.8,"blossom")
                for j in range(4):
                    x=end[0]+p.rng.uniform(-.5,.5);z=end[2]+p.rng.uniform(-.5,.5)
                    p.orb(x,yy-.4-j*.15,z,.09,"paper",.45,7,4)
            for i in range(7):
                a=TAU*i/7
                p.beam((0,.3,0),(math.cos(a)*.9,.03,math.sin(a)*.9),.10,"wood")
            p.solid((0,1.7,0),(.8,3.4,.8))
        elif n=="HedgeWall":
            p.block(0,.15,0,6,.3,1.5,"stone",.09)
            for i in range(10):
                xx=(i-4.5)*.54
                p.block(xx,1.2,0,.12,2.2,.16,"wood",.025)
                for yy in (1,1.7,2.3): p.leaf_cloud(xx,yy,0,.49)
            for i in range(9):
                p.orb((i-4)*.58,2.7,-.55,.13,"blossom",.7,8,4)
            p.solid((0,1.3,0),(5.8,2.6,1.3))
        else:
            p.passability="visual water plane only; caller owns water/reset behavior and supporting terrain"
            p.lathe(0,0,[(0,9),(.012,9)],"water",64)
            for i in range(9):
                p.torus(-2,.03+i*.004,1,1.0+i*.58,.012,"mirror",False,64)
            for i in range(7):
                a=TAU*i/7;p.orb(math.cos(a)*7,.02,math.sin(a)*7,.24,"leaf",.07,12,4)

    def make_celestial(p):
        n=p.name
        if n=="ArchiveShelf":
            for xx in (-2.35,2.35): p.block(xx,3.4,0,.3,6.8,1.3,"wood",.05)
            p.block(0,3.4,.57,4.9,6.8,.13,"dark",.025)
            for shelf in range(7):
                yy=.15+shelf*1.04
                p.block(0,yy,0,5,.15,1.4,"trim",.035)
                for book in range(17):
                    xx=(book-8)*.255;h=.57+(book%5)*.065
                    p.block(xx,yy+.08+h/2,-.04,.20,h,.88,"book" if book%3 else "paper",.012,yaw=.025*(book%4-1))
                    for by in (.15,.39): p.block(xx,yy+by,-.49,.205,.025,.025,"trim",.004)
            p.arch(0,6.65,0,1.7,.25,1.35,"trim",12)
            p.solid((0,3.4,0),(4.9,6.8,1.3))
        elif n=="BronzeCauldron":
            for i in range(3):
                a=TAU*i/3
                p.lathe(math.cos(a)*1.05,math.sin(a)*1.05,[(0,.32),(.3,.23),(1.3,.28)],"trim",12,flute=.12)
            p.lathe(0,0,[(1,.72),(1.3,1.25),(2.4,1.7),(3.05,1.65),(3.15,1.82),(3.34,1.82),(3.30,1.60),(3.1,1.5),(2.3,1.5),(1.3,.65)],"trim",36,flute=.025)
            for side in (-1,1): p.torus(side*1.6,2.9,0,.52,.105,"dark",True,24)
            for yy,rr in ((1.6,1.42),(2.7,1.67)): p.torus(0,yy,0,rr,.07,"jade",False,36)
            for i in range(12):
                a=TAU*i/12
                p.orb(math.cos(a)*1.64,2.5,math.sin(a)*1.64,.075,"jade",1.2,8,5)
            p.lathe(0,0,[(2.3,.25),(3.3,.4),(3.8,.19),(4.7,.02)],"glow",9,twist=.18)
            p.solid((0,1.6,0),(3.1,3.2,3.1))
        elif n=="CelestialSpire":
            pedestal(p,4.8,4.8,.65)
            for layer in range(4):
                yy=.65+layer*2.15;rr=1.55-layer*.23
                p.lathe(0,0,[(yy,rr),(yy+.25,rr),(yy+.4,rr*.64),(yy+1.9,rr*.57),(yy+2.12,rr*.9)],"stone",8,flute=.05)
                p.torus(0,yy+.25,0,rr,.06,"trim",False,16)
                for i in range(4):
                    a=TAU*i/4
                    p.block(math.cos(a)*rr*.75,yy+1,math.sin(a)*rr*.75,.12,.95,.12,"jade",.02)
            p.lathe(0,0,[(9,.48),(9.5,.62),(10,.28),(11.3,.08),(12,.01)],"trim",12)
            p.solid((0,4.5,0),(2.7,9,2.7))
        elif n=="BrokenArch":
            p.passability="wide central arch opening; asymmetric broken top, solid side piers"
            for side in (-1,1):
                for row in range(6 if side<0 else 4): p.block(side*3.15,.5+row*.78,0,1.3,.72,1.7,"stone" if row%2 else "stone_light",.09)
                p.solid((side*3.15,2.4 if side<0 else 1.65,0),(1.35,4.8 if side<0 else 3.3,1.7))
            p.arch(0,4.5,0,2.45,.7,1.8,"stone",15)
            for i in range(5):
                p.block(-3.4+i*.18,5.0+i*.4,0,1.2,.38,1.7,"trim",.07,yaw=.05*i)
        elif n=="Orrery":
            pedestal(p,3.8,3.8,.55)
            p.lathe(0,0,[(.55,.75),(1.8,.32),(2.2,.45)],"trim",20)
            for i in range(3):
                start={k:len(v[0]) for k,v in p.meshes.items()}
                p.torus(0,3.4,0,1.85+i*.15,.07,"trim",True,48)
                # Crossed orbital planes distinguish celestial machinery from a flat seal.
                for mat,(vertices,faces) in p.meshes.items():
                    for j in range(start.get(mat,0),len(vertices)):
                        x,y,z=vertices[j]; a=i*TAU/3;vertices[j]=(x*math.cos(a)-z*math.sin(a),y,x*math.sin(a)+z*math.cos(a))
                a=i*2.3;p.orb(math.cos(a)*1.7,3.4+math.sin(a)*1.7,0,.24,"jade",1,14,8)
            p.orb(0,3.4,0,.5,"glow",1,18,10)
            p.solid((0,1.1,0),(1.6,2.2,1.6))
        else:
            p.block(0,.08,0,2.9,.16,1.9,"cloth",.04)
            for xx in (-1.0,1.0): p.block(xx,.43,.25,.15,.7,.85,"wood",.03)
            p.block(0,.8,.25,2.6,.15,1.2,"wood",.045)
            # Open last-page book, rolled scripture, and a cold tea cup.
            for side in (-1,1): p.block(side*.34,.91,.05,.65,.045,.72,"paper",.008,yaw=side*.08)
            for i in range(6): p.beam((-.6+i*.2,.943,-.2),(-.6+i*.2,.943,.3),.009,"dark",4)
            p.lathe(.85,.4,[(.89,.15),(1.05,.18),(1.08,.20),(1.08,.15),(.96,.12)],"jade",20)
            p.block(-.9,1.0,.5,.32,.2,.5,"paper",.06)
            p.solid((0,.5,.1),(2.7,1,1.45))

    def memorial_symbol(p, index):
        yy,zz=2.8,-.81
        if index==0: # Star Forger: radial star and hammer.
            glyph(p,0,yy,zz,.64,5)
            p.beam((-.3,3.6,-.3),(.3,3.9,-.3),.08,"trim")
            p.block(.3,3.92,-.3,.48,.18,.18,"trim",.04)
        elif index==1: # Thought Breaker: parted head halo.
            p.arch(0,2.7,zz,.54,.07,.12,"trim",9)
            for side in (-1,1): p.beam((side*.12,2.2,zz),(side*.43,3.4,zz),.09,"trim")
        elif index==2: # Dust Returner: hourglass and cascading grains.
            for side in (-1,1):
                p.beam((side*.45,2.1,zz),(-side*.45,3.5,zz),.06,"trim")
            for y in (2.1,3.5): p.beam((-.5,y,zz),(.5,y,zz),.06,"trim")
            for i in range(5): p.orb((i%2-.5)*.15,2.25+i*.2,zz,.06,"trim",1,7,4)
        elif index==3: # Fate Weaver: crossed shuttle threads.
            for i in range(5):
                p.beam((-.55,2.2+i*.24,zz),(.55,3.25-i*.18,zz),.035,"trim")
            p.beam((0,2.05,zz),(0,3.5,zz),.11,"jade")
        elif index==4: # Gate Keeper: twin pylons and open lintel.
            for side in (-1,1): p.block(side*.46,2.65,zz,.20,1.2,.12,"trim",.035)
            p.arch(0,3.1,zz,.37,.13,.15,"trim",11)
        elif index==5: # Sin Measurer: balanced scales.
            p.beam((0,2.1,zz),(0,3.5,zz),.055,"trim")
            p.beam((-.65,3.2,zz),(.65,3.2,zz),.05,"trim")
            for side in (-1,1):
                p.beam((side*.55,3.2,zz),(side*.55,2.7,zz),.025,"trim")
                p.arch(side*.55,2.45,zz,.22,.045,.1,"trim",7)
        elif index==6: # Lamp Lighter: hanging lantern/flame.
            p.torus(0,3.3,zz,.19,.04,"trim",True,18)
            p.block(0,2.65,zz,.63,.7,.15,"trim",.05)
            p.lathe(0,zz-.10,[(2.37,.1),(2.72,.19),(3,.01)],"glow",7,twist=.13)
        elif index==7: # Soul Pacifier: cradle curves shelter a soul.
            p.torus(0,2.85,zz,.52,.05,"trim",True,28)
            p.orb(0,2.85,zz-.08,.25,"jade",1.25,14,7)
            for side in (-1,1): p.beam((side*.67,2.3,zz),(0,2.1,zz),.07,"trim")
        else: # Cycle Turner: three eccentric interlocked wheels.
            for i in range(3): p.torus(math.cos(i*TAU/3)*.25,2.8+math.sin(i*TAU/3)*.25,zz-i*.03,.43,.048,"trim",True,22+i*2)

    def make_ember(p):
        n=p.name
        if n.startswith("Memorial"):
            index=list(x for x in CATALOG["ember_abyss"] if x.startswith("Memorial")).index(n)
            pedestal(p,2.9,3.9,.48)
            p.block(0,.84,.6,2.3,.65,2.45,"stone",.14)
            p.block(0,1.22,.6,2.45,.18,2.55,"stone_light",.08)
            p.block(0,2.35,-.4,2.0,3.75,.65,"stone",.15)
            p.arch(0,3.2,-.4,.8,.26,.72,"stone_light",10+index)
            for xx in (-1.0,1.0): p.block(xx,2.25,-.8,.11,2.8,.09,"trim",.025)
            memorial_symbol(p,index)
            # Dedicated grooves make individual records discernible even in silhouette.
            for i in range(index+1): p.block(-.82+i*.17,1.42,-.77,.08,.13,.08,"trim",.01)
            p.solid((0,1.7,0),(2.75,3.4,3.7))
        elif n.startswith("LivingSeal"):
            pedestal(p,2.9,2.9,.55)
            p.torus(0,1.8,0,1.05,.10,"trim",True,36)
            if n.endswith("TorchDragon"):
                for i in range(11):
                    a=-.4+math.pi*1.7*i/10
                    p.orb(math.cos(a)*.63,1.8+math.sin(a)*.63,-.1,.13,"trim",1,9,6)
                p.lathe(.52,-.1,[(2.2,.12),(2.55,.17),(2.9,.01)],"glow",7)
            elif n.endswith("CloudWanderer"):
                for i in range(4):
                    p.torus((i-1.5)*.27,1.55+(i%2)*.3,-.11,.29,.045,"jade",True,18+i*2)
                p.beam((-.55,2.1,-.1),(.55,2.3,-.1),.05,"trim")
            else:
                for xx in (-.27,.27): p.beam((xx,1.1,-.1),(xx,2.45,-.1),.08,"trim")
                p.torus(0,1.8,-.1,.58,.035,"dark",True,30)
            p.solid((0,1.1,0),(2.2,2.2,.7))
        elif n=="AshShore":
            for i in range(31):
                x=p.rng.uniform(-7.2,7.2);z=p.rng.uniform(-4.5,4.5)
                p.orb(x,.04,z,p.rng.uniform(.6,1.9),"ash" if i%3 else "stone",.04,12,4)
            for i in range(13):
                x=p.rng.uniform(-6,6);z=p.rng.uniform(-4,4)
                p.beam((x,.09,z),(x+p.rng.uniform(.2,.9),.10,z+.2),.02,"bone",5)
            p.passability="non-solid shore skin; supporting terrain remains authoritative"
        elif n=="SoulRib":
            p.arch(0,1.9,0,2.65,.42,1.0,"bone",18)
            for side in (-1,1):
                p.beam((side*2.6,0,.4),(side*2.7,2,0),.31,"bone",12)
                for i in range(3): p.beam((side*2.6,.8+i*.7,0),(side*1.9,1.0+i*.75,1.2),.14,"bone",9)
                for yy in (.45,.8): p.torus(side*2.65,yy,.2,.31,.045,"dark",False,18)
                p.solid((side*2.65,1.7,0),(.9,3.4,1.8))
            p.passability="soul skeleton arch, open middle; ribs and feet block"
        elif n=="Throne":
            for step in range(4): p.block(0,.12+step*.22,.3-step*.1,5-step*.6,.24,5-step*.65,"stone",.08)
            p.block(0,1.8,0,2.6,2,.9,"dark",.14)
            p.block(0,1.65,-.85,2.6,.35,1.8,"stone",.12)
            for side in (-1,1):
                p.block(side*1.15,2,-.7,.4,1.15,1.8,"trim",.09)
                p.lathe(side*1.02,.2,[(1,.22),(4.8,.22),(5.8,.04)],"stone",7,flute=.17)
            for i in range(9):
                xx=(i-4)*.29;h=5.4-abs(i-4)*.33
                p.lathe(xx,.45,[(1.6,.15),(h,.13),(h+.65,.01)],"stone_light" if i%2 else "stone",6)
                p.torus(xx,3.4+(4-abs(i-4))*.16,-.05,.105,.025,"trim",True,14)
            p.solid((0,2.35,0),(2.8,4.7,2.2))
        elif n=="ChainAnchor":
            pedestal(p,2.8,2.8,.5)
            p.lathe(0,0,[(.5,.55),(1.5,.43),(2.2,.6),(2.5,.32)],"dark",12,flute=.12)
            p.torus(0,2.15,0,.55,.13,"trim",True,24)
            for i in range(9):
                # Interlocked alternating planes, hanging towards the arena center (-Z).
                p.torus(0,2.25+i*.22,-.38-i*.35,.25,.065,"trim",i%2==0,16)
            p.solid((0,1.2,0),(2,2.4,2))
        elif n in ("DecoyBell","DecoyBellBroken"):
            pedestal(p,1.35,1.35,.22)
            for side in (-1,1): p.beam((side*.55,.22,0),(side*.55,2.5,0),.065,"wood")
            p.roof(0,2.45,0,1.4,1.1,.3)
            bell(p,y=1.02,broken=n.endswith("Broken"),size=1)
            p.solid((0,1.05,0),(1.1,2.1,.7))
        else:
            p.passability="open octagonal bell hall; two opposite 5m door bays; side walls and columns only"
            # No full floor slab: the existing arena floor remains walkable and authoritative.
            for i in range(8):
                a=TAU*i/8+math.pi/8;xx,zz=math.cos(a)*6.3,math.sin(a)*6.3
                p.lathe(xx,zz,[(0,.55),(.45,.65),(1,.42),(10.7,.35),(11,.65)],"stone",12,flute=.08)
                p.solid((xx,5.3,zz),(1.2,10.6,1.2))
            for side in (-1,1):
                for row in range(9):
                    for col in range(10):
                        zz=(col-4.5)*.85
                        if row in (4,5,6) and col in (2,7): continue # Moonlight arrow windows.
                        p.block(side*6.55,.5+row*.84,zz,.65,.78,.8,"stone" if col%3 else "stone_light",.055)
                p.solid((side*6.55,3.8,0),(.7,7.6,8.5))
            for zz in (-5.82,5.82):
                p.arch(0,5.0,zz,2.5,.65,.85,"stone",20)
                for side in (-1,1):
                    p.block(side*3.05,2.5,zz,1.1,5,1,"stone",.08)
                    p.solid((side*3.05,2.5,zz),(1.1,5,1))
            p.roof(0,10.8,0,15.8,15.2,3.2)
            for i in range(12):
                a=TAU*i/12
                bell(p,math.cos(a)*5.9,math.sin(a)*5.9,8.6,False,.55)
            p.lathe(0,0,[(13.9,.24),(14.2,.35),(15,.015)],"trim",16)

    manifest={"schema_version":1,"coordinates":"Godot Y-up meters; identity roots; foot Y=0; front=-Z",
              "navigation":"exact physical mesh triangles on layer 1; bounded solid-only navigation proxies on layer 524288; place outside reserved routes",
              "palette_encoding":"display sRGB converted to linear material factors","parts":{}}
    initial_scenes=list(bpy.data.scenes)
    preview_scenes=[]
    for theme_index,(theme,catalog) in enumerate(CATALOG.items()):
        scene=bpy.data.scenes.new("StoryProps_"+theme)
        bpy.context.window.scene=scene
        scene.unit_settings.system="METRIC"
        mats=kit.materials(theme)
        colors={"cloth":(.43,.095,.075) if theme=="blood_iron" else (.46,.16,.20),
                "paper":(.70,.58,.36),"book":(.16,.28,.29),"jade":(.18,.46,.35),
                "blossom":(.54,.27,.46),"mirror":(.22,.35,.33),"water":(.055,.17,.19),
                "bone":(.46,.43,.33),"ash":(.26,.25,.27)}
        for label,color in colors.items():
            mat=bpy.data.materials.new(theme+"_"+label);mat.use_nodes=True
            linear=tuple(kit.srgb_to_linear(c) for c in color)
            mat.diffuse_color=(*linear,1)
            bs=mat.node_tree.nodes.get("Principled BSDF")
            bs.inputs["Base Color"].default_value=(*linear,1)
            bs.inputs["Roughness"].default_value=.18 if label in ("mirror","water") else .76
            bs.inputs["Metallic"].default_value=.75 if label=="mirror" else .0
            mat.use_backface_culling=False;mats[label]=mat
        mats["glow"].node_tree.nodes.get("Principled BSDF").inputs["Emission Strength"].default_value=.55
        for part_index,(name,size) in enumerate(catalog.items()):
            p=StoryPart(name,theme,random.Random(291000+theme_index*100+part_index))
            {"spirit_ruins":make_spirit,"blood_iron":make_blood,"jade_veil":make_jade,
             "celestial_fall":make_celestial,"ember_abyss":make_ember}[theme](p)
            p.normalize(size)
            bounds=kit.realize(p,scene,mats)
            manifest["parts"][name]={"resource":"res://assets/environment/story_props/"+theme+".glb",
                "theme":theme,"bounds":bounds,"footprint":[size[0],size[2]],"height":size[1],
                "navigation_boxes":p.navigation_boxes,"collision":name not in ("LakeSurface","AshShore"),
                "passability":p.passability,"source":SOURCES[theme]}
        bpy.ops.export_scene.gltf(filepath=str(OUT/(theme+".glb")),export_format="GLB",
                                  use_active_scene=True,export_animations=False,export_yup=True,
                                  export_apply=True,export_extras=True)
        # Export first; only then spread the roots into a readable studio catalog.
        cols=4;spacing=21;rows=math.ceil(len(catalog)/cols)
        for i,name in enumerate(catalog):
            obj=scene.objects.get(name);x=(i%cols-(cols-1)/2)*spacing;z=(i//cols-(rows-1)/2)*spacing
            obj.location=(x,-z,0)
            font=bpy.data.curves.new(name+"_Label","FONT");font.body=name;font.size=.85; font.align_x='CENTER'
            label=bpy.data.objects.new(name+"_Label",font);scene.collection.objects.link(label)
            label.location=(x,-z+8,.05);label.data.materials.append(mats["paper"])
        camera_data=bpy.data.cameras.new(theme+"_Camera");camera=bpy.data.objects.new(theme+"_Camera",camera_data)
        scene.collection.objects.link(camera);camera.location=(45,70,65)
        camera.rotation_euler=(Vector((0,0,1))-camera.location).to_track_quat('-Z','Y').to_euler()
        camera_data.type='ORTHO';camera_data.ortho_scale=max(100,rows*22);scene.camera=camera
        bpy.context.view_layer.update()
        projected=[]
        view=camera.matrix_world.inverted()
        for obj in scene.objects:
            if obj.type in ('MESH','FONT'):
                projected.extend(view @ (obj.matrix_world @ Vector(corner)) for corner in obj.bound_box)
        xmin,xmax=min(v.x for v in projected),max(v.x for v in projected)
        ymin,ymax=min(v.y for v in projected),max(v.y for v in projected)
        camera.location += camera.rotation_euler.to_matrix() @ Vector(((xmin+xmax)/2,(ymin+ymax)/2,0))
        camera_data.ortho_scale=max(xmax-xmin,(ymax-ymin)*4/3)*1.12
        world=bpy.data.worlds.new(theme+"_World");world.use_nodes=True
        world.node_tree.nodes["Background"].inputs["Color"].default_value=(.12,.15,.19,1)
        world.node_tree.nodes["Background"].inputs["Strength"].default_value=.6;scene.world=world
        sun_data=bpy.data.lights.new(theme+"_Sun",'SUN');sun_data.energy=2.5;sun_data.angle=.25
        sun=bpy.data.objects.new(theme+"_Sun",sun_data);scene.collection.objects.link(sun);sun.rotation_euler=(.5,-.35,-.5)
        area_data=bpy.data.lights.new(theme+"_Fill",'AREA');area_data.energy=6500;area_data.size=40
        area=bpy.data.objects.new(theme+"_Fill",area_data);scene.collection.objects.link(area);area.location=(-25,18,42)
        area.rotation_euler=(Vector((0,0,3))-area.location).to_track_quat('-Z','Y').to_euler()
        scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=2000;scene.render.resolution_y=1500
        scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG'
        scene.render.filepath=str(EVIDENCE/(theme+"-catalog.png"));scene.view_settings.view_transform='Standard'
        # Verify framing after final render aspect/parent transforms are applied.
        from bpy_extras.object_utils import world_to_camera_view
        bpy.context.view_layer.update()
        camera_points=[world_to_camera_view(scene,camera,obj.matrix_world @ Vector(corner))
                       for obj in scene.objects if obj.type in ('MESH','FONT') for corner in obj.bound_box]
        margin=max(max(abs(v.x-.5),abs(v.y-.5))*2 for v in camera_points)
        camera_data.ortho_scale *= max(1,margin*1.08)
        preview_scenes.append(scene)
        print("STORY_PROPS_EXPORTED "+theme+" parts="+str(len(catalog)),flush=True)
    for scene in initial_scenes: bpy.data.scenes.remove(scene)
    (OUT/"manifest.json").write_text(json.dumps(manifest,indent=2),encoding="utf-8")
    (EVIDENCE/"story-props-report.json").write_text(json.dumps(manifest,indent=2),encoding="utf-8")
    bpy.ops.wm.save_as_mainfile(filepath=str(EVIDENCE/"campaign-story-props.blend"))
    check_assets()
    if render_previews:
        for scene in preview_scenes:
            bpy.context.window.scene=scene;bpy.ops.render.render(write_still=True)
            print("STORY_PROPS_PREVIEW_OK "+scene.name,flush=True)


if __name__=="__main__":
    if "--check" in sys.argv:
        check_assets()
    else:
        build_assets("--render-previews" in sys.argv)
