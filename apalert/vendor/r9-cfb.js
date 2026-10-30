/* Minimal Compound File Binary (OLE2) writer, v3 / 512-byte sectors. Region 9. window.r9cfb(files) -> Uint8Array.
   files: {"path/inside/stream": Uint8Array}; storages are implied by paths. rootClsid: 16-byte hex string (optional). */
(function(){
var FREE=0xFFFFFFFF,END=0xFFFFFFFE,FATS=0xFFFFFFFD,DIFS=0xFFFFFFFC,NOS=0xFFFFFFFF;
function cmp(a,b){if(a.length!==b.length)return a.length-b.length;var A=a.toUpperCase(),B=b.toUpperCase();return A<B?-1:A>B?1:0}
window.r9cfb=function(files,rootClsid){
 var root={name:"Root Entry",type:5,kids:{},clsid:rootClsid};
 Object.keys(files).forEach(function(p){var parts=p.split("/").filter(Boolean),n=root;for(var i=0;i<parts.length-1;i++){n=n.kids[parts[i]]||(n.kids[parts[i]]={name:parts[i],type:1,kids:{}})}n.kids[parts[parts.length-1]]={name:parts[parts.length-1],type:2,data:files[p]}});
 var ents=[];(function walk(n){n.id=ents.length;ents.push(n);if(n.kids){var k=Object.values(n.kids).sort(function(a,b){return cmp(a.name,b.name)});k.forEach(walk);
   n.child=(function bal(lo,hi){if(lo>hi)return NOS;var m=(lo+hi)>>1,x=k[m];x.L=bal(lo,m-1);x.R=bal(m+1,hi);return x.id})(0,k.length-1)}})(root);
 // mini stream
 var mini=[],miniLen=0,big=[];ents.forEach(function(e){if(e.type!==2)return;var n=e.data.length;if(n===0){e.start=END;return}if(n<4096){e.mini=true;e.start=miniLen/64;mini.push(e);miniLen+=Math.ceil(n/64)*64}else big.push(e)});
 var nMiniSec=miniLen/64,minifatSecs=Math.ceil(nMiniSec*4/512),ministreamSecs=Math.ceil(miniLen/512),dirSecs=Math.ceil(ents.length*128/512);
 var bigSecs=0;big.forEach(function(e){bigSecs+=Math.ceil(e.data.length/512)});
 var nFat=1,nDif=0;for(;;){var tot=nFat+nDif+dirSecs+minifatSecs+ministreamSecs+bigSecs;var needF=Math.ceil(tot/128),needD=needF>109?Math.ceil((needF-109)/127):0;if(needF===nFat&&needD===nDif)break;nFat=needF;nDif=needD}
 var total=nDif+nFat+dirSecs+minifatSecs+ministreamSecs+bigSecs,out=new Uint8Array(512+total*512),dv=new DataView(out.buffer);
 var fat=new Uint32Array(nFat*128).fill(FREE),cur=0;
 function chain(n){var s=cur;for(var i=0;i<n;i++)fat[cur+i]=i===n-1?END:cur+i+1;cur+=n;return n?s:END}
 var difStart=cur;for(var i=0;i<nDif;i++)fat[cur++]=DIFS;var fatStart=cur;for(i=0;i<nFat;i++)fat[cur++]=FATS;
 var dirStart=chain(dirSecs),mfStart=chain(minifatSecs),msStart=chain(ministreamSecs);
 big.forEach(function(e){e.start=chain(Math.ceil(e.data.length/512))});
 function off(s){return 512+s*512}
 // header
 out.set([0xD0,0xCF,0x11,0xE0,0xA1,0xB1,0x1A,0xE1],0);dv.setUint16(24,0x3E,!0);dv.setUint16(26,3,!0);dv.setUint16(28,0xFFFE,!0);dv.setUint16(30,9,!0);dv.setUint16(32,6,!0);
 dv.setUint32(44,nFat,!0);dv.setUint32(48,dirStart,!0);dv.setUint32(56,4096,!0);dv.setUint32(60,minifatSecs?mfStart:END,!0);dv.setUint32(64,minifatSecs,!0);dv.setUint32(68,nDif?difStart:END,!0);dv.setUint32(72,nDif,!0);
 for(i=0;i<109;i++)dv.setUint32(76+4*i,i<nFat?fatStart+i:FREE,!0);
 for(var d=0;d<nDif;d++){var o=off(difStart+d);for(var j=0;j<127;j++){var fi=109+d*127+j;dv.setUint32(o+4*j,fi<nFat?fatStart+fi:FREE,!0)}dv.setUint32(o+508,d===nDif-1?END:difStart+d+1,!0)}
 for(i=0;i<fat.length;i++)dv.setUint32(off(fatStart)+4*i,fat[i],!0);
 // minifat + ministream
 var mfo=off(mfStart),mfi=0;for(i=0;i<minifatSecs*128;i++)dv.setUint32(mfo+4*i,FREE,!0);
 mini.forEach(function(e){var n=Math.ceil(e.data.length/64);for(var k=0;k<n;k++){dv.setUint32(mfo+4*(e.start+k),k===n-1?END:e.start+k+1,!0)}out.set(e.data,off(msStart)+e.start*64)});
 big.forEach(function(e){out.set(e.data,off(e.start))});
 root.start=ministreamSecs?msStart:END;root.size=miniLen;
 // directory
 var dO=off(dirStart);for(i=0;i<dirSecs*4;i++){var b=dO+i*128;if(i>=ents.length){dv.setUint32(b+68,NOS,!0);dv.setUint32(b+72,NOS,!0);dv.setUint32(b+76,NOS,!0);continue}
  var e=ents[i];for(j=0;j<e.name.length;j++)dv.setUint16(b+2*j,e.name.charCodeAt(j),!0);dv.setUint16(b+64,2*(e.name.length+1),!0);out[b+66]=e.type;out[b+67]=1;
  dv.setUint32(b+68,e.L===undefined?NOS:e.L,!0);dv.setUint32(b+72,e.R===undefined?NOS:e.R,!0);dv.setUint32(b+76,e.child===undefined?NOS:e.child,!0);
  if(e.clsid)for(j=0;j<16;j++)out[b+80+j]=parseInt(e.clsid.substr(2*j,2),16);
  if(e.type===2){dv.setUint32(b+116,e.start,!0);dv.setUint32(b+120,e.data.length,!0)}else if(e.type===5){dv.setUint32(b+116,root.start,!0);dv.setUint32(b+120,root.size,!0)}}
 return out};
})();
