"""Original creature/mechanism poses, in Z-up, -Y-forward model-rest axes.

Data only: existing bones, no rest/mesh/weight edits, no scale or root tracks.
The saved bell rig welds both clappers to bell_core; its strike is assembly
recoil, not independent clapper articulation. Native evaluation is external.
"""
from math import cos, hypot, sin, tau

from model_action_common import put, sampled_action, envelope, curve


def _clips(specs, pose_at):
    return [sampled_action(name, seconds, loop, lambda t: pose_at(name, t), kind,
                           steps=64)
            for name, seconds, loop, kind in specs]


def _strike(t):
    return curve(t, [(0, 0), (.25, -.35), (.46, 1), (.60, .3), (1, 0)])


def _settle(t):
    return curve(t, [(0, 0), (.24, .12), (.64, .92), (.84, 1), (1, 1)])


def _quadruped(rig):
    fox = 'NineTails.glb' in rig['file']
    stone = 'Maze-Guardian' in rig['file']
    h = rig['height']
    tails = [b for b in rig['bones'] if b.startswith('tail.')]
    special = 'tail_fan' if fox else 'stone_stomp' if stone else 'wraith_pounce'

    def pose_at(name, t):
        pose, wave = {}, sin(tau * t)
        death = _settle(t) if name == 'death' else 0
        strike = _strike(t) if name in ('attack', 'stone_stomp', 'wraith_pounce') else 0
        impact = envelope(t) if name == 'hit' else 0
        gait = name in ('walk', 'trot')
        strength = (.20 if name == 'walk' else .32) * (.65 if stone else 1)
        bob = .002 * (1 - cos(2 * tau * t)) if gait else 0
        jump = curve(t, [(0, 0), (.25, -.008), (.45, .045), (.65, .006), (1, 0)])
        put(pose, rig, 'hips', rotation=(0, .12 * death, 0),
            translation=(0, -.015 * h * max(strike, 0),
                         h * (bob - .065 * death + (jump if name == 'wraith_pounce' else 0))))
        put(pose, rig, 'chest', rotation=(.07 * strike - .07 * impact + .08 * death,
                                        0, .008 * wave if name == 'idle' else 0))
        put(pose, rig, 'neck', rotation=(.14 * strike - .12 * impact + .18 * death, 0, 0))
        put(pose, rig, 'head', rotation=(.19 * strike + .17 * death,
                                       .09 * impact, .025 * wave if name == 'idle' else 0))
        # Four-beat walk; diagonal front/hind pairs synchronize only in trot.
        offsets = (0, .5, .25, .75) if name == 'walk' else (0, .5, .5, 0)
        for i, suffix in enumerate(('front.L', 'front.R', 'hind.L', 'hind.R')):
            swing = sin(tau * (t + offsets[i])) if gait else 0
            lift = max(0, cos(tau * (t + offsets[i]))) if gait else 0
            upper = -strength * swing - .32 * death
            knee = (.24 if name == 'walk' else .38) * lift + .52 * death
            if i < 2:
                upper -= (.30 if name == 'stone_stomp' else .13) * max(strike, 0)
                knee += .15 * max(strike, 0)
            else:
                upper += .10 * strike
            put(pose, rig, 'thigh.' + suffix, rotation=(upper, 0, 0))
            put(pose, rig, 'shin.' + suffix, rotation=(knee, 0, 0))
            put(pose, rig, 'foot.' + suffix, rotation=(-upper - knee, 0, 0))
        fan = envelope(t) if name == 'tail_fan' else 0
        sweep = _strike(t) if name == 'tail_sweep' else 0
        for bone in tails:
            tokens = bone.split('.')
            segment = int(tokens[-1])
            index = int(tokens[1]) if fox else 1
            lag = sin(tau * t - segment * .45 - index * .31)
            sway = (.012 if stone else .022) * lag if name != 'death' else 0
            spread = (5 - index) / 4 if fox else 0
            put(pose, rig, bone, rotation=(.045 * death - .028 * fan,
                                          .012 * fan * spread,
                                          sway + (.07 * spread * fan + .09 * sweep) / segment))
        return pose

    specs = [('idle', 3.2, True, 'idle'), ('walk', 1.35 if stone else 1.1, True, 'locomotion'),
             ('trot', .92 if stone else .68, True, 'locomotion'),
             ('attack', 1.25 if stone else .85, False, 'attack'), ('hit', .48, False, 'hit'),
             ('death', 1.8, False, 'death'), (special, 1.6, False, 'special')]
    if fox:
        specs.append(('tail_sweep', 1.2, False, 'special'))
    return _clips(specs, pose_at)


def _flying(rig):
    insect = rig['family'] == 'insect'
    bat = 'Ember-Bat' in rig['file']
    h = rig['height']
    wings = [b for b in rig['bones'] if b.startswith('wing.')]
    special = 'illusion_flutter' if insect else 'ember_screech' if bat else 'gust_buffet'

    def pose_at(name, t):
        pose = {}
        death = _settle(t) if name == 'death' else 0
        strike = _strike(t) if name == 'attack' else 0
        hit = envelope(t) if name == 'hit' else 0
        spell = envelope(t) if name == special else 0
        cycles = 3 if insect else 2 if bat else 1
        wave = sin(tau * cycles * t)
        amplitude = {'idle': .07, 'idle_hover': .24, 'fly': .36, 'glide': .035,
                     'flutter': .19}.get(name, .12)
        put(pose, rig, 'hips', rotation=(.20 * strike + .22 * death, .10 * hit, 0),
            translation=(0, -.025 * h * max(strike, 0),
                         h * (-.055 * death + .008 * wave * (1 - death))))
        put(pose, rig, 'head', rotation=(.13 * strike - .18 * spell + .18 * death, 0, .09 * hit))
        for bone in wings:
            side = -1 if '.L' in bone else 1
            lag = .5 if bone.endswith('.02') else 0
            flap = amplitude * sin(tau * cycles * t - lag)
            flap = (flap + .18 * spell * cos(2 * tau * t)) * (1 - death)
            if name == special:
                if bat:
                    flap = -.24 * spell + .025 * wave
                elif insect:
                    flap = .28 * spell * sin(3 * tau * t - lag + side * .25)
                else:
                    flap = .36 * spell * sin(2 * tau * t)
            fold = flap + .48 * death + .14 * hit - .10 * max(strike, 0)
            rotation = (0, .04 * spell, side * fold) if insect else (
                0, side * fold, -side * .15 * max(strike, 0))
            put(pose, rig, bone, rotation=rotation)
        for bone in rig['bones']:
            if bone.startswith(('thigh.', 'shin.', 'foot.')):
                curl = .22 * max(strike, 0) + .28 * death + .08 * spell
                put(pose, rig, bone, rotation=(curl + .025 * wave * (1 - death), 0, 0))
        put(pose, rig, 'tail.01', rotation=(.10 * strike + .16 * death, .04 * spell, 0))
        return pose

    return _clips([('idle', 2.8, True, 'idle'), ('idle_hover', 1.4, True, 'idle'),
                   ('fly', .9 if insect or bat else 1.25, True, 'locomotion'),
                   ('flutter' if insect else 'glide', 1.8, True, 'locomotion'),
                   ('attack', 1.1, False, 'attack'), ('hit', .45, False, 'hit'),
                   ('death', 1.6, False, 'death'), (special, 1.7, False, 'special')], pose_at)


def _bell(rig):
    head = rig['bones']['part.bell_core']['head']
    pivot = rig['bones']['part.hang_shackle']['head']

    def pose_at(name, t):
        wave = sin(tau * t)
        angle = {'idle': .035, 'swing': .18}.get(name, 0) * wave
        if name == 'attack':
            angle = .26 * _strike(t)
        elif name == 'hit':
            angle = .10 * envelope(t) * sin(3 * tau * t)
        elif name == 'listen':
            angle = -.12 * envelope(t)
        elif name == 'toll_resonance':
            angle = .16 * envelope(t) * sin(2 * tau * t)
        elif name == 'death':
            angle = .24 * _settle(t)
        # Rotate about the saved suspension, compensating the low bell_core origin.
        dy, dz = head[1] - pivot[1], head[2] - pivot[2]
        delta = (0, (cos(angle) - 1) * dy - sin(angle) * dz,
                 sin(angle) * dy + (cos(angle) - 1) * dz)
        pose = {}
        put(pose, rig, 'part.bell_core', rotation=(angle, 0, 0), translation=delta)
        return pose

    return _clips([('idle', 3.8, True, 'idle'), ('swing', 2.2, True, 'locomotion'),
                   ('attack', 1.3, False, 'attack'), ('hit', .65, False, 'hit'),
                   ('death', 2.6, False, 'death'), ('listen', 2.1, False, 'special'),
                   ('toll_resonance', 2.8, False, 'special')], pose_at)


def _lotus(rig):
    petals = [b for b in rig['bones'] if b.startswith('part.petal_')]

    def pose_at(name, t):
        pose, wave = {}, sin(tau * t)
        progress = _settle(t)
        closure = {'open': .28 - .36 * progress, 'close': -.08 + .36 * progress,
                   'death': .34 * progress, 'hit': .11 * envelope(t)}.get(name, 0)
        pulse = envelope(t) * (1 + .3 * sin(3 * tau * t)) if name == 'pulse' else 0
        bloom = envelope(t) if name == 'rebirth_bloom' else 0
        for bone in petals:
            x, y, _ = rig['bones'][bone]['head']
            radius = max(hypot(x, y), 1e-8)
            layer = .72 if 'inner' in bone else .86 if 'mid' in bone else 1
            flutter = .025 * wave if name == 'idle' else 0
            if name == 'drift':
                flutter = .055 * sin(tau * t + int(bone.rsplit('_', 1)[1]) * .6)
            angle = layer * (closure + flutter - .12 * pulse - .17 * bloom)
            put(pose, rig, bone, rotation=(-y / radius * angle, x / radius * angle, 0))
        # The nested heart meshes translate together; incense and stem stay fixed.
        for bone in ('part.heart', 'part.heart_core'):
            put(pose, rig, bone, translation=(0, 0, rig['height'] * .004 * (pulse + bloom)))
        return pose

    return _clips([('idle', 3.2, True, 'idle'), ('drift', 2.4, True, 'locomotion'),
                   ('open', 1.8, False, 'special'), ('close', 1.5, False, 'special'),
                   ('pulse', 1.4, False, 'special'), ('hit', .5, False, 'hit'),
                   ('death', 2.2, False, 'death'), ('rebirth_bloom', 2.6, False, 'special')], pose_at)


def _torture(rig):
    def pose_at(name, t):
        pose, wave = {}, sin(tau * t)
        death = _settle(t) if name == 'death' else 0
        hit = envelope(t) if name == 'hit' else 0
        attack = _strike(t) if name in ('attack', 'chain_claw_attack') else 0
        door = {'door_open': -.72 * _settle(t), 'door_close': -.72 * (1 - _settle(t)),
                'death': -.48 * death}.get(name, -.18 * max(attack, 0) - .06 * hit)
        put(pose, rig, 'torture.door', local_rotation=(0, door, 0))
        for side, sign in (('L', -1), ('R', 1)):
            drag = .07 * wave * sign if name == 'chain_drag' else .016 * wave if name == 'idle' else 0
            reach = attack if name == 'chain_claw_attack' or side == 'R' else -.3 * attack
            put(pose, rig, 'torture.chain.' + side,
                rotation=(drag - .08 * hit, sign * .24 * death, -sign * .32 * reach))
            put(pose, rig, 'torture.claw.' + side,
                rotation=(-.26 * max(reach, 0) + .18 * death, sign * .08 * hit, 0))
        return pose

    return _clips([('idle', 3.3, True, 'idle'), ('chain_drag', 1.7, True, 'locomotion'),
                   ('attack', 1.1, False, 'attack'), ('hit', .6, False, 'hit'),
                   ('death', 2.1, False, 'death'), ('door_open', 1.3, False, 'special'),
                   ('door_close', .95, False, 'special'),
                   ('chain_claw_attack', 1.6, False, 'special')], pose_at)


def _lantern(rig):
    pendants = [b for b in rig['bones'] if b.startswith('lantern.') and b != 'lantern.hang']

    def pose_at(name, t):
        pose, wave = {}, sin(tau * t)
        death = _settle(t) if name == 'death' else 0
        spell = envelope(t) if name in ('pendant_spell', 'foxfire_burst') else 0
        strike = _strike(t) if name == 'attack' else 0
        hit = envelope(t) if name == 'hit' else 0
        sway = {'idle': .055, 'swing': .17}.get(name, 0) * wave
        put(pose, rig, 'lantern.hang', rotation=(sway + .16 * strike - .13 * hit + .18 * death, 0, 0))
        for i, bone in enumerate(pendants):
            lag = .045 * sin(tau * t - i * .4) if name in ('idle', 'swing') else 0
            cast = -.32 * spell if name == 'pendant_spell' and bone == 'lantern.pendant' else 0
            cast += .15 * spell * sin(2 * tau * t - i * .5) if name == 'foxfire_burst' else 0
            put(pose, rig, bone, rotation=(lag - .5 * sway - .18 * strike + cast + .20 * death,
                                          .07 * hit, 0))
        return pose

    return _clips([('idle', 3.2, True, 'idle'), ('swing', 1.9, True, 'locomotion'),
                   ('attack', 1, False, 'attack'), ('hit', .55, False, 'hit'),
                   ('death', 2.3, False, 'death'), ('pendant_spell', 1.8, False, 'special'),
                   ('foxfire_burst', 1.45, False, 'special')], pose_at)


def _furnace(rig):
    legs = [b for b in rig['bones'] if b.startswith('furnace.leg.')]

    def pose_at(name, t):
        pose, wave, h = {}, sin(tau * t), rig['height']
        death = _settle(t) if name == 'death' else 0
        strike = _strike(t) if name in ('attack', 'stomp') else 0
        steam = envelope(t) if name == 'lid_steam' else 0
        hit = envelope(t) if name == 'hit' else 0
        bob = .003 * (1 - cos(3 * tau * t)) if name == 'move' else 0
        put(pose, rig, 'body', rotation=(.035 * strike, .04 * hit, 0),
            translation=(0, 0, h * (bob - .018 * death)))
        lid = .001 * (1 - cos(tau * t)) if name == 'idle' else 0
        rattle = .018 * sin(2 * tau * t) if name == 'idle' else 0
        put(pose, rig, 'furnace.lid', rotation=(rattle + .06 * hit + .08 * death, 0, 0),
            translation=(0, 0, h * (lid + .04 * steam + .018 * max(strike, 0))))
        for i, bone in enumerate(legs):
            step = .13 * sin(tau * t + i * tau / 3) if name == 'move' else 0
            stamp = .24 * strike if name == 'stomp' else .05 * strike
            x, y, _ = rig['bones'][bone]['head']
            radius = max(hypot(x, y), 1e-8)
            spread = .25 * death + stamp
            put(pose, rig, bone, rotation=(step - y / radius * spread, x / radius * spread, 0))
        return pose

    return _clips([('idle', 2.8, True, 'idle'), ('move', 1.6, True, 'locomotion'),
                   ('attack', 1.25, False, 'attack'), ('hit', .65, False, 'hit'),
                   ('death', 2.4, False, 'death'), ('lid_steam', 2, False, 'special'),
                   ('stomp', 1.45, False, 'special')], pose_at)


def _book(rig):
    def pose_at(name, t):
        pose, wave = {}, sin(tau * t)
        death = _settle(t) if name == 'death' else 0
        hit = envelope(t) if name == 'hit' else 0
        attack = _strike(t) if name == 'attack' else 0
        cast = envelope(t) if name == 'cast' else 0
        opening = {'cover_open': .38 * (1 - _settle(t)),
                   'cover_close': .38 * _settle(t)}.get(name, 0)
        put(pose, rig, 'book.spine', rotation=(.22 * attack + .30 * death, .12 * hit, 0),
            translation=(0, 0, -rig['height'] * .045 * death))
        for side, sign in (('L', -1), ('R', 1)):
            flap = {'idle': .025, 'flutter': .16}.get(name, 0) * wave
            put(pose, rig, 'book.cover.' + side,
                local_rotation=(0, sign * (opening + flap + .38 * death - .12 * cast + .12 * attack), 0))
            for i in range(5):
                ripple = .02 * sin(tau * t - i * .4) if name in ('idle', 'flutter') else 0
                if name == 'page_flip':
                    turn = max(0, min(1, (t - i * .11) / .5))
                    ripple += .58 * envelope(turn)
                ripple += .17 * cast * sin(tau * t - i * .6) + .12 * death + .08 * hit
                put(pose, rig, 'book.page.' + side + '.' + str(i),
                    local_rotation=(0, sign * ripple, 0))
        return pose

    return _clips([('idle', 2.6, True, 'idle'), ('flutter', 1.2, True, 'locomotion'),
                   ('attack', .9, False, 'attack'), ('hit', .45, False, 'hit'),
                   ('death', 1.7, False, 'death'), ('cover_open', 1.3, False, 'special'),
                   ('cover_close', 1.1, False, 'special'), ('page_flip', 1.8, False, 'special'),
                   ('cast', 2.1, False, 'special')], pose_at)


def build_actions(rig):
    """Return original clips for supported live rig families, otherwise []."""
    family = rig.get('family')
    if family == 'quadruped':
        return _quadruped(rig)
    if family in ('bird', 'insect'):
        return _flying(rig)
    if family == 'mechanism':
        for joint, author in (('part.bell_core', _bell), ('part.petal_outer_0', _lotus),
                              ('torture.door', _torture), ('lantern.hang', _lantern),
                              ('furnace.lid', _furnace), ('book.spine', _book)):
            if joint in rig['bones']:
                return author(rig)
    return []
