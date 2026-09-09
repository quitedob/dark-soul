"""Original humanoid keyframes, authored in Z-up, -Y-forward model-rest space.

No external clips, rig edits, gameplay displacement, or equipment reparenting.
Event values are clip-local seconds marking phase starts. Missing bones rest.
Legacy chest-parented hands need the export owner's follower bake; these recipes
do not silently repair that hierarchy. Rigid bowstrings cannot deform separately.
"""
import math

from model_action_common import put, sampled_action, envelope, curve


# Content identities, not random seeds: special name, gesture, combat style.
_ROLES = {
    'Divine-Marksman': ('draw_release', 'draw', 'archer'),
    'Frenzied-Warrior': ('twin_axe_cleave', 'cleave', 'heavy'),
    'Mystic-Mage': ('gate_seal_ritual', 'seal', 'caster'),
    'Invocation-Master': ('guardian_invocation', 'invoke', 'caster'),
    'Yin-Yang-Master': ('yin_yang_balance', 'balance', 'caster'),
    'War-Shaman': ('ancestral_stomp', 'stomp', 'heavy'),
    'Arcane-Archer': ('arcane_draw_release', 'arcane_draw', 'archer'),
    'Asura': ('asura_alternating_rend', 'flurry', 'brawler'),
    'Furnace-Keeper-JuQue': ('furnace_gate_slam', 'slam', 'heavy'),
    'Blood-General-XingTian': ('blood_axe_execution', 'cleave', 'heavy'),
    'Fallen-Immortal-XuanXiao': ('falling_star_cut', 'skyfall', 'blade'),
    'Lord-of-the-Ember-Abyss-ZhuYin': ('abyss_convergence', 'abyss', 'caster'),
    'WrathFragment': ('wrath_breaker', 'punch', 'brawler'),
    'ObsessionFragment': ('obsession_binding', 'seal', 'caster'),
    'Cloud-Wanderer': ('wanderer_blessing', 'blessing', 'npc'),
    'Iron-Heart': ('forge_hammer', 'forge', 'npc'),
    'Lady-of-Memories': ('memory_reading', 'read', 'npc'),
    'XuanXiao-Remnant': ('remnant_recollection', 'recall', 'npc'),
    'Silence-Bringer': ('lantern_vigil', 'lantern', 'npc'),
    'Tea-Soul': ('pour_tea', 'pour', 'npc'),
    'Ember-Tea-Keeper': ('offer_ember_tea', 'offer', 'npc'),
    'DharmaProtectingChildSpirit': ('dharma_ward', 'invoke', 'caster'),
    'GoldenArmoredGuardian': ('golden_shield_bash', 'bash', 'heavy'),
    'ResentfulSpirit': ('resentment_wail', 'wail', 'caster'),
    'WhiteCraneAttendant': ('attendant_fan_gust', 'fan', 'caster'),
    'Lost-Soul-Soldier': ('sentinel_thrust', 'thrust', 'blade'),
    'Temple-Guardian-Warrior': ('temple_greatsword_judgment', 'skyfall', 'heavy'),
    'Mirror-Shade': ('mirror_reversal', 'balance', 'caster'),
    'Furnace-Slag-Beast': ('slag_double_slam', 'slam', 'brawler'),
    'Lost-Soldier-BattleWorn': ('battleworn_spear_lunge', 'thrust', 'blade'),
    'Camp-Guard-Wraith': ('camp_shield_advance', 'bash', 'heavy'),
    'Generals-Personal-Guard': ('personal_guard_cleave', 'cleave', 'heavy'),
    'Beacon-Keeper-Wraith': ('beacon_flame_offering', 'invoke', 'caster'),
    'Memory-Thief': ('memory_siphon', 'drain', 'caster'),
    'Echo-Spirit': ('echo_sword_command', 'fan', 'blade'),
    'Wedding-Gown-Ghost': ('bridal_lament', 'wail', 'caster'),
    'Water-Moon': ('moon_tide', 'tide', 'caster'),
    'Mirror-Flower-Spirit': ('mirror_bloom', 'bloom', 'caster'),
    'MindLost-Fox-Demon': ('feral_claw_rake', 'flurry', 'brawler'),
    'Ember-Greedy-Ghost': ('ember_devour', 'drain', 'brawler'),
    'Stairway-Guard-Wraith': ('stairway_halberd_sweep', 'cleave', 'heavy'),
    'Alchemy-Fallen-Immortal': ('elixir_decant', 'brew', 'caster'),
    'Library-Guardian-Spirit': ('forbidden_page_invocation', 'read', 'caster'),
    'Broken-Immortal-Body': ('broken_wing_rebuke', 'fan', 'heavy'),
    'Ember-Shore-Drifter': ('shore_soul_reach', 'drain', 'caster'),
    'Inverted-Guardian': ('anchor_uppercut', 'punch', 'heavy'),
    'Forked-Path-Guardian': ('forked_path_verdict', 'balance', 'caster'),
    'Shadow-of-Possibility': ('possibility_feint_rend', 'flurry', 'blade'),
}
_HOVER = ('Fallen-Immortal-XuanXiao', 'Lord-of-the-Ember-Abyss-ZhuYin',
          'Mirror-Flower-Spirit', 'DharmaProtectingChildSpirit')


def _side(rig, side):
    bone = rig['bones'].get('upper_arm.' + side, {})
    center = rig['bones'].get('chest', {}).get('head', (0, 0, 0))[0]
    x = bone.get('head', (center + (-1 if side == 'L' else 1), 0, 0))[0]
    return -1 if x < center else 1


def _arm(pose, rig, side, lift=0., bend=0., spread=0., turn=0., wrist=0.):
    # Raised/offset source arms stay raised: all values are offsets, not T poses.
    sign = _side(rig, side)
    for stem, pitch, outward, yaw in (
            ('upper_arm', lift, spread, turn), ('forearm', bend, 0., 0.),
            ('hand', 0., 0., wrist)):
        bone = rig['bones'].get(stem + '.' + side)
        if bone is None:
            continue
        dz = bone['tail'][2] - bone['head'][2]
        pitch_sign = 1 if dz > 0 and stem != 'hand' else -1
        pitch = max(-.90, min(.90, pitch))
        put(pose, rig, stem + '.' + side,
            rotation=(pitch_sign * pitch, pitch_sign * sign * outward, sign * yaw))


def _body(pose, rig, lean=0., twist=0., crouch=0., sway=0.):
    put(pose, rig, 'hips', rotation=(lean * .2, sway, -twist * .2),
        translation=(0., 0., -rig['height'] * crouch))
    put(pose, rig, 'spine', rotation=(lean * .35, -sway * .3, twist * .3))
    put(pose, rig, 'chest', rotation=(lean * .45, sway * .25, twist * .7))
    put(pose, rig, 'head', rotation=(-lean * .22, 0., -twist * .3))


def _leg(pose, rig, side, hip, knee, roll=0.):
    thigh, shin, foot = (stem + '.' + side for stem in ('thigh', 'shin', 'foot'))
    put(pose, rig, thigh, rotation=(hip, roll, 0.))
    put(pose, rig, shin, rotation=(knee, 0., 0.))
    # Some legacy feet are siblings of the thigh, not descendants of a shin.
    parent = rig['bones'].get(foot, {}).get('parent', '')
    inherited = 0.
    inherited_roll = 0.
    while parent in rig['bones']:
        inherited += hip if parent == thigh else knee if parent == shin else 0.
        inherited_roll += roll if parent == thigh else 0.
        parent = rig['bones'][parent].get('parent', '')
    put(pose, rig, foot, rotation=(-inherited, -inherited_roll, 0.))


def _secondary(pose, rig, phase, strength, loop=False):
    fade = 1. if loop else envelope(phase)
    for name, rest in rig['bones'].items():
        if not name.startswith(('cloth.', 'tail', 'wing.')):
            continue
        parent = rest.get('parent', '')
        lag = .65 if parent.startswith(('cloth.', 'tail')) else 0.
        wave = math.sin(math.tau * phase - lag) * strength * fade
        side = -1 if rest['head'][0] < rig['bones']['hips']['head'][0] else 1
        if name.startswith('wing.'):
            put(pose, rig, name, rotation=(wave * .3, side * wave, 0.))
        elif name.startswith('tail'):
            put(pose, rig, name, rotation=(wave * .35, 0., wave))
        else:
            put(pose, rig, name, rotation=(wave, side * wave * .25, 0.))


def _idle(rig, phase):
    pose = {}
    breath = math.sin(math.tau * phase)
    _body(pose, rig, lean=.018 * breath, sway=.008 * breath)
    put(pose, rig, 'chest', rotation=(.014 * breath, 0., 0.),
        scale=(1 + .006 * breath, 1 + .009 * breath, 1 + .003 * breath))
    for side in ('L', 'R'):
        _arm(pose, rig, side, lift=.014 * breath, bend=.012 * breath)
    _secondary(pose, rig, phase, .026, loop=True)
    return pose


def _locomotion(rig, phase, mode):
    pose = {}
    running = mode == 'run'
    lateral = -1 if mode == 'strafe_left' else 1 if mode == 'strafe_right' else 0
    stride = (.48 if running else .28) * (.78 if rig['_heavy'] else 1.)
    wave = math.sin(math.tau * phase)
    bob = math.cos(2 * math.tau * phase)
    floating = rig['_floating']
    _body(pose, rig, lean=.14 if running else .045,
          twist=.05 * wave, crouch=(.018 if running else .009) * (1 - bob),
          sway=(lateral * .055 if lateral else .022 * wave))
    if floating:
        put(pose, rig, 'hips', translation=(.012 * rig['height'] * lateral * wave,
            0., .012 * rig['height'] * wave), rotation=(.10 if running else .045, lateral * .045, .035 * wave))
    for side, polarity in (('L', 1), ('R', -1)):
        swing = wave * polarity
        lift = max(0., swing)
        thigh = -stride * swing
        knee = (.55 if running else .30) * lift
        if not floating:
            _leg(pose, rig, side, thigh * (.20 if lateral else 1.), knee,
                 -lateral * stride * swing * .65)
        # Arms counter the same-side advancing leg, including hover propulsion.
        _arm(pose, rig, side, lift=-swing * stride * (.5 if floating else .65),
             bend=(.18 if running else .06) + .07 * lift,
             spread=.055 + .025 * lateral * _side(rig, side) if lateral else .015)
    _secondary(pose, rig, phase, .09 if running else .05, loop=True)
    return pose


def _pulses(phase, heavy=False):
    start, end = (.50, .72) if heavy else (.34, .60)
    charge = curve(phase, [(0., 0.), (start - .06, 1.), (start, .9), (end, 0.), (1., 0.)])
    strike = curve(phase, [(0., 0.), (start, 0.), (start + .08, 1.), (end, .85), (.92, 0.), (1., 0.)])
    return charge, strike


def _combat(rig, phase, heavy=False, casting=False):
    pose = {}
    charge, strike = _pulses(phase, heavy)
    dominant = rig['_hand']
    other = 'L' if dominant == 'R' else 'R'
    sign = _side(rig, dominant)
    _body(pose, rig, lean=-.12 * charge + .24 * strike,
          twist=sign * (-.18 * charge + .24 * strike), crouch=.022 * charge)
    if casting or rig['_style'] == 'caster':
        _arm(pose, rig, dominant, .35 * charge + .62 * strike,
             .32 * charge - .08 * strike, .06 * charge, .10 * strike, .20 * strike)
        _arm(pose, rig, other, .24 * charge + .30 * strike, .20 * charge,
             .12 * strike, -.06 * strike)
        put(pose, rig, 'head', rotation=(.08 * charge - .09 * strike, 0., .08 * strike))
        if heavy:
            _arm(pose, rig, other, .55 * charge + .50 * strike, .32 * charge, .18 * strike)
        if casting:
            _body(pose, rig, lean=-.08 * charge, twist=.10 * strike, crouch=-.012 * strike)
            _arm(pose, rig, other, .45 * charge + .25 * strike, .22 * strike, .24 * strike)
    elif rig['_style'] == 'archer':
        release = .50 if heavy else .34
        charge = curve(phase, [(0., 0.), (release - .06, 1.),
                              (release, 1.), (release + .04, 0.), (1., 0.)])
        _arm(pose, rig, 'L', .36 * charge + .40 * strike, .04 * charge, .035 * charge)
        _arm(pose, rig, 'R', -.10 * charge + .16 * strike,
             .48 * charge + .08 * strike, .12 * charge, .12 * charge)
        if heavy:
            _body(pose, rig, lean=-.11 * charge, twist=-.24 * charge + .10 * strike, crouch=.026 * charge)
            _arm(pose, rig, 'L', .52 * charge + .50 * strike, .08 * charge, .06 * charge)
    else:
        _arm(pose, rig, dominant, (.65 if heavy else -.16) * charge + .64 * strike,
             .42 * charge - .08 * strike, .14 * charge, -.22 * charge + .24 * strike)
        _arm(pose, rig, other, .18 * charge + .10 * strike, .18 * charge, .07 * strike)
        if heavy and rig['_style'] in ('heavy', 'brawler'):
            _arm(pose, rig, other, .53 * charge + .42 * strike, .30 * charge, .13 * charge)
    if not rig['_floating']:
        put(pose, rig, 'thigh.' + dominant, rotation=(-.14 * strike, 0., 0.))
        put(pose, rig, 'shin.' + other, rotation=(.18 * charge, 0., 0.))
    _secondary(pose, rig, phase, .10 if heavy else .065)
    return pose


def _special(rig, phase, motif):
    pose = {}
    charge, strike = _pulses(phase, heavy=True)
    hold = curve(phase, [(0., 0.), (.30, .8), (.48, 1.), (.72, 1.), (1., 0.)])
    circle = math.sin(math.tau * phase) * envelope(phase)
    hand, other = rig['_hand'], 'L' if rig['_hand'] == 'R' else 'R'
    _body(pose, rig, lean=-.08 * charge + .18 * strike, crouch=.018 * charge)
    if motif in ('draw', 'arcane_draw'):
        charge = curve(phase, [(0., 0.), (.20, .25), (.42, 1.),
                              (.50, 1.), (.54, 0.), (1., 0.)])
        rune = .18 * charge if motif == 'arcane_draw' else 0.
        _body(pose, rig, lean=-.09 * charge + .07 * strike, twist=-.30 * hold, crouch=.012 * charge)
        _arm(pose, rig, 'L', .52 * hold + rune, .08 * charge, .07 * hold, .08 * hold)
        _arm(pose, rig, 'R', -.18 * charge + .20 * strike,
             .64 * charge + .10 * strike, .22 * charge, .18 * charge, .25 * strike + rune)
        put(pose, rig, 'head', rotation=(-rune, 0., .22 * hold))
    elif motif in ('cleave', 'slam', 'skyfall', 'forge'):
        sweep = .34 if motif == 'cleave' else .10 if motif == 'skyfall' else 0.
        _body(pose, rig, lean=-.20 * charge + .42 * strike,
              twist=sweep * (-charge + strike), crouch=.035 * strike)
        _arm(pose, rig, hand, .82 * charge + .16 * strike,
             .48 * charge - .08 * strike, .16 * charge, sweep * (-charge + strike))
        _arm(pose, rig, other, (.70 if motif in ('cleave', 'slam') else .22) * charge,
             .28 * charge, .20 * hold, -.10 * strike)
        if motif == 'forge':
            _arm(pose, rig, other, .27 * hold, .16 * hold)
    elif motif in ('seal', 'invoke', 'balance', 'abyss', 'bloom', 'tide'):
        spread = .32 if motif in ('abyss', 'bloom') else .14
        for side, polarity in (('L', -1), ('R', 1)):
            alternate = polarity * circle if motif in ('balance', 'tide') else 0.
            lift = (.65 if motif in ('invoke', 'abyss') else .36) * hold + .18 * alternate
            _arm(pose, rig, side, lift, .30 * charge + .12 * alternate,
                 spread * strike, .14 * alternate, .22 * strike * polarity)
        _body(pose, rig, lean=(-.16 if motif == 'abyss' else .10) * strike,
              twist=.22 * circle if motif == 'balance' else .05 * charge,
              crouch=(-.025 if motif in ('invoke', 'bloom') else .015) * strike)
        if motif == 'seal':
            _arm(pose, rig, 'R', .42 * hold, .35 * charge, .05 * strike, .20 * circle, .32 * circle)
        put(pose, rig, 'held.fireball', translation=(0., -.035 * rig['height'] * strike, .025 * rig['height'] * hold))
        put(pose, rig, 'ornament.moon', rotation=(.12 * circle, 0., .20 * strike))
    elif motif in ('stomp', 'punch', 'bash', 'thrust', 'flurry'):
        first = strike
        second = curve(phase, [(0., 0.), (.60, 0.), (.75, 1.), (.88, .3), (1., 0.)]) if motif == 'flurry' else 0.
        _body(pose, rig, lean=-.12 * charge + .28 * first,
              twist=.26 * (first - second), crouch=.045 * first)
        use = 'L' if motif == 'bash' else hand
        _arm(pose, rig, use, (-.18 if motif != 'punch' else -.30) * charge + .72 * first,
             .40 * charge - .10 * first, .10 * charge, .15 * first)
        _arm(pose, rig, 'R' if use == 'L' else 'L', .18 * charge + .60 * second,
             .22 * hold, .08 * hold, -.18 * second)
        if motif == 'stomp':
            put(pose, rig, 'thigh.R', rotation=(-.62 * charge + .12 * strike, 0., 0.))
            put(pose, rig, 'shin.R', rotation=(.66 * charge, 0., 0.))
            put(pose, rig, 'foot.R', rotation=(-.15 * charge, 0., 0.))
    elif motif in ('drain', 'wail', 'fan'):
        for side in ('L', 'R'):
            _arm(pose, rig, side, .24 * charge + (.64 if motif == 'drain' else .40) * strike,
                 .28 * charge + .12 * strike, (.26 if motif == 'wail' else .12) * hold,
                 .24 * circle if motif == 'fan' else 0.)
        _body(pose, rig, lean=(.24 if motif == 'drain' else -.22) * strike, twist=.26 * circle if motif == 'fan' else 0.)
        put(pose, rig, 'head', rotation=(-.25 * strike if motif == 'wail' else .12 * strike, 0., 0.))
        put(pose, rig, 'held.sword', rotation=(.40 * strike, .10 * charge, .42 * circle),
            translation=(0., -.06 * rig['height'] * strike, .02 * rig['height'] * charge))
    else:
        # Object handling: inspect, tilt, present, and return, with distinct wrists.
        _arm(pose, rig, other, .24 * hold, .20 * hold, .06 * hold)
        lift = .62 if motif in ('lantern', 'blessing') else .30
        _arm(pose, rig, hand, lift * hold, .25 * charge, .08 * hold,
             .12 * circle, .32 * strike if motif in ('pour', 'brew') else .10 * circle)
        _body(pose, rig, lean=.16 * hold if motif == 'read' else .06 * charge,
              twist=.16 * circle if motif == 'recall' else .04 * strike)
        if motif == 'read':
            _arm(pose, rig, hand, .20 * hold, .28 * hold, .04 * hold, .17 * circle, .24 * circle)
            put(pose, rig, 'held.book', rotation=(.16 * hold, 0., .10 * circle),
                translation=(0., 0., .035 * rig['height'] * hold))
        if motif == 'offer':
            _arm(pose, rig, hand, .47 * strike + .20 * charge, .22 * charge - .08 * strike)
        if motif in ('pour', 'brew'):
            put(pose, rig, 'hand.' + hand, rotation=(.10 * charge, -.45 * strike, 0.))
        if motif == 'blessing':
            put(pose, rig, 'head', rotation=(.18 * strike, 0., 0.))
    _secondary(pose, rig, phase, .12)
    return pose


def _social(rig, phase, gesture):
    pose = {}
    amount = envelope(phase)
    wave = math.sin(2 * math.tau * phase) * amount
    _body(pose, rig, lean=(.20 if gesture == 'greet' else .07) * amount,
          twist=.07 * wave if gesture == 'talk' else 0.)
    for side in ('L', 'R'):
        _arm(pose, rig, side, .12 * amount, .08 * amount)
    if gesture == 'greet':
        _arm(pose, rig, 'R', .40 * amount, .24 * amount, .14 * amount, wrist=.16 * wave)
        put(pose, rig, 'head', rotation=(.16 * amount, 0., 0.))
    elif gesture == 'talk':
        _arm(pose, rig, 'L', .20 * amount + .10 * wave, .18 * amount, .08 * amount)
        put(pose, rig, 'head', rotation=(.08 * wave, 0., .11 * amount))
    else:
        _arm(pose, rig, 'R', .48 * amount, .12 * amount, .02 * amount, wrist=.14 * amount)
        _body(pose, rig, lean=.22 * amount, twist=.10 * amount)
    _secondary(pose, rig, phase, .045)
    return pose


def _reaction(rig, phase, name):
    pose = {}
    if name == 'death':
        drop = curve(phase, [(0., 0.), (.20, .18), (.65, .85), (.85, 1.), (1., 1.)])
        _body(pose, rig, lean=.85 * drop, twist=.15 * drop,
              crouch=(.08 if rig['_floating'] else .18) * drop, sway=.12 * drop)
        put(pose, rig, 'head', rotation=(.32 * drop, 0., -.12 * drop))
        for side in ('L', 'R'):
            _arm(pose, rig, side, -.20 * drop, .14 * drop, .18 * drop)
            if not rig['_floating']:
                put(pose, rig, 'thigh.' + side, rotation=(-.40 * drop, 0., 0.))
                put(pose, rig, 'shin.' + side, rotation=(.65 * drop, 0., 0.))
                put(pose, rig, 'foot.' + side, rotation=(-.25 * drop, 0., 0.))
        _secondary(pose, rig, min(phase / .85, 1.), .10)
    else:
        amount = curve(phase, [(0., 0.), (.18, 1.), (.38, .7), (.78, .12), (1., 0.)])
        dodge = name == 'dodge'
        _body(pose, rig, lean=(.42 if dodge else -.28) * amount,
              twist=(-.28 if dodge else .17) * amount,
              crouch=(.065 if dodge else .012) * amount, sway=.16 * amount if dodge else 0.)
        for side in ('L', 'R'):
            _arm(pose, rig, side, -.18 * amount if dodge else .16 * amount,
                 .35 * amount, .12 * amount)
            if dodge and not rig['_floating']:
                put(pose, rig, 'thigh.' + side, rotation=(-.30 * amount, .12 * amount, 0.))
                put(pose, rig, 'shin.' + side, rotation=(.44 * amount, 0., 0.))
                put(pose, rig, 'foot.' + side, rotation=(-.14 * amount, 0., 0.))
        put(pose, rig, 'head', rotation=(.10 * amount if dodge else -.18 * amount, 0., .12 * amount))
        _secondary(pose, rig, phase, .09)
    return pose


def build_actions(rig):
    """Return humanoid recipes only; input rest definitions are never mutated."""
    if rig.get('family') != 'humanoid':
        return []
    filename = str(rig['file']).replace('\\', '/').rsplit('/', 1)[-1]
    identity = filename.removesuffix('.glb').split('-', 1)[-1]
    special, motif, style = _ROLES.get(identity, ('guard_counter', 'thrust', 'blade'))
    bones = rig['bones']
    height = float(rig.get('height', rig.get('size', 1.)))
    if not math.isfinite(height) or height <= 0:
        raise ValueError('Humanoid action height must be finite and positive')
    hand = 'R' if 'upper_arm.R' in bones and ('hand.R' in bones or 'forearm.R' in bones) else 'L'
    # The battleworn soldier's source spear belongs to the left hand.
    if identity == 'Lost-Soldier-BattleWorn':
        hand = 'L'
    context = dict(rig, height=height, _style=style, _hand=hand, _heavy=style == 'heavy',
                   _floating=identity in _HOVER or not all('thigh.' + s in bones for s in ('L', 'R')))
    actions = []

    def add(name, duration, loop, callback, kind, heavy=None):
        events = {}
        if heavy is not None:
            start, end = (.50, .72) if heavy else (.34, .60)
            if name == special and motif == 'flurry':
                end = .86
            events = dict(windup=0., active_start=duration * start,
                          active_end=duration * end, recovery=duration * end)
        actions.append(sampled_action(name, duration, loop, callback, kind, steps=48, events=events))

    add('idle', 3.2 if style in ('npc', 'caster') else 2.6, True, lambda t: _idle(context, t), 'idle')
    add('walk', 1.3 if style in ('npc', 'heavy') else 1.1, True, lambda t: _locomotion(context, t, 'walk'), 'locomotion')
    add('hit', .65, False, lambda t: _reaction(context, t, 'hit'), 'reaction')
    add('death', 2.2, False, lambda t: _reaction(context, t, 'death'), 'death')
    if style == 'npc':
        for name, duration in (('greet', 1.8), ('talk', 2.6), ('interact', 1.6)):
            add(name, duration, name == 'talk', lambda t, n=name: _social(context, t, n), 'interaction')
    else:
        for mode, duration in (('run', .72), ('strafe_left', 1.15), ('strafe_right', 1.15)):
            add(mode, duration, True, lambda t, m=mode: _locomotion(context, t, m), 'locomotion')
        add('dodge', .85, False, lambda t: _reaction(context, t, 'dodge'), 'dodge')
        add('attack_light', .95, False, lambda t: _combat(context, t), 'attack', False)
        add('attack_heavy', 1.65, False, lambda t: _combat(context, t, heavy=True), 'attack', True)
        add('cast', 1.5, False, lambda t: _combat(context, t, casting=True), 'cast', False)
    add(special, 2.4 if style == 'npc' else 1.9, False,
        lambda t: _special(context, t, motif), 'interaction' if style == 'npc' else 'special',
        None if style == 'npc' else True)
    return actions
