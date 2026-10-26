module browserjs

// MessageEvent is shared by Window and worker realms. Only Window receives
// the Window.postMessage overloads; a dedicated worker supplies its own sender.
fn window_message_binding_factory() string {
	return r'(function(operate,global,windowMessaging){
 const define=Object.defineProperty,descriptor=Object.getOwnPropertyDescriptor,create=Object.create,freeze=Object.freeze;
 const T=global.TypeError,Parent=global.Event,ports=new WeakMap();
 const object=value=>value!==null&&(typeof value==="object"||typeof value==="function");
 function sequence(value){
  if(value===undefined)return [];
  if(!object(value))throw new T("transfer must be an iterable object");
  const result=[];for(const item of value){if(!object(item))throw new T("transfer entries must be objects");result.push(item)}return result;
 }
 const methods={postMessage(message,targetOrigin){
  if(arguments.length<1)throw new T("postMessage requires one argument");
  const receiver=this==null?global:this;operate("windowBrand",receiver);
  let origin="/",transfer=[];
  if(targetOrigin==null||object(targetOrigin)){
   if(targetOrigin!=null){const value=targetOrigin.targetOrigin;if(value!==undefined)origin=operate("string",receiver,value);transfer=sequence(targetOrigin.transfer)}
  }else{origin=operate("string",receiver,targetOrigin);transfer=sequence(arguments[2])}
  return operate("post",receiver,message,origin,transfer.length);
 },initMessageEvent(type,bubbles=false,cancelable=false,data=null,origin="",lastEventId="",source=null,ports=[]){
  if(arguments.length<1)throw new T("initMessageEvent requires one argument");
  operate("init",this,type,bubbles,cancelable,data,origin,lastEventId,source,sequence(ports));
 }};
 if(windowMessaging)define(global,"postMessage",{value:methods.postMessage,writable:true,enumerable:true,configurable:true});
 const prototype=create(Parent.prototype);
 const MessageEvent=new Proxy(function MessageEvent(type,eventInitDict={}){throw new T("MessageEvent constructor requires new")},{construct(target,args,newTarget){
  if(args.length<1)throw new T("MessageEvent requires one argument");
  const requested=newTarget.prototype,receiver=create(object(requested)?requested:prototype);
  operate("construct",receiver,args[0],args.length>1?args[1]:undefined);return receiver;
 }});
 Object.setPrototypeOf(MessageEvent,Parent);
 define(MessageEvent,"prototype",{value:prototype,writable:false});
 define(prototype,"constructor",{value:MessageEvent,writable:true,configurable:true});
 define(prototype,"initMessageEvent",{value:methods.initMessageEvent,writable:true,enumerable:true,configurable:true});
 for(const name of ["data","origin","lastEventId","source","ports"]){
  const get=descriptor({get [name](){
   if(name!=="ports")return operate(name,this);
   operate("eventBrand",this);if(!ports.has(this))ports.set(this,freeze(operate(name,this)));return ports.get(this);
  }},name).get;
  define(prototype,name,{get,enumerable:true,configurable:true});
 }
 define(prototype,Symbol.toStringTag,{value:"MessageEvent",configurable:true});
 define(global,"MessageEvent",{value:MessageEvent,writable:true,configurable:true});
 return [prototype,function validatePorts(value){if(sequence(value).length)throw new T("ports must contain native MessagePort objects")}];
})'
}
