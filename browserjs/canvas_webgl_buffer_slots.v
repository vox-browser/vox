// Copyright (c) 2026-present, the Ladybird developers.
// Copyright (c) 2024-2025, Aliaksandr Kalenik <kalenik.aliaksandr@gmail.com>
// Copyright (c) 2024-2025, Luke Wilde <luke@ladybird.org>
// SPDX-License-Identifier: BSD-2-Clause
// Actual engine-slot adaptation of generated buffer IDL conversions and
// WebGLRenderingContextBase::{with_buffer_source_bytes,span_from_typed_array}.
module browserjs

fn webgl_buffer_source_bootstrap() string {
	return r'
const __webglBufferSlots=(function(){
 const apply=Reflect.apply,get=Object.getOwnPropertyDescriptor,define=Object.defineProperty,T=TypeError,U8=Uint8Array,F32=Float32Array,I32=Int32Array,U32=Uint32Array,isView=ArrayBuffer.isView;
 const ab=get(ArrayBuffer.prototype,"byteLength").get,resizable=get(ArrayBuffer.prototype,"resizable"),tp=Object.getPrototypeOf(U8.prototype),tb=get(tp,"buffer").get,offset=get(tp,"byteOffset").get,length=get(tp,"byteLength").get,tag=get(tp,Symbol.toStringTag).get,values=tp.values,set=tp.set;
 const db=get(DataView.prototype,"buffer").get,doff=get(DataView.prototype,"byteOffset").get,dl=get(DataView.prototype,"byteLength").get,sab=typeof SharedArrayBuffer==="function"?get(SharedArrayBuffer.prototype,"byteLength").get:null,growable=typeof SharedArrayBuffer==="function"?get(SharedArrayBuffer.prototype,"growable"):null;
 const sizes={Int8Array:1,Uint8Array:1,Uint8ClampedArray:1,Int16Array:2,Uint16Array:2,Float16Array:2,Int32Array:4,Uint32Array:4,Float32Array:4,Float64Array:8,BigInt64Array:8,BigUint64Array:8};
 function own(array,index,value){apply(define,Object,[array,index,{value,writable:true,enumerable:true,configurable:true}]);}
 function describe(value){try{return {buffer:apply(tb,value,[]),type:apply(tag,value,[])}}catch(error){}try{return {buffer:apply(db,value,[]),type:"DataView"}}catch(error){}try{apply(ab,value,[]);return {buffer:value,type:"ArrayBuffer"}}catch(error){}return null;}
 function shared(buffer){if(!sab)return false;try{apply(sab,buffer,[]);return true}catch(error){return false}}
 function validate(value,type){const nullable=type.endsWith("?");if(value==null&&nullable)return;const d=describe(value);if(!d||(type.startsWith("ArrayBufferView")&&d.type==="ArrayBuffer"))throw new T("No union types matched");const isShared=shared(d.buffer);if(isShared&&!type.startsWith("ArrayBufferView"))throw new T("The array buffer object cannot be a SharedArrayBuffer");const adjustable=isShared?(growable&&apply(growable.get,d.buffer,[])):(resizable&&apply(resizable.get,d.buffer,[]));if(adjustable)throw new T("Not an object of type fixed-length "+d.type);}
 function isBuffer(value){return apply(isView,ArrayBuffer,[value])||describe(value)!==null;}
 function typedList(value,type){let name;try{name=apply(tag,value,[])}catch(error){return false}return type==="Float32List"?name==="Float32Array":type==="Int32List"?name==="Int32Array":type==="Uint32List"?name==="Uint32Array":false;}
 function witness(value){const d=describe(value);if(!d)throw new T("No union types matched");const state={elementSize:sizes[d.type]||1,detached:false,outOfBounds:false};try{new U8(d.buffer)}catch(error){state.detached=true;return state}if(d.type!=="ArrayBuffer")try{if(d.type==="DataView")apply(dl,value,[]);else apply(values,value,[])}catch(error){state.outOfBounds=true}return state;}
 function span(value){const d=describe(value),state=witness(value);if(state.detached||state.outOfBounds)return {state,buffer:d.buffer,offset:0,length:0};if(d.type==="ArrayBuffer")return {state,buffer:d.buffer,offset:0,length:apply(ab,d.buffer,[])};return {state,buffer:d.buffer,offset:apply(d.type==="DataView"?doff:offset,value,[]),length:apply(d.type==="DataView"?dl:length,value,[])};}
 function bytes(value){const d=span(value),result=[];if(d.state.detached||d.state.outOfBounds)return result;const view=new U8(d.buffer,d.offset,d.length);for(let i=0;i<d.length;i++)own(result,i,view[i]);return result;}
 function list(value,type){const d=span(value),result=[];if(d.state.detached||d.state.outOfBounds)return result;const Constructor=type==="Float32List"?F32:type==="Int32List"?I32:U32,view=new Constructor(d.buffer,d.offset,d.length/4);for(let i=0;i<d.length/4;i++)own(result,i,__webglNumber(view[i]));return result;}
 function write(value,data){const d=span(value);if(d.state.detached||d.state.outOfBounds)return;apply(set,new U8(d.buffer,d.offset,d.length),[data]);}
 return {validate,isBuffer,typedList,witness,bytes,list,write};
})();
'
}
