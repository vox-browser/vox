module html

import dom
import editing

fn prepare_history_document(markup string, host_id string, offset int) (&dom.Document, &dom.Element, &dom.Text, &editing.EditingHistory) {
	document := parse_document(markup)
	host := document.get_element_by_id(host_id) or { panic('missing editing host') }
	text_node := host.as_node().first_child() or { panic('missing host text') }
	text := unsafe { &dom.Text(text_node) }
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_browsing_context(&dom.BrowsingContext{
		active_document_: document
	})
	selection_pointer := document.get_selection() or { panic('missing selection') }
	mut selection := unsafe { &dom.Selection(selection_pointer) }
	selection.collapse(text_node, offset) or { panic(err) }
	history := editing.install_editing_history(document)
	return document, host, text, history
}

fn collapse_history_selection(document &dom.Document, text &dom.Text, offset int) {
	selection_pointer := document.get_selection() or { panic('missing selection') }
	mut selection := unsafe { &dom.Selection(selection_pointer) }
	selection.collapse(text.as_node(), offset) or { panic(err) }
}

fn test_editing_history_undoes_and_redoes_proxy_mutations_and_selection() {
	document, host, text, history_pointer := prepare_history_document('<!doctype html><body><div id="host" contenteditable>abc</div></body>', 'host', 1)
	mut history := unsafe { &editing.EditingHistory(history_pointer) }
	history.begin_recording(host.as_node(), .insertion)
	editing.insert_data(&text.CharacterData, 1, 'X') or { panic(err) }
	collapse_history_selection(document, text, 2)
	history.end_recording()

	assert text.data() == 'aXbc'
	assert history.can_undo()
	assert !history.can_redo()
	assert history.undo(document)
	assert text.data() == 'abc'
	selection := document.get_selection() or { panic('missing selection') }
	assert selection.focus_node()? == text.as_node()
	assert selection.focus_offset() == 1
	assert history.can_redo()

	assert history.redo(document)
	assert text.data() == 'aXbc'
	assert selection.focus_node()? == text.as_node()
	assert selection.focus_offset() == 2
}

fn test_editing_history_coalesces_adjacent_insertions() {
	document, host, text, history_pointer := prepare_history_document('<!doctype html><body><div id="host" contenteditable>a</div></body>', 'host', 1)
	mut history := unsafe { &editing.EditingHistory(history_pointer) }

	history.begin_recording(host.as_node(), .insertion)
	editing.insert_data(&text.CharacterData, 1, 'x') or { panic(err) }
	collapse_history_selection(document, text, 2)
	history.end_recording()
	history.begin_recording(host.as_node(), .insertion)
	editing.insert_data(&text.CharacterData, 2, 'y') or { panic(err) }
	collapse_history_selection(document, text, 3)
	history.end_recording()

	assert text.data() == 'axy'
	assert history.undo(document)
	assert text.data() == 'a'
	assert history.redo(document)
	assert text.data() == 'axy'
}

fn test_external_selection_change_ends_typing_coalescence() {
	document, host, text, history_pointer := prepare_history_document('<!doctype html><body><div id="host" contenteditable>a</div></body>', 'host', 1)
	mut history := unsafe { &editing.EditingHistory(history_pointer) }

	history.begin_recording(host.as_node(), .insertion)
	editing.insert_data(&text.CharacterData, 1, 'x') or { panic(err) }
	collapse_history_selection(document, text, 2)
	history.end_recording()
	// This script-visible selection mutation happens outside a recording and
	// closes the open typing unit.
	collapse_history_selection(document, text, 1)
	history.begin_recording(host.as_node(), .insertion)
	editing.insert_data(&text.CharacterData, 1, 'y') or { panic(err) }
	collapse_history_selection(document, text, 2)
	history.end_recording()

	assert text.data() == 'ayx'
	assert history.undo(document)
	assert text.data() == 'ax'
	assert history.undo(document)
	assert text.data() == 'a'
}

fn test_editing_history_rolls_back_partial_undo_after_script_mutation() {
	document := parse_document('<!doctype html><body><div id="host" contenteditable><span id="first">A</span><span id="second">B</span></div></body>')
	host := document.get_element_by_id('host') or { panic('missing host') }
	first_node := document.get_element_by_id('first')?.as_node().first_child() or {
		panic('missing first text')
	}
	second_node := document.get_element_by_id('second')?.as_node().first_child() or {
		panic('missing second text')
	}
	first := unsafe { &dom.CharacterData(first_node) }
	second := unsafe { &dom.CharacterData(second_node) }
	history_pointer := editing.install_editing_history(document)
	mut history := unsafe { &editing.EditingHistory(history_pointer) }
	history.begin_recording(host.as_node(), .other)
	editing.replace_data(first, 0, 1, 'X') or { panic(err) }
	editing.replace_data(second, 0, 1, 'Y') or { panic(err) }
	history.end_recording()

	// Invalidate the first command only. Undo reverses the second command first,
	// then refuses the first and must reapply the second before dropping the step.
	mut mutable_first := unsafe { &dom.CharacterData(first) }
	mutable_first.replace_data(0, 1, 'Z') or { panic(err) }
	assert history.undo(document)
	assert first.data() == 'Z'
	assert second.data() == 'Y'
	assert !history.can_redo()
}

fn test_history_diagnoses_raw_dom_mutation_during_recording() {
	_, host, text, history_pointer := prepare_history_document('<!doctype html><body><div id="host" contenteditable>a</div></body>', 'host', 1)
	mut history := unsafe { &editing.EditingHistory(history_pointer) }
	history.begin_recording(host.as_node(), .other)
	mut mutable_text := unsafe { &dom.CharacterData(&text.CharacterData) }
	mutable_text.replace_data(0, 1, 'b') or { panic(err) }
	assert history.unproxied_mutation_count() == 1
	editing.replace_data(&text.CharacterData, 0, 1, 'c') or { panic(err) }
	assert history.unproxied_mutation_count() == 1
	history.end_recording()
}

@[heap]
struct HistoryEventObservation {
mut:
	before_input_types []string
	input_types        []string
	cancel_beforeinput bool
}

fn history_event_callback(observation &HistoryEventObservation) &dom.CallbackType {
	return &dom.CallbackType{
		handle_event: fn [observation] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			input_event := unsafe { &dom.InputEvent(event) }
			mut mutable_observation := unsafe { &HistoryEventObservation(observation) }
			if event.type_name() == 'beforeinput' {
				mutable_observation.before_input_types << input_event.input_type()
				if mutable_observation.cancel_beforeinput {
					mut mutable_event := unsafe { &dom.Event(event) }
					mutable_event.prevent_default()
				}
			} else {
				mutable_observation.input_types << input_event.input_type()
			}
			return dom.js_undefined()
		}
	}
}

fn test_user_history_action_dispatches_cancelable_beforeinput_and_input() {
	document, host, text, history_pointer := prepare_history_document('<!doctype html><body><div id="host" contenteditable>a</div></body>', 'host', 1)
	mut history := unsafe { &editing.EditingHistory(history_pointer) }
	mut observation := &HistoryEventObservation{ cancel_beforeinput: true }
	listener := dom.IDLEventListener.create(history_event_callback(observation))
	target := unsafe { &dom.EventTarget(host.as_node()) }
	target.add_event_listener_without_options('beforeinput', listener)
	target.add_event_listener_without_options('input', listener)
	history.begin_recording(host.as_node(), .insertion)
	editing.insert_data(&text.CharacterData, 1, 'x') or { panic(err) }
	history.end_recording()

	assert editing.perform_history_action(document, .undo) == .handled
	assert text.data() == 'ax'
	assert observation.before_input_types == ['historyUndo']
	assert observation.input_types.len == 0
	observation.cancel_beforeinput = false
	assert editing.perform_history_action(document, .undo) == .handled
	assert text.data() == 'a'
	assert observation.input_types == ['historyUndo']
}
