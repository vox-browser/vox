module main

import dom
import browserjs
import html
import io
import layout
import net
import page
import requestserver
import time

@[heap]
struct ChildBrowserMessages {
mut:
	values []string
}

fn child_browser_fixture(markup string, address string) (&BrowserChildDocumentHost, &dom.Document) {
	owner := page.Page.create(1) or { panic(err) }
	document := parse_browser_navigation_document_for_page_with_response_time(markup,
		dom.URL{ value: address }, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	return browser_child_document_host(document, .javascriptcore), document
}

fn child_browser_wait(host &BrowserChildDocumentHost, id string, mut messages []string) {
	mut loop := html.main_thread_event_loop()
	deadline := time.sys_mono_now() + 20 * time.second
	trace := &ChildBrowserMessages{}
	loop.spin_until(fn [host, id, deadline, trace] () bool {
		if time.sys_mono_now() >= deadline { return true }
		mut owner := unsafe { &BrowserChildDocumentHost(host) }
		mut log := unsafe { &ChildBrowserMessages(trace) }
		owner.poll(mut log.values)
		if host.root.layout_engine_handle() == unsafe { nil } || !host.root.layout_is_up_to_date() {
			_ = layout.run_document_layout(host.root, 320, 200)
		}
		for child in host.children {
			if service := child.service {
				if service.initialized && service.document.get_element_by_id(id) != none {
					return true
				}
			}
		}
		return false
	})
	messages << trace.values
	mut owner := unsafe { &BrowserChildDocumentHost(host) }
	owner.poll(mut messages)
	assert host.children.any(it.service != none), messages.join('\n')
	mut found := false
	for child in host.children {
		if document := child.navigable.active_document() {
			messages << 'child state: ${document.url.serialize()} ${child.navigable.ongoing_navigation().kind}'
		}
		if service := child.service {
			found = found || (service.initialized && service.document.get_element_by_id(id) != none)
		}
	}
	assert found, messages.join('\n')
}

fn child_browser_serve(mut listener net.TcpListener, finished chan bool) {
	mut socket := listener.accept() or {
		finished <- false
		return
	}
	defer { socket.close() or {} }
	socket.set_read_timeout(5 * time.second)
	mut reader := io.new_buffered_reader(reader: socket)
	request := reader.read_line() or { panic(err) }
	assert request.contains('/child')
	for { if (reader.read_line() or { '' }) == '' { break } }
	body := '<!doctype html><style>body{background:rgb(17 83 29)}</style><p id="loaded">loaded child</p><script>document.getElementById("loaded").textContent="script ran in child";globalThis.childRan=true;globalThis.childWidth=innerWidth;globalThis.receivedMessages=[];globalThis.parentAck=false;window.addEventListener("message",e=>{receivedMessages.push(e.data);parentAck=e.data==="parent-ack"&&e.source===parent&&parent===top;});parent.postMessage({kind:"child-ready"},"*");</script>'
	socket.write_string('HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: ${body.len}\r\nConnection: close\r\n\r\n${body}') or { panic(err) }
	finished <- true
}

fn test_browser_child_host_loads_and_scripts_a_network_iframe_then_removes_it() {
	$if !darwin {
		return
	}
	requestserver.install_native_font_fetch_host()!
	defer { requestserver.close_native_font_fetch_host() }
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	listener.set_accept_timeout(20 * time.second)
	defer { listener.close() or {} }
	address := 'http://${listener.addr()!}'
	finished := chan bool{cap: 1}
	spawn child_browser_serve(mut listener, finished)
	mut host, mut parent := child_browser_fixture('<!doctype html><iframe id="frame" src="${address}/child" style="width:200px;height:100px"></iframe>', 'http://parent.example/parent')
	defer {
		host.close()
		parent.destroy_a_document_and_its_descendants()
		parent.finalize()
		parent.release_native_storage()
	}
	mut messages := []string{}
	mut parent_runtime := browserjs.Runtime.create()
	defer { parent_runtime.close() }
	run_document_javascript(parent, parent.url.serialize(), ['globalThis.expectedChildOrigin="${address}";' + r'
globalThis.childLoads=0;globalThis.messageChecks=[];globalThis.savedChild=document.getElementById("frame").contentWindow;
document.getElementById("frame").addEventListener("load",()=>childLoads++);
window.addEventListener("message",e=>{
 if(e.data.kind!=="child-ready")return;
 let blocked=false;try{e.source.document}catch(error){blocked=error.name==="SecurityError"}
 messageChecks=[e.source===savedChild,e.source===document.getElementById("frame").contentWindow,e.origin===expectedChildOrigin,blocked,Object.getPrototypeOf(e.source)===null,parent===window,top===window,frames===window,length===1];
 e.source.postMessage("wrong-origin","https://wrong.example");e.source.postMessage("parent-ack","*");
});'], parent_runtime, mut messages)
	assert parent.get_element_by_id('frame')?.as_node().has_event_listener('load'), messages.join('\n')
	child_browser_wait(host, 'loaded', mut messages)
	assert <-finished
	service := host.children[0].service?
	assert service.runtime != unsafe { nil }, messages.join('\n')
	assert service.runtime.evaluate_host('childRan && window !== undefined')! == 'true'
	assert service.runtime.evaluate_host('String(childWidth)')! == '200'
	assert service.document.get_element_by_id('loaded')?.text_content()? == 'script ran in child'
	assert parent.get_element_by_id('loaded') == none
	mut loop := html.main_thread_event_loop()
	deadline := time.sys_mono_now() + 5 * time.second
	loop.spin_until(fn [parent_runtime, service, deadline] () bool {
		return ((parent_runtime.evaluate_host('childLoads') or { '0' }) == '1'
			&& (service.runtime.evaluate_host('parentAck') or { 'false' }) == 'true') || time.sys_mono_now() >= deadline
	})
	loads := parent_runtime.evaluate_host('childLoads')!
	checks := parent_runtime.evaluate_host('JSON.stringify(messageChecks)')!
	assert parent_runtime.evaluate_host('messageChecks.length===9&&messageChecks.every(Boolean)')! == 'true', 'checks=${checks} child=${service.runtime.evaluate_host('JSON.stringify({ack:parentAck,received:receivedMessages})')!} messages=${messages.join('\n')}'
	assert service.runtime.evaluate_host('parentAck&&receivedMessages.length===1')! == 'true'
	assert loads == '1', 'loads=${loads} fired=${service.load_fired} delayed=${service.document.anything_is_delaying_the_load_event()} messages=${messages.join('\n')}'
	root := layout.layout_document_typed_in_viewport(parent, 320, 200)
	commands := root.paint_commands().filter(it.kind == 'paint_nested_display_list')
	assert commands.len == 1
	assert commands[0].nested_viewport_commands.any(it.kind == 'fill_rect' && it.color == 'rgb(17 83 29)')
	assert commands[0].nested_viewport_commands.any(it.text == 'script ran in child')
	$if prealloc {
		assert service.document.native_storage().arena.contains(service.document.get_element_by_id('loaded')?)
	}
	mut frame := parent.get_element_by_id('frame')?
	mut node := frame.as_node()
	node.remove(false)
	host.poll(mut messages)
	assert host.children[0].closed
	assert service.runtime == unsafe { nil }
	assert commands[0].nested_viewport_commands.any(it.text == 'script ran in child')
	frame.set_attribute_value('srcdoc', '<p id=readded>reinserted child</p>')
	parent.body()?.as_node().append_child(node)!
	child_browser_wait(host, 'readded', mut messages)
	assert host.children.len == 2 && host.children[0].closed && !host.children[1].closed
	assert parent_runtime.evaluate_host('savedChild!==document.getElementById("frame").contentWindow')! == 'true'
}

fn test_browser_child_host_preserves_srcdoc_precedence_and_separate_realms() {
	$if !darwin {
		return
	}
	mut host, mut parent := child_browser_fixture('<!doctype html><iframe src="https://unused.example/" srcdoc="<p id=inline>inline</p><script>globalThis.onlyChild=42;</script>"></iframe>', 'https://parent.example/')
	defer {
		host.close()
		parent.destroy_a_document_and_its_descendants()
		parent.finalize()
		parent.release_native_storage()
	}
	mut messages := []string{}
	child_browser_wait(host, 'inline', mut messages)
	service := host.children[0].service?
	assert service.document.url.serialize() == 'about:srcdoc'
	assert service.runtime.evaluate_host('onlyChild')! == '42'
	assert service.document.is_fully_active()
	assert service.document.origin().is_same_origin(parent.origin())
	assert service.document.base_url().serialize() == parent.base_url().serialize()
	mut frame := parent.get_elements_by_tag_name('iframe').item(0)?
	frame.set_attribute_value('src', 'https://also-unused.example/')
	host.poll(mut messages)
	assert voidptr(host.children[0].navigable.active_document()?) == voidptr(service.document)
	assert service.runtime.evaluate_host('onlyChild')! == '42'
	frame.set_attribute_value('src', '')
	frame.remove_attribute('srcdoc')
	for _ in 0 .. 3 {
		host.poll(mut messages)
		_ = layout.run_document_layout(parent, 320, 200)
	}
	blank := host.children[0].navigable.active_document()?
	assert blank.url.serialize() == 'about:blank'
	assert blank.origin().is_same_origin(parent.origin())
	assert voidptr(blank.page()) == voidptr(parent.page())
}

fn test_browser_content_window_tracks_eager_contexts_and_detached_receivers() {
	$if !darwin {
		return
	}
	mut host, mut document := child_browser_fixture('<!doctype html><body></body>', 'https://parent.example/')
	mut runtime := browserjs.Runtime.create()
	defer {
		host.close()
		runtime.close()
		document.destroy_a_document_and_its_descendants()
		document.finalize()
		document.release_native_storage()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
 const descriptor=Object.getOwnPropertyDescriptor(HTMLIFrameElement.prototype,"contentWindow");
 globalThis.frameGetter=descriptor.get;
 const parentAttribute=Object.getOwnPropertyDescriptor(window,"parent"),topAttribute=Object.getOwnPropertyDescriptor(window,"top");
 globalThis.globalAccessors=parentAttribute.get.call(null)===window&&parentAttribute.get.name==="get parent"&&parentAttribute.set.name==="set parent"&&parentAttribute.set.prototype===undefined&&!topAttribute.configurable&&topAttribute.set===undefined;
 globalThis.getterMetadata=descriptor.enumerable&&descriptor.configurable&&frameGetter.name==="get contentWindow"&&frameGetter.length===0;
 globalThis.badReceivers=0;for(const receiver of [{},document.body,null]){try{frameGetter.call(receiver)}catch(error){if(error instanceof TypeError)badReceivers++}}
 globalThis.dynamicFrame=document.createElement("iframe");
 globalThis.detachedWindow=dynamicFrame.contentWindow;
 document.body.appendChild(dynamicFrame);
 globalThis.eagerWindow=dynamicFrame.contentWindow;
 globalThis.windowIdentities=eagerWindow!==null&&eagerWindow===dynamicFrame.contentWindow&&eagerWindow.parent===window&&eagerWindow.top===window&&length===1;
 dynamicFrame.remove();
 globalThis.removedWindow=dynamicFrame.contentWindow;
 '], runtime, mut messages)
	for check in ['getterMetadata', 'globalAccessors', 'badReceivers===3', 'detachedWindow===null',
		'removedWindow===null', 'windowIdentities'] {
		assert runtime.evaluate_host(check)! == 'true', '${check}: ${runtime.evaluate_host('JSON.stringify({getterMetadata,globalAccessors,badReceivers,detached:detachedWindow===null,removed:removedWindow===null,windowIdentities})')!} ${messages.join('\n')}'
	}
	assert host.children.len == 1
	host.poll(mut messages)
	assert host.children[0].closed
	assert runtime.evaluate_host('eagerWindow.closed&&length===0&&parent===window&&top===window&&frames===window')! == 'true'
	host.close()
	assert voidptr(document) !in browser_child_document_hosts_
}
