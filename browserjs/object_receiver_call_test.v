module browserjs

fn test_object_receiver_calls_preserve_proxy_and_boxed_identity_without_author_coercion() {
	$if !darwin && !linux { return }
	mut runtime := Runtime.create_with_engine(.javascriptcore)
	defer { runtime.close() }
	install_native_callback_call_test(mut runtime)!
	assert runtime.evaluate_host(r'(()=>{
 let reads=0;const marker={},symbol=Symbol("receiver");
 const proxy=new Proxy(Object.create(null),{get(){reads++;throw marker},getPrototypeOf(){reads++;throw marker}});
 const callableReceiver=new Proxy(function(){},{get(){reads++;throw marker},getPrototypeOf(){reads++;throw marker}});
 const receivers=[proxy,callableReceiver,Object.freeze({}),Object.freeze([]),Object(1n),Object(symbol),new Uint8Array([1,2]),globalThis];
 const strict=function(value){"use strict";return this===value},sloppy=Function("value","return this===value");
 for(const callback of [strict,sloppy]){
  Object.defineProperty(callback,"call",{get(){reads++;throw marker}});
  Object.defineProperty(callback,"apply",{get(){reads++;throw marker}});
  for(const receiver of receivers)if(!__invokeCallback(callback,receiver,receiver))return false;
 }
 const thrower=function(value){"use strict";if(this!==proxy)throw "wrong receiver";throw value};
 try{__invokeCallback(thrower,proxy,marker);return false}catch(reason){if(reason!==marker)return false}
 return reads===0;
})()')! == 'true'
}
