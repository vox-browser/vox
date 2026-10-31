// UIEvents/KeyboardEvent.idl. Exposed only on an owning Window.
module browserjs

fn keyboard_event_bootstrap() string {
	return r'(function(parent,global,construct,...functions){
 const apply=Reflect.apply,create=Object.create,define=Object.defineProperty,T=TypeError,prototype=create(parent.prototype);
 const KeyboardEvent=new Proxy(function KeyboardEvent(type,eventInitDict={}){throw new T("KeyboardEvent constructor requires new")},{construct(target,args,newTarget){
  const requested=newTarget.prototype,receiver=create(requested!==null&&(typeof requested==="object"||typeof requested==="function")?requested:prototype);
  if(args.length<1)throw new T("KeyboardEvent constructor requires one argument");
  apply(construct,receiver,[args[0],args.length>1?args[1]:void 0]);return receiver;
 }});
 Object.setPrototypeOf(KeyboardEvent,parent);define(KeyboardEvent,"prototype",{value:prototype,writable:false});
 define(prototype,"constructor",{value:KeyboardEvent,writable:true,configurable:true});
 const fields=["key","code","location","ctrlKey","shiftKey","altKey","metaKey","repeat","isComposing","charCode","keyCode"];
 for(let i=0;i<fields.length;i++)define(prototype,fields[i],{get:functions[i],enumerable:true,configurable:true});
 define(prototype,"getModifierState",{value:functions[fields.length],writable:true,enumerable:true,configurable:true});
 define(prototype,"initKeyboardEvent",{value:functions[fields.length+1],writable:true,enumerable:true,configurable:true});
 for(const [name,value] of [["DOM_KEY_LOCATION_STANDARD",0],["DOM_KEY_LOCATION_LEFT",1],["DOM_KEY_LOCATION_RIGHT",2],["DOM_KEY_LOCATION_NUMPAD",3]]){
  define(KeyboardEvent,name,{value,enumerable:true});define(prototype,name,{value,enumerable:true});
 }
 define(prototype,Symbol.toStringTag,{value:"KeyboardEvent",configurable:true});
 define(global,"KeyboardEvent",{value:KeyboardEvent,writable:true,configurable:true});
 return prototype;
})'
}
