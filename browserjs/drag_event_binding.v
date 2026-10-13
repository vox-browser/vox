// HTML/DragEvent.idl; only the owning Window exposes this interface.
module browserjs

fn drag_event_bootstrap() string {
	return r'(function(parent,global,construct,getTransfer){
 const apply=Reflect.apply,create=Object.create,define=Object.defineProperty,T=TypeError,prototype=create(parent.prototype);
 const DragEvent=new Proxy(function DragEvent(type,eventInitDict={}){throw new T("DragEvent constructor requires new")},{construct(target,args,newTarget){
  const requested=newTarget.prototype,receiver=create(requested!==null&&(typeof requested==="object"||typeof requested==="function")?requested:prototype);
  if(args.length<1)throw new T("DragEvent constructor requires one argument");
  apply(construct,receiver,[args[0],args.length>1?args[1]:void 0]);return receiver;
 }});
 Object.setPrototypeOf(DragEvent,parent);define(DragEvent,"prototype",{value:prototype,writable:false});
 define(prototype,"constructor",{value:DragEvent,writable:true,configurable:true});
 define(prototype,"dataTransfer",{get:getTransfer,enumerable:true,configurable:true});
 define(prototype,Symbol.toStringTag,{value:"DragEvent",configurable:true});
 define(global,"DragEvent",{value:DragEvent,writable:true,configurable:true});
 return prototype;
})'
}
