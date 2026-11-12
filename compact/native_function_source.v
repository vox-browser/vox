module main

import os

// Same-binary control: leave bridge functions with their JavaScript source text.
const plain_bridge_function_source = os.getenv('VOX_PLAIN_BRIDGE_FUNCTION_SOURCE') != ''

// The compact engine implements many platform operations as JavaScript
// functions, such as document.getElementsByClassName, Node.contains and
// compareDocumentPosition. Engines print platform functions as
// `function name() { [native code] }`, and libraries rely on it: Sizzle (in
// jQuery) enables its getElementsByClassName finder and native containment and
// ordering only for functions whose source matches /\{\s*\[native \w/. With the
// JavaScript text visible it fell back to scanning getElementsByTagName("*")
// with per-element attribute and offsetWidth reads; Old Reddit's
// DOMContentLoaded handlers made 39,316 bridge calls instead of 2,146.
//
// This runs after the native bindings install their globals and before page scripts:
// every function then reachable from the global object, document and the
// global constructors (including their prototypes, getters and setters) prints
// as a platform function. Functions created later, including all page script,
// keep their source text. The private weak registry belongs to the agent, so
// borrowing another same-origin realm's toString preserves platform identity.
fn compact_native_function_source_bootstrap() string {
	if plain_bridge_function_source { return '' }
	return r'
(function(markNative,isNative){
 const sourceText=Function.prototype.toString,apply=Reflect.apply,descriptor=Reflect.getOwnPropertyDescriptor,ownKeys=Reflect.ownKeys;
 function mark(value){if(typeof value==="function")markNative(value);}
 function markObject(object){
  if(object===null||(typeof object!=="object"&&typeof object!=="function"))return;
  for(const key of ownKeys(object)){let own;try{own=descriptor(object,key);}catch(error){continue;}if(!own)continue;mark(own.value);mark(own.get);mark(own.set);}
 }
 markObject(globalThis);markObject(document);
 for(const key of ownKeys(globalThis)){
  let own;try{own=descriptor(globalThis,key);}catch(error){continue;}
  const value=own&&own.value;if(typeof value!=="function")continue;
  markObject(value);let prototype;try{prototype=value.prototype;}catch(error){continue;}
  if(prototype!==null&&typeof prototype==="object")markObject(prototype);
 }
 const toString={toString(){
  if(isNative(this)){const name=this.name;return "function "+(typeof name==="string"?name:"")+"() {\n    [native code]\n}";}
  return apply(sourceText,this,arguments);
 }}.toString;
 mark(toString);
 Object.defineProperty(Function.prototype,"toString",{value:toString,writable:true,enumerable:false,configurable:true});
})'
}
