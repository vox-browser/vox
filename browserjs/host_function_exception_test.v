module browserjs

import webidl

fn test_string_host_transports_preserve_callback_exception_identity() {
	mut runtime := Runtime.create()
	defer { runtime.close() }
	owner := voidptr(runtime)
	runtime.define_host_function('relay', fn [owner] (_ string) !string {
		mut callback_runtime := unsafe { &Runtime(owner) }
		callback_runtime.evaluate_host_value('throw globalThis.reason;') or {
			return copy_host_exception(err)
		}
		return ''
	})!
	runtime.define_temporary_host_function('temporaryRelay', fn [owner] (_ string) !HostFunctionReply {
		mut callback_runtime := unsafe { &Runtime(owner) }
		callback_runtime.evaluate_host_value('throw globalThis.reason;') or {
			return copy_host_exception(err)
		}
		return HostFunctionReply{}
	})!
	runtime.define_host_function('plainFailure', fn (_ string) !string {
		return error('ordinary native failure')
	})!
	runtime.define_host_function('webidlRelay', fn [owner] (_ string) !string {
		mut callback_runtime := unsafe { &Runtime(owner) }
		value := callback_runtime.evaluate_host_value('globalThis.reason')!
		return copy_host_exception(webidl.throw_value(callback_runtime.webidl_value(value)!))
	})!
	assert runtime.evaluate_host(r'
(function(){
 const reasons=[undefined,null,false,0,"callback failure",17n,Symbol("reason"),{},new Error("original")];
 for(const reason of reasons){
  globalThis.reason=reason;
  for(const relay of [globalThis.relay,globalThis.temporaryRelay,globalThis.webidlRelay]){
   let threw=false;try{relay("request");}catch(error){threw=true;if(error!==reason)throw new Error("callback exception identity changed for "+typeof reason+": "+String(error));}
   if(!threw)throw new Error("callback exception disappeared");
  }
 }
 try{plainFailure("request");}catch(error){return error instanceof Error&&error.message==="ordinary native failure";}
 return false;
})()
')! == 'true'
}
