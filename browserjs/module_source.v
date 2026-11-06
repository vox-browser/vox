// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import os

const retain_asm_module_lexer = os.getenv('VOX_RETAIN_ASM_MODULE_LEXER') != ''
const module_lexer_diagnostics = os.getenv('VOX_MODULE_LEXER_DIAGNOSTICS') != ''

fn module_specifier_lexer_factory(retain_asm bool) string {
	asm_source := $embed_file('vendor/es-module-lexer-1.7.0/lexer.asm.js').to_string()
		.replace('export function parse', 'function parse')
	wasm_source := $embed_file('vendor/es-module-lexer-1.7.0/lexer.wasm.js').to_string()
		.replace('export var ImportType', 'var ImportType')
		.replace('export function parse', 'function parse')
		.replace('export const init=WebAssembly.compile(E()).then(WebAssembly.instantiate).then((({exports:A})=>{C=A}));', 'const init=undefined;')
		.replace('export const initSync', 'const initSync')
		.replace('function k(A){try{return(0,eval)(A)}catch(A){}}', 'function k(A){return moduleStringLiteral(A)}')
	// Use the same strict quoted-string decoder as the retained asm build.
	// Its invalid-escape rejection must survive before native module parsing.
	literal_decoder := asm_source.all_after('return[w,d,!!e.f(),!!e.ms()]}')
	assert literal_decoder.starts_with('function b(e,a)')
	// Capture constructors before author code can replace them. Decode only the
	// pinned private Wasm payload; no global Buffer/atob dependency is installed.
	return r'
const WasmIntrinsic=(()=>{
 try{
  if(typeof WebAssembly!=="object")return null;
  const Module=WebAssembly.Module,Instance=WebAssembly.Instance,apply=Reflect.apply;
  const exportsOf=Object.getOwnPropertyDescriptor(Instance.prototype,"exports").get;
  const bufferOf=Object.getOwnPropertyDescriptor(WebAssembly.Memory.prototype,"buffer").get,grow=WebAssembly.Memory.prototype.grow;
  const globalValue=Object.getOwnPropertyDescriptor(WebAssembly.Global.prototype,"value").get;
  return {Module,Instance:function(module){
   const raw=apply(exportsOf,new Instance(module),[]),memory=raw.memory;
   const heap=typeof raw.__heap_base==="object"?{value:apply(globalValue,raw.__heap_base,[])}:raw.__heap_base;
   return {exports:{...raw,__heap_base:heap,memory:{get buffer(){return apply(bufferOf,memory,[])},grow(pages){return apply(grow,memory,[pages])}}}};
  }};
 }catch(error){return null;}
})();
const base64Index=Function.prototype.call.bind(String.prototype.indexOf);
const moduleStringLiteral=(function(){let t,c,n;' + literal_decoder + r';return function(input){t=input;c="specifier";return b(1,t.charCodeAt(0));};})();
const lexerBuffer={from(input){
 const alphabet="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
 const length=input.length,bytes=new Uint8Array((length>>2)*3-(input[length-1]==="="?1:0)-(input[length-2]==="="?1:0));
 let target=0;
 for(let i=0;i<length;i+=4){
  const bits=(base64Index(alphabet,input[i])<<18)|(base64Index(alphabet,input[i+1])<<12)|((input[i+2]==="="?0:base64Index(alphabet,input[i+2]))<<6)|(input[i+3]==="="?0:base64Index(alphabet,input[i+3]));
  bytes[target++]=bits>>16;if(target<bytes.length)bytes[target++]=bits>>8;if(target<bytes.length)bytes[target++]=bits;
 }
 return bytes;
}};
let specifierLexer=null,lexerBackend="uninitialized";
function parse(input,name){
 if(specifierLexer===null){
  if(' + if retain_asm { 'false' } else { 'true' } + r' && WasmIntrinsic){
   try{specifierLexer=(function(WebAssembly,Buffer){' + wasm_source + r';initSync();return parse;})(WasmIntrinsic,lexerBuffer);lexerBackend="wasm";}catch(error){}
  }
  if(specifierLexer===null){specifierLexer=(function(){' + asm_source + r';return parse;})();lexerBackend=' + if retain_asm { '"asm-control"' } else { '"asm-fallback"' } + r';}
 }
 return specifierLexer(input,name);
}
'
}

// A trusted lexer closure rewrites URL positions only. The backend retains all
// module declarations, lexical scopes, live bindings, cycles and await syntax.
fn module_source_factory() string {
	return module_source_factory_with_lexer(retain_asm_module_lexer)
}

fn module_source_factory_with_lexer(retain_asm bool) string {
	return '(function(resolve,helperName){"use strict";const global=globalThis;const {ArrayBuffer,Uint8Array,Uint16Array,Int8Array,Int16Array,Int32Array,Object,String,Error,Math,parseInt}=globalThis;const self={Int8Array,Int16Array,Int32Array,Uint8Array,Uint16Array};' + module_specifier_lexer_factory(retain_asm) + r'
const stringify=JSON.stringify,apply=Reflect.apply,slice=Function.prototype.call.bind(String.prototype.slice),StringIntrinsic=String,TypeErrorIntrinsic=TypeError;
const dynamic=function(base,key,value,options){return import({toString(){if(typeof value==="symbol")throw new TypeErrorIntrinsic("Cannot convert a Symbol to a string");return resolve(StringIntrinsic(value),base,key);}},options);};
Object.defineProperty(dynamic,"resolve",{value:function(value,base,key){if(typeof value==="symbol")throw new TypeErrorIntrinsic("Cannot convert a Symbol to a string");return resolve(StringIntrinsic(value),base,key);}});
return [function(source,base,key,isModule,skipSpecifierLexer){
 let imports=[];if(!skipSpecifierLexer){try{imports=parse(source,key)[0];}catch(error){return source;}}
 function rewrite(start,end){
  let output="",cursor=start;
  for(const entry of imports){
   const begin=entry.d===-1?entry.s-1:entry.ss;
   if(begin<cursor||begin>=end||entry.d===-2)continue;
   if(entry.d===-1){
    output+=slice(source,cursor,begin)+stringify(resolve(entry.n,base,key));cursor=entry.e+1;
   }else if(entry.d>=0){
    // Keep an unreachable original import for native syntax validation,
    // including argument count, spread and contextual await/yield grammar.
    // Only the helper branch runs. Its native import performs ToString and
    // options validation, so failures still reject a genuine import promise.
    output+=slice(source,cursor,begin)+"(false?"+slice(source,begin,entry.se)+":"+helperName+"("+stringify(base)+","+stringify(key)+","+rewrite(entry.d+1,entry.se-1)+"))";
    cursor=entry.se;
   }
  }
  return output+slice(source,cursor,end);
 }
 source=rewrite(0,source.length);
 // The native key identifies cache entries. The final HTML response URL is the
 // base for import.meta, including redirects and uniquely keyed inline scripts.
 if(!isModule)return source;
 const metadata="import.meta.url="+stringify(base)+";delete import.meta.filename;import.meta.resolve=function resolve(specifier){return "+helperName+".resolve(specifier,"+stringify(base)+","+stringify(key)+")};";
 if(source.startsWith("#!")){const line=source.indexOf("\n");return line<0?source+"\n"+metadata:slice(source,0,line+1)+metadata+slice(source,line+1);}
 return metadata+source;
},dynamic,function(){return lexerBackend;}];})'
}
