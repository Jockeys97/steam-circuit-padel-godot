import fs from 'node:fs/promises';
import sharp from 'sharp';
const input = new URL('../meshy/carioca-pilot/image-v2.glb', import.meta.url);
const output = new URL('../godot/assets/arenas/carioca/sugarloaf.glb', import.meta.url);
const b = await fs.readFile(input);
const jsonSize=b.readUInt32LE(12);
const j=JSON.parse(b.subarray(20,20+jsonSize).toString());
const bin=b.subarray(28+jsonSize);
const images=new Map(j.images.map(x=>[x.bufferView,x]));
const parts=[];
let offset=0;
for(let i=0;i<j.bufferViews.length;i++){
 const view=j.bufferViews[i];
 let data=bin.subarray(view.byteOffset||0,(view.byteOffset||0)+view.byteLength);
 if(images.has(i)){
  data=await sharp(data).resize({width:1024,height:1024,fit:'inside',withoutEnlargement:true}).png().toBuffer();
  images.get(i).mimeType='image/png';
 }
 view.byteOffset=offset; view.byteLength=data.length;
 const pad=Buffer.alloc((4-data.length%4)%4);
 parts.push(data,pad); offset+=data.length+pad.length;
}
j.buffers[0].byteLength=offset;
const json=Buffer.from(JSON.stringify(j));
const jp=Buffer.alloc((4-json.length%4)%4,32);
const header=Buffer.alloc(20);
header.write('glTF'); header.writeUInt32LE(2,4);
header.writeUInt32LE(28+json.length+jp.length+offset,8);
header.writeUInt32LE(json.length+jp.length,12);header.writeUInt32LE(0x4e4f534a,16);
const bh=Buffer.alloc(8);bh.writeUInt32LE(offset);bh.writeUInt32LE(0x004e4942,4);
await fs.mkdir(new URL('.',output),{recursive:true});
const result=Buffer.concat([header,json,jp,bh,...parts]);
await fs.writeFile(output,result);
console.log(JSON.stringify({sourceBytes:b.length,runtimeBytes:result.length,textures:images.size}));
