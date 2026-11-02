module browserjs

// HTML/MessageChannel.idl and MessagePort.idl. The actual port owns its queue,
// entanglement and EventTarget; this factory only supplies realm wrappers.
fn message_channel_binding_factory() string {
	return r'(function(operate,global){
 const define=Object.defineProperty,descriptor=Object.getOwnPropertyDescriptor,T=global.TypeError;
 const object=value=>value!==null&&(typeof value==="object"||typeof value==="function");
 function sequence(value,method){
  if(!object(value))throw new T("transfer must be an iterable object");
  if(arguments.length<2)method=value[Symbol.iterator];
  if(typeof method!=="function")throw new T("transfer must be iterable");
  const result=[],iterable={[Symbol.iterator](){return Reflect.apply(method,value,[]);}};
  for(const item of iterable){if(!object(item))throw new T("transfer entries must be objects");result.push(item);}
  return result;
 }
 function MessageChannel(){if(!new.target)throw new T("MessageChannel constructor requires new");operate("construct",this);}
 function MessagePort(){throw new T("Illegal constructor");}
 Object.setPrototypeOf(MessagePort,global.EventTarget);
 Object.setPrototypeOf(MessagePort.prototype,global.EventTarget.prototype);
 for(const [constructor,name] of [[MessageChannel,"MessageChannel"],[MessagePort,"MessagePort"]]){
  define(constructor,"prototype",{writable:false});
  define(constructor.prototype,Symbol.toStringTag,{value:name,configurable:true});
  define(global,name,{value:constructor,writable:true,configurable:true});
 }
 for(const name of ["port1","port2"]){
  const get=descriptor({get [name](){return operate(name,this);}},name).get;
  define(MessageChannel.prototype,name,{get,enumerable:true,configurable:true});
 }
 const methods={postMessage(message){
  operate("brand",this);
  if(arguments.length<1)throw new T("postMessage requires one argument");
  const options=arguments[1];let transfer=[];
  if(options!=null){
   if(!object(options))throw new T("StructuredSerializeOptions must be an object");
   const iterator=options[Symbol.iterator];
   if(iterator!=null)transfer=sequence(options,iterator);
   else{const value=options.transfer;if(value!==undefined)transfer=sequence(value);}
  }
  return operate("post",this,message,transfer);
 },start(){return operate("start",this);},close(){return operate("close",this);}};
 for(const name of ["postMessage","start","close"])define(MessagePort.prototype,name,{value:methods[name],writable:true,enumerable:true,configurable:true});
 for(const name of ["onmessage","onmessageerror"]){
  const attributes=descriptor({get [name](){return operate("getHandler",this,name.slice(2));},set [name](value){operate("setHandler",this,name.slice(2),value);}},name);
  define(MessagePort.prototype,name,{get:attributes.get,set:attributes.set,enumerable:true,configurable:true});
 }
 return MessagePort.prototype;
})'
}
