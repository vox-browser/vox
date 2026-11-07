module main

import browserjs
import dom
import platform

fn install_compact_iframe_windows(document &dom.Document, mut runtime browserjs.Runtime) ! {
	host := browser_child_document_host(document, runtime.engine)
	if voidptr(host.root) == voidptr(document) {
		runtime.add_close_handler(fn [host] () {
			mut owner := unsafe { &BrowserChildDocumentHost(host) }
			owner.close()
		})
	}
	owner := voidptr(&runtime)
	runtime.install_window_proxy_binding(fn [document, owner, host] (wrapper voidptr, realm bool) !browserjs.FrameWindowResult {
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		mut runtime := unsafe { &browserjs.Runtime(owner) }
		target := runtime.native_event_target(wrapper)!
		if target.data.kind != .node {
			return error('TypeError: Illegal HTMLIFrameElement receiver')
		}
		element := unsafe { &dom.Node(target) }.as_element() or {
			return error('TypeError: Illegal HTMLIFrameElement receiver')
		}
		if !element.is_html_element() || element.local_name() != 'iframe' {
			return error('TypeError: Illegal HTMLIFrameElement receiver')
		}
		state := runtime.evaluate_host('__ladybirdFinalize()')!
		mut messages := []string{}
		apply_javascript_runtime_state(document, state, runtime, mut messages)
		if !element.as_node().is_connected() || !element.document().has_page() || !element.document().is_fully_active() {
			return browserjs.FrameWindowResult{}
		}
		mut manager := unsafe { &BrowserChildDocumentHost(host) }
		model := manager.ensure_child(element)!
		if realm { manager.ensure_initial_realm(element, mut messages) }
		if proxy := model.active_window_proxy() {
			return browserjs.FrameWindowResult{ proxy: proxy.dom_proxy() }
		}
		return browserjs.FrameWindowResult{}
	})!
}
