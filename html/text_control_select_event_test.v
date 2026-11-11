module html

import dom
import editing

@[heap]
struct SelectEventObservation {
mut:
	count int
}

fn record_select_events(element &dom.Element) &SelectEventObservation {
	mut observation := &SelectEventObservation{}
	listener := dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn [mut observation] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			observation.count++
			return dom.js_undefined()
		}
	})
	mut target := unsafe { &dom.EventTarget(element.as_node()) }
	target.add_event_listener_without_options('select', listener)
	return observation
}

fn drain_select_event_tasks() {
	mut loop := main_thread_event_loop()
	for _ in 0 .. 1000 {
		if !loop.task_queue().has_runnable_tasks() { return }
		loop.process()
	}
	assert !loop.task_queue().has_runnable_tasks()
}

fn test_value_changes_typing_deletion_and_history_do_not_dispatch_select() {
	mut document := parse_document('<!doctype html><input id="control" value="abcd">')
	_ = WindowModel.create_top_level(document, none, 'select-events') or { panic(err) }
	element := document.get_element_by_id('control') or { panic('missing input') }
	mut model := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
	document.set_focused_area(element.as_node())
	_ = editing.install_editing_history(document)
	mut events := record_select_events(element)
	model.set_value('abcdef')!
	drain_select_event_tasks()
	assert events.count == 0
	model.text_control.set_selection_range(1, 3, 'forward')!
	drain_select_event_tasks()
	assert events.count == 1
	events.count = 0
	model.text_control.handle_insert(dom.input_type_insert_text, 'XY')!
	drain_select_event_tasks()
	assert model.value() == 'aXYdef'
	assert events.count == 0
	assert document.exec_command('undo', false, '')!
	drain_select_event_tasks()
	assert model.value() == 'abcdef'
	assert model.text_control.selection_start() == 1
	assert model.text_control.selection_end() == 3
	assert events.count == 0
	assert document.exec_command('redo', false, '')!
	model.text_control.handle_delete(dom.input_type_delete_content_backward)!
	drain_select_event_tasks()
	assert model.value() == 'aXdef'
	assert events.count == 0
	model.text_control.set_range_text('Q', 0, 1, .select)!
	drain_select_event_tasks()
	assert events.count == 1
}

fn test_textarea_value_assignment_suppresses_select_but_user_range_selection_fires_it() {
	document := parse_document('<!doctype html><textarea id="control">abcd</textarea>')
	_ = WindowModel.create_top_level(document, none, 'textarea-select-events') or { panic(err) }
	element := document.get_element_by_id('control') or { panic('missing textarea') }
	mut events := record_select_events(element)
	mut model := HTMLTextAreaElementModel.create(unsafe { &dom.HTMLTextAreaElement(element) })
	drain_select_event_tasks()
	assert events.count == 0
	assert model.text.selection_start() == 4
	assert model.text.selection_end() == 4
	model.set_value('abcdef')
	drain_select_event_tasks()
	assert events.count == 0
	model.text.set_the_selection_range(1, 3, .forward, .ui)
	drain_select_event_tasks()
	assert events.count == 1
	events.count = 0
	model.text.set_the_selection_range(3, 3, .none, .ui)
	drain_select_event_tasks()
	assert events.count == 0
	model.text.set_selection_range(0, 2, 'forward')!
	drain_select_event_tasks()
	assert events.count == 1
	model.text.set_range_text('Q', 0, 2, .select)!
	drain_select_event_tasks()
	assert events.count == 2
}
