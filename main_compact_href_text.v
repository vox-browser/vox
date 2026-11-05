module main

fn compact_href_text_bootstrap() string {
	return r'
const __hrefTextNative=globalThis.__ladybirdSerializeURLText;
const __hrefTextConstructor=typeof __hrefTextNative==="function"?__hrefTextNative.nativeConstructor:null;
const __hrefTextPrototype=typeof __hrefTextNative==="function"?__hrefTextNative.nativePrototype:null;
const __hrefTextGetter=typeof __hrefTextNative==="function"?__hrefTextNative.nativeHrefGetter:null;
const __hrefTextDescriptor=Object.getOwnPropertyDescriptor,__hrefTextDefine=Object.defineProperty;
const __hrefTextHasOwn=Object.prototype.hasOwnProperty;
function __compactHrefTextBindings(object,state){
 if(typeof __hrefTextNative!=="function"||state.namespaceURI!=="http://www.w3.org/1999/xhtml"||!["a","area","link","base"].includes(state.tagName))return;
 const original=__hrefTextDescriptor(object,"href");if(!original||typeof original.get!=="function")return;
 __hrefTextDefine(object,"href",{configurable:original.configurable,enumerable:original.enumerable,set:original.set,get:function(){
  if(!Object.prototype.hasOwnProperty.call(state.attributes,"href"))return "";
  const value=String(state.attributes.href);
  if(__compactOwnerDocument(object)!==document)return __queryElements(state.bridgeKey,"elementURL","href");
  try{
   const constructor=globalThis.URL,base=__state.location;
   if(constructor===__hrefTextConstructor&&constructor.prototype===__hrefTextPrototype&&typeof base==="string"){
    const descriptor=__hrefTextDescriptor(__hrefTextPrototype,"href");
    if(descriptor&&__elementApply(__hrefTextHasOwn,descriptor,["get"])&&descriptor.get===__hrefTextGetter){const text=__hrefTextNative(value,base);if(typeof text==="string")return text;}
   }
   return new constructor(value,base).href;
  }catch(error){return value;}
 }});
}'
}
