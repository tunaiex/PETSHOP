# Per-character configuration (all coordinates are image pixels: x right, y down).
# Character's LEFT side == image RIGHT side (character faces the viewer).
# Bone tuple: (name, parent, head(x,y[,dz]), tail(x,y[,dz]), group)
# group drives weight masking: core | arm_L | arm_R | leg_L | leg_R | acc:<region>
# dz: depth offset in px, negative = towards the front (character's facing direction)


def arm(side, sh0, sh1, elbow, wrist, hand, tip):
    g = 'arm_' + side
    return [
        (f'Shoulder.{side}', 'Spine2', sh0, sh1, 'clav_' + side),
        (f'UpperArm.{side}', f'Shoulder.{side}', sh1, elbow, g),
        (f'ForeArm.{side}', f'UpperArm.{side}', elbow, wrist, g),
        (f'Hand.{side}', f'ForeArm.{side}', wrist, hand, g),
        (f'Fingers1.{side}', f'Hand.{side}', hand, ((hand[0] + tip[0]) / 2, (hand[1] + tip[1]) / 2), g),
        (f'Fingers2.{side}', f'Fingers1.{side}', ((hand[0] + tip[0]) / 2, (hand[1] + tip[1]) / 2), tip, g),
    ]


def leg(side, hip, knee, ankle, toe_len):
    g = 'leg_' + side
    ax, ay = ankle
    return [
        (f'UpperLeg.{side}', 'Hips', hip, knee, g),
        (f'LowerLeg.{side}', f'UpperLeg.{side}', knee, ankle, g),
        (f'Foot.{side}', f'LowerLeg.{side}', ankle, (ax, ay + toe_len * 0.6, -toe_len * 0.9), g),
        (f'Toes.{side}', f'Foot.{side}', (ax, ay + toe_len * 0.6, -toe_len * 0.9), (ax, ay + toe_len * 0.75, -toe_len * 1.5), g),
    ]


def spine(cx, hips, sp, sp1, sp2, neck, head, top):
    return [
        ('Hips', 'Root', (cx, hips), (cx, sp), 'core'),
        ('Spine', 'Hips', (cx, sp), (cx, sp1), 'core'),
        ('Spine1', 'Spine', (cx, sp1), (cx, sp2), 'core'),
        ('Spine2', 'Spine1', (cx, sp2), (cx, neck), 'core'),
        ('Neck', 'Spine2', (cx, neck), (cx, head), 'core'),
        ('Head', 'Neck', (cx, head), (cx, top), 'head'),
    ]


def chain(prefix, parent, pts, region, dz=0):
    out = []
    for i in range(len(pts) - 1):
        p = parent if i == 0 else f'{prefix}{i}'
        a = tuple(pts[i]) + ((dz,) if len(pts[i]) == 2 else ())
        b = tuple(pts[i + 1]) + ((dz,) if len(pts[i + 1]) == 2 else ())
        out.append((f'{prefix}{i + 1}', p, a, b, 'acc:' + region))
    return out


CHARS = {}

# ---------------------------------------------------------------- BEBEK (baby)
b = []
b += spine(600, 880, 800, 720, 640, 575, 535, 95)
b += [('Belly', 'Spine', (600, 800, 0), (600, 800, -90), 'acc:belly')]
b += arm('R', (575, 600), (450, 625), (330, 640), (205, 632), (150, 625), (95, 620))
b += arm('L', (625, 600), (750, 625), (870, 640), (995, 632), (1050, 625), (1100, 620))
b += leg('R', (520, 900), (500, 1060), (485, 1215), 90)
b += leg('L', (690, 900), (705, 1060), (710, 1215), 90)
b += chain('Hat', 'Head', [(640, 140), (770, 110), (870, 220), (905, 320)], 'hat')
b += [('Pompom', 'Hat3', (905, 320), (910, 400), 'acc:pompom')]
b += chain('HairBun', 'Head', [(500, 140), (470, 30)], 'bun')
b += chain('HairSide.R', 'Head', [(400, 290), (375, 370), (365, 450), (380, 540)], 'hairR')
b += chain('HairSide.L', 'Head', [(810, 320), (830, 400), (825, 480), (790, 560)], 'hairL')
b += chain('HairBack', 'Head', [(600, 300, 120), (600, 400, 150), (600, 480, 140), (600, 555, 110)], 'hairB')
b += [('Bow', 'Head', (385, 255), (385, 255, -60), 'acc:bow')]
b += [('Pacifier', 'Head', (600, 505), (600, 505, -80), 'acc:paci')]
CHARS['Bebek'] = dict(
    file='01_Bebek.png', height=0.80, cx=600, head_core=(600, 345, 250, 235),
    bones=b,
    regions={  # ellipses: (cx, cy, rx, ry) + optional color filter
        'belly': dict(ell=(600, 800, 150, 110)),
        'hat': dict(ell=(830, 230, 150, 210), color='hat'),
        'pompom': dict(ell=(915, 390, 65, 65)),
        'bun': dict(ell=(480, 60, 70, 70), color='hair'),
        'hairR': dict(ell=(370, 420, 75, 160), color='hair'),
        'hairL': dict(ell=(815, 450, 60, 140), color='hair'),
        'hairB': dict(ell=(600, 440, 230, 140), back=True),
        'bow': dict(ell=(385, 255, 50, 50)),
        'paci': dict(ell=(600, 505, 62, 58)),
    },
    # where torso ends and arms start (|x - cx|), and where legs start (y)
    arm_start=150, leg_start=900,
    # back texture edits: face -> hair, front details -> fabric patches
    back=dict(
        hair_fill=[dict(ell=(605, 395, 205, 185), src=(330, 400, 90, 130))],
        patches=[  # (dst_x, dst_y, w, h, src_x, src_y)
            (495, 720, 215, 150, 495, 880),   # cat pocket -> plaid
            (480, 650, 70, 70, 480, 910),     # buttons
            (650, 650, 70, 70, 650, 910),
        ],
    ),
)

# ---------------------------------------------------------------- GENC (young)
g = []
g += spine(520, 720, 640, 540, 440, 335, 290, 55)
g += arm('R', (495, 355), (400, 375), (260, 395), (135, 400), (70, 405), (5, 405))
g += arm('L', (545, 355), (640, 375), (780, 395), (905, 400), (990, 405), (1080, 405))
g += leg('R', (450, 730), (440, 1010), (445, 1335), 70)
g += leg('L', (595, 730), (600, 1010), (595, 1335), 70)
g += chain('Hat', 'Head', [(560, 55), (640, 60), (680, 150)], 'hat')
g += [('Pompom', 'Hat2', (680, 150), (690, 230), 'acc:pompom')]
g += chain('Hair.R', 'Head', [(420, 170), (400, 300), (380, 420), (380, 540)], 'hairR')
g += chain('Hair.L', 'Head', [(620, 170), (650, 300), (670, 420), (665, 530)], 'hairL')
g += chain('HairBack', 'Head', [(520, 160, 60), (520, 300, 80), (520, 420, 85), (520, 560, 80)], 'hairB')
CHARS['Genc'] = dict(
    file='02_Genc.png', height=1.62, cx=520, head_core=(520, 175, 105, 125),
    bones=g,
    regions={
        'hat': dict(ell=(640, 100, 75, 95), color='hat'),
        'pompom': dict(ell=(688, 215, 45, 45)),
        'hairR': dict(ell=(395, 380, 75, 200), color='hair', ymin=150),
        'hairL': dict(ell=(650, 370, 70, 200), color='hair', ymin=150),
        'hairB': dict(ell=(520, 390, 150, 240), back=True, ymin=170),
    },
    arm_start=125, leg_start=720,
    back=dict(
        hair_fill=[dict(ell=(518, 215, 98, 112), src=(405, 200, 40, 110)),
                   dict(ell=(518, 420, 140, 170), src=(405, 200, 40, 110), ymin=270)],
        patches=[],
    ),
)

# ---------------------------------------------------------------- YASLI (old)
y = []
y += spine(535, 830, 730, 620, 500, 335, 300, 45)
y += arm('R', (505, 360), (385, 385), (245, 410), (115, 415), (55, 412), (5, 410))
y += arm('L', (565, 360), (685, 385), (825, 410), (955, 415), (1020, 412), (1080, 410))
y += leg('R', (470, 850), (465, 1100), (455, 1370), 70)
y += leg('L', (600, 850), (610, 1100), (615, 1370), 70)
y += chain('Hat', 'Head', [(590, 40), (680, 60), (715, 170)], 'hat')
y += [('Pompom', 'Hat2', (715, 170), (715, 280), 'acc:pompom')]
y += chain('Scarf', 'Spine2', [(630, 400), (640, 480), (645, 550), (650, 615)], 'scarf')
y += chain('HairPuff.R', 'Head', [(415, 140), (385, 210), (380, 285)], 'hairR')
y += chain('HairPuff.L', 'Head', [(640, 170), (665, 230), (670, 290)], 'hairL')
y += chain('HairBack', 'Head', [(535, 150, 70), (535, 240, 95), (535, 320, 80)], 'hairB')
y += chain('Skirt.R', 'Hips', [(470, 860), (400, 1060), (330, 1270)], 'skirtR')
y += chain('Skirt.L', 'Hips', [(600, 860), (670, 1060), (735, 1270)], 'skirtL')
y += chain('Skirt.F', 'Hips', [(535, 860, -40), (535, 1060, -60), (535, 1270, -80)], 'skirtF')
y += chain('Skirt.B', 'Hips', [(535, 860, 40), (535, 1060, 60), (535, 1270, 80)], 'skirtB')
CHARS['Yasli'] = dict(
    file='03_Yasli.png', height=1.55, cx=535, head_core=(535, 180, 110, 125),
    bones=y,
    regions={
        'hat': dict(ell=(670, 110, 80, 110), color='hat'),
        'pompom': dict(ell=(715, 245, 50, 50)),
        'scarf': dict(ell=(625, 520, 65, 110), ymin=440),
        'hairR': dict(ell=(385, 220, 55, 100), color='hairgray'),
        'hairL': dict(ell=(665, 240, 40, 70), color='hairgray'),
        'hairB': dict(ell=(535, 250, 140, 110), back=True),
        # skirt: special handling (x position + front/back side)
        'skirtR': dict(skirt=True), 'skirtL': dict(skirt=True),
        'skirtF': dict(skirt=True), 'skirtB': dict(skirt=True),
    },
    arm_start=130, leg_start=850, skirt=dict(top=850, bottom=1290),
    back=dict(
        hair_fill=[dict(ell=(535, 210, 112, 118), src=(385, 120, 55, 120))],
        fills=[(468, 425, 100, 435, (335, 440, 80, 130))],  # cardigan opening -> knit
        patches=[
            (370, 590, 110, 90, 330, 470),    # flowers L
            (600, 590, 100, 90, 330, 470),    # flowers R
        ],
    ),
)
