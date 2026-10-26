module browserjs

// JSC owns Promise jobs in the browser backend. Use that same FIFO for the
// host's queueMicrotask jobs, then enter the translated HTML callback realm.
fn microtask_binding_factory() string {
	return r'(function(deliver,global,promise,queue){
 "use strict";
 const apply=Reflect.apply,then=Promise.prototype.then,define=Object.defineProperty;
 // Promise.prototype.constructor and @@species are author mutable. This
 // private carrier must always use the engine intrinsic default constructor.
 define(promise,"constructor",{value:undefined});
 define(global,"queueMicrotask",{value:queue,writable:true,enumerable:true,configurable:true});
 let active=true;
 return [function enqueue(token){apply(then,promise,[function(){if(active)deliver(token)}])},function close(){active=false}];
})'
}
