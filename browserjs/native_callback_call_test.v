module browserjs

fn install_native_callback_call_test(mut runtime Runtime) ! {
	owner := voidptr(&runtime)
	runtime.define_value_host_function('__invokeCallback', fn [owner] (_ voidptr, args []voidptr) !voidptr {
		runtime := unsafe { &Runtime(owner) }
		return runtime.call_javascript_function(args[0], args[1], args[2..])
	})!
}

fn test_native_callback_call_preserves_strict_and_sloppy_primitive_receivers() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	install_native_callback_call_test(mut runtime)!
	assert runtime.evaluate_host(r'(()=>{
 const strict=function(){"use strict";return this},sloppy=Function("return this");
 for(const receiver of [undefined,null,false,true,-0,42,NaN,1n,"text",Symbol("receiver"),{},[]]){
  if(!Object.is(__invokeCallback(strict,receiver),receiver))return false;
  const actual=__invokeCallback(sloppy,receiver);
  if(receiver==null){if(actual!==globalThis)return false}
  else if(typeof receiver==="object"){if(actual!==receiver)return false}
  else if(!Object.is(actual.valueOf(),receiver))return false;
 }
 return true;
})()')! == 'true'
}

fn test_native_callback_call_preserves_argument_counts_and_actual_values() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	install_native_callback_call_test(mut runtime)!
	assert runtime.evaluate_host(r'(()=>{
 const receiver={},cycle={};cycle.self=cycle;
 const values=[undefined,null,false,-0,NaN,1n,Symbol("value"),cycle,new Uint8Array([1,2]),()=>42];
 const callback=function(){"use strict";return {receiver:this,values:Array.from(arguments)}};
 for(const length of [0,1,6,7,8,9,20,100]){
  const args=Array.from({length},(_,i)=>values[i%values.length]);
  const result=__invokeCallback(callback,receiver,...args);
  if(result.receiver!==receiver||result.values.length!==length)return false;
  if(!args.every((value,index)=>Object.is(value,result.values[index])))return false;
 }
 return true;
})()')! == 'true'
}

fn test_native_callback_call_keeps_captured_intrinsics_and_ignores_target_call_properties() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	install_native_callback_call_test(mut runtime)!
	assert runtime.evaluate_host(r'(()=>{
 const savedCall=Function.prototype.call,savedApply=Reflect.apply;
 const receiver=Symbol("receiver"),callback=function(value){"use strict";return this===receiver&&value===receiver};
 Object.defineProperty(callback,"call",{get(){throw "target call getter"}});
 Object.defineProperty(callback,"apply",{get(){throw "target apply getter"}});
 Function.prototype.call=()=>{throw "author call"};Reflect.apply=()=>{throw "author apply"};
 try{return __invokeCallback(callback,receiver,receiver)}
 finally{Function.prototype.call=savedCall;Reflect.apply=savedApply}
})()')! == 'true'
}

fn test_native_callback_call_preserves_bound_functions_proxies_and_noncallable_errors() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	install_native_callback_call_test(mut runtime)!
	assert runtime.evaluate_host(r'(()=>{
 const owner={},receiver={},callback=function(value){"use strict";return [this,value]};
 const bound=callback.bind(owner,owner),result=__invokeCallback(bound,receiver,receiver);
 if(result[0]!==owner||result[1]!==owner)return false;
 let calls=0;
 const proxy=new Proxy(callback,{apply(target,actual,args){calls++;return Reflect.apply(target,actual,args)}});
 const forwarded=__invokeCallback(proxy,receiver,owner);
 if(calls!==1||forwarded[0]!==receiver||forwarded[1]!==owner)return false;
 const revoked=Proxy.revocable(callback,{});revoked.revoke();
 for(const target of [undefined,null,1,"text",{},class Example{},revoked.proxy]){
  let caught=false;try{__invokeCallback(target,receiver)}catch(error){caught=error instanceof TypeError}
  if(!caught)return false;
 }
 return true;
})()')! == 'true'
}

fn test_native_callback_call_preserves_thrown_values_reentry_and_promise_order() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	install_native_callback_call_test(mut runtime)!
	assert runtime.evaluate_host(r'(()=>{
 const throwing=function(value){throw value};
 for(const reason of [undefined,null,false,-0,NaN,1n,"reason",Symbol("reason"),{}]){
  let caught=false;try{__invokeCallback(throwing,undefined,reason)}catch(error){caught=true;if(!Object.is(error,reason))return false}
  if(!caught)return false;
 }
 const strict=function(value){"use strict";return this===value};
 const outer=function(value){return __invokeCallback(strict,value,value)};
 if(!__invokeCallback(outer,null,Symbol("nested")))return false;
 globalThis.nativeCallOrder=[];
 __invokeCallback(function(){Promise.resolve().then(()=>nativeCallOrder.push("reaction"));nativeCallOrder.push("callback")},undefined);
 nativeCallOrder.push("outer");
 return nativeCallOrder.join(",")==="callback,outer";
})()')! == 'true'
	assert runtime.evaluate_host('nativeCallOrder.join(",")')! == 'callback,outer,reaction'
}
