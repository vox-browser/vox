// UIEvents/MouseEvent.idl; concrete pointer/wheel/drag interfaces remain separate.
module browserjs

fn mouse_event_bootstrap() string {
	return r'(function(parent,global,construct,...functions){
 const apply=Reflect.apply,create=Object.create,define=Object.defineProperty,T=TypeError,prototype=create(parent.prototype);
 const MouseEvent=new Proxy(function MouseEvent(type,eventInitDict={}){throw new T("MouseEvent constructor requires new")},{construct(target,args,newTarget){
  const requested=newTarget.prototype;
  const receiver=create(requested!==null&&(typeof requested==="object"||typeof requested==="function")?requested:prototype);
  if(args.length<1)throw new T("MouseEvent constructor requires one argument");
  apply(construct,receiver,[args[0],args.length>1?args[1]:void 0]);
  return receiver;
 }});
 Object.setPrototypeOf(MouseEvent,parent);define(MouseEvent,"prototype",{value:prototype,writable:false});
 define(MouseEvent.prototype,"constructor",{value:MouseEvent,writable:true,configurable:true});
 const properties=["screenX","screenY","pageX","pageY","clientX","clientY","x","y","offsetX","offsetY","ctrlKey","shiftKey","altKey","metaKey","movementX","movementY","button","buttons","relatedTarget"];
 for(let i=0;i<properties.length;i++)define(MouseEvent.prototype,properties[i],{get:functions[i],enumerable:true,configurable:true});
 define(MouseEvent.prototype,"getModifierState",{value:functions[19],writable:true,enumerable:true,configurable:true});
 define(MouseEvent.prototype,"initMouseEvent",{value:functions[20],writable:true,enumerable:true,configurable:true});
 define(MouseEvent.prototype,Symbol.toStringTag,{value:"MouseEvent",configurable:true});
 define(global,"MouseEvent",{value:MouseEvent,writable:true,configurable:true});
 return MouseEvent.prototype;
})'
}
