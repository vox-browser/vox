// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

fn webgl_extension_slot_bootstrap() string {
	return r'
const __webglExtensionSlots=(function(){
 const apply=Reflect.apply,W=WeakMap,get=W.prototype.get,set=W.prototype.set,T=TypeError,store=new W;
 return {record:function(receiver,type){const value=apply(get,store,[receiver]);if(value===undefined||value.type!==type)throw new T("Not an object of type "+type);return value;},install:function(object,state,type){apply(set,store,[object,{state,type}])}};
})();
'
}

// Names are copied from available_webgl_extensions factories; all implemented
// extension IDLs use LegacyNoInterfaceObject. Native V owns extension behavior.
fn webgl_extension_interface_bootstrap() string {
	return r'
const __webglCreateExtension=(function(){
 const slots=__webglContextSlots,objectPrototype=Object.prototype,prototypes={},I=__webglBuildIntrinsics,types={ANGLE_instanced_arrays:"ANGLEInstancedArrays",EXT_blend_minmax:"EXTBlendMinMax",EXT_color_buffer_float:"EXTColorBufferFloat",EXT_render_snorm:"EXTRenderSnorm",EXT_texture_filter_anisotropic:"EXTTextureFilterAnisotropic",EXT_texture_norm16:"EXTTextureNorm16",OES_element_index_uint:"OESElementIndexUint",OES_standard_derivatives:"OESStandardDerivatives",OES_vertex_array_object:"OESVertexArrayObject",WEBGL_compressed_texture_s3tc:"WebGLCompressedTextureS3tc",WEBGL_compressed_texture_s3tc_srgb:"WebGLCompressedTextureS3tcSrgb",WEBGL_debug_renderer_info:"WebGLDebugRendererInfo",WEBGL_draw_buffers:"WebGLDrawBuffers"};
 let methods=null;
 // Extension prototypes are built with the first getExtension call.
 function build(){
 methods={ANGLEInstancedArrays:{drawArraysInstancedANGLE:[[4,["GLenum","GLint","GLsizei","GLsizei"],"undefined"]],drawElementsInstancedANGLE:[[5,["GLenum","GLsizei","GLenum","GLintptr","GLsizei"],"undefined"]],vertexAttribDivisorANGLE:[[2,["GLuint","GLuint"],"undefined"]]},OESVertexArrayObject:{createVertexArrayOES:[[0,[],"WebGLVertexArrayObjectOES"]],deleteVertexArrayOES:[[1,["WebGLVertexArrayObjectOES?"],"undefined"]],isVertexArrayOES:[[1,["WebGLVertexArrayObjectOES?"],"boolean"]],bindVertexArrayOES:[[1,["WebGLVertexArrayObjectOES?"],"undefined"]]},WebGLDrawBuffers:{drawBuffersWEBGL:[[1,["sequence<GLenum>"],"undefined"]]}};
 const extensionConstants=__webglExtensionConstants(),canonicals=I.apply(I.keys,I.O,[types]);
 for(let i=0;i<canonicals.length;i++){const canonical=canonicals[i],type=types[canonical],prototype=slots.create(objectPrototype),constants=extensionConstants[canonical]||extensionConstants[type]||{},operations=methods[type]||{};
  const constantKeys=I.apply(I.keys,I.O,[constants]);
  for(let j=0;j<constantKeys.length;j++){const key=constantKeys[j];slots.property(prototype,key,{value:constants[key],enumerable:true});}
  const operationNames=I.apply(I.keys,I.O,[operations]);
  for(let j=0;j<operationNames.length;j++){const name=operationNames[j];slots.property(prototype,name,{value:__webglMethod(null,name,operations[name],type),writable:true,enumerable:true,configurable:true});}
  slots.property(prototype,I.toStringTag,{value:type,configurable:true});prototypes[canonical]=prototype;
 }
 }
 return function(canonical,state,empty){if(empty)return slots.create(objectPrototype);if(methods===null)build();const object=slots.create(prototypes[canonical]);__webglExtensionSlots.install(object,state,types[canonical]);return object;};
})();
'
}
