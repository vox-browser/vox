// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

// Direct translation of the pinned sequence generator's GetIteratorFromMethod /
// IteratorStepValue loop. Its conversion failure path does not IteratorClose.
// Union selection uses the same cached GetMethod, with the source final error
// when neither a typed-list member nor its iterable sequence member matches.
const webidl_sequence_conversion_factory = r'(function(convert,union){
 const apply=Reflect.apply,define=Object.defineProperty,iteratorSymbol=Symbol.iterator,T=TypeError,S=String,isArray=Array.isArray;
 function object(value){return value!==null&&(typeof value==="object"||typeof value==="function")}
 function display(value){if(!object(value))return S(value);return typeof value==="function"?"[object Function]":isArray(value)?"[object Array]":"[object Object]"}
 function failure(value,suffix){throw new T(display(value)+suffix)}
 return function(value){if(!object(value)){if(union)throw new T("No union types matched");failure(value," is not an object")}const method=value[iteratorSymbol];if(method==null){if(union)throw new T("No union types matched");failure(value," is not iterable")}if(typeof method!=="function")failure(method," is not a function");const iterator=apply(method,value,[]);if(!object(iterator))failure(value," is not iterable");const next=iterator.next,result=[];let index=0;for(;;){if(typeof next!=="function")failure(next," is not a function");const step=apply(next,iterator,[]);if(!object(step))failure(step," is not an object");if(step.done)return result;const item=convert(step.value);define(result,index++,{value:item,writable:true,enumerable:true,configurable:true})}}
})'
