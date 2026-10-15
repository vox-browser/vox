module html

import dom
import page

@[heap]
struct RawHandlerScriptingOwnerObservation {
mut:
	calls int
}

fn raw_handler_scripting_document(address string, markup string) !(&page.Page, &dom.Document) {
	owner := page.Page.create(1)!
	url := dom.URL{value: address}
	mut document := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	document.set_document_type(.html)
	parse_html_from_a_string(document, markup)
	return owner, document
}

fn test_parser_raw_handler_after_adoption_checks_current_document_scripting_before_compiler() {
	mut source_owner, mut source := raw_handler_scripting_document('https://raw-source-scripting.example/', '<button id=button onclick="return false;">Button</button>')!
	mut target_owner, mut target := raw_handler_scripting_document('https://raw-target-scripting.example/', '<main id=host></main>')!
	defer {
		source.finalize()
		target.finalize()
	}
	element := source.get_element_by_id('button')?
	event_target := unsafe { &dom.EventTarget(element) }
	handler := event_target.data.event_handler('click') or { panic('parser-created raw handler') }
	listener := handler.listener or { panic('activated original listener') }
	state := &RawHandlerScriptingOwnerObservation{}
	original_window := source.get_window()?
	current_window := target.get_window()?
	assert handler.value.kind == .string
	source.set_inline_event_handler_compiler(dom.InlineEventHandlerCompiler{
		can_compile: fn (_ &dom.EventTarget) bool { return true }
		compile:     fn (_ &dom.EventTarget, _ string, _ string, _ string) ?&dom.CallbackType {
			panic('adopted raw handler must use its current Document compiler')
		}
	})
	target.set_inline_event_handler_compiler(dom.InlineEventHandlerCompiler{
		can_compile: fn (_ &dom.EventTarget) bool { return true }
		compile:     fn [state, target, current_window] (owner &dom.EventTarget, name string, body string, source_text string) ?&dom.CallbackType {
			assert unsafe { &dom.Element(owner) }.document() == target
			assert name == 'click' && body == 'return false;'
			assert source_text == 'function onclick(event) {\nreturn false;\n}'
			mut observation := unsafe { &RawHandlerScriptingOwnerObservation(state) }
			observation.calls++
			return &dom.CallbackType{
				associated_window: current_window
				handle_event:      fn (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
					return dom.js_bool(false)
				}
			}
		}
	})
	target_owner.set_is_scripting_enabled(false)
	_ = target.adopt_node_binding(element.as_node())!
	host := target.get_element_by_id('host')?
	mut host_node := host.as_node()
	host_node.append_child(element.as_node())!
	assert element.as_node().is_scripting_disabled()
	assert event_target.event_handler_attribute('click') == none
	assert state.calls == 0 && handler.value.kind == .string
	assert voidptr(handler.listener or { panic('listener') }) == voidptr(listener)
	source_owner.set_is_scripting_enabled(false)
	target_owner.set_is_scripting_enabled(true)
	assert element.as_node().is_scripting_enabled()
	callback := event_target.event_handler_attribute('click') or { panic('current owner compiler') }
	assert state.calls == 1 && voidptr(callback.associated_window?) == voidptr(current_window)
	assert voidptr(current_window) != voidptr(original_window)
	assert !event_target.dispatch_event(dom.Event.create('click', dom.EventInit{ cancelable: true }))
	assert state.calls == 1
	assert voidptr(handler.listener or { panic('listener') }) == voidptr(listener)
}
