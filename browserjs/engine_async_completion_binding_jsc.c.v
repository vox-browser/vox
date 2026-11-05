// JavaScriptCore settles WebAssembly compilation from its own run-loop timer,
// outside any Vox host callback. The continuations then run with no host
// boundary that marks the document state dirty, so DOM changes they record
// (Discord's Rust core inserts its next script chunk there) were never
// replayed and the page stalled. Observe those settlements and wake the
// embedder; the original promise and its reaction order are unchanged.
module browserjs

pub fn (mut runtime Runtime) install_engine_async_completion_binding() ! {
	runtime.require_javascript_value_context()!
	owner := voidptr(&runtime)
	notify := runtime.make_value_host_function(fn [owner] (_ voidptr, _ []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		runtime.mark_document_state_dirty()
		return C.vox_jsc_JSValueMakeUndefined(runtime.context)
	})!
	installer := runtime.evaluate_host_value(engine_async_completion_bootstrap)!
	defer { runtime.release_javascript_value(installer) }
	runtime.call_javascript_function(installer, C.vox_jsc_JSValueMakeUndefined(runtime.context), [
		notify,
	])!
}

const engine_async_completion_bootstrap = r'(function(notify){
 "use strict";
 const engine=globalThis.WebAssembly;
 if(typeof engine!=="object"||engine===null)return;
 const then=Promise.prototype.then,apply=Reflect.apply,define=Object.defineProperty;
 for(const name of ["compile","instantiate","compileStreaming","instantiateStreaming"]){
  const original=engine[name];
  if(typeof original!=="function")continue;
  const wrapped={[name](source){const promise=apply(original,this,arguments);apply(then,promise,[notify,notify]);return promise}}[name];
  define(wrapped,"length",{value:original.length,configurable:true});
  define(engine,name,{value:wrapped,writable:true,enumerable:false,configurable:true});
 }
})'
