module browserjs

// Encoding/TextDecoder.idl conversion and realm wrappers. Decoding and retained
// streaming state belong to the translated Encoding owner.
fn text_decoder_binding_factory() string {
	return r'(function(operate,intrinsics,global){
 const define=Object.defineProperty,get=Object.getOwnPropertyDescriptor,T=global.TypeError,apply=Reflect.apply;
 const brands=new WeakSet(),has=WeakSet.prototype.has,add=WeakSet.prototype.add;
 const tb=get(Object.getPrototypeOf(Uint8Array.prototype),"buffer").get,db=get(DataView.prototype,"buffer").get;
 const resizable=get(ArrayBuffer.prototype,"resizable"),growable=typeof SharedArrayBuffer==="function"?get(SharedArrayBuffer.prototype,"growable"):undefined,validate=intrinsics.validate;
 function brand(value){if(!apply(has,brands,[value]))throw new T("Not an object of type TextDecoder");}
 function dictionary(value){if(value!=null&&typeof value!=="object"&&typeof value!=="function")throw new T("Options must be a dictionary");return value;}
 function fixed(value){validate(value,false);let backing;try{backing=apply(tb,value,[]);}catch(error){try{backing=apply(db,value,[]);}catch(error){backing=value;}}let grows=false;try{grows=resizable&&apply(resizable.get,backing,[]);}catch(error){grows=growable&&apply(growable.get,backing,[]);}if(grows)throw new T("input must have a fixed-length buffer");}
 function TextDecoder(){if(!new.target)throw new T("TextDecoder constructor requires new");const label=arguments[0]===undefined?"utf-8":`${arguments[0]}`,options=dictionary(arguments[1]),fatal=!!(options&&options.fatal),ignoreBOM=!!(options&&options.ignoreBOM);operate("construct",this,label,fatal,ignoreBOM);apply(add,brands,[this]);}
 define(TextDecoder,"prototype",{writable:false});
 define(TextDecoder.prototype,Symbol.toStringTag,{value:"TextDecoder",configurable:true});
 const getters={get encoding(){brand(this);return operate("encoding",this);},get fatal(){brand(this);return operate("fatal",this);},get ignoreBOM(){brand(this);return operate("ignoreBOM",this);}};
 for(const name of ["encoding","fatal","ignoreBOM"])define(TextDecoder.prototype,name,{get:get(getters,name).get,enumerable:true,configurable:true});
 const methods={decode(){brand(this);const input=arguments[0];if(input!==undefined)fixed(input);const options=dictionary(arguments[1]),stream=!!(options&&options.stream);return operate("decode",this,input,stream);}};
 define(TextDecoder.prototype,"decode",{value:methods.decode,writable:true,enumerable:true,configurable:true});
 define(global,"TextDecoder",{value:TextDecoder,writable:true,configurable:true});
})'
}
