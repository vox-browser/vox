module browserjs

#include "@DIR/native_forwarding_test.h"

fn C.vox_forwarding_reset_api_exceptions()
fn C.vox_forwarding_api_exception_count() u32
fn C.JSGarbageCollect(context voidptr)

fn test_native_forwarding_keeps_exception_identity_without_an_intermediate_api_exception() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	callback := runtime.evaluate_host_value('(function(value){throw value})')!
	ordinary := runtime.make_native_value_host_function('ordinary', 1, fn [runtime, callback] (receiver voidptr, args []voidptr) !voidptr {
		return runtime.call_javascript_function(callback, receiver, args)
	})!
	forwarded := runtime.make_native_value_host_function('forwarded', 1, fn [runtime, callback] (receiver voidptr, args []voidptr) !voidptr {
		return runtime.forward_javascript_function(callback, receiver, args)
	})!
	runtime.define_value_host_function('__ordinaryForward', fn [ordinary] (_ voidptr, _ []voidptr) !voidptr { return ordinary })!
	runtime.define_value_host_function('__caughtForward', fn [forwarded] (_ voidptr, _ []voidptr) !voidptr { return forwarded })!
	C.vox_forwarding_reset_api_exceptions()
	assert runtime.evaluate_host('(()=>{const marker={};try{__ordinaryForward()(marker)}catch(error){return error===marker}return false})()')! == 'true'
	assert C.vox_forwarding_api_exception_count() > 0
	C.vox_forwarding_reset_api_exceptions()
	assert runtime.evaluate_host(r'(()=>{
 const forwarded=__caughtForward();
 const revoked=Proxy.revocable({},{});revoked.revoke();
 for(const marker of [undefined,null,false,0,1n,"reason",Symbol("reason"),{},revoked.proxy]){
  let caught=false;try{forwarded(marker)}catch(error){caught=true;if(!Object.is(error,marker))return false}
  if(!caught)return false;
 }
 return true;
})()')! == 'true'
	assert C.vox_forwarding_api_exception_count() == 0
}

fn test_native_forwarding_preserves_strict_receivers_success_values_reentry_and_intrinsics() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	callback := runtime.evaluate_host_value('(function(value){"use strict";return [this,value]})')!
	primitive := runtime.evaluate_host_value('Symbol("strict primitive receiver")')!
	result := runtime.retain_javascript_value(runtime.forward_javascript_function(callback, primitive, [primitive])!)!
	runtime.define_value_host_function('__strictForwardedResult', fn [result] (_ voidptr, _ []voidptr) !voidptr { return result })!
	assert runtime.evaluate_host('__strictForwardedResult()[0]===__strictForwardedResult()[1]')! == 'true'
	forwarded := runtime.make_native_value_host_function('forwarded', 1, fn [runtime, callback] (receiver voidptr, args []voidptr) !voidptr {
		return runtime.forward_javascript_function(callback, receiver, args)
	})!
	runtime.define_value_host_function('__successfulForward', fn [forwarded] (_ voidptr, _ []voidptr) !voidptr { return forwarded })!
	assert runtime.evaluate_host(r'(()=>{
 const forwarded=__successfulForward(),receiver={},value={};
 const saved=Reflect.apply;Reflect.apply=()=>{throw "author apply"};
 try{const result=forwarded.call(receiver,value);return result[0]===receiver&&result[1]===value}
 finally{Reflect.apply=saved}
})()')! == 'true'
	inner := runtime.evaluate_host_value('(function(value){throw value})')!
	runtime.define_value_host_function('__nestedForward', fn [runtime, inner] (receiver voidptr, args []voidptr) !voidptr {
		return runtime.forward_javascript_function(inner, receiver, args)
	})!
	outer := runtime.evaluate_host_value('(function(value){return __nestedForward(value)})')!
	runtime.define_value_host_function('__outerForward', fn [runtime, outer] (receiver voidptr, args []voidptr) !voidptr {
		return runtime.forward_javascript_function(outer, receiver, args)
	})!
	C.vox_forwarding_reset_api_exceptions()
	assert runtime.evaluate_host('(()=>{const marker={};try{__outerForward(marker)}catch(error){return error===marker}return false})()')! == 'true'
	assert C.vox_forwarding_api_exception_count() == 0
}

fn test_native_forwarding_retains_thrown_values_for_collection_and_rejects_closed_runtimes() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	callback := runtime.evaluate_host_value('(function(){throw {answer:42}})')!
	mut retained := unsafe { nil }
	if _ := runtime.forward_javascript_function(callback, C.vox_jsc_JSValueMakeUndefined(runtime.context), []voidptr{}) {
		assert false
	} else {
		if err is JavaScriptValueException { retained = err.value } else { assert false }
	}
	C.JSGarbageCollect(runtime.context)
	runtime.define_value_host_function('__forwardedReason', fn [retained] (_ voidptr, _ []voidptr) !voidptr { return retained })!
	assert runtime.evaluate_host('__forwardedReason().answer')! == '42'
	runtime.close()
	assert runtime.protected_values_.len == 0
	C.vox_forwarding_reset_api_exceptions()
	if _ := runtime.forward_javascript_function(callback, unsafe { nil }, []voidptr{}) { assert false }
	else { assert err.msg().contains('closed') }
	assert C.vox_forwarding_api_exception_count() == 0
}

// Every argument count reaches the implementation unchanged, results are
// returned as they are, and a throw inside a nested forward does not disturb
// the value an outer forward is about to report.
fn test_native_forwarding_passes_each_argument_and_keeps_nested_failures_apart() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	callback := runtime.evaluate_host_value('(function(){"use strict";return [this,arguments.length,...arguments]})')!
	forwarded := runtime.make_native_value_host_function('forwarded', 0, fn [runtime, callback] (receiver voidptr, args []voidptr) !voidptr {
		return runtime.forward_javascript_function(callback, receiver, args)
	})!
	runtime.define_value_host_function('__argumentForward', fn [forwarded] (_ voidptr, _ []voidptr) !voidptr { return forwarded })!
	assert runtime.evaluate_host(r'(()=>{
 const forwarded=__argumentForward(),receiver={},a={},b=[];
 for(const args of [[],[a],[a,b],[undefined,null,a],[1,"two",a,b,Symbol.iterator,6n,7,8]]){
  const result=forwarded.apply(receiver,args);
  if(result[0]!==receiver||result[1]!==args.length)return false;
  for(let i=0;i<args.length;i++)if(!Object.is(result[i+2],args[i]))return false;
 }
 return true;
})()')! == 'true'
	// The inner forward fails and is handled by the implementation of the
	// outer one, which then throws a different value.
	inner := runtime.evaluate_host_value('(function(value){throw value})')!
	runtime.define_value_host_function('__innerFailure', fn [runtime, inner] (receiver voidptr, args []voidptr) !voidptr {
		return runtime.forward_javascript_function(inner, receiver, args)
	})!
	outer := runtime.evaluate_host_value('(function(first,second){let seen;try{__innerFailure(first)}catch(error){seen=error}if(seen!==first)throw Error("inner identity");if(second===undefined)return seen;throw second})')!
	runtime.define_value_host_function('__outerFailure', fn [runtime, outer] (receiver voidptr, args []voidptr) !voidptr {
		return runtime.forward_javascript_function(outer, receiver, args)
	})!
	C.vox_forwarding_reset_api_exceptions()
	assert runtime.evaluate_host(r'(()=>{
 const first={},second={};
 if(__outerFailure(first)!==first)return false;
 try{__outerFailure(first,second)}catch(error){return error===second&&__outerFailure(second)===second}
 return false;
})()')! == 'true'
	assert C.vox_forwarding_api_exception_count() == 0
}
