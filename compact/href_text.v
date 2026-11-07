module main

import os

const retain_uncached_href_text = os.getenv('VOX_RETAIN_UNCACHED_HREF_TEXT') != ''

fn compact_href_text_bootstrap() string {
	return 'const __hrefTextCacheEnabled=' + if retain_uncached_href_text {
		'false;'
	} else {
		'true;'
	} + r'
const __hrefTextNative=globalThis.__ladybirdSerializeURLText;
const __hrefTextConstructor=typeof __hrefTextNative==="function"?__hrefTextNative.nativeConstructor:null;
const __hrefTextPrototype=typeof __hrefTextNative==="function"?__hrefTextNative.nativePrototype:null;
const __hrefTextGetter=typeof __hrefTextNative==="function"?__hrefTextNative.nativeHrefGetter:null;
const __hrefTextDescriptor=Object.getOwnPropertyDescriptor,__hrefTextDefine=Object.defineProperty;
const __hrefTextHasOwn=Object.prototype.hasOwnProperty;
const __hrefTextCache=new Map(),__hrefTextGet=Map.prototype.get,__hrefTextSet=Map.prototype.set;
const __hrefTextCacheReport=typeof __hrefTextNative==="function"?__hrefTextNative.reportCacheHit:undefined;
let __hrefTextCacheEntries=0,__hrefTextCacheUnits=0,__hrefTextCacheReported=false;
function __compactHrefText(value,base){
 const eligible=__hrefTextCacheEnabled&&typeof value==="string"&&typeof base==="string"&&value.length<=2048&&base.length<=2048;
 const old=eligible?__elementApply(__hrefTextGet,__hrefTextCache,[value]):undefined;
 if(old&&old.base===base){
  if(!__hrefTextCacheReported&&typeof __hrefTextCacheReport==="function"){__hrefTextCacheReported=true;__hrefTextCacheReport();}
  return old.text;
 }
 const text=__hrefTextNative(value,base);
 if(eligible&&typeof text==="string"&&text.length<=4096){
  const units=value.length+base.length+text.length,nextUnits=__hrefTextCacheUnits-(old?old.units:0)+units;
  // Keep admitted entries when full: cyclic oversized working sets must not evict every hit.
  if((old||__hrefTextCacheEntries<256)&&nextUnits<=262144){
   __elementApply(__hrefTextSet,__hrefTextCache,[value,{base,text,units}]);__hrefTextCacheUnits=nextUnits;if(!old)__hrefTextCacheEntries++;
  }
 }
 return text;
}
// https://html.spec.whatwg.org/multipage/links.html#htmlhyperlinkelementutils
// Each component reads the element URL, and each setter changes a copy of it
// through the URL setters and stores the serialization in the href attribute.
const __hyperlinkURL=globalThis.URL,__hyperlinkParts=["protocol","username","password","host","hostname","port","pathname","search","hash"];
function __compactHyperlinkParse(object,state){
 if(!__hrefTextHasOwn.call(state.attributes,"href"))return null;
 try{return new __hyperlinkURL(object.href);}catch(error){return null;}
}
function __compactHyperlinkBindings(object,state){
 if(state.namespaceURI!=="http://www.w3.org/1999/xhtml"||(state.tagName!=="a"&&state.tagName!=="area"))return;
 __hrefTextDefine(object,"origin",{configurable:true,enumerable:true,get:function(){const url=__compactHyperlinkParse(this,state);return url?url.origin:"";}});
 for(const name of __hyperlinkParts)__hrefTextDefine(object,name,{configurable:true,enumerable:true,
  get:function(){const url=__compactHyperlinkParse(this,state);return url?url[name]:name==="protocol"?":":"";},
  set:function(value){
   const url=__compactHyperlinkParse(this,state);if(!url)return;
   if(typeof value==="symbol")throw new TypeError("Cannot convert a Symbol to a string");
   url[name]=String(value);__setAttribute(state,"href",url.href);
  }});
 if(!__hrefTextHasOwn.call(object,"toString"))__hrefTextDefine(object,"toString",{configurable:true,enumerable:true,writable:true,value:function toString(){return this.href;}});
}
let __compactDocumentEncodingIsLegacy;
function __compactLegacyEncodedDocument(){
 if(__compactDocumentEncodingIsLegacy===undefined){const name=String(document.characterSet||"UTF-8").toUpperCase();__compactDocumentEncodingIsLegacy=name!=="UTF-8";}
 return __compactDocumentEncodingIsLegacy;
}
function __compactHrefTextBindings(object,state){
 __compactHyperlinkBindings(object,state);
 if(typeof __hrefTextNative!=="function"||state.namespaceURI!=="http://www.w3.org/1999/xhtml"||!["a","area","link","base"].includes(state.tagName))return;
 const original=__hrefTextDescriptor(object,"href");if(!original||typeof original.get!=="function")return;
 __hrefTextDefine(object,"href",{configurable:original.configurable,enumerable:original.enumerable,set:original.set,get:function(){
  if(!Object.prototype.hasOwnProperty.call(state.attributes,"href"))return "";
  const value=String(state.attributes.href);
  // A document in a legacy encoding encodes the query with it; only the
  // native URL parser knows that encoding.
  if(__compactOwnerDocument(object)!==document||__compactLegacyEncodedDocument())return __queryElements(state.bridgeKey,"elementURL","href");
  try{
   const constructor=globalThis.URL,base=__state.location;
   if(constructor===__hrefTextConstructor&&constructor.prototype===__hrefTextPrototype&&typeof base==="string"){
    const descriptor=__hrefTextDescriptor(__hrefTextPrototype,"href");
    if(descriptor&&__elementApply(__hrefTextHasOwn,descriptor,["get"])&&descriptor.get===__hrefTextGetter){const text=__compactHrefText(value,base);if(typeof text==="string")return text;}
   }
   return new constructor(value,base).href;
  }catch(error){return value;}
 }});
}'
}
