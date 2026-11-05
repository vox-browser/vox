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

fn child_browser_fixture(markup string, address string) (&BrowserChildDocumentHost, &dom.Document) {
	owner := page.Page.create(1) or { panic(err) }
	document := parse_browser_navigation_document_for_page_with_response_time(markup,
		dom.URL{ value: address }, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	return &BrowserChildDocumentHost{ root: document, engine: .javascriptcore, scripting: true }, document
}

fn child_browser_wait(host &BrowserChildDocumentHost, id string, mut messages []string) {
	mut loop := html.main_thread_event_loop()
	deadline := time.sys_mono_now() + 20 * time.second
	loop.spin_until(fn [host, id, deadline] () bool {
		if time.sys_mono_now() >= deadline { return true }
		mut owner := unsafe { &BrowserChildDocumentHost(host) }
		mut messages := []string{}
		owner.poll(mut messages)
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
	body := '<!doctype html><style>body{background:rgb(17 83 29)}</style><p id="loaded">loaded child</p><script>document.getElementById("loaded").textContent="script ran in child";globalThis.childRan=true;globalThis.childWidth=innerWidth;</script>'
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
	mut host, mut parent := child_browser_fixture('<!doctype html><iframe id="frame" src="/child" style="width:200px;height:100px"></iframe>', '${address}/parent')
	defer {
		host.close()
		parent.destroy_a_document_and_its_descendants()
		parent.finalize()
		parent.release_native_storage()
	}
	mut messages := []string{}
	mut parent_runtime := browserjs.Runtime.create()
	defer { parent_runtime.close() }
	run_document_javascript(parent, parent.url.serialize(), [r'globalThis.childLoads=0;document.getElementById("frame").addEventListener("load",()=>childLoads++);'], parent_runtime, mut messages)
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
	loop.spin_until(fn [parent_runtime, deadline] () bool {
		return (parent_runtime.evaluate_host('childLoads') or { '0' }) == '1' || time.sys_mono_now() >= deadline
	})
	loads := parent_runtime.evaluate_host('childLoads')!
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
