// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

// Actual engine receiver records adapting generated impl_from checks and
// WebGL context interface prototype initialization.
fn webgl_context_slot_bootstrap() string {
	return r'
const __webglContextSlots=(function(){
 const O=Object,apply=Reflect.apply,create=O.create,define=O.defineProperty,W=WeakMap,get=W.prototype.get,set=W.prototype.set,T=TypeError,store=new W;
 function property(object,name,descriptor){apply(define,O,[object,name,descriptor]);}
 function record(receiver,version){const value=apply(get,store,[receiver]);if(value===undefined||value.version!==version)throw new T("Not an object of type "+(version===2?"WebGL2RenderingContext":"WebGLRenderingContext"));return value;}
 function metadata(operation,name,length){property(operation,"name",{value:name,configurable:true});property(operation,"length",{value:length,configurable:true});return operation;}
 function constructor(name){const Constructor=function(){if(!new.target)throw new T(name+" constructor must be called with \u0027new\u0027");throw new T(name+" is not a constructor");};metadata(Constructor,name,0);property(Constructor,"prototype",{writable:false});return Constructor;}
 return {property,record,metadata,constructor,create:function(prototype){return apply(create,O,[prototype])},install:function(object,state,version){apply(set,store,[object,{state,version,extensions:apply(create,O,[null])}])}};
})();
'
}

fn webgl_context_interface_bootstrap() string {
	return r'
const __webglCreateContext=(function(){
 const slots=__webglContextSlots,prototypes={},makeXRCompatibleNative=__ladybirdWebGLMakeXRCompatible;
 for(const version of [1,2]){
  const name=version===2?"WebGL2RenderingContext":"WebGLRenderingContext",Constructor=slots.constructor(name),prototype=Constructor.prototype;
  slots.property(globalThis,name,{value:Constructor,writable:true,configurable:true});
  const specs=Object.assign({},__webglSpecs1,version===2?__webglSpecs2:{}),constants=Object.assign({},__webglConstants1,version===2?__webglConstants2:{});
  for(const key of Object.keys(constants)){const descriptor={value:constants[key],enumerable:true};slots.property(prototype,key,descriptor);slots.property(Constructor,key,descriptor);}
  for(const method of Object.keys(specs)){if(specs[method].every(function(entry){return entry[2].startsWith("[FIXME]");}))continue;const operation=method==="getExtension"?__webglExtensionMethod(version):__webglMethod(null,method,specs[method],version);slots.property(prototype,method,{value:operation,writable:true,enumerable:true,configurable:true});}
  const makeXRCompatible=({makeXRCompatible(){let record;try{record=slots.record(this,version)}catch(error){return makeXRCompatibleNative(undefined,error)}return makeXRCompatibleNative(record.state.bridgeKey||record.state.id)}}).makeXRCompatible;
  slots.metadata(makeXRCompatible,"makeXRCompatible",0);slots.property(prototype,"makeXRCompatible",{value:makeXRCompatible,writable:true,enumerable:true,configurable:true});
  for(const key of ["canvas","drawingBufferWidth","drawingBufferHeight"]){const getter=({[key](){const state=slots.record(this,version).state;return key==="canvas"?__element(state):__webglCall(state,key)}})[key];slots.metadata(getter,"get "+key,0);slots.property(prototype,key,{get:getter,enumerable:true,configurable:true});}
  slots.property(prototype,Symbol.toStringTag,{value:name,configurable:true});prototypes[version]=prototype;
 }
 return function(state,version){const object=slots.create(prototypes[version]);slots.install(object,state,version);return object;};
})();
'
}
