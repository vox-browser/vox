module browserjs

pub type IntersectionObserverBeforeObserveHook = fn (&Runtime) !

fn intersection_observer_binding_factory() string {
	return r'(function(operate,global){
 "use strict";
 const define=Object.defineProperty,descriptor=Object.getOwnPropertyDescriptor,create=Object.create,freeze=Object.freeze,apply=Reflect.apply,T=global.TypeError;
 const object=v=>v!==null&&(typeof v==="object"||typeof v==="function");
 const prototypes=[{},{}];
 const IntersectionObserver=new Proxy(function IntersectionObserver(callback){throw new T("IntersectionObserver requires new")},{construct(target,args,newTarget){
  if(args.length===0||typeof args[0]!=="function")throw new T("IntersectionObserver requires a callback function");
  let options=args[1];if(options!=null&&!object(options))throw new T("IntersectionObserverInit must be a dictionary");options=options==null?{}:options;
  const rawDelay=options.delay,delay=rawDelay===undefined?0:operate("long",null,rawDelay);
  const rawRoot=options.root,root=rawRoot==null?null:operate("rootArgument",null,rawRoot);
  const rawMargin=options.rootMargin,margin=rawMargin===undefined?"0px":operate("string",null,rawMargin);
  const rawScroll=options.scrollMargin,scroll=rawScroll===undefined?"0px":operate("string",null,rawScroll);
  const rawThreshold=options.threshold;let thresholds=[];
  if(rawThreshold===undefined)thresholds=[0];
  else {
   const iterator=object(rawThreshold)?rawThreshold[Symbol.iterator]:undefined;
   if(iterator!=null){if(typeof iterator!=="function")throw new T("threshold iterator must be callable");for(const value of {[Symbol.iterator](){return apply(iterator,rawThreshold,[])}})thresholds.push(operate("double",null,value))}
   else thresholds=[operate("double",null,rawThreshold)];
  }
  const visibility=!!options.trackVisibility;
  const requested=newTarget.prototype,receiver=create(object(requested)?requested:prototypes[0]);
  operate("construct",receiver,args[0],root,margin,scroll,thresholds,delay,visibility);return receiver;
 }});
 function IntersectionObserverEntry(){throw new T("Illegal constructor")}
 for(const [index,constructor,name] of [[0,IntersectionObserver,"IntersectionObserver"],[1,IntersectionObserverEntry,"IntersectionObserverEntry"]]){
  define(constructor,"prototype",{value:prototypes[index],writable:false});
  define(prototypes[index],"constructor",{value:constructor,writable:true,configurable:true});
  define(prototypes[index],Symbol.toStringTag,{value:name,configurable:true});
  define(global,name,{value:constructor,writable:true,configurable:true});
 }
 const methods={observe(target){operate("observerBrand",this);if(arguments.length===0)throw new T("observe requires an Element");return operate("observe",this,target)},unobserve(target){operate("observerBrand",this);if(arguments.length===0)throw new T("unobserve requires an Element");return operate("unobserve",this,target)},disconnect(){return operate("disconnect",this)},takeRecords(){return operate("takeRecords",this)}};
 for(const name of Object.keys(methods))define(prototypes[0],name,{value:methods[name],writable:true,enumerable:true,configurable:true});
 for(const [index,names] of [[0,["root","rootMargin","scrollMargin","thresholds","delay","trackVisibility"]],[1,["time","rootBounds","boundingClientRect","intersectionRect","isIntersecting","intersectionRatio","target"]]])for(const name of names){
  const get=descriptor({get [name](){return operate(index===0?name:"entry "+name,this)}},name).get;
  define(prototypes[index],name,{get,enumerable:true,configurable:true});
 }
 return function make(kind,value){return kind===0?create(prototypes[1]):freeze(value)};
})'
}
