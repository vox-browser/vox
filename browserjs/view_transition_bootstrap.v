// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// ViewTransition.idl conversion and same-object wrappers for the native host.
module browserjs

pub fn view_transition_bootstrap() string {
	return dom_exception_bootstrap() + r'
const __viewTransitions=new Map(),__viewTransitionStates=new WeakMap(),__viewTransitionToken={},__viewTransitionDOMException=globalThis.DOMException;
function __viewTransitionCall(method,key,extra){return JSON.parse(__ladybirdViewTransition(JSON.stringify(Object.assign({method:method,key:key},extra||{}))));}
function __viewTransitionState(receiver){const state=__viewTransitionStates.get(receiver);if(!state)throw new TypeError("Illegal invocation");return state;}
function __viewTransitionPromise(){let resolve,reject;const promise=new Promise(function(a,b){resolve=a;reject=b;});return{promise:promise,resolve:resolve,reject:reject};}
class ViewTransition {
 constructor(token,key,callback){
  if(token!==__viewTransitionToken)throw new TypeError("Illegal constructor");
  const state={key:key,callback:callback,callbackCalled:false,callbackRejected:false,callbackReason:undefined,ready:__viewTransitionPromise(),updateCallbackDone:__viewTransitionPromise(),finished:__viewTransitionPromise()};
  state.finished.promise.catch(function(){});
  __viewTransitionStates.set(this,state);__viewTransitions.set(key,this);
  __viewTransitionCall("subscribe",key);
 }
 get ready(){return __viewTransitionState(this).ready.promise;}
 get updateCallbackDone(){return __viewTransitionState(this).updateCallbackDone.promise;}
 get finished(){return __viewTransitionState(this).finished.promise;}
 skipTransition(){const state=__viewTransitionState(this);__viewTransitionCall("skip",state.key);}
}
Object.defineProperty(ViewTransition.prototype,Symbol.toStringTag,{value:"ViewTransition",configurable:true});
Object.defineProperty(ViewTransition,"length",{value:0,configurable:true});
for(const name of ["ready","updateCallbackDone","finished","skipTransition"]){const descriptor=Object.getOwnPropertyDescriptor(ViewTransition.prototype,name);descriptor.enumerable=true;Object.defineProperty(ViewTransition.prototype,name,descriptor);}
Object.defineProperty(globalThis,"ViewTransition",{value:ViewTransition,writable:true,configurable:true});
globalThis.__ladybirdViewTransitionInvoke=function(key){
 const transition=__viewTransitions.get(key),state=__viewTransitionState(transition);
 if(state.callbackCalled)return;state.callbackCalled=true;
 function reject(reason){state.callbackRejected=true;state.callbackReason=reason;__viewTransitionCall("settleCallback",key,{fulfilled:false});}
 let result;try{result=Reflect.apply(state.callback,undefined,[]);}catch(reason){reject(reason);return;}
 Promise.resolve(result).then(function(){__viewTransitionCall("settleCallback",key,{fulfilled:true});},reject);
};
globalThis.__ladybirdViewTransitionSettle=function(payload){
 const transition=__viewTransitions.get(payload.key),state=__viewTransitionState(transition),entry=state[payload.promise];
 if(payload.fulfilled){entry.resolve(undefined);return;}
 if(payload.handled)entry.promise.catch(function(){});
 if(state.callbackRejected&&payload.reason==="__view_transition_callback_"+payload.key){entry.reject(state.callbackReason);return;}
 const match=/^([A-Za-z]+Error):\s*(.*)/.exec(payload.reason),name=match?match[1]:"Error",message=match?match[2]:payload.reason;
 const reason=new __viewTransitionDOMException(message,name);
 entry.reject(reason);
};
Object.defineProperty(document,"startViewTransition",{value:function startViewTransition(callback=undefined){
 if(this!==document)throw new TypeError("Illegal invocation");
 // The pinned IDL accepts an optional non-nullable function; null and
 // StartViewTransitionOptions dictionaries are not accepted by its binding.
 if(callback!==undefined&&typeof callback!=="function")throw new TypeError("ViewTransition update callback must be a function");
 const key=__viewTransitionCall("start",0,{hasCallback:callback!==undefined});
 return new ViewTransition(__viewTransitionToken,key,callback);
},writable:true,configurable:true,enumerable:true});
Object.defineProperty(document,"activeViewTransition",{get:function(){
 if(this!==document)throw new TypeError("Illegal invocation");
 const key=__viewTransitionCall("active",0);return key===null?null:__viewTransitions.get(key)||new ViewTransition(__viewTransitionToken,key,undefined);
},configurable:true,enumerable:true});
'
}
