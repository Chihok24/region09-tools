#!/usr/bin/env python3
"""Re-runnable: make Alarm Exceptions resolve the area from the partition NAME
(e.g. 'PARTITION 1 - CASH OFFICE') before the O/C number, since some clubs
wire cash office / perimeter / employee entry to different partition numbers."""
import glob,sys
FN=("function r9Area(f,h,m){for(let s of[f,h]){if(!s)continue;let x=String(s).match(/partition\\s*\\d+\\s*-\\s*([a-z][a-z ]*)/i);"
    "if(!x)continue;let n=x[1].toLowerCase();if(/\\bcash\\s*office/.test(n))return 2;if(/\\bperim/.test(n))return 1;"
    "if(/\\bemployee(\\s*entr|\\s*$)/.test(n))return 5;if(/\\bgas/.test(n))break;return null}return an(m,`${f} ${h}`)}")
OLD="let _=an(m,`${f} ${h}`);"
NEW="let _=r9Area(f,h,m);"
for root in sys.argv[1:] or ['/workspace/region09','/workspace/r09repo','/workspace/ghp']:
    for p in glob.glob(root+'/alarm/assets/routes-*.js'):
        s=open(p).read()
        if 'function r9Area(' in s: print('already',p); continue
        assert s.count(OLD)==1 and s.count('function an(e,t=``)')==1, p
        s=s.replace(OLD,NEW).replace('function an(e,t=``)',FN+'function an(e,t=``)')
        open(p,'w').write(s); print('patched',p)
