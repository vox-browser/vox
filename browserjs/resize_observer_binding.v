module browserjs

pub type ResizeObserverBeforeObserveHook = fn (&Runtime) !

fn resize_observer_binding_factory() string {
	return r'(function(operate,global){
 "use strict";
 const define=Object.defineProperty,descriptor=Object.getOwnPropertyDescriptor,create=Object.create,freeze=Object.freeze,T=global.TypeError;
 const object=v=>v!==null&&(typeof v==="object"||typeof v==="function");
 const prototypes=[{},{},{}];
 const ResizeObserver=new Proxy(function ResizeObserver(callback){throw new T("ResizeObserver requires new")},{construct(target,args,newTarget){
  if(args.length===0||typeof args[0]!=="function")throw new T("ResizeObserver requires a callback function");
  const requested=newTarget.prototype,receiver=create(object(requested)?requested:prototypes[0]);
  operate("construct",receiver,args[0]);return receiver;
 }});
 function ResizeObserverEntry(){throw new T("Illegal constructor")}
 function ResizeObserverSize(){throw new T("Illegal constructor")}
 for(const [index,constructor,name] of [[0,ResizeObserver,"ResizeObserver"],[1,ResizeObserverEntry,"ResizeObserverEntry"],[2,ResizeObserverSize,"ResizeObserverSize"]]){
  define(constructor,"prototype",{value:prototypes[index],writable:false});
  define(prototypes[index],"constructor",{value:constructor,writable:true,configurable:true});
  define(prototypes[index],Symbol.toStringTag,{value:name,configurable:true});
  define(global,name,{value:constructor,writable:true,configurable:true});
 }
 const methods={observe(target){
  operate("brand",this);if(arguments.length===0)throw new T("observe requires an Element");operate("element",null,target);
  let options=arguments[1];if(options!=null&&!object(options))throw new T("ResizeObserverOptions must be a dictionary");options=options==null?{}:options;
  const raw=options.box,box=raw===undefined?"content-box":operate("string",null,raw);
  if(box!=="content-box"&&box!=="border-box"&&box!=="device-pixel-content-box")throw new T("Invalid ResizeObserverBoxOptions");
  return operate("observe",this,target,box);
 },unobserve(target){operate("brand",this);if(arguments.length===0)throw new T("unobserve requires an Element");return operate("unobserve",this,target)},disconnect(){return operate("disconnect",this)}};
 for(const name of Object.keys(methods))define(prototypes[0],name,{value:methods[name],writable:true,enumerable:true,configurable:true});
 for(const [index,names] of [[1,["target","contentRect","borderBoxSize","contentBoxSize","devicePixelContentBoxSize"]],[2,["inlineSize","blockSize"]]])for(const name of names){
  const get=descriptor({get [name](){return operate((index===1?"entry ":"size ")+name,this)}},name).get;
  define(prototypes[index],name,{get,enumerable:true,configurable:true});
 }
 return function make(kind,value){return kind===3?freeze(value):create(prototypes[kind])};
})'
}
