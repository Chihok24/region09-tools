import sys
for f in sys.argv[1:]:
    s=open(f).read()
    if 'createElement(`form`);o.method=`POST`' not in s: continue
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

# PDF typography to match the live preview (two-line title, bigger fields/synopsis/footer, photos right after synopsis).
import re
def R(s,a,b):
    assert a in s, a[:60]; return s.replace(a,b,1)
for f in sys.argv[1:]:
    s=open(f).read()
    if 'r9pdfv2' in s: continue
    i=s.index('function lc(e,t,n,r,i,a,o,s){'); j=s.index('async function dc(',i)
    seg=s[i:j]
    seg=seg.replace(',9)',',12)').replace('size:9','size:12').replace('(i+1)*12','(i+1)*16').replace('n-12*(','n-16*(').replace('n-12}','n-16}')
    seg=seg.replace('y:n-1,width:8,height:8','y:n-1.5,width:10,height:10').replace('s+6.4','s+8.4').replace('n+5.4','n+7.4')
    s=s[:i]+seg+s[j:]
    s=R(s,'c=756-s;','c=723-s/2;/*r9pdfv2*/')
    a=s.index('let l=`ASSET PROTECTION `'); b=s.index('let v=c-12;',a)
    s=s[:a]+'let l=`ASSET PROTECTION`,u=e.scope||`Choose an item.`,d=` ALERT`,f=e.scope?r:a,p=e.scope?tc:rc,m2=e=>f.widthOfTextAtSize(u,e)+r.widthOfTextAtSize(d,e),h=31;for(;h>18&&Math.max(r.widthOfTextAtSize(l,h),m2(h))>420;)--h;n.drawText(l,{x:(Zs-r.widthOfTextAtSize(l,h))/2,y:756-h*.78,size:h,font:r,color:tc});let g=(Zs-m2(h))/2,_=756-h*.78-h*1.18;n.drawText(u,{x:g,y:_,size:h,font:f,color:p}),g+=f.widthOfTextAtSize(u,h),n.drawText(d,{x:g,y:_,size:h,font:r,color:tc});let v=Math.min(c,_-h*.25)-10;'+s[b+len('let v=c-12;'):]
    s=R(s,'b=v-18,','b=v-20,')
    s=R(s,'n.drawRectangle({x:$s,y:w-16,width:ec,height:16,color:tc}),sc(n,`SYNOPSIS`,w-12,r,9,ro(1,1,1)),w-=32;','n.drawRectangle({x:$s,y:w-18,width:ec,height:18,color:tc}),sc(n,`SYNOPSIS`,w-13.5,r,10.5,ro(1,1,1)),w-=36;')
    s=R(s,'for(let e of E){for(let t of oc(e,i,11,ec))n.drawText(t,{x:$s,y:w,size:11,font:i,color:nc}),w-=14;w-=6}',
      'let Z=12;for(;Z>8;Z-=.5){let H=0;for(let e of E)H+=oc(e,i,Z,ec).length*Z*1.42+6;if(w-H>=(e.photos.length?230:105))break}for(let e of E){for(let t of oc(e,i,Z,ec))n.drawText(t,{x:$s,y:w,size:Z,font:i,color:nc}),w-=Z*1.42;w-=6}')
    s=R(s,'te=Math.max(72,N-92)','te=Math.max(72,N-118)')
    s=R(s,'ie=N-Math.max(0,(te-re)/2);','ie=N;')
    s=R(s,'observed in the club.`,74,r,10,nc)','observed in the club.`,94,r,12,nc),n.drawLine({start:{x:$s,y:80},end:{x:572,y:80},thickness:.6,color:rc})')
    s=R(s,'INCIDENT`,46,r,7,nc)','INCIDENT`,64,r,10,nc)')
    s=R(s,'a,7,528).forEach((e,t)=>sc(n,e,34-t*9,a,7,rc))','a,9.5,528).forEach((e,t)=>sc(n,e,50-t*12,a,9.5,rc))')
    open(f,'w').write(s); print('pdfv2',f)

# HEIC/HEIF photos: convert client-side with vendored heic2any (apalert/vendor/heic2any.min.js, lazy-loaded).
for f in sys.argv[1:]:
    s=open(f).read()
    if 'r9heic' in s: continue
    base=os.path.dirname(os.path.dirname(f))
    pre='/region09-tools/apalert/' if '/ghp/' in os.path.abspath(f) else '/apalert/'
    H=('const r9isheic=e=>/^image\\/hei[cf]/i.test(e.type)||/\\.hei[cf]$/i.test(e.name||``);'
       'let r9hp;const r9heic=async e=>{if(!r9isheic(e))return e;try{return await createImageBitmap(e),e}catch{}'
       'r9hp||(r9hp=new Promise((t,n)=>{let r=document.createElement(`script`);r.src=`'+pre+'vendor/heic2any.min.js`;r.onload=()=>t(window.heic2any);r.onerror=()=>{r9hp=null,n(Error(`HEIC decoder failed to load`))};document.head.append(r)}));'
       'let t=await r9hp,n=await t({blob:e,toType:`image/jpeg`,quality:.92});return Array.isArray(n)&&(n=n[0]),n};')
    s=R(s,'async function Bc(e){let t=await createImageBitmap(e),',H+'async function Bc(e){let t=await createImageBitmap(await r9heic(e)),')
    s=R(s,'filter(e=>e.type.startsWith(`image/`))','filter(e=>e.type.startsWith(`image/`)||r9isheic(e))')
    s=R(s,'accept:`image/*`,multiple','accept:`image/*,.heic,.heif,image/heic,image/heif`,multiple')
    os.makedirs(os.path.join(base,'vendor'),exist_ok=True)
    shutil.copy('/workspace/heictest/node_modules/heic2any/dist/heic2any.min.js',os.path.join(base,'vendor','heic2any.min.js'))
    open(f,'w').write(s); print('heic',f)

# Extra exports: 'Export picture' (PNG at 2.5x of the PDF page) and 'Export email' (.oft Outlook template with inline image + PDF attached).
# Code lives in apalert/vendor/r9-apexport.js + vendor/r9-cfb.js (own minimal OLE/CFB writer), copied from /workspace/region09/apx/, lazy-loaded.
for f in sys.argv[1:]:
    s=open(f).read()
    if 'r9apxv1' in s: continue
    base=os.path.dirname(os.path.dirname(f))
    pre='/region09-tools/apalert/' if '/ghp/' in os.path.abspath(f) else '/apalert/'
    L=('let r9xp;const r9ld=e=>new Promise((t,n)=>{let r=document.createElement(`script`);r.src=`'+pre+'vendor/`+e+`?v=2`;r.onload=t;r.onerror=()=>n(Error(`Export helper failed to load`));document.head.append(r)});'
       'const r9xload=()=>r9xp||(r9xp=Promise.all([r9ld(`r9-cfb.js`),r9ld(`r9-apexport.js`)]).catch(e=>{throw r9xp=null,e}));'
       'const r9pdfjs=async()=>{let t=await s(()=>import(`./pdf-DIIIQF8Y.js`),__vite__mapDeps([0,1])),n=await s(()=>import(`./pdf.worker.min-WWY7VKxM.js`),[]);return t.GlobalWorkerOptions&&(t.GlobalWorkerOptions.workerSrc=n.default),t};/*r9apxv1*/')
    s=R(s,'async function Dc(e){',L+'async function Dc(e){')
    s=R(s,'async function N(){if(!te.length){','async function N(r9m){if(typeof r9m!=`string`&&(r9m=null),!te.length){')
    s=R(s,'a=new File([r],i,{type:`application/pdf`}),o=document.createElement(`a`);',
      'a=new File([r],i,{type:`application/pdf`});if(r9m){await r9xload();b(await window.r9apx(r9m,a,i,e,await r9pdfjs()));return}let o=document.createElement(`a`);')
    BTN=lambda m,lab,busy: '(0,$.jsx)(`button`,{type:`button`,onClick:()=>N(`'+m+'`),disabled:s||te.length>0,className:`flex h-11 flex-1 items-center justify-center gap-2 rounded-md border-2 border-alert bg-sheet font-display text-base tracking-wide text-alert transition hover:bg-alert hover:text-paper disabled:cursor-not-allowed disabled:opacity-50`,children:[(0,$.jsx)(l,{className:`size-4`,"aria-hidden":`true`}),`'+lab+'`]})'
    a='s?`Building alert…`:`Download PDF alert`]}),'
    s=R(s,a,a+'(0,$.jsxs)(`div`,{className:`mt-2 flex gap-2`,children:['+BTN('png','Export picture','')+','+BTN('oft','Export email (.oft)','')+']}),')
    os.makedirs(os.path.join(base,'vendor'),exist_ok=True)
    for n in ('r9-apexport.js','r9-cfb.js'): shutil.copy('/workspace/region09/apx/'+n,os.path.join(base,'vendor',n))
    open(f,'w').write(s); print('apx',f)

# Matching static HTML for the export buttons in index.html (avoids a React hydration mismatch).
for f in sys.argv[1:]:
    p=os.path.join(os.path.dirname(os.path.dirname(f)),'index.html'); h=open(p).read()
    if 'Export picture' in h: continue
    h=R(h,'Download PDF alert</button>','Download PDF alert</button>'+open('/workspace/region09/apx/buttons.html').read().strip())
    open(p,'w').write(h); print('apx-html',p)
