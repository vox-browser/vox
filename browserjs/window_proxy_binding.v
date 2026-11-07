module browserjs

import dom

pub struct FrameWindowResult {
pub:
	proxy ?&dom.WindowProxy
}

pub type FrameWindowResolver = fn (voidptr) !FrameWindowResult

fn window_proxy_binding_factory() string {
	return r'(function(operate,global){
 "use strict";
 const define=Object.defineProperty,descriptor=Object.getOwnPropertyDescriptor,create=Object.create;
 const post=global.postMessage,apply=Reflect.apply,WindowPrototype=global.Window.prototype;
 const frame=descriptor({get contentWindow(){return operate("frame",this)}},"contentWindow").get;
 define(global.HTMLIFrameElement.prototype,"contentWindow",{get:frame,enumerable:true,configurable:true});
 // A same-origin child WindowProxy is its global; other proxies throw or
 // expose no document, and both mean the content document is unavailable.
 const content=descriptor({get contentDocument(){
  const view=apply(frame,this,[]);if(view===null||view===undefined)return null;
  try{const value=view.document;return value===undefined?null:value;}catch(error){return null;}
 }},"contentDocument").get;
 define(global.HTMLIFrameElement.prototype,"contentDocument",{get:content,enumerable:true,configurable:true});
 for(const name of ["parent","top","frames","length"]){
  const accessors=descriptor({
   get [name](){const receiver=this==null?global:this;return name==="frames"?(operate("brand",receiver),receiver):operate(name,receiver)},
   set [name](value){const receiver=this==null?global:this;operate("brand",receiver);define(receiver,name,{value,writable:true,enumerable:true,configurable:true})}
  },name);
  const attributes={get:accessors.get,set:undefined,enumerable:true,configurable:name!=="top"};
  if(name!=="top")attributes.set=accessors.set;
  define(global,name,attributes);
 }
 return function(){
  let proxy;
  const target=create(WindowPrototype),methods={
   postMessage(message,targetOrigin){return apply(post,this,arguments)},
   close(){return operate("close",this)},focus(){return operate("focus",this)},blur(){return operate("blur",this)},
   toString(){return "[object Window]"}
  };
  proxy=new Proxy(target,{
   get(target,key){
    if(key===Symbol.toStringTag)return "Window";
    if(key==="then")return undefined;
    if(typeof key!=="string")return undefined;
    if(key==="window"||key==="self"||key==="frames")return proxy;
    if(Object.prototype.hasOwnProperty.call(methods,key))return methods[key];
    if(key==="parent"||key==="top"||key==="opener"||key==="length"||key==="closed")return operate(key,proxy);
    if(/^(0|[1-9][0-9]*)$/.test(key))return operate("index",proxy,key);
    return operate("get",proxy,key);
   },
   set(){return operate("write",proxy)},
   defineProperty(){return operate("write",proxy)},
   deleteProperty(){return operate("write",proxy)},
   getPrototypeOf(){return operate("sameOrigin",proxy)?WindowPrototype:null},
   preventExtensions(){return false}
  });
  return proxy;
 };
})'
}
