module browserjs

import dom
import html
import loader

fn window_message_fixture() !(&Runtime, &dom.Document) {
	if !loader.is_initialized() { loader.initialize() }
	url := dom.URL{ value: 'https://message.test/' }
	document := html.parse_navigation_document('<!doctype html>', url, url.origin(), none)!
	mut runtime := Runtime.create()
	runtime.bind_scripting_environment(unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) })!
	runtime.install_window_message_binding()!
	return runtime, document
}

fn deliver_window_binding_messages() {
	mut queue := html.main_thread_event_loop().task_queue()
	for {
		task := queue.take_first_runnable_matching(fn (task &html.Task) bool {
			return task.source() == .posted_message
		}) or { break }
		task.execute()
	}
}

fn test_window_message_binding_clones_real_values_and_dispatches_async_events() {
	$if !darwin && !linux {
		return
	}
	mut runtime, mut document := window_message_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'
 globalThis.received=[];globalThis.original={text:"before",map:new Map([["key",7n]])};original.self=original;
 onmessage=function(event){received.push(event);};
 postMessage(original);original.text="after";
 postMessage("ignored","https://other.test");postMessage("wildcard","*");postMessage("options",{targetOrigin:"https://message.test/path",transfer:[]});
 received.length===0;
 ')! == 'true'
	deliver_window_binding_messages()
	assert runtime.evaluate_host(r'
 const event=received[0],data=event.data;
 received.length===3&&event instanceof MessageEvent&&event instanceof Event&&event.type==="message"&&event.isTrusted&&event.source===globalThis&&event.origin==="https://message.test"&&event.target===globalThis&&event.currentTarget===null&&event.lastEventId===""&&data===event.data&&data!==original&&data.text==="before"&&data.self===data&&data.map.get("key")===7n&&Object.isFrozen(event.ports)&&event.ports===event.ports&&event.ports.length===0&&received[1].data==="wildcard"&&received[2].data==="options";
 ')! == 'true'
	assert runtime.evaluate_host(r'
 let errors=0;for(const send of [()=>postMessage(),()=>postMessage.call({},0,"*"),()=>new postMessage(0,"*"),()=>postMessage(0,Symbol())]){try{send()}catch(e){if(e instanceof TypeError)errors++}}
 let clone=false,syntax=false,originalThrow=false,reads=0;const marker={};
 try{postMessage(()=>0,"https://other.test")}catch(e){clone=e instanceof DOMException&&e.name==="DataCloneError"}
 try{postMessage({get a(){reads++;}},"/relative")}catch(e){syntax=e instanceof DOMException&&e.name==="SyntaxError"}
 try{postMessage({get a(){throw marker}},"*")}catch(e){originalThrow=e===marker}
 errors===4&&clone&&syntax&&reads===0&&originalThrow;
 ')! == 'true'
	assert runtime.evaluate_host('globalThis.postMessage=17;true')! == 'true'
	runtime.install_window_message_binding()!
	assert runtime.evaluate_host('postMessage===17')! == 'true'
}

fn test_message_event_binding_preserves_constructor_data_and_legacy_initialization() {
	$if !darwin && !linux {
		return
	}
	mut runtime, mut document := window_message_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'
 const value={x:1};const event=new MessageEvent("custom",{data:value,origin:"sender",lastEventId:"id",source:globalThis,bubbles:true});
 const initial=event.data===value&&event.source===globalThis&&event.origin==="sender"&&event.lastEventId==="id"&&event.bubbles&&!event.isTrusted&&Object.isFrozen(event.ports);
 event.initMessageEvent("changed",false,true,9,"next","last",null,[]);
 const changed=event.type==="changed"&&event.data===9&&event.origin==="next"&&event.lastEventId==="last"&&event.source===null&&!event.bubbles&&event.cancelable;
 class Derived extends MessageEvent{};const derived=new Derived("derived");
 let errors=0;for(const create of [()=>MessageEvent("x"),()=>new MessageEvent(),()=>Object.getOwnPropertyDescriptor(MessageEvent.prototype,"data").get.call({}),()=>new MessageEvent("x",{source:{}}),()=>new MessageEvent("x",{ports:[{}]})]){try{create()}catch(e){if(e instanceof TypeError)errors++}}
 initial&&changed&&derived instanceof Derived&&derived instanceof Event&&derived.data===null&&derived.origin===""&&derived.ports.length===0&&errors===5&&postMessage.length===2&&MessageEvent.length===1&&MessageEvent.prototype.initMessageEvent.length===1;
 ')! == 'true'
}
