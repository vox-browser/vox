// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs

fn channel_fixture() !(&Host, &libjs.VM) {
	address := dom.URL{value: 'https://message-channel.test/'}
	document := html.parse_navigation_document('<body></body>', address, address.origin(), none)!
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	return Host.create(vm, vm.realm(), document, Hooks{})!, vm
}

fn channel_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'message-channel.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{max_instructions: 100000}) or {
		return error(exception_message(err))
	}
}

fn drain_channel_tasks(host &Host) {
	settings := unsafe { &html.EnvironmentSettingsObject(host.document.relevant_settings_object()) }
	mut queue := settings.responsible_event_loop().task_queue()
	for {
		task := queue.take_first_runnable_matching(fn (task &html.Task) bool {
			return task.source() == .posted_message
		}) or { break }
		task.execute()
	}
}

fn test_libjs_message_channel_queues_fifo_and_preserves_clone_identity() {
	mut host, mut vm := channel_fixture()!
	defer { host.close() }
	assert channel_eval(mut vm, r'
		var channel=new MessageChannel(),first=channel.port1,second=channel.port2,seen=[];
		var shared={x:1},original={left:shared,right:shared};original.self=original;
		first.postMessage(original);first.postMessage(null);shared.x=2;
		second.addEventListener("message",function(event){seen.push([event,this===second&&event.target===second]);});
		first===channel.port1&&second===channel.port2&&first!==second&&first instanceof MessagePort&&
			first instanceof EventTarget&&MessageChannel.length===0&&seen.length===0')!.as_bool()
	drain_channel_tasks(host)
	assert channel_eval(mut vm, 'seen.length===0;')!.as_bool()
	channel_eval(mut vm, 'second.start();second.start();')!
	drain_channel_tasks(host)
	assert channel_eval(mut vm, r'
		var event=seen[0][0],copy=event.data;
		seen.length===2&&seen[0][1]&&seen[1][1]&&event instanceof MessageEvent&&event.isTrusted&&
			event.data===copy&&copy!==original&&copy.left===copy.right&&copy.self===copy&&
			copy.left.x===1&&seen[1][0].data===null&&Object.isFrozen(event.ports)')!.as_bool()
	channel_eval(mut vm, 'first.postMessage("discarded");second.close();')!
	drain_channel_tasks(host)
	assert channel_eval(mut vm, 'seen.length===2;')!.as_bool()
}

fn test_libjs_message_channel_transfers_a_port_to_the_receiving_event() {
	mut host, mut vm := channel_fixture()!
	defer { host.close() }
	channel_eval(mut vm, r'
		var carrier=new MessageChannel(),peer=new MessageChannel(),received,reply,failed=0,touched=0;
		carrier.port2.onmessage=function(event){received=event;event.data.port.postMessage("hello");};
		peer.port2.onmessage=event=>{reply=event.data;};
		try{carrier.port1.postMessage({port:peer.port1});}catch(error){if(error.name==="DataCloneError")failed++;}
		try{carrier.port1.postMessage({get x(){touched++;}},[peer.port1,peer.port1]);}
		catch(error){if(error.name==="DataCloneError")failed++;}
		carrier.port1.postMessage({port:peer.port1,again:peer.port1},{transfer:[peer.port1]});
		peer.port1.postMessage("detached");')!
	drain_channel_tasks(host)
	assert channel_eval(mut vm, r'
		failed===2&&touched===0&&typeof carrier.port2.onmessage==="function"&&received.ports===received.ports&&
			received.ports.length===1&&received.ports[0]===received.data.port&&
			received.data.port===received.data.again&&received.data.port!==peer.port1&&reply==="hello"')!.as_bool()
}

fn test_libjs_message_event_initialization_preserves_author_values_and_brands() {
	mut host, mut vm := channel_fixture()!
	defer { host.close() }
	assert channel_eval(mut vm, r'
		var channel=new MessageChannel(),data={},port=channel.port1;
		var event=new MessageEvent("message",{data,source:window,ports:[port],lastEventId:"12",origin:"https://a.test"});
		var original=event.data===data&&event.source===window&&event.ports[0]===port&&
			event.lastEventId==="12"&&event.origin==="https://a.test"&&!event.isTrusted;
		event.initMessageEvent("other",false,false,5,"","",port,[]);
		var n=0;
		for (const action of [()=>new MessagePort(),()=>MessageChannel(),()=>port.postMessage(),
		    ()=>Object.getOwnPropertyDescriptor(MessageEvent.prototype,"data").get.call({})]) {
			try{action();}catch(error){if(error instanceof TypeError)n++;}
		}
		original&&event.type==="other"&&event.data===5&&event.source===port&&event.ports.length===0&&n===4')!.as_bool()
}
