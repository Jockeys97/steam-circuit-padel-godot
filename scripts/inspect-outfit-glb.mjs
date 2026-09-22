import {readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
async function inspect(path) {
  const data = await readFile(path);
  if(data.readUInt32LE(0)!==0x46546c67) throw Error('Not GLB');
  const length=data.readUInt32LE(12);
  const json=JSON.parse(data.subarray(20,20+length).toString());
  const bin=data.subarray(28+length);
  const componentBytes={5120:1,5121:1,5122:2,5123:2,5125:4,5126:4};
  const dimensions={SCALAR:1,VEC2:2,VEC3:3,VEC4:4,MAT4:16};
  function accessor(id) {
    if(id===undefined)return null;
    const a=json.accessors[id],v=json.bufferViews[a.bufferView];
    if(a.sparse)throw Error('Sparse accessor unsupported');
    const width=componentBytes[a.componentType]*dimensions[a.type];
    const hash=createHash('sha256');
    for(let i=0;i<a.count;i++) {
      const offset=(v.byteOffset??0)+(a.byteOffset??0)+i*(v.byteStride??width);
      hash.update(bin.subarray(offset,offset+width));
    }
    return {count:a.count,type:a.type,componentType:a.componentType,sha256:hash.digest('hex')};
  }
  function uvTriangles(p) {
    function values(id) {
      const a=json.accessors[id],v=json.bufferViews[a.bufferView];
      const n=dimensions[a.type],width=componentBytes[a.componentType];
      const method={5123:'readUInt16LE',5125:'readUInt32LE',5126:'readFloatLE'}[a.componentType];
      if(!method)throw Error('Unsupported UV/index component type');
      return Array.from({length:a.count},(_,i)=>Array.from({length:n},(_,k)=>bin[method]((v.byteOffset??0)+(a.byteOffset??0)+i*(v.byteStride??n*width)+k*width)));
    }
    const uv=values(p.attributes.TEXCOORD_0),indices=values(p.indices).flat(),triangles=[];
    for(let i=0;i<indices.length;i+=3)triangles.push(indices.slice(i,i+3).map(index=>uv[index].map(v=>Math.round(v*100000)).join(',')).sort().join('|'));
    return {triangles:triangles.length,roundedUvTriangleSha256:createHash('sha256').update(triangles.sort().join('\n')).digest('hex')};
  }
  const meshes=json.meshes.map(m=>({
    name:m.name,
    primitives:m.primitives.map(p=>({
      mode:p.mode??4,
      indices:accessor(p.indices),
      uvTopology:uvTriangles(p),
      attributes:Object.fromEntries(Object.entries(p.attributes).map(([k,id])=>[k,accessor(id)]))
    }))
  }));
  return {path,bytes:data.length,skins:json.skins?.map(s=>({joints:s.joints.length}))??[],animations:json.animations?.map(a=>a.name)??[],materials:json.materials?.length??0,meshes};
}
for(const path of process.argv.slice(2))console.log(JSON.stringify(await inspect(path)));
