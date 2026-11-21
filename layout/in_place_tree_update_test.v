module layout

import dom
import html
import os

fn in_place_handle(document &dom.Document, id string) voidptr {
	element := document.get_element_by_id(id) or { panic(id) }
	node := element.as_node()
	mirror := node.unsafe_layout_node() or { panic('no box for ${id}') }
	return mirror.real_layout_handle()
}

fn in_place_matches_full_rebuild(mut document dom.Document, label string) {
	before := (document.record_display_list() or { panic('paint') }).dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert (document.record_display_list() or { panic('full paint') }).dump() == before, label
}

fn in_place_document() &dom.Document {
	return html.parse_document('<!doctype html><style>
		body{margin:0;font:16px/20px sans-serif}
		#app{padding:4px}
		.box{height:30px;margin:2px 0;background:#eee}
		.row{display:flex;height:20px}
	</style><body>
		<div id="app">
			<div id="a" class="box">a</div>
			<div id="b" class="box">b</div>
		</div>
		<p id="tail">tail</p>
	</body>')
}

// Child list changes of ordinary block containers keep the committed tree,
// whitespace and inline runs (in anonymous wrappers) included: the flagged
// parent's box and every other box stay, and the paint matches a complete
// rebuild.
fn test_block_child_list_changes_keep_the_committed_tree() {
	mut document := in_place_document()
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	enabled := os.getenv('VOX_DISABLE_IN_PLACE_TREE_UPDATE') == ''
	mut app := document.get_element_by_id('app') or { panic('app') }
	mut app_node := app.as_node()
	steps := ['append', 'remove', 'restyle', 'portal', 'inline', 'list', 'icon']
	for step in steps {
		kept_app := in_place_handle(document, 'app')
		kept_tail := in_place_handle(document, 'tail')
		updated_before, _ := in_place_tree_update_statistics()
		match step {
			'append' {
				mut added := document.create_element('div') or { panic(err) }
				added.set_attribute_value('id', 'c')
				added.set_attribute_value('class', 'box')
				mut added_node := added.as_node()
				added_node.append_child(document.create_text_node('c').as_node()) or { panic(err) }
				app_node.append_child(added_node) or { panic(err) }
			}
			'remove' {
				mut first := document.get_element_by_id('a') or { panic('a') }
				first.as_node().remove(false)
			}
			'restyle' {
				mut second := document.get_element_by_id('b') or { panic('b') }
				second.set_attribute_value('class', 'row')
			}
			'list' {
				mut list := document.create_element('div') or { panic(err) }
				list.set_inner_html('<ol><li>one</li><li>two</li></ol>') or { panic(err) }
				app_node.append_child(list.as_node()) or { panic(err) }
			}
			'icon' {
				mut icon := document.create_element('div') or { panic(err) }
				icon.set_inner_html('<svg width="16" height="16" viewBox="0 0 16 16"><path d="M0 0h16v16H0z"/></svg>') or { panic(err) }
				app_node.append_child(icon.as_node()) or { panic(err) }
			}
			'inline' {
				mut span := document.create_element('span') or { panic(err) }
				mut span_node := span.as_node()
				span_node.append_child(document.create_text_node('inline text').as_node()) or { panic(err) }
				app_node.append_child(span_node) or { panic(err) }
			}
			else {
				mut body := document.body() or { panic('body') }
				mut portal := document.create_element('div') or { panic(err) }
				portal.set_attribute_value('id', 'portal')
				portal.set_attribute_value('class', 'box')
				mut body_node := body.as_node()
				body_node.append_child(portal.as_node()) or { panic(err) }
			}
		}
		document.update_layout(.debugging)
		updated_after, _ := in_place_tree_update_statistics()
		if enabled {
			assert updated_after == updated_before + 1, step
			assert in_place_handle(document, 'app') == kept_app, step
			assert in_place_handle(document, 'tail') == kept_tail, step
		} else {
			assert updated_after == updated_before, step
		}
		in_place_matches_full_rebuild(mut document, step)
	}
}

// A table, or generated content showing a counter, keeps the complete
// builder; so do list items once some generated content shows counters.
fn test_unsupported_child_lists_keep_the_complete_builder() {
	for markup in ['<table id="new"><tr><td>cell</td></tr></table>',
		'<div class="counted">counted</div>', '<ol><li>one</li></ol>'] {
		mut document := html.parse_document('<!doctype html><style>
			body{margin:0;font:16px/20px sans-serif}
			.counted::before{content:counter(list-item) ". "}
		</style><body><div id="app"><div id="a">a</div><div class="counted">first</div></div></body>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 400, 300)
		mut app := document.get_element_by_id('app') or { panic('app') }
		updated_before, declined_before := in_place_tree_update_statistics()
		mut holder := document.create_element('div') or { panic(err) }
		holder.set_inner_html(markup) or { panic(err) }
		mut new_node := holder.as_node().first_child() or { panic('child') }
		mut app_node := app.as_node()
		app_node.append_child(new_node) or { panic(err) }
		document.update_layout(.debugging)
		updated_after, declined_after := in_place_tree_update_statistics()
		assert updated_after == updated_before, markup
		if os.getenv('VOX_DISABLE_IN_PLACE_TREE_UPDATE') == '' {
			assert declined_after == declined_before + 1, markup
		}
		in_place_matches_full_rebuild(mut document, markup)
	}
}

// Boxes the builder derives from state no flag covers (an input's
// placeholder, an SVG viewport's natural size) send the next update
// anywhere to the complete builder once that state changes, as before.
fn test_changed_builder_state_keeps_the_complete_builder() {
	for state in ['input', 'svg'] {
		mut document := html.parse_document('<!doctype html><body><div id="changed"></div><section id="stable"><p>Label <input id="field" placeholder="Search"> <svg id="icon" width="16" height="16"><rect width="16" height="16"/></svg></p></section></body>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 400, 300)
		mut target := document.get_element_by_id(if state == 'input' { 'field' } else { 'icon' }) or { panic(state) }
		if state == 'input' {
			target.set_attribute_value('placeholder', 'Find a file')
		} else {
			target.set_attribute_value('width', '32')
		}
		document.update_layout(.debugging)
		updated_before, _ := in_place_tree_update_statistics()
		mut changed := document.get_element_by_id('changed') or { panic('changed') }
		changed.set_inner_html('<p>sibling</p>') or { panic(err) }
		document.update_layout(.debugging)
		updated_after, _ := in_place_tree_update_statistics()
		assert updated_after == updated_before, state
		in_place_matches_full_rebuild(mut document, state)
	}
}

// Scripts set an input's type through its model (`input.type = 'hidden'`),
// as the JavaScript bridge relays attribute changes.
fn in_place_set_input_type(element &dom.Element, value string) {
	mut model := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
	model.set_type(value)
}

// Typing a disconnected input requests nothing of the document's layout
// tree, so inserting it keeps the committed tree; changing a connected
// input's type still replaces its box.
fn test_inserted_typed_inputs_keep_the_committed_tree() {
	mut document := in_place_document()
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	enabled := os.getenv('VOX_DISABLE_IN_PLACE_TREE_UPDATE') == ''
	kept_tail := in_place_handle(document, 'tail')
	updated_before, _ := in_place_tree_update_statistics()
	mut form := document.create_element('div') or { panic(err) }
	mut form_node := form.as_node()
	for type_, id in {
		'hidden':   'token'
		'checkbox': 'check'
	} {
		mut input := document.create_element('input') or { panic(err) }
		in_place_set_input_type(input, type_)
		input.set_attribute_value('id', id)
		form_node.append_child(input.as_node()) or { panic(err) }
	}
	assert !document.needs_full_layout_tree_update()
	mut app := document.get_element_by_id('app') or { panic('app') }
	mut app_node := app.as_node()
	app_node.append_child(form_node) or { panic(err) }
	document.update_layout(.debugging)
	updated_after, _ := in_place_tree_update_statistics()
	if enabled {
		assert updated_after == updated_before + 1
		assert in_place_handle(document, 'tail') == kept_tail
	}
	in_place_matches_full_rebuild(mut document, 'typed inputs')
	check := document.get_element_by_id('check') or { panic('check') }
	kept_check := in_place_handle(document, 'check')
	in_place_set_input_type(check, 'radio')
	document.update_layout(.debugging)
	assert in_place_handle(document, 'check') != kept_check
	in_place_matches_full_rebuild(mut document, 'type change')
}
