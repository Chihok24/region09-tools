import sys
for f in sys.argv[1:]:
    s=open(f).read()
    a=s.index('o=document.createElement(`form`);o.method=`POST`'); b=s.index('o.submit(),o.remove(),',a)+len('o.submit(),o.remove(),')
    s=s[:a]+'o=document.createElement(`a`);o.href=URL.createObjectURL(a),o.download=i,document.body.append(o),o.click(),o.remove(),setTimeout(()=>URL.revokeObjectURL(o.href),6e4),'+s[b:]
    open(f,'w').write(s); print('ok',f)

# No preloaded sample: drop the auto-load effect and the bundled sample PDF.
import os, shutil
for f in sys.argv[1:]:
    s=open(f).read()
    s=s.replace('(0,m.useEffect)(()=>(O(++T.current),()=>{','(0,m.useEffect)(()=>(()=>{')
    open(f,'w').write(s)
    d=os.path.join(os.path.dirname(os.path.dirname(f)),'sample')
    if os.path.isdir(d): shutil.rmtree(d)
    print('no-sample',f)
