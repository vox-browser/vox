module html

import dom
import platform

// The local host for NavigableContainer::create_new_child_navigable(). The
// metadata-only adapter can still be used without a Page; browser callers use
// this entry point so layout, navigation and Window all share one Document.
pub fn create_child_navigable_for_element(element &dom.Element) !&NavigableModel {
	if !element.is_html_element() || element.local_name() !in ['iframe', 'frame', 'object'] {
		return error('InvalidStateError: element is not a navigable container')
	}
	if existing := element.as_node().content_navigable() {
		return navigable_model_for_host(existing) or {
			return error('InvalidStateError: child navigable has no HTML owner')
		}
	}
	owner := element.document()
	if !element.as_node().is_connected() || !owner.is_fully_active() {
		return error('InvalidStateError: child navigable requires a fully active connected container')
	}
	if !owner.has_page() {
		return error('InvalidStateError: child navigable requires its owner Page')
	}
	if owner.get_browsing_context() == none || owner.navigable() == none {
		return error('InvalidStateError: child navigable requires its parent browsing context')
	}
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	initial := BrowsingContextModel.create_a_new_browsing_context_and_document(owner.page(), owner, element)!
	mut context := initial.browsing_context
	context.set_target_name(element.get_attribute_value('name'))
	host := initial.document.navigable() or { return error('Missing initial child navigable') }
	mut model := NavigableModel.create(host, context)!
	model.set_has_session_history_entry_and_ready_for_navigation()
	mut node := element.as_node()
	node.set_load_event_delay_hook(dom.NodeLoadEventDelayHook{
		target:   voidptr(host)
		callback: fn (target voidptr) bool {
			return unsafe { &dom.Navigable(target) }.delays_the_load_event_of_its_container()
		}
	})
	node.set_active_window_proxy_hook(dom.NodeActiveWindowProxyHook{
		target:   voidptr(model)
		callback: fn (target voidptr) ?&dom.WindowProxy {
			model := unsafe { &NavigableModel(target) }
			proxy := model.active_window_proxy() or { return none }
			return proxy.dom_proxy()
		}
	})
	return model
}

// Script-visible contentDocument keeps its origin check here. Painting uses
// Node.content_navigable() and does not expose the unfiltered child to script.
pub fn content_document_for_element(element &dom.Element) ?&dom.Document {
	navigable := element.as_node().content_navigable() or { return none }
	document := navigable.active_document() or { return none }
	if !document.origin().is_same_origin_domain(element.document().origin()) { return none }
	return document
}
