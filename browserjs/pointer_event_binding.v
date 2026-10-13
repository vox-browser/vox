// UIEvents/PointerEvent.idl; only the owning Window exposes this interface.
module browserjs

fn pointer_event_bootstrap() string {
	return r'(function(parent,global,secure,construct,brand,...functions){
 const apply=Reflect.apply,create=Object.create,define=Object.defineProperty,T=TypeError,iteratorKey=Symbol.iterator,prototype=create(parent.prototype);
 const object=value=>value!==null&&(typeof value==="object"||typeof value==="function");
 const PointerEvent=new Proxy(function PointerEvent(type,eventInitDict={}){throw new T("PointerEvent constructor requires new")},{construct(target,args,newTarget){
  const requested=newTarget.prototype,receiver=create(object(requested)?requested:prototype);
  if(args.length<1)throw new T("PointerEvent constructor requires one argument");
  apply(construct,receiver,[args[0],args.length>1?args[1]:void 0]);return receiver;
 }});
 Object.setPrototypeOf(PointerEvent,parent);define(PointerEvent,"prototype",{value:prototype,writable:false});
 define(prototype,"constructor",{value:PointerEvent,writable:true,configurable:true});
 const fields=["pointerId","width","height","pressure","tangentialPressure","tiltX","tiltY","twist","altitudeAngle","azimuthAngle","pointerType","isPrimary","persistentDeviceId"];
 for(let i=0;i<fields.length;i++)define(prototype,fields[i],{get:functions[i],enumerable:true,configurable:true});
 if(secure)define(prototype,"getCoalescedEvents",{value:functions[13],writable:true,enumerable:true,configurable:true});
 define(prototype,"getPredictedEvents",{value:functions[14],writable:true,enumerable:true,configurable:true});
 define(prototype,Symbol.toStringTag,{value:"PointerEvent",configurable:true});
 define(global,"PointerEvent",{value:PointerEvent,writable:true,configurable:true});
 const sequence=value=>{
  if(!object(value))throw new T("PointerEvent sequence must be an object");
  const method=value[iteratorKey];if(typeof method!=="function")throw new T("PointerEvent sequence must be iterable");
  const iterator=apply(method,value,[]);if(!object(iterator))throw new T("PointerEvent iterator must be an object");
  const next=iterator.next,result=[];let index=0;
  // The pinned generated converter uses IteratorStepValue and direct TRY on
  // each item. Its abrupt completions do not invoke IteratorClose.
  for(;;){const step=apply(next,iterator,[]);if(!object(step))throw new T("PointerEvent iterator result must be an object");if(step.done)return result;
   const item=step.value;apply(brand,void 0,[item]);define(result,index++,{value:item,writable:true,enumerable:true,configurable:true});
  }
 };
 return [prototype,sequence];
})'
}
