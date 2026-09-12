"""Author a meter-scale ruined Han temple kit and layout; run with Blender -b.

Godot coordinates are converted explicitly to Blender (x, -z, y).  Materials,
bevelled masonry, carved columns, curved tiled roofs and terrain are real meshes.
The JSON describes gameplay support and simple architecture collisions separately
from decorative roofs.  No downloads or existing game models are modified.
"""
import bpy
import json
import math
import random
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'game/assets/environment/awakening_temple'
EVIDENCE = ROOT / 'build/temple-redesign-20260909'
OUT.mkdir(parents=True, exist_ok=True)
EVIDENCE.mkdir(parents=True, exist_ok=True)
random.seed(1909)
scene = bpy.data.scenes.new('Awakening_Temple_Authored')
bpy.context.window.scene = scene
groups = {}
collisions = []

def mat(name, color, roughness=.85, metal=0, emission=0):
    # Palette swatches are display sRGB; glTF PBR factors are linear RGB.
    color = tuple(c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4 for c in color)
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    bs = m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value = (*color, 1)
    bs.inputs['Roughness'].default_value = roughness
    bs.inputs['Metallic'].default_value = metal
    if emission:
        bs.inputs['Emission Color'].default_value = (*color, 1)
        bs.inputs['Emission Strength'].default_value = emission
    return m

stone = [mat('Limestone_%d' % i, c) for i, c in enumerate([
    (.29,.32,.31), (.34,.36,.33), (.25,.28,.27), (.38,.39,.35)])]
dark = mat('Carved_Basalt', (.12,.16,.18))
wood = mat('Weathered_Red_Cedar', (.23,.075,.045), .8)
tile = mat('Jade_Glazed_Roof', (.065,.16,.17), .48, .12)
bronze = mat('Aged_Bronze', (.39,.24,.085), .58, .65)
moss = mat('Moss_And_Fern', (.075,.145,.07))
rock = mat('Stratified_Cliff', (.15,.18,.18))
ember = mat('Lantern_Ember', (1,.32,.055), .55, 0, 2)

def xyz(x, y, z):
    return (x, -z, y)

def mesh(name, verts, faces, material, category):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    data.materials.append(material)
    data.update()
    obj = bpy.data.objects.new(name, data)
    scene.collection.objects.link(obj)
    groups.setdefault(category, []).append(obj)
    return obj

def block(name, x, y, z, sx, sy, sz, material, bevel=.055, category='Masonry'):
    # Chamfered octagonal footprint, with an inset top shoulder.
    b = min(bevel, sx*.18, sz*.18, sy*.2)
    outline = [(-sx/2+b,-sz/2),(sx/2-b,-sz/2),(sx/2,-sz/2+b),
               (sx/2,sz/2-b),(sx/2-b,sz/2),(-sx/2+b,sz/2),
               (-sx/2,sz/2-b),(-sx/2,-sz/2+b)]
    verts = []
    for yy, inset in [(y-sy/2, 0),(y+sy/2-b,0),(y+sy/2,b)]:
        for xx, zz in outline:
            verts.append(xyz(x+xx*(1-inset/max(sx/2,.01)), yy,
                             z+zz*(1-inset/max(sz/2,.01))))
    faces=[tuple(range(7,-1,-1)),tuple(range(16,24))]
    for ring in range(2):
        for i in range(8):
            j=(i+1)%8
            faces.append((ring*8+i,ring*8+j,(ring+1)*8+j,(ring+1)*8+i))
    return mesh(name,verts,[tuple(reversed(f)) for f in faces],material,category)

def column(name,x,z,height=6,r=.55):
    rings=[(0,r*1.65),(.2,r*1.65),(.35,r*1.2),(.65,r),
           (height-.65,r*.9),(height-.4,r*1.35),(height-.15,r*1.65),(height,r*1.65)]
    vs=[xyz(x+math.cos(a*math.tau/12)*rr,y,z+math.sin(a*math.tau/12)*rr)
        for y,rr in rings for a in range(12)]
    fs=[tuple(range(11,-1,-1)),tuple(range(84,96))]
    for k in range(len(rings)-1):
        for a in range(12): fs.append((k*12+a,k*12+(a+1)%12,(k+1)*12+(a+1)%12,(k+1)*12+a))
    mesh(name,vs,[tuple(reversed(f)) for f in fs],dark,'Carved_Columns')
    # Inlaid vertical panels and collar, instead of featureless cylinders.
    for side in [-1,1]:
        block(name+'_inlay',x+side*r*.87,height*.48,z,.035,height*.55,r*.65,bronze,.01,'Bronze_Detail')
    collisions.append(dict(name=name,position=[x,height/2,z],size=[r*1.8,height,r*1.8],rotation_y=0))

def roof(name,x,z,width,depth,y):
    # Four sloping panels with raised eaves, visible thickness and segmented ribs.
    profiles=[(1,0),(.94,-.13),(.70,.42),(.38,1.45),(.04,2.45)]
    for side in [-1,1]:
        seg=max(12,round(width/.5))
        vs=[]
        for f,h in profiles:
            for i in range(seg+1):
                u=i/seg*2-1
                corner=.55*abs(u)**5*f**2
                vs.append(xyz(x+u*(width/2)*(1-.12*(1-f)), y+h+corner, z+side*depth/2*f))
        fs=[]
        for r in range(4):
            for i in range(seg): fs.append((r*(seg+1)+i,r*(seg+1)+i+1,(r+1)*(seg+1)+i+1,(r+1)*(seg+1)+i))
        upward=[]
        for face in fs:
            a,b,c=(Vector(vs[k]) for k in face[:3])
            upward.append(tuple(reversed(face)) if (b-a).cross(c-a).z < 0 else face)
        mesh(name+'_slope',vs,upward,tile,'Roof_Tiles')
        # Actual curved tile ribs follow each roof strip (not a painted rectangle).
        for i in range(0,seg+1,2):
            u=i/seg*2-1
            for j in range(4):
                f,h=profiles[j]; f2,h2=profiles[j+1]
                a=Vector(xyz(x+u*width/2*(1-.12*(1-f)),y+h+.06+.55*abs(u)**5*f*f,z+side*depth/2*f))
                b=Vector(xyz(x+u*width/2*(1-.12*(1-f2)),y+h2+.06+.55*abs(u)**5*f2*f2,z+side*depth/2*f2))
                beam(name+'_tile_rib',a,b,.055,tile,'Roof_Ribs')
    block(name+'_ridge',x,y+2.48,z,width*.92,.16,.24,bronze,.025,'Bronze_Detail')
    for side in [-1,1]:
        block(name+'_eave',x,y+.05,z+side*depth/2,width,.16,.22,wood,.04,'Timber_Frames')

def beam(name,a,b,r,material,category):
    axis=(b-a).normalized()
    normal=axis.cross(Vector((0,0,1)))
    if normal.length<.01: normal=axis.cross(Vector((1,0,0)))
    normal.normalize(); other=axis.cross(normal)
    vs=[tuple(p+normal*math.cos(i*math.tau/6)*r+other*math.sin(i*math.tau/6)*r)
        for p in [a,b] for i in range(6)]
    fs=[tuple(range(5,-1,-1)),tuple(range(6,12))]
    fs += [(i,(i+1)%6,(i+1)%6+6,i+6) for i in range(6)]
    mesh(name,vs,fs,material,category)

def gate(name,x,z,width=18):
    for side in [-1,1]:
        column(name+'_pillar',x+side*width*.35,z,7,.75)
        block(name+'_foot',x+side*width*.35,.2,z,2.4,.4,2.8,stone[1],.12)
        for yy in [5.7,6.1,6.5]:
            block(name+'_dougong',x+side*width*.35,yy,z,3.4-(yy-5.7),.2,2.2+(yy-5.7),wood)
    block(name+'_beam',x,6.45,z,width*.82,.7,1.25,wood,.1,'Timber_Frames')
    block(name+'_carved_seal',x,6.4,z+0.72,2.4,.7,.15,bronze,.04,'Bronze_Detail')
    roof(name,x,z,width,7,7)

def lantern(x,z):
    block('Lantern_plinth',x,.15,z,.85,.3,.85,stone[1])
    block('Lantern_column',x,.85,z,.38,1.2,.38,dark)
    block('Lantern_sill',x,1.48,z,.78,.16,.78,bronze)
    block('Lantern_flame',x,1.8,z,.32,.52,.32,ember,.05,'Lantern_Flames')
    for xx in [-.27,.27]:
        for zz in [-.27,.27]: block('Lantern_frame',x+xx,1.83,z+zz,.07,.65,.07,bronze,.01,'Bronze_Detail')
    roof('Lantern_cap',x,z,1.05,1.05,2.2)

cells=set()
def rect(xa,xb,za,zb):
    cells.update((x,0,z) for z in range(za,zb+1) for x in range(xa,xb+1))
rect(-3,3,-2,5);rect(-1,1,6,15);rect(-4,4,16,22)
rect(-8,-6,4,16);rect(6,8,7,18)
rect(-7,0,5,6);rect(-7,0,15,16);rect(0,7,8,9);rect(0,7,17,18)
cells=sorted(cells,key=lambda c:(c[2],c[0]))
cellset=set(cells)
# Stone foundations, pavers and edge masonry communicate a built ruin, not grids.
for x,_,z in cells:
    xx,zz=x*6,-z*6
    block('Foundation',xx,-1.4,zz,6.02,2.6,6.02,rock,.24,'Cliff_Foundations')
    for a in range(4):
        for b in range(4):
            block('Hand_cut_flagstone',xx-2.25+a*1.5,-.09,zz-2.25+b*1.5,
                  1.46,.18,1.46,random.choice(stone),.045,'Paved_Ground')
    for dx,dz in [(1,0),(-1,0),(0,1),(0,-1)]:
        if (x+dx,0,z+dz) in cellset: continue
        ex,ez=xx+dx*2.83,zz-dz*2.83
        sx,sz=(.45,6) if dx else (6,.45)
        block('Retaining_wall',ex,.72,ez,sx,1.45,sz,stone[2],.08)
        block('Wall_coping',ex,1.49,ez,sx+.2,.18,sz+.2,stone[1],.055)
        collisions.append(dict(name='Retaining_wall',position=[ex,.78,ez],size=[sx,1.56,sz],rotation_y=0))
        # Broken posts, masonry courses and moss break up the uniform parapet.
        for n in [-2.15,0,2.15]:
            px,pz=(ex,ez+n) if dx else (ex+n,ez)
            block('Coping_post',px,1.15,pz,.7,2.3,.7,dark,.075)
        if random.random()<.48:
            block('Creeping_moss',ex-dx*.25,.12,ez+dz*.25,.5 if dx else 2.0,.06,2.0 if dx else .5,moss,.02,'Garden_Moss')

gate('First_Moon_Gate',0,-31,18)
gate('Inner_Procession_Gate',0,-86,18)
gate('Furnace_Sanctum_Gate',0,-128,26)
# Cloister roofs frame exploration routes, with regularly spaced carved supports.
for x,z,length in [(-42,-60,36),(-42,-84,30),(42,-72,36),(42,-96,24)]:
    for dz in [-length/2,0,length/2]:
        for dx in [-5.5,5.5]: column('Cloister_column',x+dx,z+dz,4.5,.42)
    roof('Cloister',x,z,14,length+4,4.7)
    for dx in [-5.5,5.5]: block('Cloister_tie',x+dx,4.3,z,.28,.4,length+2,wood,.035,'Timber_Frames')

# Terminal hall side pavilions: real walls, inset doors, stone foundations, roof tiers.
for x in [-19,19]:
    z=-115
    block('Pavilion_foundation',x,.6,z,11,1.2,13,stone[2],.15)
    block('Pavilion_back',x,3.5,z-5.6,10,5,1.1,stone[0],.12)
    for dx in [-4.5,4.5]:
        block('Pavilion_wall',x+dx,3.5,z,1,5,11,stone[0],.1)
        column('Pavilion_front_column',x+dx,z+5.5,6,.5)
    for n in range(6): block('Pavilion_stair',x,(n+1)*.1,z+8.4-n*.4,6,(n+1)*.2,.5,stone[1],.035)
    collisions.append(dict(name='Pavilion_stair_ramp',position=[x,.55527864,z+7.67763932],
                           size=[6,.1,2.78],rotation_y=0,rotation_x=math.atan2(1.2,2.4)))
    roof('Pavilion_lower_roof',x,z,14,16,6.1)
    roof('Pavilion_upper_roof',x,z,9,10,9.2)
    collisions += [dict(name='Pavilion_base',position=[x,.6,z],size=[11,1.2,13],rotation_y=0),
                   dict(name='Pavilion_back',position=[x,3.5,z-5.6],size=[10,5,1.1],rotation_y=0)]
    for dx in [-4.5,4.5]: collisions.append(dict(name='Pavilion_side',position=[x+dx,3.5,z],size=[1,5,11],rotation_y=0))
    block('Pavilion_altar',x,1.5,z-2,4,.6,2,dark,.12)
    block('Pavilion_ancestral_stele',x,3.15,z-2,1.3,2.7,1.05,stone[1],.18)
    block('Stele_inlaid_tablet',x,3.25,z-1.44,.83,1.8,.065,bronze,.04,'Bronze_Detail')
    for dx in [-2.5,2.5]:
        block('Altar_lamp_stand',x+dx,2,z-1.8,.4,1.6,.4,bronze,.055)
        block('Altar_lamp_fire',x+dx,2.98,z-1.8,.34,.46,.34,ember,.045,'Lantern_Flames')
    collisions += [dict(name='Pavilion_altar',position=[x,1.5,z-2],size=[4,.6,2],rotation_y=0),
                   dict(name='Pavilion_stele',position=[x,3.15,z-2],size=[1.3,2.7,1.05],rotation_y=0)]

for z in [-18,-39,-57,-75,-99,-120]:
    for x in [-7.5,7.5]: lantern(x,z)
# Layered rock masses and bent trees outside playable paths, with remote mountain silhouettes.
for i in range(42):
    angle=i*math.tau/42
    x=math.cos(angle)*82;z=-61+math.sin(angle)*120
    r=random.uniform(9,18);h=random.uniform(14,39)
    vs=[]
    rock_profile=[(-10,r),(0,r*.95),(h*.35,r*.88),(h*.72,r*.62),(h*.94,r*.52),(h,r*.31)]
    for yy,rr in rock_profile:
        for j in range(9):
            a=j*math.tau/9;rrr=rr*random.uniform(.8,1.15)
            vs.append(xyz(x+math.cos(a)*rrr+yy*.07,yy,z+math.sin(a)*rrr+math.sin(yy*.2)*1.2))
    fs=[]
    for k in range(len(rock_profile)-1):
        for j in range(9):fs.append((k*9+j,k*9+(j+1)%9,(k+1)*9+(j+1)%9,(k+1)*9+j))
    fs.append(tuple(range(45,54)))
    mesh('Distant_Karst',vs,[tuple(reversed(f)) for f in fs],rock,'Karst_Horizon')

def foliage_cluster(x,y,z,sx,sy,sz):
    verts=[]
    for ring in range(7):
        latitude=-math.pi/2+math.pi*ring/6
        for side in range(12):
            angle=side*math.tau/12
            irregular=random.uniform(.8,1.15)
            verts.append(xyz(x+math.cos(latitude)*math.cos(angle)*sx*irregular,
                             y+math.sin(latitude)*sy*irregular,
                             z+math.cos(latitude)*math.sin(angle)*sz*irregular))
    faces=[]
    for ring in range(6):
        for side in range(12):
            faces.append((ring*12+side,ring*12+(side+1)%12,
                          (ring+1)*12+(side+1)%12,(ring+1)*12+side))
    mesh('Cypress_foliage_cluster',verts,[tuple(reversed(f)) for f in faces],moss,'Ancient_Trees')

for x,z in [(-15,-8),(16,-18),(-43,-35),(42,-48),(-24,-100),(18,-99)]:
    collisions.append(dict(name='Cypress_trunk',position=[x,3,z],size=[.65,6,.65],rotation_y=0))
    for k in range(5):
        a=Vector(xyz(x,0,z));b=Vector(xyz(x+.3*k,2+k*1.1,z-.12*k))
        beam('Ancient_cypress_trunk',a,b,.28-k*.027,wood,'Ancient_Trees')
        for sign in [-1,1]:
            c=b+Vector((sign*(1.5+k*.2),sign*.7,.6))
            beam('Cypress_branch',b,c,.11,wood,'Ancient_Trees')
            for lobe in range(3):
                foliage_cluster(c.x+random.uniform(-.7,.7),c.z+random.uniform(-.2,.35),
                                -c.y+random.uniform(-.5,.5),1.15,.55,.9)
            collisions.append(dict(name='Cypress_crown',position=[c.x,c.z,-c.y],
                                   size=[3.6,1.35,2.8],rotation_y=0))

# Batch authored geometry by material/category for a bounded Web draw-call count.
for category,objects in list(groups.items()):
    by_material={}
    for obj in objects:by_material.setdefault(obj.data.materials[0].name,[]).append(obj)
    for material,items in by_material.items():
        bpy.ops.object.select_all(action='DESELECT')
        for obj in items:obj.select_set(True)
        bpy.context.view_layer.objects.active=items[0]
        bpy.ops.object.join()
        items[0].name=category+'_'+material

layout=dict(version=1,cell_size=6,walkable_cells=[list(c) for c in cells],
    markers=dict(spawn=[0,1.1,2],checkpoint=[0,0,-6],exit=[0,0,-130]),
    modules=dict(fragile_floor=[-42,0,-66],gate_exit=[0,0,-126]),
    shortcuts=dict(one_way_door=[-24,0,-30],far_side=[-30,.7,-30],elevator=[-42,0,-90],shrine_dock=[-12,0,-18]),
    collision_boxes=collisions,
    encounters=[[-5,0,-42],[5,0,-57],[-42,0,-60],[42,0,-81],[-8,0,-110],[8,0,-119]],
    landmarks=dict(moon_gate=[0,0,-31],inner_gate=[0,0,-86],sanctum=[0,0,-128],west_cloister=[-42,0,-66],east_cloister=[42,0,-84]))
(OUT/'layout.json').write_text(json.dumps(layout,indent=2),encoding='utf-8')
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(OUT/'temple.glb'),export_format='GLB',use_selection=True,use_active_scene=True,
    export_animations=False,export_yup=True,export_apply=True)
bpy.ops.wm.save_as_mainfile(filepath=str(EVIDENCE/'awakening-temple.blend'))
report=dict(objects=len(scene.objects),vertices=sum(len(o.data.vertices) for o in scene.objects if o.type=='MESH'),
    cells=len(cells),walkable_area_m2=len(cells)*36,collision_boxes=len(collisions),
    bounds_m=[102,150],glb_bytes=(OUT/'temple.glb').stat().st_size)
(EVIDENCE/'model-report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('AWAKENING_TEMPLE_MODELED '+json.dumps(report))
