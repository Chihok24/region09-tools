/* Region 9 AP Alert extra exports: PNG picture and Outlook template (.oft). Needs vendor/r9-cfb.js. */
(function(){
var BODY=["Team,","","Please communicate the attached AP Alert.","","Ensure that all MEAs, Frontline Team Members, Cart Retrievers, BOPIC Team Members, Recovery Team Members, Utility Clerks and MODs are informed, as it is critical that we identify these subjects immediately upon entry.","","Please print the attached AP Alert in color and post it in the following locations:","","Employee Breakroom AP Board","Front Door AP Binder","Additionally, review this alert during all team huddles.","Reminder: These alerts must be reviewed promptly upon receipt, communicated to the team after printing, and kept readily available for reference should an individual matching the description enter the club. Please contact your RAPM immediately with any sightings or relevant information."];
function esc(t){return t.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;")}
var P='<p class=MsoNormal style="margin:0">';
function html(cid){var b=BODY,o=[];
 o.push(P+esc(b[0])+'</p>',P+'&nbsp;</p>',P+esc(b[2])+'</p>',P+'&nbsp;</p>',P+esc(b[4])+'</p>',P+'&nbsp;</p>',P+esc(b[6])+'</p>',P+'&nbsp;</p>');
 o.push('<ul style="margin-top:0;margin-bottom:0"><li>'+esc(b[8])+'</li><li>'+esc(b[9])+'</li></ul>');
 o.push(P+esc(b[10])+'</p>',P+esc(b[11])+'</p>',P+'&nbsp;</p>');
 o.push(P+'<img src="cid:'+cid+'" width="612" alt="AP Alert" style="width:6.375in;max-width:100%"></p>');
 return '<html><head><meta http-equiv="Content-Type" content="text/html; charset=utf-8"><style>body,p,li{font-family:Calibri,Arial,sans-serif;font-size:11pt}</style></head><body>'+o.join("")+'</body></html>';}
function dl(blob,name){var a=document.createElement("a");a.href=URL.createObjectURL(blob);a.download=name;document.body.append(a);a.click();a.remove();setTimeout(function(){URL.revokeObjectURL(a.href)},6e4)}
async function png(pdfFile,pdfjs){var buf=new Uint8Array(await pdfFile.arrayBuffer());var d=await pdfjs.getDocument({data:buf,isEvalSupported:!1}).promise;var pg=await d.getPage(1),v=pg.getViewport({scale:2.5});var c=document.createElement("canvas");c.width=Math.round(v.width);c.height=Math.round(v.height);var x=c.getContext("2d");x.fillStyle="#fff";x.fillRect(0,0,c.width,c.height);await pg.render({canvasContext:x,viewport:v}).promise;d.destroy&&d.destroy();return await new Promise(function(r){c.toBlob(r,"image/png")})}
function u16(s){var a=new Uint8Array(s.length*2+2);for(var i=0;i<s.length;i++){var c=s.charCodeAt(i);a[2*i]=c&255;a[2*i+1]=c>>8}return a}
function hex4(n){return("0000"+n.toString(16).toUpperCase()).slice(-4)}
function hex8(n){return("00000000"+(n>>>0).toString(16).toUpperCase()).slice(-8)}
/* props: [id,type,value]; returns {streams, propbytes} */
function props(list,hdr){var fixed=[],streams=[];list.forEach(function(p){var id=p[0],t=p[1],v=p[2],e=new Uint8Array(16),dv=new DataView(e.buffer);dv.setUint32(0,(id<<16|t)>>>0,!0);dv.setUint32(4,6,!0);
 if(t===3){dv.setInt32(8,v,!0)}else if(t===11){dv.setUint16(8,v?1:0,!0)}else{var data=t===31?u16(v).subarray(0,v.length*2):v;streams.push(["__substg1.0_"+hex4(id)+hex4(t),data]);dv.setUint32(8,t===31?data.length+2:data.length,!0)}fixed.push(e)});
 var out=new Uint8Array(hdr.length+16*fixed.length);out.set(hdr,0);fixed.forEach(function(e,i){out.set(e,hdr.length+16*i)});streams.push(["__properties_version1.0",out]);return streams}
function oft(o){var F={};
 var top=new Uint8Array(32),dv=new DataView(top.buffer);dv.setUint32(8,0,!0);dv.setUint32(12,o.atts.length,!0);dv.setUint32(16,0,!0);dv.setUint32(20,o.atts.length,!0);
 var plain=BODY.join("\r\n")+"\r\n";
 var L=[[0x001A,31,"IPM.Note"],[0x0037,31,o.subject],[0x0E1D,31,o.subject],[0x1000,31,plain],[0x1013,258,new TextEncoder().encode(o.html)],[0x3FDE,3,65001],[0x0E07,3,8],[0x340D,3,0x00040000],[0x0E1B,11,1],[0x0017,3,1]];
 function add(path,data){F[path]=data}
 props(L,top).forEach(function(s){add("/"+s[0],s[1])});
 ["00020102","00030102","00040102"].forEach(function(n){add("/__nameid_version1.0/__substg1.0_"+n,new Uint8Array(0))});
 o.atts.forEach(function(a,i){var dir="/__attach_version1.0_#"+hex8(i)+"/";var A=[[0x3705,3,1],[0x3701,258,a.data],[0x3704,31,a.name],[0x3707,31,a.name],[0x3001,31,a.name],[0x370E,31,a.mime],[0x0E21,3,i],[0x370B,3,-1]];
  if(a.cid){A.push([0x3712,31,a.cid],[0x3714,3,4],[0x7FFE,11,1])}
  props(A,new Uint8Array(8)).forEach(function(s){add(dir+s[0],s[1])})});
 return window.r9cfb(F,"0B0D020000000000C000000000000046")}
window.r9apx=async function(mode,pdfFile,pdfName,form,pdfjs){var base=pdfName.replace(/\.pdf$/i,"");var img=await png(pdfFile,pdfjs);
 if(mode==="png"){dl(img,base+".png");return base+".png"}
 var title=["AP Alert",form.scope&&form.scope+" ALERT",form.incidentType&&form.incidentType.trim(),form.impactedClubs&&"Club "+form.impactedClubs.trim(),form.caseNumber&&"Case "+form.caseNumber.trim()].filter(Boolean);
 var subject=title[0]+" - "+title.slice(1).join(" - ");var cid="apalert-"+Date.now()+"@region9";
 var bytes=oft({subject:subject,html:html(cid),atts:[{name:base+".png",mime:"image/png",data:new Uint8Array(await img.arrayBuffer()),cid:cid},{name:pdfName,mime:"application/pdf",data:new Uint8Array(await pdfFile.arrayBuffer())}]});
 dl(new Blob([bytes],{type:"application/vnd.ms-outlook"}),base+".oft");return base+".oft"};
})();
