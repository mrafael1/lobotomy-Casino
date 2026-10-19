"""V1 measurements in 320x640 recipe units; exports derive both other spaces."""
REEL_X=(49,126,203)
REEL_TOP=218
REEL_W=58
REEL_H=108
SYMBOL_TOP=242
SYMBOL_H=66
POWER_SOCKETS=((76,'REROLL'),(160,'SHIFT'),(244,'LOCK'))
STASH_X=(229,267)
SOURCE_SCALE=2
LAYOUT_SCALE=.5


def rect(x,y,w,h):
    return {'source':[v*SOURCE_SCALE for v in (x,y,w,h)],
            'layout':[v*LAYOUT_SCALE for v in (x,y,w,h)]}


def geometry():
    return {
        'source_size':[640,1280],'safe_layout_size':[160,320],
        'source_to_layout':.25,'texture_filter':'nearest','mipmaps':False,
        'reels':[{'aperture':rect(x+4,REEL_TOP,REEL_W,REEL_H),
                  'symbol':rect(x+4,SYMBOL_TOP,REEL_W,SYMBOL_H),
                  'top_adjacent':rect(x+4,224,58,17),
                  'bottom_adjacent':rect(x+4,305,58,14),
                  'touch':rect(x+4,REEL_TOP,REEL_W,REEL_H)} for x in REEL_X],
        'powers':[{'center_source':[x*2,921],'touch':rect(x-25,439,50,55)} for x,_ in POWER_SOCKETS],
        'spin':{'touch':rect(99,503,110,49),'cap':rect(97,506,114,43)},
        'spins_readout':rect(38,514,43,24),
        'stash':[{'touch':rect(x-17,507,34,42)} for x in STASH_X],
        'account':rect(46,357,228,65),
        # Reserve four full-size digits for the existing 5,000 goal. The
        # three-digit mockup is right-aligned inside this larger live field.
        'wealth':rect(55,382,69,21),'target':rect(192,382,69,21),
        'progress':rect(56,411,166,3),'multiplier':rect(239,405,22,14),
        'countdown':{'pips':[rect(86+i*14,191,9,3) for i in range(10)],
                     'warnings':[rect(244+i*9,190,5,5) for i in range(3)]},
        'restore_lamps':[rect(x+27,208,12,3) for x in REEL_X],
        'active_items':[rect(48+i*45,573,35,17) for i in range(5)],
        'cash_tray':rect(117,596,86,23),
        'augment_tabs':[rect(x,598,21,15) for x in (47,72,97)],
        'menu':rect(267,9,40,24),
    }
