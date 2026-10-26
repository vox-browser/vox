module browserjs

// Encoding/TextEncoder.idl. Only realm wrappers and WebIDL receiver checks
// live here; scalar conversion and UTF-8 encoding use the native algorithms.
fn text_encoder_binding_factory() string {
	return r'(function(operate,global){
 const define=Object.defineProperty,get=Object.getOwnPropertyDescriptor,T=global.TypeError;
 const brands=new WeakSet(),apply=Reflect.apply,has=WeakSet.prototype.has,add=WeakSet.prototype.add;
 const buffer=get(Object.getPrototypeOf(Uint8Array.prototype),"buffer").get;
 const resizable=get(ArrayBuffer.prototype,"resizable"),growable=typeof SharedArrayBuffer==="function"?get(SharedArrayBuffer.prototype,"growable"):undefined;
 function fixed(value){const backing=apply(buffer,value,[]);let grows=false;try{grows=resizable&&apply(resizable.get,backing,[]);}catch(error){grows=growable&&apply(growable.get,backing,[]);}if(grows)throw new T("destination must have a fixed-length buffer");}
 function brand(value){if(!apply(has,brands,[value]))throw new T("Not an object of type TextEncoder");}
 function TextEncoder(){if(!new.target)throw new T("TextEncoder constructor requires new");apply(add,brands,[this]);}
 define(TextEncoder,"prototype",{writable:false});
 define(TextEncoder.prototype,Symbol.toStringTag,{value:"TextEncoder",configurable:true});
 define(TextEncoder.prototype,"encoding",{get:get({get encoding(){brand(this);return operate("encoding");}},"encoding").get,enumerable:true,configurable:true});
 const methods={
  encode(){brand(this);return operate("encode",arguments[0]===undefined?"":arguments[0]);},
  encodeInto(source,destination){brand(this);if(arguments.length<2)throw new T("encodeInto requires two arguments");source=operate("source",source);fixed(destination);const result=operate("encodeInto",source,destination);return {read:result[0],written:result[1]};}
 };
 for(const name of ["encode","encodeInto"])define(TextEncoder.prototype,name,{value:methods[name],writable:true,enumerable:true,configurable:true});
 define(global,"TextEncoder",{value:TextEncoder,writable:true,configurable:true});
})'
}
