module browserjs

import platform

fn test_message_channel_binding_queues_native_messages_and_clones_values_at_send_time() {
	$if !darwin && !linux {
		return
	}
	mut runtime, mut document := window_message_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	runtime.install_message_channel_binding()!
	assert runtime.evaluate_host(r'
 globalThis.channel=new MessageChannel();globalThis.received=[];
 globalThis.original={text:"before",map:new Map([["key",7n]]),bytes:new Uint8Array([1,2,3])};original.self=original;
 channel.port2.postMessage(original);original.text="after";original.bytes[0]=9;
 channel.port1.onmessage=function(event){if(this!==channel.port1)throw new Error("callback receiver");received.push(event);};
 received.length===0;
 ')! == 'true'
	deliver_window_binding_messages()
	assert runtime.evaluate_host(r'
 const event=received[0],data=event.data;
 received.length===1&&event instanceof MessageEvent&&event instanceof Event&&event.isTrusted&&event.target===channel.port1&&event.currentTarget===null&&event.source===null&&event.origin===""&&event.lastEventId===""&&data===event.data&&data!==original&&data.self===data&&data.text==="before"&&data.map.get("key")===7n&&data.bytes[0]===1&&data.bytes!==original.bytes&&Object.isFrozen(event.ports)&&event.ports.length===0;
 ')! == 'true'
	// The wrapper must use the same native queue as the translated model.
	binding := message_channel_bindings_[voidptr(runtime)] or { panic('MessageChannel binding missing') }
	assert binding.channels.len == 1
	assert binding.ports.len == 2
	for _, channel in binding.channels {
		assert channel.port1().is_entangled()
		assert voidptr(channel.port1().entangled_port()?) == voidptr(channel.port2())
	}
}

fn test_message_port_listener_start_and_onmessage_enable_the_actual_queue() {
	$if !darwin && !linux {
		return
	}
	mut runtime, mut document := window_message_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	runtime.install_message_channel_binding()!
	assert runtime.evaluate_host(r'
 globalThis.channel=new MessageChannel();globalThis.received=[];globalThis.replies=[];
 channel.port1.addEventListener("message",event=>received.push(event.data));
 channel.port1.onmessageerror=()=>{throw new Error("unexpected clone error");};
 channel.port2.onmessage=event=>replies.push(event.data);
 channel.port2.postMessage("queued");true;
 ')! == 'true'
	deliver_window_binding_messages()
	assert runtime.evaluate_host('received.length===0')! == 'true'
	assert runtime.evaluate_host('channel.port1.start();channel.port1.start();channel.port1.postMessage("reply");received.length===0&&replies.length===0')! == 'true'
	deliver_window_binding_messages()
	assert runtime.evaluate_host('received.join() === "queued"&&replies.join() === "reply"')! == 'true'
	assert runtime.evaluate_host(r'
 globalThis.second=new MessageChannel();second.port2.postMessage("queued before handler");
 second.port1.addEventListener("message",event=>received.push(event.data));
 second.port1.onmessage=null;true;
 ')! == 'true'
	deliver_window_binding_messages()
	assert runtime.evaluate_host('received.join("|")==="queued|queued before handler"')! == 'true'
}

fn test_message_port_close_and_clone_failures_do_not_deliver_or_enter_closed_realms() {
	$if !darwin && !linux {
		return
	}
	mut runtime, mut document := window_message_fixture()!
	defer { document.finalize() }
	runtime.install_message_channel_binding()!
	assert runtime.evaluate_host(r'
 globalThis.channel=new MessageChannel();globalThis.count=0;
 channel.port1.onmessage=()=>count++;channel.port2.postMessage(1);channel.port1.close();channel.port1.start();
 let cloneErrors=0,reads=0;const marker={};let getterError=false;
 for(const value of [()=>0,Symbol(),channel.port2,new MessageChannel()]){try{channel.port1.postMessage(value)}catch(error){if(error instanceof DOMException&&error.name==="DataCloneError")cloneErrors++;}}
 try{channel.port2.postMessage({get value(){reads++;throw marker}})}catch(error){getterError=error===marker;}
 let transferError=false;try{channel.port2.postMessage(0,[channel.port1])}catch(error){transferError=error instanceof DOMException&&error.name==="DataCloneError";}
 cloneErrors===4&&reads===1&&getterError&&transferError;
 ')! == 'true'
	deliver_window_binding_messages()
	assert runtime.evaluate_host('count===0')! == 'true'
	assert runtime.evaluate_host(r'
 globalThis.pending=new MessageChannel();pending.port1.onmessage=()=>{throw new Error("closed realm callback")};pending.port2.postMessage(2);true;
 ')! == 'true'
	binding := message_channel_bindings_[voidptr(runtime)] or { panic('MessageChannel binding missing') }
	ports := binding.ports.values()
	runtime.close()
	assert voidptr(runtime) !in message_channel_bindings_
	for port in ports {
		assert port.is_detached()
		assert !port.is_entangled()
		assert port.pending_incoming_message_count() == 0
	}
	deliver_window_binding_messages()
}

fn test_message_channel_webidl_identity_brands_and_argument_conversion() {
	$if !darwin && !linux {
		return
	}
	mut runtime, mut document := window_message_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	runtime.install_message_channel_binding()!
	assert runtime.evaluate_host(r'
 const channel=new MessageChannel(),port=channel.port1;
 class Derived extends MessageChannel{};const derived=new Derived();
 const identity=channel.port1===port&&channel.port2!==port&&port instanceof MessagePort&&port instanceof EventTarget&&derived instanceof Derived&&derived.port1 instanceof MessagePort&&Object.prototype.toString.call(channel)==="[object MessageChannel]"&&Object.prototype.toString.call(port)==="[object MessagePort]";
 let errors=0;for(const operation of [()=>MessageChannel(),()=>new MessagePort(),()=>Object.getOwnPropertyDescriptor(MessageChannel.prototype,"port1").get.call({}),()=>MessagePort.prototype.start.call({}),()=>MessagePort.prototype.close.call({}),()=>MessagePort.prototype.postMessage.call({},1),()=>port.postMessage(),()=>port.postMessage(1,7),()=>port.postMessage(1,{transfer:[null]}),()=>port.postMessage(1,{transfer:{}}),()=>new port.start()]){try{operation()}catch(error){if(error instanceof TypeError)errors++;}}
 let reads=0;const options={get transfer(){reads++;return [];}};port.postMessage(1,options);port.postMessage(2,null);port.postMessage(3,[]);
 let iteratorReads=0,iteratorCalls=0;const iterable={get [Symbol.iterator](){iteratorReads++;return function(){if(this!==iterable)throw new Error("iterator receiver");iteratorCalls++;return [][Symbol.iterator]();};}};port.postMessage(4,iterable);
 let nestedReads=0;port.postMessage(5,{transfer:{get [Symbol.iterator](){nestedReads++;return function(){return [][Symbol.iterator]();};}}});
 const marker={};let getterException=false,invalidIterator=false;try{port.postMessage(1,{get [Symbol.iterator](){throw marker;}})}catch(error){getterException=error===marker;}
 try{port.postMessage(1,{[Symbol.iterator]:4,get transfer(){throw new Error("must not read dictionary");}})}catch(error){invalidIterator=error instanceof TypeError;}
 const handler=()=>{};port.onmessage=handler;const stored=port.onmessage===handler;port.onmessage=4;
 identity&&errors===11&&reads===1&&iteratorReads===1&&iteratorCalls===1&&nestedReads===1&&getterException&&invalidIterator&&stored&&port.onmessage===null&&MessageChannel.length===0&&MessagePort.length===0&&port.postMessage.length===1&&port.start.length===0&&port.close.length===0;
 ')! == 'true'
	assert runtime.evaluate_host('globalThis.MessageChannel=17;true')! == 'true'
	runtime.install_message_channel_binding()!
	assert runtime.evaluate_host('MessageChannel===17')! == 'true'
}

fn test_message_channel_messages_and_events_outlive_temporary_allocations() {
	$if !darwin && !linux {
		return
	}
	mut runtime, mut document := window_message_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	runtime.install_message_channel_binding()!
	mut caller := platform.begin_thread_scratch('MessageChannel caller')
	assert runtime.evaluate_host(r'
 globalThis.channel=new MessageChannel();globalThis.saved=null;
 channel.port1.onmessage=event=>{saved=event;};
 channel.port2.postMessage({text:"Санкт-Петербург 😀".repeat(64),nested:{value:42}});true;
 ')! == 'true'
	caller.finish()
	gc_collect()
	mut delivery := platform.begin_thread_scratch('MessageChannel delivery')
	deliver_window_binding_messages()
	delivery.finish()
	gc_collect()
	assert runtime.evaluate_host('saved.target===channel.port1&&saved.data.text==="Санкт-Петербург 😀".repeat(64)&&saved.data.nested.value===42')! == 'true'
}
