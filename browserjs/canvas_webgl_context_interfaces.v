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
 const slots=__webglContextSlots,prototypes={},makeXRCompatibleNative=__ladybirdWebGLMakeXRCompatible,I=__webglBuildIntrinsics;
 const names=["WebGLRenderingContext","WebGL2RenderingContext"],getters=[];
 let built=false;
 // Both interfaces define about two thousand properties and functions, but
 // few pages use WebGL. Build them with the first context or the first read
 // of either global; a page that replaced or deleted a global keeps its choice.
 function build(){
  built=true;
  for(let version=1;version<=2;version++){
   const name=names[version-1],Constructor=slots.constructor(name),prototype=Constructor.prototype;
   const current=I.apply(I.describe,I.O,[globalThis,name]);
   if(current!==undefined&&current.get===getters[version-1])slots.property(globalThis,name,{value:Constructor,writable:true,configurable:true});
   const specs=__webglSpecs1(),constants=__webglConstants1();
   if(version===2){
    const extraSpecs=__webglSpecs2(),extraConstants=__webglConstants2(),specKeys=I.apply(I.keys,I.O,[extraSpecs]),constantKeys=I.apply(I.keys,I.O,[extraConstants]);
    for(let i=0;i<specKeys.length;i++)slots.property(specs,specKeys[i],{value:extraSpecs[specKeys[i]],writable:true,enumerable:true,configurable:true});
    for(let i=0;i<constantKeys.length;i++)slots.property(constants,constantKeys[i],{value:extraConstants[constantKeys[i]],writable:true,enumerable:true,configurable:true});
   }
   const constantKeys=I.apply(I.keys,I.O,[constants]);
   for(let i=0;i<constantKeys.length;i++){const key=constantKeys[i],descriptor={value:constants[key],enumerable:true};slots.property(prototype,key,descriptor);slots.property(Constructor,key,descriptor);}
   const methods=I.apply(I.keys,I.O,[specs]);
   for(let i=0;i<methods.length;i++){const method=methods[i];if(I.apply(I.every,specs[method],[function(entry){return I.apply(I.startsWith,entry[2],["[FIXME]"]);}]))continue;const operation=method==="getExtension"?__webglExtensionMethod(version):__webglMethod(null,method,specs[method],version);slots.property(prototype,method,{value:operation,writable:true,enumerable:true,configurable:true});}
   const makeXRCompatible=({makeXRCompatible(){let record;try{record=slots.record(this,version)}catch(error){return makeXRCompatibleNative(undefined,error)}return makeXRCompatibleNative(record.state.bridgeKey||record.state.id)}}).makeXRCompatible;
   slots.metadata(makeXRCompatible,"makeXRCompatible",0);slots.property(prototype,"makeXRCompatible",{value:makeXRCompatible,writable:true,enumerable:true,configurable:true});
   const accessors=["canvas","drawingBufferWidth","drawingBufferHeight"];
   for(let i=0;i<accessors.length;i++){const key=accessors[i],getter=({[key](){const state=slots.record(this,version).state;return key==="canvas"?__element(state):__webglCall(state,key)}})[key];slots.metadata(getter,"get "+key,0);slots.property(prototype,key,{get:getter,enumerable:true,configurable:true});}
   slots.property(prototype,I.toStringTag,{value:name,configurable:true});prototypes[version]=prototype;
  }
 }
 for(let i=0;i<names.length;i++){
  const name=names[i];
  getters[i]=function(){if(!built)build();return globalThis[name];};
  slots.property(globalThis,name,{get:getters[i],set:function(value){slots.property(globalThis,name,{value:value,writable:true,configurable:true});},configurable:true});
 }
 return function(state,version){if(!built)build();const object=slots.create(prototypes[version]);slots.install(object,state,version);return object;};
})();
'
}
