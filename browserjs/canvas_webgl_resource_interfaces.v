// Copyright (c) 2024, Jelle Raaijmakers <jelle@ladybird.org>
// Copyright (c) 2024, Aliaksandr Kalenik <kalenik.aliaksandr@gmail.com>
// Copyright (c) 2024, Luke Wilde <luke@ladybird.org>
// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

// Generated resource interface inheritance/brands, WebGLObject label accessors,
// and AbstractOperations::to_utf16_usv_string through the actual engine builtin.
fn webgl_resource_interface_bootstrap() string {
	return r'
const __webglResources=(function(){
 const O=Object,apply=Reflect.apply,create=O.create,setPrototype=O.setPrototypeOf,W=WeakMap,get=W.prototype.get,set=W.prototype.set,T=TypeError,wellFormed=String.prototype.toWellFormed,slots=__webglContextSlots,records=new W,cache=apply(create,O,[null]),prototypes=apply(create,O,[null]);
 const names={buffer:"WebGLBuffer",framebuffer:"WebGLFramebuffer",renderbuffer:"WebGLRenderbuffer",texture:"WebGLTexture",shader:"WebGLShader",program:"WebGLProgram",query:"WebGLQuery",sampler:"WebGLSampler",sync:"WebGLSync",transform_feedback:"WebGLTransformFeedback",vertex_array:"WebGLVertexArrayObject",vertex_array_oes:"WebGLVertexArrayObjectOES",uniform_location:"WebGLUniformLocation"};
 const Base=slots.constructor("WebGLObject"),base=Base.prototype;
 slots.property(globalThis,"WebGLObject",{value:Base,writable:true,configurable:true});slots.property(base,Symbol.toStringTag,{value:"WebGLObject",configurable:true});
 function data(receiver,type){const record=apply(get,records,[receiver]);if(record===undefined||(type==="WebGLObject"?record.value.kind==="uniform_location":names[record.value.kind]!==type))throw new T("Not an object of type "+type);return record;}
 const getter=({label(){const record=data(this,"WebGLObject");return __webglCall(record.state,"__getObjectLabel",[record.value]);}}).label;
 const setter=({label(value){const record=data(this,"WebGLObject"),string=apply(wellFormed,`${value}`,[]);__webglCall(record.state,"__setObjectLabel",[record.value,string]);}}).label;
 slots.metadata(getter,"get label",0);slots.metadata(setter,"set label",1);slots.property(base,"label",{get:getter,set:setter,enumerable:true,configurable:true});
 for(const kind of O.keys(names)){const name=names[kind];let prototype;
  if(kind==="vertex_array_oes")prototype=apply(create,O,[base]);
  else {const Constructor=slots.constructor(name);prototype=Constructor.prototype;if(kind!=="uniform_location"){apply(setPrototype,O,[Constructor,Base]);apply(setPrototype,O,[prototype,base]);}slots.property(globalThis,name,{value:Constructor,writable:true,configurable:true});}
  slots.property(prototype,Symbol.toStringTag,{value:name,configurable:true});prototypes[kind]=prototype;
 }
 return {argument:function(value,type,nullable){if(value==null&&nullable)return null;return data(value,type).value;},wrap:function(value,state){if(cache[value.handle])return cache[value.handle];const object=apply(create,O,[prototypes[value.kind]]);apply(set,records,[object,{value,state}]);cache[value.handle]=object;return object;}};
})();
'
}
