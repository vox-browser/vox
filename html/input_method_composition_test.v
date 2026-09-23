@[has_globals]
module html

import dom

__global (
	input_method_event_log        []string
	cancel_next_composition_start bool
	cancel_next_beforeinput       bool
)

fn record_input_method_event(event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
	unsafe {
		if event.interface_ == .composition_event {
			composition := &dom.CompositionEvent(event)
			input_method_event_log << '${event.type_name()}:${composition.data()}:${event.cancelable()}:${event.bubbles()}'
			if event.type_name() == 'compositionstart' && cancel_next_composition_start {
				mut mutable_event := &dom.Event(event)
				mutable_event.prevent_default()
				cancel_next_composition_start = false
			}
		} else if event.interface_ == .input_event {
			input := &dom.InputEvent(event)
			input_method_event_log << '${event.type_name()}:${input.input_type()}:${input.data() or {
				''
			}}:${input.is_composing()}:${event.cancelable()}'
			if event.type_name() == 'beforeinput' && cancel_next_beforeinput {
				mut mutable_event := &dom.Event(event)
				mutable_event.prevent_default()
				cancel_next_beforeinput = false
			}
		}
	}
	return dom.js_undefined()
}

fn input_method_find_element(node &dom.Node, name string) ?&dom.Element {
	if element := node.as_element() {
		if element.local_name() == name {
			return element
		}
	}
	for child in node.children_as_vector() {
		if element := input_method_find_element(child, name) {
			return element
		}
	}
	return none
}

fn input_method_test_input() (&dom.Document, &dom.Navigable, &HTMLInputElementModel) {
	mut document := parse_document('<input value="ab">')
	document.set_browsing_context(&dom.BrowsingContext{
		active_document_: document
	})
	input_element := input_method_find_element(unsafe { &dom.Node(document) }, 'input') or {
		panic('missing input')
	}
	mut model := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(input_element) })
	model.text_control.set_selection_range(1, 1, 'none') or { panic(err) }
	document.set_focused_area(input_element.as_node())
	mut navigable := &dom.Navigable{
		is_top_level_traversable_: true
	}
	navigable.set_active_document(document)

	listener := dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: record_input_method_event
	})
	target := unsafe { &dom.EventTarget(input_element.as_node()) }
	for event_name in ['compositionstart', 'compositionupdate', 'compositionend', 'beforeinput',
		'input'] {
		target.add_event_listener_without_options(event_name, listener)
	}
	return document, navigable, model
}

fn test_input_method_composition_updates_replace_the_marked_range() {
	mut document, mut navigable, model := input_method_test_input()
	unsafe {
		input_method_event_log = []
		cancel_next_composition_start = false
		cancel_next_beforeinput = false
	}

	navigable.set_marked_text_from_input_method('x')
	assert document.is_input_method_composing()
	assert model.value() == 'axb'
	navigable.set_marked_text_from_input_method('yz')
	assert model.value() == 'ayzb'
	navigable.commit_text_from_input_method('Q', 0, 0)
	assert !document.is_input_method_composing()
	assert model.value() == 'aQb'
	assert unsafe { input_method_event_log.clone() } == [
		'compositionstart::true:true',
		'compositionupdate:x:false:true',
		'beforeinput:insertCompositionText:x:true:false',
		'input:insertCompositionText:x:true:false',
		'compositionupdate:yz:false:true',
		'beforeinput:insertCompositionText:yz:true:false',
		'input:insertCompositionText:yz:true:false',
		'compositionupdate:Q:false:true',
		'beforeinput:insertCompositionText:Q:true:false',
		'input:insertCompositionText:Q:true:false',
		'compositionend:Q:false:true',
	]
}

fn test_input_method_unmark_cancel_and_cancelled_start_end_the_session() {
	mut document, mut navigable, mut model := input_method_test_input()
	model.set_value('')!
	model.text_control.set_selection_range(0, 0, 'none')!
	unsafe {
		input_method_event_log = []
		cancel_next_composition_start = false
		cancel_next_beforeinput = false
	}

	navigable.set_marked_text_from_input_method('?')
	navigable.unmark_text_from_input_method()
	assert model.value() == '?'
	assert unsafe { input_method_event_log.last() } == 'compositionend:?:false:true'

	unsafe { input_method_event_log = [] }
	navigable.set_marked_text_from_input_method('x')
	navigable.set_marked_text_from_input_method('')
	assert model.value() == '?'
	assert unsafe { input_method_event_log[input_method_event_log.len - 4..].clone() } == [
		'compositionupdate::false:true',
		'beforeinput:insertCompositionText::true:false',
		'input:insertCompositionText::true:false',
		'compositionend::false:true',
	]
	assert !document.is_input_method_composing()

	unsafe {
		input_method_event_log = []
		cancel_next_beforeinput = true
	}
	navigable.set_marked_text_from_input_method('a')
	navigable.commit_text_from_input_method('a', 0, 0)
	assert model.value() == '?a'
	assert !unsafe { cancel_next_beforeinput }

	unsafe {
		input_method_event_log = []
		cancel_next_composition_start = true
	}
	navigable.set_marked_text_from_input_method('z')
	assert model.value() == '?a'
	assert unsafe { input_method_event_log.clone() } == [
		'compositionstart::true:true',
		'compositionend::false:true',
	]
	assert !document.is_input_method_composing()
}

fn test_input_method_replacement_commit_without_active_composition() {
	_, mut navigable, mut model := input_method_test_input()
	model.set_value('a')!
	model.text_control.set_selection_range(1, 1, 'none')!
	unsafe { input_method_event_log = [] }

	navigable.commit_text_from_input_method('å', -1, 1)
	assert model.value() == 'å'
	assert unsafe { input_method_event_log.clone() } == [
		'beforeinput:insertCompositionText:å:false:false',
		'input:insertCompositionText:å:false:false',
	]

	model.set_value('b')!
	model.text_control.set_selection_range(1, 1, 'none')!
	unsafe { input_method_event_log = [] }
	navigable.set_marked_text_from_input_method('c')
	navigable.commit_text_from_input_method('ç', -1, 1)
	assert model.value() == 'çc'
	assert unsafe { input_method_event_log.clone() } == [
		'compositionstart::true:true',
		'compositionupdate:c:false:true',
		'beforeinput:insertCompositionText:c:true:false',
		'input:insertCompositionText:c:true:false',
		'compositionupdate:ç:false:true',
		'beforeinput:insertCompositionText:ç:true:false',
		'input:insertCompositionText:ç:true:false',
		'compositionend:ç:false:true',
	]
}

fn test_input_method_composition_start_reports_the_selected_text() {
	document, mut navigable, mut model := input_method_test_input()
	model.set_value('好')!
	model.text_control.set_selection_range(0, 1, 'forward')!
	selection := document.get_selection() or { panic('missing selection') }
	assert selection.to_string() == '好'
	unsafe { input_method_event_log = [] }

	navigable.set_marked_text_from_input_method('q')
	navigable.commit_text_from_input_method('q', 0, 0)
	assert model.value() == 'q'
	assert unsafe { input_method_event_log[0] } == 'compositionstart:好:true:true'
}

fn test_input_method_composition_uses_the_contenteditable_input_path() {
	mut document := parse_document('<div contenteditable="true">ab</div>')
	document.set_editable(true)
	document.set_browsing_context(&dom.BrowsingContext{
		active_document_: document
	})
	host := input_method_find_element(unsafe { &dom.Node(document) }, 'div') or {
		panic('missing editing host')
	}
	text := host.as_node().children_as_vector()[0]
	selection_pointer := document.get_selection() or { panic('missing selection') }
	mut selection := unsafe { &dom.Selection(selection_pointer) }
	selection.collapse(text, 1)!
	document.set_focused_area(host.as_node())
	html_element_did_receive_focus(unsafe { &dom.HTMLElement(host) })
	mut navigable := &dom.Navigable{
		is_top_level_traversable_: true
	}
	navigable.set_active_document(document)
	listener := dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: record_input_method_event
	})
	target := unsafe { &dom.EventTarget(host.as_node()) }
	for event_name in ['compositionstart', 'compositionupdate', 'compositionend', 'beforeinput',
		'input'] {
		target.add_event_listener_without_options(event_name, listener)
	}
	unsafe { input_method_event_log = [] }

	navigable.set_marked_text_from_input_method('x')
	marked_node := navigable.input_method_composition_node_ or { panic('missing marked node') }
	assert marked_node.is_connected()
	assert navigable.input_method_composition_offset_ == 1
	assert document.active_input_events_target(marked_node) != none
	assert selection.is_collapsed()
	assert selection.focus_offset() == 2
	navigable.commit_text_from_input_method('Y', 0, 0)
	assert host.as_node().text_content()? == 'aYb'
	assert unsafe { input_method_event_log.clone() } == [
		'compositionstart::true:true',
		'compositionupdate:x:false:true',
		'beforeinput:insertCompositionText:x:true:false',
		'input:insertCompositionText:x:true:false',
		'compositionupdate:Y:false:true',
		'beforeinput:insertCompositionText:Y:true:false',
		'input:insertCompositionText:Y:true:false',
		'compositionend:Y:false:true',
	]
}
