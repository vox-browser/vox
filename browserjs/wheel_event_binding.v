// UIEvents/WheelEvent.idl; only the owning Window exposes this interface.
module browserjs

fn wheel_event_bootstrap() string {
	return r'(function(parent,global,construct,...functions){
 const apply=Reflect.apply,create=Object.create,define=Object.defineProperty,T=TypeError,prototype=create(parent.prototype);
 const WheelEvent=new Proxy(function WheelEvent(type,eventInitDict={}){throw new T("WheelEvent constructor requires new")},{construct(target,args,newTarget){
  const requested=newTarget.prototype,receiver=create(requested!==null&&(typeof requested==="object"||typeof requested==="function")?requested:prototype);
  if(args.length<1)throw new T("WheelEvent constructor requires one argument");
  apply(construct,receiver,[args[0],args.length>1?args[1]:void 0]);return receiver;
 }});
 Object.setPrototypeOf(WheelEvent,parent);define(WheelEvent,"prototype",{value:prototype,writable:false});
 define(prototype,"constructor",{value:WheelEvent,writable:true,configurable:true});
 const fields=["deltaX","deltaY","deltaZ","deltaMode","wheelDeltaX","wheelDeltaY","wheelDelta"];
 for(let i=0;i<fields.length;i++)define(prototype,fields[i],{get:functions[i],enumerable:true,configurable:true});
 for(const [name,value] of [["DOM_DELTA_PIXEL",0],["DOM_DELTA_LINE",1],["DOM_DELTA_PAGE",2]]){
  define(WheelEvent,name,{value,enumerable:true});define(prototype,name,{value,enumerable:true});
 }
 define(prototype,Symbol.toStringTag,{value:"WheelEvent",configurable:true});
 define(global,"WheelEvent",{value:WheelEvent,writable:true,configurable:true});
 return prototype;
})'
}
