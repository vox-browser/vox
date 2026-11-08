// Clipboard/ClipboardEvent.idl; only the owning Window exposes this interface.
module browserjs

fn clipboard_event_bootstrap() string {
	return r'(function(parent,global,construct,getTransfer){
 const apply=Reflect.apply,create=Object.create,define=Object.defineProperty,T=TypeError,prototype=create(parent.prototype);
 const ClipboardEvent=new Proxy(function ClipboardEvent(type,eventInitDict={}){throw new T("ClipboardEvent constructor requires new")},{construct(target,args,newTarget){
  const requested=newTarget.prototype,receiver=create(requested!==null&&(typeof requested==="object"||typeof requested==="function")?requested:prototype);
  if(args.length<1)throw new T("ClipboardEvent constructor requires one argument");
  apply(construct,receiver,[args[0],args.length>1?args[1]:void 0]);return receiver;
 }});
 Object.setPrototypeOf(ClipboardEvent,parent);define(ClipboardEvent,"prototype",{value:prototype,writable:false});
 define(prototype,"constructor",{value:ClipboardEvent,writable:true,configurable:true});
 define(prototype,"clipboardData",{get:getTransfer,enumerable:true,configurable:true});
 define(prototype,Symbol.toStringTag,{value:"ClipboardEvent",configurable:true});
 define(global,"ClipboardEvent",{value:ClipboardEvent,writable:true,configurable:true});
 return prototype;
})'
}
