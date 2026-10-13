// UIEvents/UIEvent.idl: the shared UIEvent surface over actual DOM records.
module browserjs

fn ui_event_bootstrap() string {
	return r'(function(parent,global,construct,view,detail,which,init){
 const apply=Reflect.apply,create=Object.create,define=Object.defineProperty,T=TypeError;
 function UIEvent(type,eventInitDict={}){
  if(!new.target)throw new T("UIEvent constructor requires new");
  if(arguments.length<1)throw new T("UIEvent constructor requires one argument");
  apply(construct,this,[type,eventInitDict]);
 }
 Object.setPrototypeOf(UIEvent,parent);UIEvent.prototype=create(parent.prototype);
 define(UIEvent.prototype,"constructor",{value:UIEvent,writable:true,configurable:true});
 define(UIEvent,"prototype",{writable:false});
 for(const [property,getter] of [["view",view],["detail",detail],["which",which]]){
  define(UIEvent.prototype,property,{get:getter,enumerable:true,configurable:true});
 }
 define(UIEvent.prototype,"initUIEvent",{value:init,writable:true,enumerable:true,configurable:true});
 define(UIEvent.prototype,Symbol.toStringTag,{value:"UIEvent",configurable:true});
 define(global,"UIEvent",{value:UIEvent,writable:true,configurable:true});
 return UIEvent.prototype;
})'
}
