// CSS/FontFace.idl and FontFaceSet.idl native record binding.
module browserjs

import css
import dom

@[heap]
pub struct FontFaceHost {
	document &dom.Document
	computer &css.FontComputer
mut:
	set                 &css.FontFaceSet
	faces               map[voidptr]&css.FontFaceObject
	wrappers            map[voidptr]voidptr
	set_wrapper         voidptr
	face_factory        voidptr
	set_cache           voidptr
	buffer_source_view  voidptr
	font_event_factory  voidptr
	font_event_sequence voidptr
	font_event_freeze   voidptr
	font_events         map[voidptr]&css.FontFaceSetLoadEvent
	font_event_faces    map[voidptr]voidptr
	closed              bool
}

pub fn FontFaceHost.create(document &dom.Document) &FontFaceHost {
	style := css.css_style_computer_for(document)
	return &FontFaceHost{
		document: document
		computer: style.font_computer()
		set:      style.font_face_set_
	}
}

pub fn font_face_bootstrap() string {
	return r'
(function(){
 const apply=Reflect.apply,reject=Promise.reject,PromiseIntrinsic=Promise,nativeCall=__ladybirdFontFace;
 function call(method,receiver,args){return nativeCall(method,receiver,...(args||[]));}
 function FontFace(family,source,descriptors={}){
  if(!new.target)throw new TypeError("FontFace constructor requires new");
  if(arguments.length<2)throw new TypeError("FontFace constructor requires two arguments");
  call("construct",this,[family,source,descriptors]);
 }
 Object.defineProperty(FontFace,"prototype",{writable:false});
 for(const property of ["family","style","weight","stretch","unicodeRange","featureSettings","variationSettings","display","ascentOverride","descentOverride","lineGapOverride"]){
  Object.defineProperty(FontFace.prototype,property,{get:function(){return call("get",this,[property]);},set:function(value){call("set",this,[property,value]);},enumerable:true,configurable:true});
 }
 for(const property of ["status","loaded"])Object.defineProperty(FontFace.prototype,property,{get:function(){return call("get",this,[property]);},enumerable:true,configurable:true});
 Object.defineProperty(FontFace.prototype,"load",{value:function load(){try{return call("load",this);}catch(error){return apply(reject,PromiseIntrinsic,[error]);}},enumerable:true,writable:true,configurable:true});
 Object.defineProperty(FontFace.prototype,Symbol.toStringTag,{value:"FontFace",configurable:true});
 const FontFaceSet=function FontFaceSet(){throw new TypeError("Illegal constructor");};
 Object.setPrototypeOf(FontFaceSet,EventTarget);Object.setPrototypeOf(FontFaceSet.prototype,EventTarget.prototype);
 Object.defineProperty(FontFaceSet,"prototype",{writable:false});
 for(const property of ["ready","status","size"])Object.defineProperty(FontFaceSet.prototype,property,{get:function(){return call("set:"+property,this);},enumerable:true,configurable:true});
 for(const method of ["add","delete","has"]){Object.defineProperty(FontFaceSet.prototype,method,{value:function(font){if(arguments.length<1)throw new TypeError("FontFaceSet."+method+" requires one argument");return call("set:"+method,this,[font]);},enumerable:true,writable:true,configurable:true});}
 Object.defineProperty(FontFaceSet.prototype,"clear",{value:function clear(){return call("set:clear",this);},enumerable:true,writable:true,configurable:true});
 for(const method of ["load","check"]){Object.defineProperty(FontFaceSet.prototype,method,{value:function(font,text=" "){try{if(arguments.length<1)throw new TypeError("FontFaceSet."+method+" requires one argument");return call("set:"+method,this,[font,text]);}catch(error){if(method==="load")return apply(reject,PromiseIntrinsic,[error]);throw error;}},enumerable:true,writable:true,configurable:true});}
 const entries=new Set(),methods={keys:Set.prototype.keys,values:Set.prototype.values,entries:Set.prototype.entries,forEach:Set.prototype.forEach};
 for(const method of ["keys","values","entries"])Object.defineProperty(FontFaceSet.prototype,method,{value:function(){call("set:brand",this);return apply(methods[method],entries,[]);},enumerable:true,writable:true,configurable:true});
 Object.defineProperty(FontFaceSet.prototype,"forEach",{value:function forEach(callback,thisArg){call("set:brand",this);if(typeof callback!=="function")throw new TypeError("Callback is not callable");const set=this;return apply(methods.forEach,entries,[function(value){apply(callback,thisArg,[value,value,set]);}]);},enumerable:true,writable:true,configurable:true});
 Object.defineProperty(FontFaceSet.prototype,Symbol.iterator,{value:FontFaceSet.prototype.values,writable:true,configurable:true});
 Object.defineProperty(FontFaceSet.prototype,Symbol.toStringTag,{value:"FontFaceSet",configurable:true});
 for(const name of ["loading","loadingdone","loadingerror"]){Object.defineProperty(FontFaceSet.prototype,"on"+name,{get:function(){return call("set:handler:get",this,[name]);},set:function(value){call("set:handler:set",this,[name,value]);},enumerable:true,configurable:true});}
 function FontFaceSetLoadEvent(type,eventInitDict={}){if(!new.target)throw new TypeError("FontFaceSetLoadEvent constructor requires new");if(arguments.length<1)throw new TypeError("FontFaceSetLoadEvent requires one argument");call("event:construct",this,[type,eventInitDict]);}
 Object.setPrototypeOf(FontFaceSetLoadEvent,Event);Object.setPrototypeOf(FontFaceSetLoadEvent.prototype,Event.prototype);Object.defineProperty(FontFaceSetLoadEvent,"prototype",{writable:false});
 Object.defineProperty(FontFaceSetLoadEvent.prototype,"fontfaces",{get:function(){return call("event:faces",this);},enumerable:true,configurable:true});
 Object.defineProperty(FontFaceSetLoadEvent.prototype,Symbol.toStringTag,{value:"FontFaceSetLoadEvent",configurable:true});
 Object.defineProperty(globalThis,"FontFace",{value:FontFace,writable:true,configurable:true});
 Object.defineProperty(globalThis,"FontFaceSet",{value:FontFaceSet,writable:true,configurable:true});
 Object.defineProperty(globalThis,"FontFaceSetLoadEvent",{value:FontFaceSetLoadEvent,writable:true,configurable:true});
 const fontSet=Object.create(FontFaceSet.prototype);
 Object.defineProperty(document,"fonts",{get:function(){return fontSet;},enumerable:true,configurable:true});
 const create=Object.create,facePrototype=FontFace.prototype;
 globalThis.__ladybirdFontFaceFactory=function(){return create(facePrototype);};
 globalThis.__ladybirdFontFaceSetWrapper=fontSet;
 const eventPrototype=FontFaceSetLoadEvent.prototype,freeze=Object.freeze;
 globalThis.__ladybirdFontLoadEventFactory=function(){return create(eventPrototype);};
 globalThis.__ladybirdFontLoadEventFreeze=function(array){return freeze(array);};
 globalThis.__ladybirdFontLoadEventSequence=function(value){if(value===undefined)return [];if((typeof value!=="object"&&typeof value!=="function")||value===null)throw new TypeError("fontfaces must be a sequence");const method=value[Symbol.iterator];if(typeof method!=="function")throw new TypeError("fontfaces must be iterable");const iterator=apply(method,value,[]),out=[];for(const face of {[Symbol.iterator](){return iterator;}}){call("event:faceBrand",null,[face]);out.push(face);}return out;};
 const setAdd=Set.prototype.add,setDelete=Set.prototype.delete,setClear=Set.prototype.clear;
 globalThis.__ladybirdFontFaceSetCache=function(operation,face){if(operation==="add")apply(setAdd,entries,[face]);else if(operation==="delete")apply(setDelete,entries,[face]);else apply(setClear,entries,[]);};
 const isView=ArrayBuffer.isView,abLength=Object.getOwnPropertyDescriptor(ArrayBuffer.prototype,"byteLength").get;
 const taProto=Object.getPrototypeOf(Uint8Array.prototype),taBuffer=Object.getOwnPropertyDescriptor(taProto,"buffer").get,taOffset=Object.getOwnPropertyDescriptor(taProto,"byteOffset").get,taLength=Object.getOwnPropertyDescriptor(taProto,"byteLength").get;
 const dvBuffer=Object.getOwnPropertyDescriptor(DataView.prototype,"buffer").get,dvOffset=Object.getOwnPropertyDescriptor(DataView.prototype,"byteOffset").get,dvLength=Object.getOwnPropertyDescriptor(DataView.prototype,"byteLength").get,U8=Uint8Array;
 globalThis.__ladybirdFontBufferSource=function(value){
  if(isView(value)){let buffer,offset,length;try{buffer=apply(taBuffer,value,[]);if(apply(abLength,buffer,[])===0)return new U8(0);offset=apply(taOffset,value,[]);length=apply(taLength,value,[]);}catch(error){try{buffer=apply(dvBuffer,value,[]);}catch(_){throw error;}if(apply(abLength,buffer,[])===0)return new U8(0);offset=apply(dvOffset,value,[]);length=apply(dvLength,value,[]);}return new U8(buffer,offset,length);}
  try{const length=apply(abLength,value,[]);if(length===0)return new U8(0);return new U8(value);}catch(_){return null;}
 };
})()
'
}
