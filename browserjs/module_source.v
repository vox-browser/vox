// SPDX-License-Identifier: BSD-2-Clause
module browserjs

// A trusted lexer closure rewrites URL positions only. The backend retains all
// module declarations, lexical scopes, live bindings, cycles and await syntax.
fn module_source_factory() string {
	lexer := $embed_file('vendor/es-module-lexer-1.7.0/lexer.asm.js').to_string()
	return '(function(resolve,helperName){"use strict";const global=globalThis;const {ArrayBuffer,Uint8Array,Uint16Array,Int8Array,Int16Array,Int32Array,Object,String,Error,Math,parseInt}=globalThis;const self={Int8Array,Int16Array,Int32Array,Uint8Array,Uint16Array};' + lexer.replace('export function parse', 'function parse') + r'
const stringify=JSON.stringify,apply=Reflect.apply,slice=Function.prototype.call.bind(String.prototype.slice),StringIntrinsic=String,TypeErrorIntrinsic=TypeError;
const dynamic=function(base,key,value,options){return import({toString(){if(typeof value==="symbol")throw new TypeErrorIntrinsic("Cannot convert a Symbol to a string");return resolve(StringIntrinsic(value),base,key);}},options);};
Object.defineProperty(dynamic,"resolve",{value:function(value,base,key){if(typeof value==="symbol")throw new TypeErrorIntrinsic("Cannot convert a Symbol to a string");return resolve(StringIntrinsic(value),base,key);}});
return [function(source,base,key,isModule){
 let imports;try{imports=parse(source,key)[0];}catch(error){return source;}
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
},dynamic];})'
}
