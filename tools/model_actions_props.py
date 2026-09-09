"""Original action recipes for the 26 source-backed prop-family rigs.

Only pose data is authored here. No scene, rig, material, or mesh is modified.
Run with python -B for the read-only report contract, not a visual-quality test.
"""
import math

from model_action_common import curve, envelope, put, sampled_action


_TAU = math.tau


def _put(pose, rig, bone, **channels):
    if not put(pose, rig, bone, **channels):
        raise ValueError(rig['file'] + ': missing action joint ' + bone)


def _ramp(t, start=0.0, end=1.0):
    x = max(0.0, min(1.0, (t - start) / (end - start)))
    return x * x * (3.0 - 2.0 * x)


def _vector(t, knots):
    return tuple(curve(t, [(time, value[i]) for time, value in knots])
                 for i in range(3))


def _about(pose, rig, bone, pivot, rotation=(0, 0, 0), offset=(0, 0, 0)):
    # Compensate source group origins without changing the frozen rest skeleton.
    x, y, z = (pivot[i] - rig['bones'][bone]['head'][i] for i in range(3))
    rx, ry, rz = rotation
    y, z = y * math.cos(rx) - z * math.sin(rx), y * math.sin(rx) + z * math.cos(rx)
    x, z = x * math.cos(ry) + z * math.sin(ry), -x * math.sin(ry) + z * math.cos(ry)
    x, y = x * math.cos(rz) - y * math.sin(rz), x * math.sin(rz) + y * math.cos(rz)
    translation = [pivot[i] - rig['bones'][bone]['head'][i] - v + offset[i]
                   for i, v in enumerate((x, y, z))]
    _put(pose, rig, bone, rotation=rotation, translation=translation)


def _soft(pose, rig, prefix, t, amplitude, cycles=1, drive=0):
    for bone in sorted(n for n in rig['bones'] if n.startswith(prefix)):
        index = int(bone.rsplit('.', 1)[-1])
        phase = _TAU * cycles * t - .48 * index
        _put(pose, rig, bone, rotation=(
            amplitude * (.6 + .2 * index) * math.sin(phase) + drive / (index + 1),
            amplitude * .45 * math.sin(phase + .7), 0))


def _clip(name, duration, loop, pose_at, kind, event=None):
    events = {event[0]: duration * event[1]} if event else None
    return sampled_action(name, duration, loop, pose_at, kind, steps=64, events=events)


def _bow_actions(rig):
    size = rig['size']
    sun = '05-Sun-' in rig['file']

    def drawn(amount):
        pose = {}
        # The source limbs and string lie in X/Z, so draw toward +X, not out of plane.
        _put(pose, rig, 'bow.draw', translation=(size * .15 * amount, 0, 0))
        for side, sign, gain in [('up', 1, .68), ('dn', -1, 1.0)]:
            for index, angle in enumerate((.065, .085, .105), 1):
                _put(pose, rig, 'bow.%s.%02d' % (side, index),
                     rotation=(0, sign * gain * angle * amount, 0))
        return pose

    def idle(t):
        return drawn(.018 * envelope(t))

    def draw(t):
        return drawn(_ramp(t, .04, .8))

    def release(t):
        return drawn(curve(t, [(0, 1), (.08, 1), (.17, -.12), (.28, .065),
                               (.43, -.025), (.65, .008), (1, 0)]))

    def power(t):
        amount = curve(t, [(0, 0), (.22, .55), (.47, 1.3 if sun else 1.18),
                           (.62, 1.3 if sun else 1.18), (.69, -.16),
                           (.77, .08), (.86, -.025), (1, 0)])
        pose = drawn(amount)
        recoil = curve(t, [(0, 0), (.63, 0), (.7, 1), (.85, .2), (1, 0)])
        _put(pose, rig, 'body', rotation=(0, -.025 * recoil, 0),
             translation=(-.008 * size * recoil, 0, 0))
        return pose

    return [_clip('idle', 3.4 if sun else 2.8, True, idle, 'idle'),
            _clip('draw', 1.45 if sun else 1.05, False, draw, 'draw', ('drawn', .8)),
            _clip('release', .7, False, release, 'attack', ('release', .08)),
            _clip('power_shot', 2.2 if sun else 1.7, False, power, 'attack', ('release', .62))]


def _weapon_pose(rig, bone, t, mode, heft=1.0, soft_prefix=None):
    size = rig['size']
    pose = {}
    paths = {
        'slash': [(0, (0, 0, 0)), (.25, (-.2, -.65, -.12)),
                  (.38, (-.22, -.72, -.12)), (.54, (.95, .65, .22)),
                  (.68, (1.1, .78, .25)), (1, (0, 0, 0))],
        'thrust': [(0, (0, 0, 0)), (.27, (1.25, -.12, 0)),
                   (.48, (math.pi / 2, 0, 0)), (.63, (math.pi / 2, 0, 0)),
                   (1, (0, 0, 0))],
        'parry': [(0, (0, 0, 0)), (.2, (.15, .9, .12)),
                  (.45, (.2, 1.02, .1)), (.54, (.05, .86, .08)),
                  (.72, (.15, .95, .1)), (1, (0, 0, 0))],
        'heavy': [(0, (0, 0, 0)), (.32, (-.68, -.1, 0)),
                  (.49, (-.75, -.1, 0)), (.62, (1.85, .1, 0)),
                  (.73, (1.9, .13, 0)), (.9, (.65, .03, 0)), (1, (0, 0, 0))],
        'sweep': [(0, (0, 0, 0)), (.26, (1.1, -.25, -.65)),
                  (.44, (1.4, -.1, -.7)), (.65, (1.4, .1, .8)),
                  (.79, (1.1, .2, .9)), (1, (0, 0, 0))],
    }
    rotation = _vector(t, paths[mode])
    push = curve(t, [(0, 0), (.32, -.12), (.52 if mode == 'thrust' else .62, 1),
                     (.73, .85), (1, 0)])
    reach = .24 if mode == 'thrust' else .07 if mode == 'parry' else .12
    _put(pose, rig, bone, rotation=rotation,
         translation=(0, -size * reach * push, size * .018 * envelope(t)))
    if soft_prefix:
        _soft(pose, rig, soft_prefix, t, .13 * heft * envelope(t), 2,
              -.18 * push * envelope(t))
    return pose


def _sword_actions(rig):
    filename = rig['file']
    star = '08-XuanXiao' in filename
    gate = '10-JuQue' in filename
    heft = 1.0 if star else 1.55 if gate else 1.35
    prefix = 'sword.'

    def idle(t):
        pose = {}
        _put(pose, rig, 'body', rotation=(.012 * math.sin(_TAU * t),
                                         .008 * math.sin(_TAU * t), 0))
        _soft(pose, rig, prefix, t, .035)
        return pose

    def special(t):
        if gate:
            pose = _weapon_pose(rig, 'body', t, 'parry', heft, prefix)
            push = curve(t, [(0, 0), (.3, -.1), (.53, 1), (.65, 1), (1, 0)])
            _put(pose, rig, 'body', translation=(0, -rig['size'] * .19 * push, 0))
        elif star:
            pose = {}
            rotation = _vector(t, [(0, (0, 0, 0)), (.3, (-.35, -.4, -.5)),
                                   (.48, (.5, .2, 1.0)), (.66, (1.45, 0, .1)),
                                   (.79, (1.6, 0, 0)), (1, (0, 0, 0))])
            _put(pose, rig, 'body', rotation=rotation,
                 translation=(0, -.2 * rig['size'] * envelope(t),
                              .08 * rig['size'] * envelope(t)))
            _soft(pose, rig, prefix, t, .2 * envelope(t), 2)
        else:
            pose = _weapon_pose(rig, 'body', t, 'sweep', heft)
        return pose

    actions = [_clip('idle', 3.2, True, idle, 'idle')]
    for mode, duration in [('slash', .95), ('thrust', 1.05), ('parry', .8), ('heavy', 1.4)]:
        actions.append(_clip(mode, duration * heft, False,
                             lambda t, m=mode: _weapon_pose(rig, 'body', t, m, heft, prefix),
                             'defense' if mode == 'parry' else 'attack'))
    name = 'starfall_cast' if star else 'gate_bash' if gate else 'end_of_stars_sweep'
    actions.append(_clip(name, 1.65 * heft, False, special, 'attack'))
    return actions


def _axe_actions(rig):
    strong = '07-XingTian' in rig['file']

    def idle(t):
        pose = {}
        for side in ('left', 'right'):
            _soft(pose, rig, 'axe_' + side + '.', t, .045, 1)
        return pose

    def strike(t, sides, mode):
        pose = {}
        for side in sides:
            sign = -1 if side == 'left' else 1
            bone = 'part.axe_' + side
            # Crossed blades pass at different depths; each still turns at its own grip.
            u = max(0, min(1, (t - (.055 if side == 'right' and mode == 'cross' else 0)) /
                           (.945 if mode == 'cross' else 1)))
            if mode == 'heavy':
                pose.update(_weapon_pose(rig, bone, u, 'heavy'))
            elif mode == 'parry':
                q = envelope(u)
                _put(pose, rig, bone, rotation=(.16 * q, -sign * .75 * q, 0),
                     translation=(0, -.04 * rig['size'] * q, 0))
            else:
                swing = curve(u, [(0, 0), (.27, -.6), (.4, -.68), (.56, .85),
                                   (.73, .92), (1, 0)])
                _put(pose, rig, bone, rotation=(.62 * envelope(u), -sign * swing,
                                              sign * .12 * envelope(u)),
                     translation=(0, -(.1 + sign * .035) * rig['size'] * envelope(u), 0))
            _soft(pose, rig, 'axe_' + side + '.', u, .2 * envelope(u), 2,
                  -.22 * envelope(u))
        return pose

    actions = [_clip('idle', 3.2, True, idle, 'idle')]
    for name, sides, mode, duration in [
            ('left_strike', ('left',), 'single', 1.0),
            ('right_strike', ('right',), 'single', 1.05),
            ('cross_strike', ('left', 'right'), 'cross', 1.4),
            ('cross_parry', ('left', 'right'), 'parry', 1.1),
            ('indomitable_slam' if strong else 'twin_slam', ('left', 'right'), 'heavy', 1.65)]:
        actions.append(_clip(name, duration * (1.2 if strong else 1), False,
                             lambda t, s=sides, m=mode: strike(t, s, m),
                             'defense' if mode == 'parry' else 'attack'))
    return actions


def _seal_actions(rig):
    size = rig['size']
    five = '06-Five' in rig['file']

    def pose_at(t, mode):
        pose = {}
        if mode == 'idle':
            q = envelope(t)
            rotation, offset = (0, 0, .04 * math.sin(_TAU * t)), (0, 0, .015 * size * q)
            flutter = .04
        elif mode == 'orbit':
            a = _TAU * t
            rotation = (.12 * math.sin(a), .08 * math.sin(2 * a), .24 * math.sin(a))
            offset = (.08 * size * (math.cos(a) - 1), .08 * size * math.sin(a),
                      .035 * size * envelope(t))
            flutter = .09
        elif mode == 'charge':
            q = _ramp(t, .05, .85)
            rotation, offset = (-.22 * q, 0, (.38 if five else -.25) * q), (0, 0, .14 * size * q)
            flutter = .14 * envelope(t) if t < 1 else 0
        else:
            q = curve(t, [(0, 0), (.28, -.2), (.48, 1), (.6, 1), (1, 0)])
            raised = 1 - _ramp(t, .62, 1)
            rotation = (-.22 * raised + .87 * q, (.18 if five else -.18) * envelope(t),
                        (.38 if five else -.25) * raised - .25 * q)
            offset = (0, -.24 * size * q, .14 * size * raised + .03 * size * envelope(t))
            flutter = .24 * envelope(t)
        _put(pose, rig, 'body', rotation=rotation, translation=offset)
        _soft(pose, rig, 'seal.', t, flutter, 2 if mode in ('charge', 'cast') else 1)
        return pose

    return [_clip(mode, duration, mode in ('idle', 'orbit'),
                  lambda t, m=mode: pose_at(t, m), 'idle' if mode == 'idle' else 'cast')
            for mode, duration in [('idle', 3.6), ('charge', 1.6), ('cast', 1.1), ('orbit', 4.2)]]


def _bead_actions(rig):
    def pose_at(t, mode):
        pose = {}
        amplitude = {'idle': .035, 'swing': .19, 'invoke': .095, 'settle': .11}[mode]
        if mode == 'invoke':
            weight = envelope(t)
            _put(pose, rig, 'body', translation=(0, -.055 * rig['size'] * weight,
                                               .095 * rig['size'] * weight))
        elif mode == 'settle':
            weight = (1 - t) ** 2
        else:
            weight = 1
        # Both strands use the same row transform; cumulative bends stay small.
        for i in range(12):
            a = _TAU * (2 if mode == 'settle' else 1) * t - i * .16
            gain = 1 if i == 0 else .13
            _put(pose, rig, 'beads.row.%02d' % i,
                 rotation=(amplitude * gain * weight * math.sin(a),
                           amplitude * gain * .6 * weight * math.sin(a + .8), 0))
        _soft(pose, rig, 'beads.tassel.', t, amplitude * weight, 2)
        _soft(pose, rig, 'beads.paper.', t, amplitude * weight * 1.3, 2)
        return pose

    return [_clip(mode, duration, mode in ('idle', 'swing'),
                  lambda t, m=mode: pose_at(t, m),
                  'cast' if mode == 'invoke' else 'idle' if mode == 'idle' else 'secondary')
            for mode, duration in [('idle', 3.4), ('swing', 2.2), ('invoke', 1.9), ('settle', 1.6)]]


def _fan_actions(rig):
    def pose_at(t, mode):
        pose = {}
        if mode == 'idle':
            rotation = (.025 * math.sin(_TAU * t), 0, 0)
            flutter = .05
        elif mode == 'flourish':
            rotation = _vector(t, [(0, (0, 0, 0)), (.24, (-.25, -.25, -.6)),
                                   (.48, (.2, .7, .85)), (.7, (.5, -.3, .2)), (1, (0, 0, 0))])
            flutter = .2 * envelope(t)
        elif mode == 'cast':
            rotation = _vector(t, [(0, (0, 0, 0)), (.28, (-.45, -.2, -.35)),
                                   (.48, (.95, .1, .3)), (.65, (1.05, .1, .35)), (1, (0, 0, 0))])
            flutter = .25 * envelope(t)
        else:
            rotation = (.12 * envelope(t), .85 * envelope(t), .12 * envelope(t))
            flutter = .12 * envelope(t)
        # Fan face and ribs remain one open rigid unit. The rig does not support folding.
        _put(pose, rig, 'body', rotation=rotation,
             translation=(0, -.1 * rig['size'] * envelope(t) if mode == 'cast' else 0, 0))
        _soft(pose, rig, 'fan.', t, flutter, 2 if mode == 'cast' else 1)
        return pose

    return [_clip(mode, duration, mode == 'idle', lambda t, m=mode: pose_at(t, m),
                  'idle' if mode == 'idle' else 'cast' if mode == 'cast' else 'gesture')
            for mode, duration in [('idle', 3.5), ('flourish', 1.65), ('cast', 1.2), ('parry', .95)]]


def _weapon_collection(rig):
    template = rig['file'].endswith('/templateweapons.glb')

    def idle(t):
        pose = {}
        if template:
            _put(pose, rig, 'part.Torch', rotation=(.025 * math.sin(_TAU * t), 0, 0))
        else:
            _soft(pose, rig, 'spear.tassel.', t, .055)
        return pose

    actions = [_clip('idle', 3.2, True, idle, 'idle')]
    if template:
        entries = [('sword_slash', 'part.Sword', 'slash'), ('sword_thrust', 'part.Sword', 'thrust'),
                   ('axe_chop', 'part.Ax', 'heavy'), ('shield_parry', 'part.Shield', 'parry'),
                   ('shield_bash', 'part.Shield', 'bash'), ('torch_raise', 'part.Torch', 'raise')]
    else:
        entries = [('sword_slash', 'part.straight_sword', 'slash'),
                   ('sword_parry', 'part.straight_sword', 'parry'),
                   ('spear_thrust', 'part.spear', 'thrust'), ('spear_sweep', 'part.spear', 'sweep'),
                   ('hammer_slam', 'part.war_hammer', 'heavy'),
                   ('hammer_parry', 'part.war_hammer', 'parry')]

    def pose_at(t, bone, mode):
        if mode not in ('bash', 'raise'):
            return _weapon_pose(rig, bone, t, mode,
                                soft_prefix='spear.tassel.' if bone == 'part.spear' else None)
        pose = {}
        q = curve(t, [(0, 0), (.25, -.1), (.5, 1), (.7, 1), (1, 0)])
        if mode == 'bash':
            _put(pose, rig, bone, rotation=(.1 * q, 0, .1 * q),
                 translation=(0, -.22 * rig['size'] * q, .03 * rig['size'] * envelope(t)))
        else:
            _put(pose, rig, bone, rotation=(.18 * envelope(t), -.15 * envelope(t), 0),
                 translation=(0, -.08 * rig['size'] * envelope(t), .26 * rig['size'] * max(0, q)))
        return pose

    for name, bone, mode in entries:
        actions.append(_clip(name, 1.55 if mode in ('heavy', 'raise') else 1.15, False,
                             lambda t, b=bone, m=mode: pose_at(t, b, m),
                             'gesture' if mode == 'raise' else 'defense' if mode == 'parry' else 'attack'))
    return actions


def _armor_actions(rig):
    light = '01-LightArmor' in rig['file']
    heavy = '03-HeavyArmor' in rig['file']

    def pose_at(t, mode):
        pose = {}
        if mode == 'idle_cloth':
            q = .12 * math.sin(_TAU * t)
            flutter = .045 if light else .025
        elif mode == 'brace':
            q = curve(t, [(0, 0), (.28, .85), (.7, 1), (1, 0)])
            flutter = .09 * envelope(t)
        elif mode == 'hit_reaction':
            q = curve(t, [(0, 0), (.15, -1), (.3, .45), (.48, -.2), (.7, .07), (1, 0)])
            flutter = .16 * envelope(t)
        else:
            q = math.cos(_TAU * 2 * t) * (1 - t) ** 3
            flutter = .1 * (1 - t) ** 2
        if light:
            _soft(pose, rig, 'armor.cloak.', t, flutter, 1, .15 * q)
            _soft(pose, rig, 'armor.fur_drape_', t, flutter * .65, 1, .08 * q)
        else:
            for side, sign in [('L', -1), ('R', 1)]:
                reaction = q * (1 if side == 'L' or mode != 'hit_reaction' else .45)
                _put(pose, rig, 'armor.pauldron.' + side,
                     rotation=(-.08 * reaction, -sign * (.13 if heavy else .18) * reaction, 0))
            if heavy:
                _soft(pose, rig, 'armor.strap.', t, flutter, 1, .12 * q)
                for i in range(3):
                    _put(pose, rig, 'armor.tasset.%02d' % i,
                         local_rotation=(0, .14 * q * (1 if i == 1 else .8), 0))
        return pose

    return [_clip(mode, duration, mode == 'idle_cloth', lambda t, m=mode: pose_at(t, m),
                  'idle' if mode == 'idle_cloth' else 'reaction')
            for mode, duration in [('idle_cloth', 3.6), ('brace', 1.15), ('hit_reaction', .8), ('settle', 1.7)]]


def _accessory_actions(rig):
    def pose_at(t, mode):
        pose = {}
        for index, group in enumerate(('jade_pendant', 'war_talisman', 'charm_bag')):
            amount = .07 if mode == 'idle' else .18 if mode == 'pendant_swing' else .12 * envelope(t)
            drive = (.22 if group == 'charm_bag' else .12) * envelope(t) if mode == 'charm_activation' else 0
            _soft(pose, rig, group + '.cord.', t + index * .08, amount, 1, drive)
        flutter = .06 if mode == 'idle' else .16
        if mode == 'charm_activation':
            flutter *= envelope(t)
        _soft(pose, rig, 'jade_pendant.tassel.', t, flutter, 2)
        if mode == 'charm_activation':
            _about(pose, rig, 'part.samsaraStone', (0, 0, 1.05),
                   rotation=(0, 0, .6 * envelope(t)), offset=(0, 0, .035 * envelope(t)))
        return pose

    return [_clip(mode, duration, mode != 'charm_activation', lambda t, m=mode: pose_at(t, m),
                  'cast' if mode == 'charm_activation' else 'idle' if mode == 'idle' else 'secondary')
            for mode, duration in [('idle', 3.8), ('pendant_swing', 2.4), ('charm_activation', 1.7)]]


def _vessel_actions(rig):
    entries = [('core_attune', 'part.furnaceCore', -.85, .55),
               ('wish_invoke', 'part.xuanxiaoWish', 0, -.75),
               ('scale_resonate', 'part.zhuyinScale', .85, .95)]

    def pose_at(t, selected=None):
        pose = {}
        for index, (_, bone, x, angle) in enumerate(entries):
            if selected is not None and selected != bone:
                continue
            # The socket and pedestal share each vessel joint: keep its base center anchored.
            q = envelope(t) if selected else .045 * math.sin(_TAU * t + index * .6)
            _about(pose, rig, bone, (x, 0, .12), rotation=(0, 0, angle * q))
        return pose

    actions = [_clip('idle', 4.8, True, pose_at, 'idle')]
    for name, bone, _, _ in entries:
        actions.append(_clip(name, 2.2, False, lambda t, b=bone: pose_at(t, b), 'cast'))
    return actions


def _shrine_actions(rig):
    def pose_at(t, mode):
        pose = {}
        if mode == 'idle':
            angle, rise = .018 * math.sin(_TAU * t), 0
        elif mode == 'incense_activation':
            angle = .13 * envelope(t)
            rise = .035 * envelope(t)
        else:
            angle = .09 * math.sin(_TAU * 2 * t) * (1 - t) ** 3
            rise = .035 * (1 - _ramp(t, 0, .8))
        # The complete incense assembly is the only joint separate from shrine masonry.
        _about(pose, rig, 'part.incenseBurner', (.5, 0, .41),
               rotation=(0, 0, angle), offset=(0, 0, rise))
        return pose

    return [_clip(mode, duration, mode == 'idle', lambda t, m=mode: pose_at(t, m),
                  'idle' if mode == 'idle' else 'interact')
            for mode, duration in [('idle', 4.6), ('incense_activation', 2.3), ('offering_settle', 1.5)]]


def _echo_actions(rig):
    def pose_at(t, mode):
        pose = {}
        if mode == 'orbit':
            # Sinusoidal yaw plus circular translation closes numerically as well as visually.
            angle = .8 * math.sin(_TAU * t)
            offset = (.05 * (math.cos(_TAU * t) - 1), .05 * math.sin(_TAU * t), .03 * envelope(t))
        elif mode == 'pickup':
            q = _ramp(t, .15, .95)
            angle, offset = 2.8 * q, (0, -.35 * q, .5 * q)
        else:
            q = envelope(t)
            angle, offset = -.6 * q, (0, 0, .12 * q)
        _about(pose, rig, 'part.emberSpiral', (0, 0, 1.2), rotation=(0, 0, angle), offset=offset)
        if mode == 'pickup':
            _about(pose, rig, 'part.ironCage', (0, 0, 1.28),
                   rotation=(0, 0, -.25 * envelope(t)), offset=(0, 0, .08 * envelope(t)))
        # echoCore is weighted to body with scorchDisc. Never move body to fake collection.
        return pose

    return [_clip(mode, duration, mode == 'orbit', lambda t, m=mode: pose_at(t, m),
                  'pickup' if mode == 'pickup' else 'ambient')
            for mode, duration in [('orbit', 4.2), ('pickup', 1.3), ('resonate', 1.8)]]


def _forge_actions(rig):
    def bellows(t, strong=True):
        pose = {}
        q = curve(t, [(0, 0), (.18, .15), (.4, 1), (.53, 1), (.82, .15), (1, 0)])
        compression = (.09 if strong else .025) * q
        # Local Y is vertical here. Anchor compression at the source nozzle center Z=.26.
        head_z = rig['bones']['part.bellows']['head'][2]
        _put(pose, rig, 'part.bellows', scale=(1, 1 - compression, 1),
             translation=(0, 0, (.26 - head_z) * compression))
        return pose

    def door(t, closing=False):
        pose = {}
        q = _ramp(t, .08, .88)
        _put(pose, rig, 'forge.door', local_rotation=(0, .95 * (1 - q if closing else q), 0))
        return pose

    return [_clip('idle', 3.2, True, lambda t: bellows(t, False), 'idle'),
            _clip('bellows_pump', 1.45, True, bellows, 'interact'),
            _clip('door_open', 1.15, False, door, 'interact'),
            _clip('door_close', .95, False, lambda t: door(t, True), 'interact')]


def _trap_actions(rig):
    travel = rig['size'] * .12
    radius = rig['size'] * (.1 / 4.6)

    def plate(t, releasing=False):
        pose = {}
        q = _ramp(t, .1, .75)
        _put(pose, rig, 'trap.pressure_top', translation=(0, 0, -.014 * (1 - q if releasing else q)))
        return pose

    def gate(t, dropping=False):
        pose = {}
        q = 1 - _ramp(t, .18, .47) if dropping else _ramp(t, .08, .9)
        lift = travel * q
        _put(pose, rig, 'trap.gate_slab', translation=(0, 0, lift))
        _put(pose, rig, 'trap.pulley', local_rotation=(0, -lift / radius, 0))
        return pose

    return [_clip('depress', .45, False, plate, 'interact', ('trigger', .75)),
            _clip('plate_release', .65, False, lambda t: plate(t, True), 'interact'),
            _clip('gate_open', 2.0, False, gate, 'interact'),
            _clip('gate_drop', .8, False, lambda t: gate(t, True), 'interact', ('impact', .47))]


def _puzzle_actions(rig):
    def mirror(t):
        pose = {}
        _put(pose, rig, 'puzzle.mirror', local_rotation=(0, math.pi / 3 * _ramp(t, .1, .85), 0))
        return pose

    def dial(t):
        pose = {}
        _put(pose, rig, 'puzzle.pointer', local_rotation=(0, math.pi / 6 * _ramp(t, .1, .55), 0))
        _put(pose, rig, 'puzzle.pointer2', local_rotation=(0, -math.pi / 3 * _ramp(t, .4, .9), 0))
        return pose

    def lid(t, closing=False):
        pose = {}
        u = 1 - t if closing else t
        lift = .18 * _ramp(u, .08, .4)
        slide = .15 * _ramp(u, .4, .85)
        _put(pose, rig, 'puzzle.cauldron_lid', translation=(slide, 0, lift))
        return pose

    return [_clip('mirror_turn', 1.5, False, mirror, 'interact'),
            _clip('dial_align', 1.8, False, dial, 'interact'),
            _clip('lid_open', 1.2, False, lid, 'interact'),
            _clip('lid_close', 1.3, False, lambda t: lid(t, True), 'interact')]


def _ambient_actions(rig):
    def breeze(t, gust=False, vine_only=False):
        pose = {}
        if not vine_only:
            amount = .18 if gust else .055
            _put(pose, rig, 'ambient.lantern', rotation=(amount * math.sin(_TAU * t),
                                                      amount * .3 * math.sin(2 * _TAU * t), 0))
            _soft(pose, rig, 'ambient.tassel.flex.', t, amount * .7, 2)
        if vine_only or not gust:
            _soft(pose, rig, 'ambient.vine.', t, .12 if vine_only else .025)
        return pose

    def coffin(t, closing=False):
        pose = {}
        u = 1 - t if closing else t
        _put(pose, rig, 'ambient.coffin_lid',
             translation=(0, .65 * _ramp(u, .28, .92), .1 * _ramp(u, .05, .28)))
        return pose

    return [_clip('idle', 4.2, True, breeze, 'idle'),
            _clip('lantern_swing', 2.6, True, lambda t: breeze(t, True), 'ambient'),
            _clip('vine_stir', 3.1, True, lambda t: breeze(t, False, True), 'ambient'),
            _clip('coffin_open', 2.3, False, coffin, 'interact'),
            _clip('coffin_close', 2.0, False, lambda t: coffin(t, True), 'interact')]


def _pickup_actions(rig):
    def collect(t, selected=None):
        pose = {}
        owners = [selected] if selected else ['part.ember', 'part.pillJar', 'part.warHorn', 'part.keyItems']
        for index, bone in enumerate(owners):
            u = _ramp(t, .08 + .04 * index, .78 + .04 * index)
            # Positive scale leaves final hiding/removal to the consuming game.
            _put(pose, rig, bone, translation=(0, -.18 * rig['size'] * u, .27 * rig['size'] * u),
                 scale=(1 - .7 * u,) * 3)
        return pose

    def idle(t):
        pose = {}
        _about(pose, rig, 'part.ember', (-.6, 0, .2),
               rotation=(0, 0, .18 * math.sin(_TAU * t)), offset=(0, 0, .02 * envelope(t)))
        return pose

    def cork(t, closing=False):
        pose = {}
        u = 1 - t if closing else t
        _put(pose, rig, 'pickup.cork', rotation=(0, 0, .6 * _ramp(u, .03, .35)),
             translation=(.1 * _ramp(u, .5, .9), 0, .16 * _ramp(u, .22, .55)))
        return pose

    actions = [_clip('idle', 3.8, True, idle, 'idle'),
               _clip('collect', 1.15, False, collect, 'pickup', ('collected', .95))]
    for item in ('stone', 'hammer', 'jade'):
        actions.append(_clip(item + '_collect', .95, False,
                             lambda t, b='pickup.' + item: collect(t, b), 'pickup', ('collected', .9)))
    actions.extend([_clip('cork_open', 1.0, False, cork, 'interact'),
                    _clip('cork_close', 1.05, False, lambda t: cork(t, True), 'interact')])
    return actions


def _tea_actions(rig):
    lifted = (0, -.12, .22)

    def pose_at(t, mode):
        pose = {}
        if mode == 'idle':
            rotation, offset = (0, 0, .012 * math.sin(_TAU * t)), (0, 0, 0)
        elif mode == 'cup_pour':
            tilt = curve(t, [(0, 0), (.18, .12), (.38, .72), (.68, .72), (.86, .12), (1, 0)])
            rotation, offset = (tilt, 0, 0), lifted
        else:
            q = _ramp(t, .08, .9)
            if mode == 'cup_setdown':
                q = 1 - q
            rotation, offset = (0, 0, 0), tuple(v * q for v in lifted)
        # Saucer, spoon and steam share teaCup; do not imply independent fluid or utensil motion.
        _about(pose, rig, 'part.teaCup', (0, 0, .7), rotation=rotation, offset=offset)
        return pose

    return [_clip(mode, duration, mode == 'idle', lambda t, m=mode: pose_at(t, m),
                  'idle' if mode == 'idle' else 'interact')
            for mode, duration in [('idle', 4.5), ('cup_lift', 1.1), ('cup_pour', 2.0), ('cup_setdown', 1.4)]]


_ROUTES = {
    'weapons/01-WindHunter-Bow.glb': _bow_actions,
    'weapons/02-XingTian-Twin-Axes.glb': _axe_actions,
    'weapons/03-Mystic-Gate-Seal.glb': _seal_actions,
    'weapons/04-Sandalwood-Beads-Talisman.glb': _bead_actions,
    'weapons/05-Sun-Falling-Bow.glb': _bow_actions,
    'weapons/06-Five-Elements-Seal.glb': _seal_actions,
    'weapons/07-XingTian-Indomitable.glb': _axe_actions,
    'weapons/08-XuanXiao-Falling-Star.glb': _sword_actions,
    'weapons/09-ZhuYin-The-End.glb': _sword_actions,
    'weapons/10-JuQue-Gatekeeper.glb': _sword_actions,
    'weapons/11-NineTails-Illusion-Moon.glb': _fan_actions,
    'weapons/12-Weapon-Types.glb': _weapon_collection,
    'weapons/templateweapons.glb': _weapon_collection,
    'equipment/01-LightArmor.glb': _armor_actions,
    'equipment/02-MediumArmor.glb': _armor_actions,
    'equipment/03-HeavyArmor.glb': _armor_actions,
    'equipment/04-Accessories.glb': _accessory_actions,
    'equipment/05-SoulVessels.glb': _vessel_actions,
    'props/01-EmberShrine.glb': _shrine_actions,
    'props/02-LostEcho.glb': _echo_actions,
    'props/03-ForgeAndAnvil.glb': _forge_actions,
    'props/04-Traps.glb': _trap_actions,
    'props/05-PuzzleProps.glb': _puzzle_actions,
    'props/06-AmbientProps.glb': _ambient_actions,
    'props/07-Pickups.glb': _pickup_actions,
    'props/08-BridgeTea.glb': _tea_actions,
}


def build_actions(rig):
    """Return sampled common-API clips for a prop rig; other families are unowned."""
    if rig['family'] != 'prop':
        return []
    route = _ROUTES.get(rig['file'])
    if route is None:
        raise ValueError('No authored prop actions: ' + rig['file'])
    if not math.isfinite(rig['size']) or rig['size'] <= 0:
        raise ValueError('Invalid prop size: ' + rig['file'])
    return route(rig)


def _read_glb(path):
    import json
    import struct

    data = path.read_bytes()
    magic, version, length = struct.unpack_from('<3I', data)
    assert magic == 0x46546c67 and version == 2 and length == len(data), str(path)
    chunks = {}
    cursor = 12
    while cursor < length:
        size, kind = struct.unpack_from('<2I', data, cursor)
        cursor += 8
        assert cursor + size <= length, str(path)
        chunks[kind] = data[cursor:cursor + size]
        cursor += size
    return json.loads(chunks[0x4e4f534a]), chunks.get(0x004e4942, b'')


def _weighted_joints(path, expected):
    import struct

    doc, blob = _read_glb(path)
    weighted = set()

    def accessor(index):
        spec = doc['accessors'][index]
        assert spec['type'] == 'VEC4' and 'sparse' not in spec, str(path)
        view = doc['bufferViews'][spec['bufferView']]
        code, width, normalizer = {5121: ('B', 1, 255), 5123: ('H', 2, 65535),
                                   5126: ('f', 4, 1)}[spec['componentType']]
        start = view.get('byteOffset', 0) + spec.get('byteOffset', 0)
        stride = view.get('byteStride', width * 4)
        for i in range(spec['count']):
            values = struct.unpack_from('<4' + code, blob, start + i * stride)
            if spec.get('normalized'):
                values = tuple(v / normalizer for v in values)
            yield values

    for node in doc['nodes']:
        if 'skin' not in node or 'mesh' not in node:
            continue
        joints = [doc['nodes'][i]['name'] for i in doc['skins'][node['skin']]['joints']]
        assert set(joints) == set(expected), (str(path), 'report/skin mismatch')
        for primitive in doc['meshes'][node['mesh']]['primitives']:
            attrs = primitive['attributes']
            for key in sorted(k for k in attrs if k.startswith('JOINTS_')):
                weights_key = key.replace('JOINTS_', 'WEIGHTS_')
                assert doc['accessors'][attrs[key]]['count'] == doc['accessors'][attrs[weights_key]]['count']
                for indices, weights in zip(accessor(attrs[key]), accessor(attrs[weights_key])):
                    assert all(math.isfinite(w) and w >= 0 for w in weights)
                    for index, weight in zip(indices, weights):
                        if weight > 1e-5:
                            assert 0 <= index < len(joints)
                            weighted.add(joints[index])
    return weighted - {'root'}


def _verify_reports():
    """Read-only, standard-library contract. Runtime skinning is the parent's gate."""
    import copy
    import json
    from pathlib import Path

    root = Path(__file__).resolve().parents[1]
    reports = root / 'build/glb-models/rigging/reports'
    observed = set()
    total = 0
    for path in sorted(reports.glob('*.json')):
        report = json.loads(path.read_text(encoding='utf8'))
        if report['family'] != 'prop':
            continue
        observed.add(report['file'])
        bones = report['bone_rest']
        # The workbench makes the root tail exactly size * .045 for these rigs.
        size = math.dist(bones['root']['head'], bones['root']['tail']) / .045
        rig = {'file': report['file'], 'family': 'prop', 'bones': bones,
               'size': size, 'height': 2 * (bones['body']['head'][2] - bones['root']['head'][2]),
               'parts': report['assignments']}
        original = copy.deepcopy(rig)
        actions = build_actions(rig)
        assert rig == original, (rig['file'], 'mutated input')
        assert actions == build_actions(rig), (rig['file'], 'nondeterministic')
        assert 3 <= len(actions) <= 7, rig['file']
        assert len({a['name'] for a in actions}) == len(actions), rig['file']
        weighted = _weighted_joints(root / 'build/glb-models/rigging/staged' / rig['file'], bones)
        source, _ = _read_glb(root / 'build/glb-models/rigging/originals' / rig['file'])
        assert sum('mesh' in n for n in source['nodes']) == report['meshes'], (rig['file'], 'source meshes')
        assert not source.get('skins'), (rig['file'], 'source already skinned')
        signatures = set()
        for action in actions:
            assert set(action) == {'name', 'duration', 'loop', 'kind', 'frames', 'events'}
            assert math.isfinite(action['duration']) and action['duration'] > 0
            frames = action['frames']
            assert len(frames) == 65 and frames[0]['time'] == 0
            assert frames[-1]['time'] == action['duration']
            assert all(a['time'] < b['time'] for a, b in zip(frames, frames[1:]))
            if action['loop']:
                assert frames[0]['bones'] == frames[-1]['bones'], (rig['file'], action['name'], 'loop')
            moving = set()
            signature = []
            for frame in frames:
                assert math.isfinite(frame['time'])
                assert 'root' not in frame['bones'], (rig['file'], action['name'], 'root motion')
                values = []
                for bone, channels in sorted(frame['bones'].items()):
                    assert bone in bones, (rig['file'], bone)
                    assert not ('rotation' in channels and 'local_rotation' in channels)
                    for channel, value in sorted(channels.items()):
                        assert channel in ('rotation', 'translation', 'scale', 'local_rotation')
                        assert len(value) == 3 and all(math.isfinite(v) for v in value)
                        if channel == 'scale':
                            assert min(value) > 0, (rig['file'], action['name'], 'scale')
                        default = [1, 1, 1] if channel == 'scale' else [0, 0, 0]
                        first = frames[0]['bones'].get(bone, {}).get(channel, default)
                        if max(abs(a - b) for a, b in zip(value, first)) > 1e-5:
                            moving.add(bone)
                        values.append((bone, channel, tuple(round(v, 6) for v in value)))
                signature.append(tuple(values))
            assert moving & weighted, (rig['file'], action['name'], 'no actually weighted nonroot motion')
            signature = tuple(signature)
            assert signature not in signatures, (rig['file'], action['name'], 'duplicate motion')
            signatures.add(signature)
            assert all(0 <= time <= action['duration'] for time in action['events'].values())
        _verify_mechanics(rig, actions)
        total += len(actions)
        print(rig['file'] + ': ' + ', '.join(a['name'] for a in actions))
    assert observed == set(_ROUTES), ('report coverage', observed ^ set(_ROUTES))
    assert len(observed) == 26
    for family in ('mechanism', 'humanoid', 'bird', 'insect', 'quadruped'):
        assert build_actions({'family': family}) == []
    try:
        build_actions({'family': 'prop', 'file': 'props/unsupported.glb'})
    except ValueError:
        pass
    else:
        raise AssertionError('Unknown prop silently accepted')
    print('MODEL_ACTIONS_PROPS_OK: %d models; %d clips; report/source/skin-data contracts only' % (len(observed), total))


def _verify_mechanics(rig, actions):
    clips = {a['name']: a for a in actions}

    def endpoints(first, second):
        assert clips[first]['frames'][-1]['bones'] == clips[second]['frames'][0]['bones'], (rig['file'], first, second)

    def close_vectors(a, b):
        assert len(a) == len(b) and all(abs(x - y) < 1e-9 for x, y in zip(a, b))

    if 'draw' in clips:
        endpoints('draw', 'release')
        for action in actions:
            for frame in action['frames']:
                pose = frame['bones']
                amount = pose['bow.draw']['translation'][0] / (rig['size'] * .15)
                close_vectors(pose['bow.up.03']['rotation'], (0, .68 * .105 * amount, 0))
                close_vectors(pose['bow.dn.03']['rotation'], (0, -.105 * amount, 0))
    if 'charge' in clips:
        endpoints('charge', 'cast')
    for first, second in [('door_open', 'door_close'), ('depress', 'plate_release'),
                          ('gate_open', 'gate_drop'), ('lid_open', 'lid_close'),
                          ('coffin_open', 'coffin_close'), ('cork_open', 'cork_close'),
                          ('cup_lift', 'cup_pour'), ('cup_pour', 'cup_setdown')]:
        if first in clips:
            endpoints(first, second)
    if 'gate_open' in clips:
        radius = rig['size'] * (.1 / 4.6)
        for name in ('gate_open', 'gate_drop'):
            heights = []
            for frame in clips[name]['frames']:
                pose = frame['bones']
                lift = pose['trap.gate_slab']['translation'][2]
                angle = pose['trap.pulley']['local_rotation'][1]
                assert abs(lift + radius * angle) < 1e-9
                assert 0 <= lift <= rig['size'] * .12
                heights.append(lift)
            sign = 1 if name == 'gate_open' else -1
            assert all(sign * (b - a) >= -1e-9 for a, b in zip(heights, heights[1:]))
    if 'part.axe_left' in rig['bones']:
        for side, other in [('left', 'right'), ('right', 'left')]:
            for frame in clips[side + '_strike']['frames']:
                assert not any(other in bone for bone in frame['bones'])
    if rig['file'].endswith('templateweapons.glb'):
        for name, bone in [('sword_slash', 'part.Sword'), ('sword_thrust', 'part.Sword'),
                           ('axe_chop', 'part.Ax'), ('shield_parry', 'part.Shield'),
                           ('shield_bash', 'part.Shield'), ('torch_raise', 'part.Torch')]:
            assert all(set(f['bones']) == {bone} for f in clips[name]['frames'])
    if rig['file'].startswith(('props/', 'equipment/')):
        for action in actions:
            for frame in action['frames']:
                assert 'body' not in frame['bones'], (rig['file'], action['name'], 'fixed body')
                for mesh, owner in rig['parts'].items():
                    if mesh.lower().startswith(('plinth', 'base', 'backboard', 'platform', 'displaybase',
                                                'brokenwall', 'caprail', 'baluster', 'framepost', 'guiderail')):
                        while owner:
                            assert owner not in frame['bones'], (rig['file'], mesh, owner, 'fixed support')
                            owner = rig['bones'][owner]['parent']


if __name__ == '__main__':
    _verify_reports()
