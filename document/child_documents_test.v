module main

import dom
import browserjs
import encoding.base64
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

fn child_canvas_serve_image(mut listener net.TcpListener, requested chan bool, release chan bool, finished chan bool) {
	mut socket := listener.accept() or { finished <- false; return }
	defer { socket.close() or {} }
	socket.set_read_timeout(5 * time.second)
	mut reader := io.new_buffered_reader(reader: socket)
	request := reader.read_line() or { panic(err) }
	assert request.contains('/canvas.png')
	for { if (reader.read_line() or { '' }) == '' { break } }
	requested <- true
	select {
		_ := <-release {}
		5 * time.second { panic('image response was never released') }
	}
	body := base64.decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=').bytestr()
	socket.write_string('HTTP/1.1 200 OK\r\nContent-Type: image/png\r\nContent-Length: ${body.len}\r\nConnection: close\r\n\r\n${body}') or { panic(err) }
	finished <- true
}

fn test_browser_child_async_image_onload_draws_into_its_native_canvas() {
	$if !darwin { return }
	mut listener := net.listen_tcp(.ip, '127.0.0.1:0')!
	listener.set_accept_timeout(10 * time.second)
	defer { listener.close() or {} }
	address := 'http://${listener.addr()!}'
	requested := chan bool{cap: 1}
	release := chan bool{cap: 1}
	finished := chan bool{cap: 1}
	spawn child_canvas_serve_image(mut listener, requested, release, finished)
	mut host, mut parent := child_browser_fixture('<!doctype html><iframe id="frame" style="width:100px;height:100px"></iframe>', '${address}/parent')
	defer {
		host.close()
		parent.destroy_a_document_and_its_descendants()
		parent.finalize()
		parent.release_native_storage()
	}
	mut frame := parent.get_element_by_id('frame')?
	frame.set_attribute_value('srcdoc', r'<!doctype html><canvas id="drawing" width="1" height="1"></canvas><script>
 globalThis.drawn=false;globalThis.image=new Image();
 image.onload=function(event){
  drawing.getContext("2d").drawImage(image,0,0);
  drawn=this===image&&event.target===image&&image.naturalWidth===1&&image.width===1&&image.height===1;
 };
 image.src="/canvas.png";
 </script>')
	mut messages := []string{}
	child_browser_wait(host, 'drawing', mut messages)
	service := host.children[0].service?
	assert <-requested
	assert service.runtime.evaluate_host('drawn===false&&!image.complete')! == 'true'
	release <- true
	assert <-finished
	mut loop := html.main_thread_event_loop()
	deadline := time.sys_mono_now() + 5 * time.second
	loop.spin_until(fn [host, service, deadline] () bool {
		mut owner := unsafe { &BrowserChildDocumentHost(host) }
		mut log := []string{}
		owner.poll(mut log)
		return (service.runtime.evaluate_host('drawn') or { 'false' }) == 'true' || time.sys_mono_now() >= deadline
	})
	assert service.runtime.evaluate_host('drawn&&image.complete')! == 'true'
	element := service.document.get_element_by_id('drawing')?
	canvas := unsafe { &dom.HTMLCanvasElement(element) }
	bitmap := html.html_canvas_element_surface(canvas) or { panic('missing child canvas surface') }
	assert bitmap.width == 1 && bitmap.height == 1
	assert bitmap.data[..4] == [u8(0), 0, 0, 255]
	assert parent.get_element_by_id('drawing') == none
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
	mut host, mut document := child_browser_fixture('<!doctype html><body><div id=parent></div><div id=top></div><div id=frames></div><div id=length></div></body>', 'https://parent.example/')
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

fn test_browser_pointer_enters_transformed_iframe_with_child_coordinates_and_single_delivery() {
	$if !darwin { return }
	mut host, mut document := child_browser_fixture('<!doctype html><style>body{margin:0}iframe{position:absolute;left:40px;top:50px;width:200px;height:120px;border:5px solid black;padding:7px;transform:translate(10px,20px) scale(1.5);transform-origin:0 0}</style><button id=child>Outer button</button><iframe id=frame></iframe>', 'https://parent.example/')
	mut frame_element := document.get_element_by_id('frame')?
	frame_element.set_attribute_value('srcdoc', '<!doctype html><style>body{margin:0;height:400px}button{position:absolute;left:20px;top:10px;width:80px;height:40px;border:0}</style><button id=child>Inner button</button><script>globalThis.childPointer=[];window.addEventListener("click",e=>{childPointer.push([e.clientX,e.clientY,e.pageY,e.isTrusted,e.view===window]);parent.postMessage("child-click","*")});</script>')
	mut runtime := browserjs.Runtime.create()
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'globalThis.outerClicks=0;globalThis.childMessages=0;document.getElementById("child").addEventListener("click",()=>outerClicks++);window.addEventListener("message",e=>{if(e.data==="child-click")childMessages++});'], runtime, mut messages)
	child_browser_wait(host, 'child', mut messages)
	service := host.children[0].service?
	mut owner := unsafe { &page.Page(document.page()) }
	if !owner.has_local_root_navigable() { owner.set_local_root_navigable(document.navigable()?)! }
	mut app := &BrowserApp{
		document: document
		page_model: owner
		js_runtime: runtime
		child_document_host: host
		layout_tree_only: true
		viewport_width: 640
		viewport_height: 400
		page_zoom: 2
	}
	defer {
		layout.release_paint_tree(app.paint_tree_storage)
		host.close()
		runtime.close()
		document.destroy_a_document_and_its_descendants()
		document.finalize()
		document.release_native_storage()
	}
	frame := document.get_element_by_id('frame')?
	assert voidptr(document.element_from_point(128, 118)?) == voidptr(frame)
	border := browser_document_pointer_hit(document, page.PixelPoint{53, 73})
	assert voidptr(border.document) == voidptr(document)
	inner := browser_document_pointer_hit(document, page.PixelPoint{128, 118})
	assert voidptr(inner.document) == voidptr(service.document)
	assert inner.position == page.PixelPoint{40, 20}
	assert inner.hit?.element.get_attribute_value('id') == 'child'
	initial_viewport := document.viewport_rect()
	document.set_viewport_rect(dom.Rect{...initial_viewport, y: 20})
	scrolled := browser_document_pointer_hit(document, page.PixelPoint{128, 98})
	assert voidptr(scrolled.document) == voidptr(service.document)
	assert scrolled.position == page.PixelPoint{40, 20}
	document.set_viewport_rect(initial_viewport)
	mut child_document := unsafe { &dom.Document(service.document) }
	child_document.set_viewport_rect(dom.Rect{...child_document.viewport_rect(), y: 10})
	app.platform_pointer_buttons = 1
	app.dispatch_chrome_pointer_event_at_viewport_point('pointerdown', 0, 256, 236)
	app.platform_pointer_buttons = 0
	app.dispatch_chrome_pointer_event_at_viewport_point('pointerup', 0, 256, 236)
	app.replay_compact_javascript_click()
	assert service.runtime.evaluate_host('JSON.stringify(childPointer)')! == '[[40,20,30,true,true]]'
	mut loop := html.main_thread_event_loop()
	deadline := time.sys_mono_now() + time.second
	loop.spin_until(fn [runtime, deadline] () bool {
		return (runtime.evaluate_host('childMessages') or { '0' }) == '1' || time.sys_mono_now() >= deadline
	})
	assert runtime.evaluate_host('outerClicks===0&&childMessages===1')! == 'true'
	assert app.js_messages == []string{}, app.js_messages.join('\n')
}

fn test_initial_about_blank_frame_is_writable_before_the_host_poll() {
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
 globalThis.frame=document.createElement("iframe");document.body.appendChild(frame);
 globalThis.held=frame.contentWindow;
 const child=frame.contentDocument;
 globalThis.initial=child!==null&&child.URL==="about:blank"&&held.document===child;
 globalThis.loads=0;frame.addEventListener("load",()=>loads++);
 child.open();child.write("<p id=written>h");child.write("i</p>");child.close();
 globalThis.written=frame.contentDocument.getElementById("written").textContent;
 globalThis.tree=frame.contentDocument.documentElement.outerHTML;
 globalThis.rewritten=(child.open(),child.write("<b>second</b>"),child.close(),child.body.innerHTML);
 // Nodes of the frame realm passed to DOM methods of this realm.
 const reference=document.implementation.createHTMLDocument("");
 reference.removeChild(reference.documentElement);
 reference.appendChild(child.documentElement.cloneNode(true));
 globalThis.adopted=reference.documentElement.outerHTML;
 const italic=child.createElement("i");italic.textContent="moved";document.body.appendChild(italic);
 globalThis.moved=document.body.lastChild.outerHTML+" "+(document.body.lastChild.ownerDocument===document);
 // A WindowProxy taken before its frame has a realm reads and writes it.
 const other=document.createElement("iframe");document.body.appendChild(other);
 const win=other.contentWindow;
 win.document.open();win.document.write("<p id=target>t</p>");win.document.close();
 win.target=win.document.getElementById("target");
 globalThis.proxied=win.target.textContent+" "+(other.contentWindow.target===win.target);
'], runtime, mut messages)
	assert runtime.evaluate_host('initial')! == 'true', messages.join('\n')
	assert runtime.evaluate_host('typeof written')! == 'string', messages.join('\n')
	assert runtime.evaluate_host('written')! == 'hi'
	tree := runtime.evaluate_host('tree')!
	assert tree == '<html><head></head><body><p id="written">hi</p></body></html>', tree
	rewritten := runtime.evaluate_host('rewritten')!
	assert rewritten == '<b>second</b>', rewritten
	adopted := runtime.evaluate_host('adopted')!
	assert adopted == '<html><head></head><body><b>second</b></body></html>', adopted
	moved := runtime.evaluate_host('moved')!
	assert moved == '<i>moved</i> true', moved
	proxied := runtime.evaluate_host('proxied')!
	assert proxied == 't true', proxied
	mut loop := html.main_thread_event_loop()
	deadline := time.sys_mono_now() + 5 * time.second
	loop.spin_until(fn [runtime, deadline] () bool {
		return (runtime.evaluate_host('loads') or { '0' }) == '2' || time.sys_mono_now() >= deadline
	})
	loads := runtime.evaluate_host('loads')!
	assert loads == '2', loads
	// The frame's load event has not been claimed by a host poll yet, so the
	// host keeps asking for polls until it has.
	assert host.has_pending_work()
	for _ in 0 .. 3 {
		host.poll(mut messages)
	}
	assert !host.has_pending_work(), messages.join('\n')
}

fn child_xml_serve(mut listener net.TcpListener, finished chan bool) {
	mut socket := listener.accept() or {
		finished <- false
		return
	}
	defer { socket.close() or {} }
	socket.set_read_timeout(5 * time.second)
	mut reader := io.new_buffered_reader(reader: socket)
	request := reader.read_line() or { panic(err) }
	assert request.contains('/dummy.xml')
	for { if (reader.read_line() or { '' }) == '' { break } }
	body := '<foo id="root">Dummy XML document</foo>\n'
	socket.write_string('HTTP/1.1 200 OK\r\nContent-Type: application/xml\r\nContent-Length: ${body.len}\r\nConnection: close\r\n\r\n${body}') or { panic(err) }
	finished <- true
}

fn test_browser_child_host_parses_an_xml_response_as_an_xml_document() {
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
	spawn child_xml_serve(mut listener, finished)
	mut host, mut parent := child_browser_fixture('<!doctype html><iframe src="${address}/dummy.xml"></iframe>', 'http://parent.example/parent')
	defer {
		host.close()
		parent.destroy_a_document_and_its_descendants()
		parent.finalize()
		parent.release_native_storage()
	}
	mut messages := []string{}
	child_browser_wait(host, 'root', mut messages)
	assert <-finished
	service := host.children[0].service?
	document := service.document
	assert document.is_xml_document(), messages.join('\n')
	assert document.get_content_type() == 'application/xml'
	root := document.document_element()?
	assert root.local_name() == 'foo'
	assert root.as_node().text_content()? == 'Dummy XML document'
	assert document.as_node().children.len == 1
}
