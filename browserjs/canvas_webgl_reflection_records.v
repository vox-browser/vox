// Copyright (c) 2024, Jelle Raaijmakers <jelle@ladybird.org>
// Copyright (c) 2024, Luke Wilde <luke@ladybird.org>
// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

// Source reflection records and generated readonly attribute/constructor
// bindings. Native V/GL owns each queried field; this adapts the result wrapper.
fn webgl_reflection_record_bootstrap() string {
	return r'
const __webglReflectionRecord=(function(){
 const O=Object,apply=Reflect.apply,create=O.create,define=O.defineProperty,W=WeakMap,get=W.prototype.get,set=W.prototype.set,T=TypeError,tag=Symbol.toStringTag;
 const records={},prototypes={},specs={WebGLActiveInfo:["size","type","name"],WebGLShaderPrecisionFormat:["rangeMin","rangeMax","precision"]};
 for(const name of ["WebGLActiveInfo","WebGLShaderPrecisionFormat"]){
  const store=new W,Constructor=function(){if(!new.target)throw new T(name+" constructor must be called with \u0027new\u0027");throw new T(name+" is not a constructor");};
  apply(define,O,[Constructor,"name",{value:name,configurable:true}]);
  const prototype=Constructor.prototype;apply(define,O,[Constructor,"prototype",{writable:false}]);
  apply(define,O,[prototype,tag,{value:name,configurable:true}]);
  for(const field of specs[name]){const getter=function(){const value=apply(get,store,[this]);if(value===undefined)throw new T("Not an object of type "+name);return value[field];};
   apply(define,O,[getter,"name",{value:"get "+field,configurable:true}]);
   apply(define,O,[prototype,field,{get:getter,enumerable:true,configurable:true}]);
  }
  apply(define,O,[globalThis,name,{value:Constructor,writable:true,configurable:true}]);records[name]=store;prototypes[name]=prototype;
 }
 return function(value,name){if(value===null)return null;const object=apply(create,O,[prototypes[name]]);apply(set,records[name],[object,value]);return object;};
})();
'
}
