module html

import dom
import editing

__global rich_paste_fragment_parse_count int

fn rich_paste_counted_fragment_parse(target voidptr, context &dom.Element, markup string, shadow_roots dom.AllowDeclarativeShadowRoots, mode dom.ParserScriptingMode) ![]&dom.Node {
	rich_paste_fragment_parse_count++
	assert mode == .inert
	return dom_html_fragment_parse_callback(target, context, markup, shadow_roots, mode)
}

// Ladybird c6e8828f2edd3be091039b59e149c185a4807511.
fn test_rich_paste_inserts_the_sanitized_foreign_tree_after_a_single_inert_parse() {
	mut document, host, text, manager := live_editing_document('seed')
	mut selection := document.get_selection()?
	selection.collapse(text.as_node(), 4)!
	hook := document.html_fragment_parsing_hook()?
	document.set_html_fragment_parsing_hook(dom.DocumentHTMLFragmentParsingHook{
		...hook
		parse_fragment: rich_paste_counted_fragment_parse
	})
	rich_paste_fragment_parse_count = 0
	mut mutable_manager := unsafe { &dom.EditingHostManager(manager) }
	mutable_manager.handle_insert_from_clipboard(dom.input_type_insert_from_paste, 'plain',
		'<svg><noscript>&lt;/svg&gt;&lt;script&gt;evil()&lt;/script&gt;&lt;img src=x onerror=&quot;evil()&quot;&gt;</noscript></svg>')
	assert rich_paste_fragment_parse_count == 1
	assert document.get_elements_by_tag_name('script').length() == 0
	assert document.get_elements_by_tag_name('img').length() == 0
	assert host.as_node().text_content()? == 'seed</svg><script>evil()</script><img src=x onerror="evil()">'
	assert host.inner_html()!.contains('<svg><noscript>&lt;/svg&gt;')
	assert document.exec_command('undo', false, '')!
	assert host.as_node().text_content()? == 'seed'
}

fn test_pasted_fragment_keeps_node_identity_and_bypasses_only_script_injection_sinks() {
	mut document, host, text, _ := live_editing_document('seed')
	mut selection := document.get_selection()?
	selection.collapse(text.as_node(), 4)!
	document.enforce_meta_csp("require-trusted-types-for 'script'")
	range_ := selection.range()?
	fragment := editing.sanitize_clipboard_html(range_, '<b id="inspected">safe</b>')!
	inspected := fragment.as_node().first_child()?
	assert document.insert_pasted_fragment(fragment, dom.input_type_insert_from_paste)!
	assert document.get_element_by_id('inspected')?.as_node() == inspected
	assert host.as_node().text_content()? == 'seedsafe'
	mut rejected := false
	range_.create_contextual_fragment('<script>unsafe()</script>') or {
		rejected = true
		unsafe { nil }
	}
	assert rejected
}

@[heap]
struct LiveEditingInputObservation {
mut:
	input_types []string
	data        []string
}

fn live_editing_input_callback(observation &LiveEditingInputObservation) &dom.CallbackType {
	return &dom.CallbackType{
		handle_event: fn [observation] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			input_event := unsafe { &dom.InputEvent(event) }
			mut mutable_observation := unsafe { &LiveEditingInputObservation(observation) }
			mutable_observation.input_types << input_event.input_type()
			mutable_observation.data << (input_event.data() or { '<null>' })
			return dom.js_undefined()
		}
	}
}

fn live_editing_document(text_value string) (&dom.Document, &dom.Element, &dom.Text, &dom.EditingHostManager) {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_document_type(.html)
	document.set_editable(true)
	document.set_browsing_context(&dom.BrowsingContext{})
	install_document_fragment_parsing_hook(document)
	mut host := document.create_element('div') or { panic(err) }
	host.set_attribute_for_bindings('contenteditable', 'true') or { panic(err) }
	text := document.create_text_node(text_value)
	mut host_node := host.as_node()
	host_node.append_child(text.as_node()) or { panic(err) }
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(host.as_node()) or { panic(err) }
	manager := document.editing_host_manager()
	return document, host, text, manager
}

fn test_document_exec_command_mutates_the_live_contenteditable_host() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_document_type(.html)
	document.set_editable(true)
	document.set_browsing_context(&dom.BrowsingContext{})
	install_document_fragment_parsing_hook(document)
	assert !document.query_command_enabled('undo')!
	assert !document.query_command_enabled('redo')!

	mut host := document.create_element('div') or { panic(err) }
	host.set_attribute_for_bindings('contenteditable', 'true') or { panic(err) }
	text := document.create_text_node('hello')
	mut host_node := host.as_node()
	host_node.append_child(text.as_node()) or { panic(err) }
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(host.as_node()) or { panic(err) }

	selection_pointer := document.get_selection() or { panic('missing selection') }
	mut selection := unsafe { &dom.Selection(selection_pointer) }
	selection.set_base_and_extent(text.as_node(), 0, text.as_node(), 5) or { panic(err) }

	assert document.exec_command('bold', false, '')!
	assert host.as_node().text_content()? == 'hello'
	assert host.inner_html()!.contains('<b>')

	// The bold command keeps the selection on the formatted run, so a
	// subsequent editing command operates on the same range.
	assert document.exec_command('insertText', false, 'V')!
	assert host.as_node().text_content()? == 'V'
	assert host.inner_html()!.contains('V')
	assert document.query_command_enabled('UNDO')!
	assert !document.query_command_enabled('redo')!

	assert document.exec_command('undo', false, '')!
	assert host.as_node().text_content()? == 'hello'
	assert host.inner_html()!.contains('<b>')
	assert document.query_command_enabled('redo')!

	assert document.exec_command('redo', false, '')!
	assert host.as_node().text_content()? == 'V'
	assert !document.query_command_enabled('redo')!
	assert document.exec_command('insertText', false, 'X')!
	assert document.exec_command('insertText', false, 'Y')!
	assert host.as_node().text_content()? == 'VXY'
	assert document.exec_command('undo', false, '')!
	assert host.as_node().text_content()? == 'V'
	history := editing.editing_history_if_exists(document) or { panic('missing editing history') }
	assert history.unproxied_mutation_count() == 0
	assert !document.exec_command('notACommand', false, '')!
}

fn test_contenteditable_paste_is_a_standalone_history_unit_with_user_input_type() {
	document, host, text, manager_pointer := live_editing_document('a')
	selection_pointer := document.get_selection() or { panic('missing selection') }
	mut selection := unsafe { &dom.Selection(selection_pointer) }
	selection.collapse(text.as_node(), 1) or { panic(err) }
	mut observation := &LiveEditingInputObservation{}
	listener := dom.IDLEventListener.create(live_editing_input_callback(observation))
	unsafe { &dom.EventTarget(host.as_node()) }.add_event_listener_without_options('input', listener)
	mut manager := unsafe { &dom.EditingHostManager(manager_pointer) }

	manager.handle_insert(dom.input_type_insert_text, 'x')
	manager.handle_insert(dom.input_type_insert_from_paste, 'y')
	assert host.as_node().text_content()? == 'axy'
	assert observation.input_types == [dom.input_type_insert_text, dom.input_type_insert_from_paste]
	assert observation.data == ['x', '<null>']
	history_pointer := editing.editing_history_if_exists(document) or {
		panic('missing editing history')
	}
	mut history := unsafe { &editing.EditingHistory(history_pointer) }
	assert history.undo(document)
	assert host.as_node().text_content()? == 'ax'
	assert history.undo(document)
	assert host.as_node().text_content()? == 'a'
}

fn test_contenteditable_clipboard_insert_prefers_sanitized_html_and_plaintext_hosts_fall_back() {
	document, host, text, manager_pointer := live_editing_document('a')
	selection_pointer := document.get_selection() or { panic('missing selection') }
	mut selection := unsafe { &dom.Selection(selection_pointer) }
	selection.collapse(text.as_node(), 1) or { panic(err) }
	mut observation := &LiveEditingInputObservation{}
	listener := dom.IDLEventListener.create(live_editing_input_callback(observation))
	unsafe { &dom.EventTarget(host.as_node()) }.add_event_listener_without_options('input', listener)
	mut manager := unsafe { &dom.EditingHostManager(manager_pointer) }

	manager.handle_insert_from_clipboard(dom.input_type_insert_from_paste, 'plain',
		'<b onclick="evil()">rich</b><script>bad()</script>')
	assert host.as_node().text_content()? == 'arich'
	markup := host.inner_html()!
	assert markup.contains('<b>rich</b>')
	assert !markup.contains('onclick')
	assert !markup.contains('script')
	assert observation.input_types == [dom.input_type_insert_from_paste]
	assert observation.data == ['<null>']
	history_pointer := editing.editing_history_if_exists(document) or {
		panic('missing editing history')
	}
	mut history := unsafe { &editing.EditingHistory(history_pointer) }
	assert history.undo(document)
	assert host.as_node().text_content()? == 'a'

	plain_document, mut plain_host, plain_text_node, plain_manager_pointer := live_editing_document('a')
	plain_host.set_attribute_for_bindings('contenteditable', 'plaintext-only')!
	plain_selection_pointer := plain_document.get_selection() or { panic('missing selection') }
	mut plain_selection := unsafe { &dom.Selection(plain_selection_pointer) }
	plain_selection.collapse(plain_text_node.as_node(), 1) or { panic(err) }
	mut plain_manager := unsafe { &dom.EditingHostManager(plain_manager_pointer) }
	plain_manager.handle_insert_from_clipboard(dom.input_type_insert_from_paste, 'plain',
		'<b>rich</b>')
	assert plain_host.as_node().text_content()? == 'aplain'
	assert !plain_host.inner_html()!.contains('<b>')
}

fn test_contenteditable_clipboard_insert_preserves_generated_image_data_url() {
	document, host, text, manager_pointer := live_editing_document('a')
	selection_pointer := document.get_selection() or { panic('missing selection') }
	mut selection := unsafe { &dom.Selection(selection_pointer) }
	selection.collapse(text.as_node(), 1) or { panic(err) }
	mut manager := unsafe { &dom.EditingHostManager(manager_pointer) }

	manager.handle_insert_from_clipboard(dom.input_type_insert_from_paste, '',
		'<img src="data:image/png;base64,AQID" />')
	markup := host.inner_html()!
	assert markup.contains('<img')
	assert markup.contains('src="data:image/png;base64,AQID"')
}

fn test_contenteditable_cut_uses_backward_delete_and_stays_separate_from_typing() {
	document, host, text, manager_pointer := live_editing_document('abc')
	selection_pointer := document.get_selection() or { panic('missing selection') }
	mut selection := unsafe { &dom.Selection(selection_pointer) }
	selection.set_base_and_extent(text.as_node(), 1, text.as_node(), 2) or { panic(err) }
	mut observation := &LiveEditingInputObservation{}
	listener := dom.IDLEventListener.create(live_editing_input_callback(observation))
	unsafe { &dom.EventTarget(host.as_node()) }.add_event_listener_without_options('input', listener)
	mut manager := unsafe { &dom.EditingHostManager(manager_pointer) }

	manager.handle_delete(dom.input_type_delete_by_cut)
	manager.handle_insert(dom.input_type_insert_text, 'X')
	assert host.as_node().text_content()? == 'aXc'
	assert observation.input_types == [dom.input_type_delete_by_cut, dom.input_type_insert_text]
	assert observation.data == ['<null>', 'X']
	history_pointer := editing.editing_history_if_exists(document) or {
		panic('missing editing history')
	}
	mut history := unsafe { &editing.EditingHistory(history_pointer) }
	assert history.undo(document)
	assert host.as_node().text_content()? == 'ac'
	assert history.undo(document)
	assert host.as_node().text_content()? == 'abc'
}
