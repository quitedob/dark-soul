"""Source-backed rigid joints and soft chains for procedural GLB props.

Only describes bones and mesh assignments on a Workbench; Blender scene creation,
skinning, export, and pose validation remain owned by rig_glb_models.py.
"""
import re

import numpy as np


class _Props:
    def __init__(self, wb):
        self.wb = wb
        self.groups = {}
        mid = (wb.low + wb.high) / 2
        wb.add('root', '', [mid[0], mid[1], wb.low[2]])
        wb.add('body', 'root', mid)
        # Keep combined asset collections separate, as in the original workbench.
        for obj in wb.parts:
            chain = wb.chains[obj]
            group = chain[-2] if len(chain) > 2 else obj
            if group not in self.groups:
                name = 'part.' + re.sub(r'[^A-Za-z0-9_.-]', '_', group.name)
                head = self.origin(group) if group.type == 'EMPTY' else wb.center[obj]
                wb.add(name, 'body', head)
                self.groups[group] = name
            wb.assignment[obj] = self.groups[group]

    def origin(self, obj):
        return np.asarray(obj.matrix_world.translation, dtype=float).copy()

    def select(self, pattern, group=None):
        return [o for o in self.wb.parts if re.fullmatch(pattern, self.wb.names[o])
                and (group is None or any(self.wb.names[a] == group for a in self.wb.chains[o][1:]))]

    def require(self, pattern, group=None):
        parts = self.select(pattern, group)
        if len(parts) != 1:
            raise ValueError('%s: expected one %s in %s, found %d' %
                             (self.wb.rel, pattern, group, len(parts)))
        return parts[0]

    def parent_group(self, obj):
        chain = self.wb.chains[obj]
        return self.groups[chain[-2] if len(chain) > 2 else obj]

    def joint(self, name, parts, parent='body', pivot=None, axis=None):
        if not parts:
            return None
        if pivot is None:
            pivot = np.mean([self.wb.center[o] for o in parts], axis=0)
        pivot = np.asarray(pivot, dtype=float)
        tail = None
        if axis is not None:
            axis = np.asarray(axis, dtype=float)
            tail = pivot + axis / max(np.linalg.norm(axis), 1e-8) * self.wb.size * .06
        self.wb.add(name, parent, pivot, tail)
        for obj in parts:
            self.wb.assignment[obj] = name
        return name

    def top(self, obj):
        points = self.wb.points[obj]
        z = points[:, 2].max()
        cap = points[points[:, 2] >= z - max(np.ptp(points[:, 2]) * .04, 1e-7)]
        return cap.mean(axis=0)

    def static_body(self):
        for obj in self.wb.parts:
            self.wb.assignment[obj] = 'body'

    def book(self):
        # enemies-ch4ch5/05-Book-Spirit.mjs:42-70: all leaves originate at the spine.
        self.static_body()
        spine = self.require('spine')
        self.joint('book.spine', self.select(r'spine.*|weapon_tip'), pivot=self.wb.center[spine])
        for side in ('l', 'r'):
            cover = self.require('cover_' + side)
            cover_bone = 'book.cover.' + side.upper()
            self.joint(cover_bone, [cover], 'book.spine', self.origin(cover), [0, 0, 1])
            for page in self.select(r'page\d+', 'pages_' + side):
                number = re.search(r'\d+$', self.wb.names[page]).group()
                parts = [page] + self.select('glyph' + number, 'pages_' + side)
                self.joint('book.page.' + side.upper() + '.' + number, parts,
                           cover_bone, self.origin(page), [0, 0, 1])

    def furnace(self):
        # enemies-ch4ch5/03-Elixir-Furnace-Spirit.mjs:57-76: lid fittings and three feet.
        self.static_body()
        lid = self.require('lid')
        self.joint('furnace.lid', self.select(r'lid(?:_.*)?|knob_fire'), pivot=self.origin(lid))
        for leg in self.select(r'beast_leg\d+'):
            index = re.search(r'\d+$', self.wb.names[leg]).group()
            self.joint('furnace.leg.' + index,
                       [leg] + self.select(r'(?:foot_claw|leg_band)' + index),
                       pivot=self.top(leg), axis=[0, 0, -1])

    def torture(self):
        # enemies-ch1ch2/04-Torture-Device-Spirit.mjs:54-100. The door frame is fixed.
        self.static_body()
        for obj in self.select(r'plinth.*|spike_base\d+'):
            self.wb.assignment[obj] = 'root'
        door = self.require('door')
        pivot = self.wb.center[door].copy()
        pivot[0] = self.wb.points[door][:, 0].min()
        self.joint('torture.door', [door] + self.select(r'door_rivet\d+'), pivot=pivot)
        for side in ('l', 'r'):
            chain = self.require('chain_' + side)
            palm = self.require('claw_palm_' + side)
            points = self.wb.points[chain]
            # The chain end closest to the shell is its shoulder attachment.
            distance = np.linalg.norm(points - self.wb.bones['body']['head'], axis=1)
            pivot = points[distance <= distance.min() + self.wb.size * .015].mean(axis=0)
            chain_bone = 'torture.chain.' + side.upper()
            self.joint(chain_bone, [chain] + self.select(r'link_' + side + r'\d+'),
                       pivot=pivot, axis=self.wb.center[palm] - pivot)
            self.joint('torture.claw.' + side.upper(),
                       [palm] + self.select(r'claw_' + side + r'\d+|chain_tip_' + side),
                       chain_bone, self.wb.center[palm])

    def lantern(self):
        # enemies-ch3/04-Foxfire-Lantern-Spirit.mjs:63-103: hanging cord and pendants.
        self.static_body()
        cord = self.require('hang_cord')
        sockets = [o for o in self.wb.objects if self.wb.names[o] == 'hang_point']
        pivot = self.origin(sockets[0]) if sockets else self.top(cord)
        self.joint('lantern.hang', [cord], 'root', pivot, [0, 0, -1])
        self.wb.bones['body']['parent'] = 'lantern.hang'
        for i, tassel in enumerate(self.select('tassel_cord')):
            candidates = self.select(r'tassel_knot|tassel_tail')
            knots = [o for o in candidates if min(self.select('tassel_cord'),
                     key=lambda c: np.linalg.norm(self.wb.center[c] - self.wb.center[o])) is tassel]
            self.joint('lantern.tassel.%02d' % i, [tassel] + knots, pivot=self.top(tassel), axis=[0, 0, -1])
        for stem, attachments in [('fu', 'fu_card'), ('pendant', 'pendant_jade')]:
            strand = self.require(stem + '_cord')
            self.joint('lantern.' + stem, [strand] + self.select(attachments),
                       pivot=self.top(strand), axis=[0, 0, -1])

    def traps(self):
        # props-equipment/04-Traps.mjs:28-90: translate pressure cap/gate; rotate pulley.
        top = self.require('plate_top', 'pressure_plate')
        self.joint('trap.pressure_top', self.select(r'plate_top|glow_seam|glyph_ring|direction_glyph|trigger_pin', 'pressure_plate'),
                   self.parent_group(top), self.wb.center[top])
        slab = self.require('gate_slab', 'falling_gate')
        self.joint('trap.gate_slab', self.select(r'gate_slab|band|ratchet_tooth|chain_[lr]', 'falling_gate'),
                   self.parent_group(slab), self.wb.center[slab])
        pulley = self.require('pulley_wheel', 'falling_gate')
        self.joint('trap.pulley', self.select(r'pulley_wheel|pulley_spoke', 'falling_gate'),
                   self.parent_group(pulley), self.wb.center[pulley], [0, -1, 0])

    def puzzles(self):
        # props-equipment/05-PuzzleProps.mjs:32-93: actual axle, pointer centers and lid.
        pivot = self.require('pivot', 'rotating_bronze_mirror')
        self.joint('puzzle.mirror', self.select(r'pivot|pivot_collar|mirror_disc|mirror_face|mirror_rim|rim_edge', 'rotating_bronze_mirror'),
                   self.parent_group(pivot), self.wb.center[pivot], [1, 0, 0])
        for pointer in self.select(r'pointer\d*', 'celestial_dial'):
            self.joint('puzzle.' + self.wb.names[pointer], [pointer],
                       self.parent_group(pointer), self.origin(pointer), [0, 0, 1])
        lid = self.require('cauldron_lid', 'bronze_cauldron')
        self.joint('puzzle.cauldron_lid', [lid] + self.select('lid_knob', 'bronze_cauldron'),
                   self.parent_group(lid), self.origin(lid))

    def forge(self):
        # props-equipment/03-ForgeAndAnvil.mjs:51-58 provides an authored door hinge.
        furnace = self.require('furnace')
        furnace_bone = self.parent_group(furnace)
        for obj in self.select(r'furnace.*|mouth_glow|door_hinge'):
            self.wb.assignment[obj] = furnace_bone
        hinge = self.require('door_hinge')
        self.joint('forge.door', self.select(r'forge_door|door_latch'),
                   furnace_bone, self.wb.center[hinge], [0, -1, 0])

    def ambient(self):
        # props-equipment/06-AmbientProps.mjs:29-70: hanging shade and removable lid.
        cord = self.require('hang_cord', 'paper_lantern')
        lantern_bone = self.joint('ambient.lantern', self.select(
            r'hang_cord|paper|rib|foxfire_bead|glow_core|foxfire_halo|top_cap|tassel', 'paper_lantern'),
            self.parent_group(cord), self.top(cord), [0, 0, -1])
        tassel = self.require('tassel', 'paper_lantern')
        self.joint('ambient.tassel', [tassel], lantern_bone, self.top(tassel), [0, 0, -1])
        lid = self.require('coffin_lid', 'stone_sarcophagus')
        self.joint('ambient.coffin_lid', self.select(r'coffin_lid|carved_figure|broken_seal|rune', 'stone_sarcophagus'),
                   self.parent_group(lid), self.origin(lid))

    def lotus(self):
        # boss-sub-summons/05-rebirth-lotus.mjs:51-74: blade origin includes radial offset.
        for obj in self.select(r'petal_(?:outer|mid|inner)_\d+_blade'):
            bone = self.wb.bones[self.wb.assignment[obj]]
            bone['head'] = self.origin(obj)
            bone['tail'] = self.wb.center[obj].copy()

    def soft(self, name, parts, parent, count=2):
        if not parts:
            return
        self.wb.chain(name, parts, parent, count, vertical=True)
        # Keep the attached edge on its owner, not an independently swinging mesh.
        for obj in parts:
            mode, names, a, b = self.wb.blends[obj]
            self.wb.blends[obj] = (mode, [parent] + names, a, b)

    def static_prop(self):
        # Shrine, echo, forge and bridge generators put fixed masonry/trim directly
        # on root. Keep their compound child collections, not one joint per rivet.
        for obj in self.wb.parts:
            if len(self.wb.chains[obj]) <= 2:
                self.wb.assignment[obj] = 'body'

    def forge_assembly(self):
        self.static_prop()
        self.forge()

    def bow(self):
        # weapons/01 and 05: paired wood layers, rigid horn tips, a single string.
        wb = self.wb
        self.static_body()
        grip = self.require('grip')
        wb.bones['body']['head'] = wb.center[grip].copy()
        tips = {}
        for side in ('up', 'dn'):
            limbs = self.select('limb_' + side + r'(?:_[fb])?')
            if not limbs:
                raise ValueError(wb.rel + ': missing bow limb ' + side)
            curves = [wb.tube_centers(o) for o in limbs]
            curve = np.mean(curves, axis=0)
            if np.linalg.norm(curve[-1] - wb.center[grip]) < np.linalg.norm(curve[0] - wb.center[grip]):
                curve = curve[::-1].copy()
            lengths = np.r_[0., np.cumsum(np.linalg.norm(np.diff(curve, axis=0), axis=1))]
            knots = np.linspace(0, lengths[-1], 4)
            joints = np.array([np.interp(knots, lengths, curve[:, axis]) for axis in range(3)]).T
            names = ['body']
            for i in range(1, 4):
                name = 'bow.' + side + '.%02d' % i
                wb.add(name, names[-1], joints[i - 1], joints[i])
                names.append(name)
            spec = ('curve', names, curve, lengths)
            for obj in limbs:
                wb.blends[obj] = spec
            tips[side] = names[-1]
            fittings = self.select(r'(?:horn_' + side + r'_curl|tip_cap_' + side +
                                   r'|ember_tip_' + side + r'|sun_(?:disc|core|ray)_' + side +
                                   r'\d*|beak_' + side + r')')
            fittings += self.select('.*', 'feather_' + side)
            for obj in fittings:
                wb.assignment[obj] = names[-1]
            for group in (('crack_main', 'crack_up') if side == 'up' else ('crack_dn',)):
                for obj in self.select('crack', group):
                    wb.blends[obj] = spec
            # Short gold rays are rigid fittings on the upper wood, not soft strips.
            if side == 'up':
                for obj in self.select(r'ray\d+'):
                    wb.assignment[obj] = min(names, key=lambda n: np.linalg.norm(wb.center[obj] - wb.bones[n]['head']))
        string = self.require(r'bowstring|fire_string')
        curve = wb.tube_centers(string)
        if curve[0, 2] < curve[-1, 2]:
            curve = curve[::-1].copy()
        lengths = np.r_[0., np.cumsum(np.linalg.norm(np.diff(curve, axis=0), axis=1))]
        middle = np.array([np.interp(lengths[-1] * .5, lengths, curve[:, axis]) for axis in range(3)])
        wb.add('bow.draw', 'body', middle)
        # Both string ends share the horn owners; drawing cannot detach the nocks.
        wb.blends[string] = ('curve', [tips['up'], 'bow.draw', tips['dn']], curve, lengths)
        for obj in self.select('string_serving'):
            wb.assignment[obj] = 'bow.draw'
        for obj in self.select('weapon_tip'):
            wb.assignment[obj] = tips['up']
        for group in ('arrow_stow', 'sun_arrow'):
            for obj in self.select('.*', group):
                wb.assignment[obj] = self.parent_group(obj)

    def weapon(self):
        # Single weapons: blade, haft, guard, inlays and sockets form one rigid unit.
        self.static_body()
        grip = self.select(r'grip|handle|knob')
        if len(grip) == 1:
            self.wb.bones['body']['head'] = self.wb.center[grip[0]].copy()
        rel = self.wb.rel
        if rel.endswith('03-Mystic-Gate-Seal.glb'):
            self.soft('seal.tassel', self.select(r'tassel_cord|tassel_tuft'), 'body')
            for obj in self.select(r'tassel_bell|bell_clapper'):
                self.wb.assignment[obj] = 'seal.tassel.02'
            for side in ('l', 'r'):
                self.soft('seal.paper.' + side, self.select('paper', 'talisman_' + side), 'body')
        elif rel.endswith('06-Five-Elements-Seal.glb'):
            self.soft('seal.tassel', self.select(r'tassel_cord|tassel_fringe'), 'body')
        elif rel.endswith('08-XuanXiao-Falling-Star.glb'):
            self.soft('sword.tassel', self.select('tassel'), 'body')
        elif rel.endswith('10-JuQue-Gatekeeper.glb'):
            self.soft('sword.talisman', self.select(r'gate_talisman|talisman_rune'), 'body')
        elif rel.endswith('11-NineTails-Illusion-Moon.glb'):
            # Face origin and rib pivots disagree in the source; keep the fan open.
            for obj in self.select(r'tassel\d+'):
                self.soft('fan.' + self.wb.names[obj], [obj], 'body')

    def weapon_bundle(self):
        # weapons/02, 07, 12 put sockets outside the authored item subtrees.
        wb = self.wb
        groups = ('straight_sword', 'spear', 'war_hammer') if '12-Weapon-Types' in wb.rel else ('axe_left', 'axe_right')
        owners = {}
        for group in groups:
            parts = self.select('.*', group)
            grip = self.require(r'handle|sword_grip|spear_shaft|hammer_handle', group)
            owner = self.parent_group(grip)
            owners[group] = owner
            wb.bones[owner]['head'] = wb.center[grip].copy()
            for obj in parts:
                wb.assignment[obj] = owner
            if group == 'spear':
                self.soft('spear.tassel', self.select(r'spear_tassel2?', group), owner)
            elif group.startswith('axe_'):
                if '02-XingTian' in wb.rel:
                    # Both strands terminate at the same loose lower ring.
                    self.soft(group + '.chain', self.select(r'chain_link2?', group), owner)
                    for obj in self.select('pommel_ring2', group):
                        wb.assignment[obj] = group + '.chain.02'
                else:
                    for strand in ('soul_chain', 'soul_chain_2'):
                        self.soft(group + '.' + strand, self.select(strand, group), owner)
                    for obj in self.select('chain_spark', group):
                        wb.assignment[obj] = group + '.soul_chain.02'
        for obj in self.select('weapon_tip'):
            # Display columns share X with their source-authored tip markers.
            wb.assignment[obj] = min(owners.values(), key=lambda n: abs(wb.center[obj][0] - wb.bones[n]['head'][0]))

    def beads(self):
        # weapons/04: two strands join the same clasp and guru bead. Shared rows
        # keep the loop closed while individual wooden beads remain rigid.
        wb = self.wb
        self.static_body()
        names, joints = [], []
        for i in range(12):
            pair = [self.require('bead_' + side + str(i)) for side in ('l', 'r')]
            joints.append(np.mean([self.origin(o) for o in pair], axis=0))
            names.append('beads.row.%02d' % i)
        for i, name in enumerate(names):
            wb.add(name, names[i - 1] if i else 'body', joints[i], joints[min(i + 1, 11)])
            for side in ('l', 'r'):
                wb.assignment[self.require('bead_' + side + str(i))] = name
        for obj in self.select(r'cord_[lr]'):
            wb.blends[obj] = ('chain', names, joints[0], joints[-1])
        for obj in self.select(r'guru_bead|vajra_(?:mid|dn2?|ember)'):
            wb.assignment[obj] = names[-1]
        self.soft('beads.tassel', self.select(r'tassel_cord|tassel_fringe'), names[-1])
        for i in (1, 2):
            parts = self.select('paper', 'talisman' + str(i)) + self.select('talisman_rune' + str(i))
            self.soft('beads.paper.' + str(i), parts, names[-1])

    def armor(self):
        # equip-01/02/03: wearable display groups, not an invented human skeleton.
        wb = self.wb
        for obj in self.select('plinth'):
            wb.assignment[obj] = 'root'
        if '01-LightArmor' in wb.rel:
            cloak = self.require('cloak_back', 'mirror_cloak')
            owner = self.parent_group(cloak)
            parts = self.select(r'cloak_(?:back|front)|(?:back_)?hem_glow', 'mirror_cloak')
            self.soft('armor.cloak', parts, owner)
            # The belt fixes the upper cloak; only the skirt below it is loose.
            belt = self.require('belt', 'mirror_cloak')
            a = wb.bones['armor.cloak.01']['head'].copy()
            a[2] = wb.points[belt][:, 2].min()
            b = wb.blends[cloak][3].copy()
            wb.bones['armor.cloak.01']['head'] = a.copy()
            wb.bones['armor.cloak.01']['tail'] = (a + b) * .5
            wb.bones['armor.cloak.02']['head'] = (a + b) * .5
            for obj in parts:
                wb.blends[obj] = ('chain', [owner, 'armor.cloak.01', 'armor.cloak.02'], a, b)
            for obj in self.select(r'fur_drape_[lr]', 'fox_fur_collar'):
                self.soft('armor.' + wb.names[obj], [obj], self.parent_group(obj))
            return
        heavy = '03-HeavyArmor' in wb.rel
        group = 'heavy_pauldrons' if heavy else 'ming_pauldrons'
        for side, sign in (('L', -1), ('R', 1)):
            parts = [o for o in self.select('.*', group) if wb.center[o][0] * sign > 0]
            plate = next(o for o in parts if wb.names[o] == ('shoulder_l1' if heavy else 'pauldron_l1'))
            owner = self.joint('armor.pauldron.' + side, parts, self.parent_group(plate), self.top(plate))
            for obj in parts:
                if wb.names[obj] == 'strap_tab':
                    self.soft('armor.strap.' + side, [obj], owner)
        if heavy:
            rivets = self.select('tasset_rivet', 'iron_cuirass')
            for i, plate in enumerate(sorted(self.select('tasset', 'iron_cuirass'), key=lambda o: wb.center[o][0])):
                rivet = min(rivets, key=lambda o: abs(wb.center[o][0] - wb.center[plate][0]))
                self.joint('armor.tasset.%02d' % i, [plate, rivet], self.parent_group(plate), self.top(plate), [1, 0, 0])

    def accessories(self):
        # equip-04: the three cords suspend complete pendants, not their boards.
        for obj in self.select(r'base|backboard|hang_rod|hook'):
            self.wb.assignment[obj] = 'root'
        for group in ('jade_pendant', 'war_talisman', 'charm_bag'):
            cord = self.require('cord', group)
            owner = self.parent_group(cord)
            self.soft(group + '.cord', [cord], owner)
            for obj in self.select('.*', group):
                if obj is not cord:
                    self.wb.assignment[obj] = group + '.cord.02'
            self.soft(group + '.tassel', self.select('tassel', group), group + '.cord.02')

    def pickups(self):
        # props/07: three distinct key items share one source group.
        for label, pattern in (
                ('stone', r'rune_stone|seal_mark|iron_band|chain_loop'),
                ('hammer', r'hammer_handle|hammer_head|leather_wrap|forge_heart'),
                ('jade', r'jade_stone|gold_band|jade_glow')):
            parts = self.select(pattern, 'key_items')
            self.joint('pickup.' + label, parts, self.parent_group(parts[0]))
        cork = self.require('cork', 'pill_jar')
        self.joint('pickup.cork', [cork], self.parent_group(cork), self.origin(cork))

    def ambient_soft(self):
        self.ambient()
        self.soft('ambient.tassel.flex', self.select('tassel', 'paper_lantern'), 'ambient.tassel')
        vine = self.require('moss_vine', 'memory_moss')
        self.soft('ambient.vine', [vine], self.parent_group(vine))

    def finish(self):
        # Remove superseded per-mesh branches and order parents before children.
        needed = {'root', 'body'}
        weighted = set(self.wb.assignment.values())
        for _, names, _, _ in self.wb.blends.values():
            weighted.update(names)
        for name in weighted:
            while name:
                if name in needed:
                    break
                needed.add(name)
                name = self.wb.bones[name]['parent']
        # A reparented body (hanging lantern) may have an added parent.
        for name in list(needed):
            parent = self.wb.bones[name]['parent']
            while parent:
                needed.add(parent)
                parent = self.wb.bones[parent]['parent']
        ordered = {}

        def visit(name):
            if name in ordered:
                return
            parent = self.wb.bones[name]['parent']
            if parent:
                visit(parent)
            ordered[name] = self.wb.bones[name]

        for name in self.wb.bones:
            if name in needed:
                visit(name)
        self.wb.bones = ordered


def build_props(wb):
    """Populate rigid assemblies and real blended weights using exact source routes."""
    profile = _Props(wb)
    routes = {
        'enemies/04-celestial-fall/05-Book-Spirit.glb': profile.book,
        'enemies/04-celestial-fall/03-Elixir-Furnace-Spirit.glb': profile.furnace,
        'enemies/02-blood-iron/04-Torture-Device-Spirit.glb': profile.torture,
        'enemies/03-jade-veil/04-Foxfire-Lantern-Spirit.glb': profile.lantern,
        'props/01-EmberShrine.glb': profile.static_prop,
        'props/02-LostEcho.glb': profile.static_prop,
        'props/04-Traps.glb': profile.traps,
        'props/05-PuzzleProps.glb': profile.puzzles,
        'props/03-ForgeAndAnvil.glb': profile.forge_assembly,
        'props/06-AmbientProps.glb': profile.ambient_soft,
        'props/07-Pickups.glb': profile.pickups,
        'props/08-BridgeTea.glb': profile.static_prop,
        'equipment/01-LightArmor.glb': profile.armor,
        'equipment/02-MediumArmor.glb': profile.armor,
        'equipment/03-HeavyArmor.glb': profile.armor,
        'equipment/04-Accessories.glb': profile.accessories,
        'weapons/01-WindHunter-Bow.glb': profile.bow,
        'weapons/02-XingTian-Twin-Axes.glb': profile.weapon_bundle,
        'weapons/03-Mystic-Gate-Seal.glb': profile.weapon,
        'weapons/04-Sandalwood-Beads-Talisman.glb': profile.beads,
        'weapons/05-Sun-Falling-Bow.glb': profile.bow,
        'weapons/06-Five-Elements-Seal.glb': profile.weapon,
        'weapons/07-XingTian-Indomitable.glb': profile.weapon_bundle,
        'weapons/08-XuanXiao-Falling-Star.glb': profile.weapon,
        'weapons/09-ZhuYin-The-End.glb': profile.weapon,
        'weapons/10-JuQue-Gatekeeper.glb': profile.weapon,
        'weapons/11-NineTails-Illusion-Moon.glb': profile.weapon,
        'weapons/12-Weapon-Types.glb': profile.weapon_bundle,
        'characters/summons/03-RebirthLotus.glb': profile.lotus,
    }
    if wb.rel in routes:
        routes[wb.rel]()
    profile.finish()
