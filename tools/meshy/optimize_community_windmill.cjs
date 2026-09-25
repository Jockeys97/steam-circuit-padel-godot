#!/usr/bin/env node
// Offline second-stage reduction for Meshy's densely disconnected windmill mesh.
// Run after a glTF Transform texture resize/weld pass. Dependencies are installed
// in a temporary npm prefix; set NODE_PATH to that prefix's node_modules.
const { NodeIO } = require('@gltf-transform/core');
const { MeshoptSimplifier } = require('meshoptimizer');

async function main() {
  const [input, output, ratioArg = '0.15', errorArg = '0.05'] = process.argv.slice(2);
  if (!input || !output || input === output) {
    throw new Error('Usage: optimize_community_windmill.cjs input.glb output.glb [triangle_ratio] [error]');
  }
  const ratio = Number(ratioArg);
  const errorLimit = Number(errorArg);
  if (!(ratio > 0 && ratio < 1) || !(errorLimit > 0 && errorLimit <= 1)) {
    throw new Error('Expected 0 < triangle_ratio < 1 and 0 < error <= 1');
  }

  const io = new NodeIO();
  const document = await io.read(input);
  const meshes = document.getRoot().listMeshes();
  if (meshes.length !== 1 || meshes[0].listPrimitives().length !== 1) {
    throw new Error('Expected exactly one mesh primitive; inspect the source before changing this script');
  }
  const primitive = meshes[0].listPrimitives()[0];
  const original = primitive.getIndices().getArray();
  const positions = primitive.getAttribute('POSITION').getArray();
  if (!(original instanceof Uint32Array) || !(positions instanceof Float32Array)) {
    throw new Error('Expected Uint32 indices and Float32 positions from the first-stage GLB');
  }
  await MeshoptSimplifier.ready;
  const target = Math.floor(original.length * ratio / 3) * 3;
  const [reduced, measuredError] = MeshoptSimplifier.simplifySloppy(
    original, positions, 3, null, target, errorLimit,
  );
  if (reduced.length >= original.length || reduced.length % 3 !== 0) {
    throw new Error('Sloppy simplification did not produce a valid reduction');
  }

  // Compact every attribute together with the index buffer. Merely replacing
  // indices leaves the original million-vertex payload in the GLB and VRAM.
  const remap = new Map();
  const compactIndices = new Uint32Array(reduced.length);
  for (let i = 0; i < reduced.length; i++) {
    const sourceIndex = reduced[i];
    let compactIndex = remap.get(sourceIndex);
    if (compactIndex === undefined) {
      compactIndex = remap.size;
      remap.set(sourceIndex, compactIndex);
    }
    compactIndices[i] = compactIndex;
  }
  for (const semantic of primitive.listSemantics()) {
    const accessor = primitive.getAttribute(semantic);
    const source = accessor.getArray();
    const stride = accessor.getElementSize();
    const compact = new source.constructor(remap.size * stride);
    for (const [sourceIndex, compactIndex] of remap) {
      for (let component = 0; component < stride; component++) {
        compact[compactIndex * stride + component] = source[sourceIndex * stride + component];
      }
    }
    accessor.setArray(compact);
  }
  primitive.getIndices().setArray(compactIndices);
  await io.write(output, document);
  console.log(JSON.stringify({
    inputTriangles: original.length / 3,
    outputTriangles: compactIndices.length / 3,
    outputVertices: remap.size,
    measuredError,
  }));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
