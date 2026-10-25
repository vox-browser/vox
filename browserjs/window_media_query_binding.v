module browserjs

// CSSOM View Window.matchMedia, MediaQueryList and MediaQueryListEvent IDL.
fn window_media_query_binding_factory() string {
	return r'(function(operate,global){
 const define=Object.defineProperty,descriptor=Object.getOwnPropertyDescriptor,create=Object.create;
 const T=global.TypeError,Target=global.EventTarget,Parent=global.Event;
 function MediaQueryList(){throw new T("Illegal constructor")}
 Object.setPrototypeOf(MediaQueryList,Target);
 Object.setPrototypeOf(MediaQueryList.prototype,Target.prototype);
 const methods={
  matchMedia(query){if(arguments.length<1)throw new T("matchMedia requires one argument");return operate("match",this,query)},
  addListener(callback){if(arguments.length<1)throw new T("addListener requires one argument");return operate("addListener",this,callback)},
  removeListener(callback){if(arguments.length<1)throw new T("removeListener requires one argument");return operate("removeListener",this,callback)}
 };
 define(global,"matchMedia",{value:methods.matchMedia,writable:true,enumerable:true,configurable:true});
 for(const name of ["addListener","removeListener"])define(MediaQueryList.prototype,name,{value:methods[name],writable:true,enumerable:true,configurable:true});
 for(const name of ["media","matches"]){const get=descriptor({get [name](){return operate(name,this)}},name).get;define(MediaQueryList.prototype,name,{get,enumerable:true,configurable:true})}
 const handler=descriptor({get onchange(){return operate("getHandler",this)},set onchange(value){operate("setHandler",this,value)}},"onchange");
 define(MediaQueryList.prototype,"onchange",{...handler,enumerable:true,configurable:true});
 const eventPrototype=create(Parent.prototype);
 const MediaQueryListEvent=new Proxy(function MediaQueryListEvent(type,eventInitDict={}){throw new T("MediaQueryListEvent constructor requires new")},{construct(target,args,newTarget){
  if(args.length<1)throw new T("MediaQueryListEvent requires one argument");
  const requested=newTarget.prototype,receiver=create(requested!==null&&(typeof requested==="object"||typeof requested==="function")?requested:eventPrototype);
  operate("constructEvent",receiver,args[0],args.length>1?args[1]:void 0);return receiver;
 }});
 Object.setPrototypeOf(MediaQueryListEvent,Parent);
 define(MediaQueryListEvent,"prototype",{value:eventPrototype,writable:false});
 define(eventPrototype,"constructor",{value:MediaQueryListEvent,writable:true,configurable:true});
 for(const name of ["media","matches"]){const get=descriptor({get [name](){return operate("event"+name,this)}},name).get;define(eventPrototype,name,{get,enumerable:true,configurable:true})}
 for(const [constructor,name] of [[MediaQueryList,"MediaQueryList"],[MediaQueryListEvent,"MediaQueryListEvent"]]){
  define(constructor.prototype,Symbol.toStringTag,{value:name,configurable:true});define(constructor,"prototype",{writable:false});define(global,name,{value:constructor,writable:true,configurable:true});
 }
 return [MediaQueryList.prototype,eventPrototype];
})'
}
