module layout

import dom
import html

fn below_flagged_handle(document &dom.Document, id string) voidptr {
	element := document.get_element_by_id(id) or { panic('missing #${id}') }
	return element.as_node().unsafe_layout_node() or { panic('missing layout for #${id}') }.real_layout_handle()
}

fn below_flagged_paint(document &dom.Document) string {
	return (document.record_display_list() or { panic('missing paint') }).dump()
}

// The kept boxes paint exactly what a complete rebuild of the same DOM paints.
fn below_flagged_check_full_rebuild(mut document dom.Document) string {
	before := below_flagged_paint(document)
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert below_flagged_paint(document) == before
	return before
}

const below_flagged_rows = '<div class="row" id="first"><p id="first-text">first <b>row</b></p><ul id="first-list"><li>a</li><li>b</li></ul></div><div class="row" id="second"><p id="second-text">second row</p><span id="second-icon"><svg width="16" height="16" viewBox="0 0 16 16" style="display:flex"><path d="M0 0h16v16H0z"></path></svg> label</span></div><div class="row" id="third"><p id="third-text">third row</p><table id="third-table"><tbody><tr><td>cell</td></tr></tbody></table></div>'

fn below_flagged_document(style string) &dom.Document {
	return html.parse_document('<!doctype html><style>.row{padding:2px}.hidden{display:none}.flex{display:flex}${style}</style><body><main id="list">${below_flagged_rows}</main><p id="tail">tail</p></body>')
}

// A removed row flags the list. The other rows are built again, as the flag
// does not say which child changed, and everything inside them is kept.
fn test_removing_a_child_keeps_the_boxes_inside_its_siblings() {
	mut document := below_flagged_document('')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	first := below_flagged_handle(document, 'first')
	kept := ['first-text', 'first-list', 'third-text', 'third-table'].map(below_flagged_handle(document, it))
	second := document.get_element_by_id('second')?
	mut second_node := unsafe { &dom.Node(second.as_node()) }
	second_node.remove(false)
	document.update_layout(.debugging)
	assert below_flagged_handle(document, 'first') != first
	for index, id in ['first-text', 'first-list', 'third-text', 'third-table'] {
		assert (below_flagged_handle(document, id) == kept[index]) == !disable_below_flagged_reuse, id
	}
	painted := below_flagged_check_full_rebuild(mut document)
	assert painted.contains('first') && painted.contains('third') && !painted.contains('second row')
}

// A style that needs another box flags the element's parent. Siblings keep
// what is inside them; the restyled element is built for its new display.
fn test_a_display_change_keeps_the_boxes_inside_the_siblings() {
	for class in ['hidden', 'flex'] {
		mut document := below_flagged_document('')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 400, 300)
		mut second := document.get_element_by_id('second')?
		for index in 0 .. 4 {
			kept := ['first-text', 'first-list', 'third-table'].map(below_flagged_handle(document, it))
			second.set_attribute_value('class', if index % 2 == 0 { 'row ${class}' } else { 'row' })
			document.update_layout(.debugging)
			for position, id in ['first-text', 'first-list', 'third-table'] {
				assert (below_flagged_handle(document, id) == kept[position]) == !disable_below_flagged_reuse, '${class} ${id}'
			}
			painted := below_flagged_check_full_rebuild(mut document)
			assert painted.contains('second row') == (class == 'flex' || index % 2 == 1), class
		}
	}
}

// Content changed while its branch was detached or not rendered carries no
// flag when the branch returns; its old boxes are not taken from the older tree.
fn test_branches_that_left_the_tree_are_built_again() {
	// Detached, edited, and inserted again before the next layout.
	mut document := below_flagged_document('')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	mut list := document.get_element_by_id('list')?
	mut list_node := list.as_node()
	first := document.get_element_by_id('first')?
	mut first_node := unsafe { &dom.Node(first.as_node()) }
	first_node.remove(false)
	mut text := document.get_element_by_id('second-text') or { panic('second text') }
	text.set_inner_html('kept <i>sibling</i>') or { panic(err) }
	mut detached_bold := first.as_node().children[0].children[1]
	detached_bold.set_text_content('EDITED')
	_ = list_node.append_child(first_node)!
	document.update_layout(.debugging)
	painted := below_flagged_check_full_rebuild(mut document)
	assert painted.contains('EDITED') && !painted.contains('row</b>')

	// Hidden for two layouts, edited meanwhile, then shown.
	mut third := document.get_element_by_id('third')?
	third.set_attribute_value('class', 'row hidden')
	document.update_layout(.debugging)
	mut third_text := document.get_element_by_id('third-text')?
	third_text.set_inner_html('changed while hidden') or { panic(err) }
	document.update_layout(.debugging)
	mut tail := document.get_element_by_id('tail')?
	tail.set_inner_html('tail again') or { panic(err) }
	document.update_layout(.debugging)
	third.set_attribute_value('class', 'row')
	document.update_layout(.debugging)
	shown := below_flagged_check_full_rebuild(mut document)
	assert shown.contains('changed while hidden') && !shown.contains('third row')
}

// Flags raised for other reasons cover the whole subtree: new markup, text
// replacement, a shadow root, an opened details element.
fn test_other_flags_rebuild_everything_below_them() {
	mut document := html.parse_document('<!doctype html><body><main id="list"><section id="host"><div id="wrap"><p id="deep">deep text</p></div></section><details id="details"><summary>More</summary><div id="body"><p id="inside">inside</p></div></details></main></body>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	mut details := document.get_element_by_id('details')?
	details.set_attribute_value('open', '')
	document.update_layout(.debugging)
	below_flagged_check_full_rebuild(mut document)
	mut inside := document.get_element_by_id('inside')?
	details.remove_attribute('open')
	document.update_layout(.debugging)
	inside.set_inner_html('edited while closed') or { panic(err) }
	document.update_layout(.debugging)
	details.set_attribute_value('open', '')
	document.update_layout(.debugging)
	opened := below_flagged_check_full_rebuild(mut document)
	assert opened.contains('edited while closed')
	// A shadow root replaces the rendering of its host's children.
	mut host := document.get_element_by_id('host')?
	deep := below_flagged_handle(document, 'deep')
	shadow := host.attach_shadow(dom.ShadowRootInit{mode: .open})!
	mut shadow_node := shadow.as_node()
	mut slot_owner := document.create_element('div')!
	slot_owner.set_inner_html('<span>shadow</span><slot></slot>') or { panic(err) }
	_ = shadow_node.append_child(slot_owner.as_node())!
	document.update_layout(.debugging)
	assert below_flagged_handle(document, 'deep') != deep
	slotted := below_flagged_check_full_rebuild(mut document)
	assert slotted.contains('shadow') && slotted.contains('deep text')
}

// Rows are rebuilt in every combination of removals, restyles and edits, and
// each result paints like a complete rebuild.
fn test_mixed_changes_below_flagged_parents_paint_like_a_complete_rebuild() {
	mut document := below_flagged_document('.row>p{margin:1px}.wide{padding-left:9px}')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	_, boxes_before, _ := clean_subtree_reuse_statistics()
	for step in 0 .. 12 {
		mut list := document.get_element_by_id('list')?
		mut list_node := list.as_node()
		match step % 6 {
			0 {
				mut second := document.get_element_by_id('second')?
				second.set_attribute_value('class', 'row hidden')
			}
			1 {
				mut first_text := document.get_element_by_id('first-text')?
				first_text.set_inner_html('edit ${step} <b>bold</b>') or { panic(err) }
			}
			2 {
				mut second := document.get_element_by_id('second')?
				second.set_attribute_value('class', 'row wide')
			}
			3 {
				mut added := document.create_element('div')!
				added.set_attribute_value('class', 'row')
				added.set_inner_html('<p>added ${step}</p>') or { panic(err) }
				_ = list_node.pre_insert(added.as_node(), list_node.first_child())!
			}
			4 {
				mut first_child := list_node.first_child() or { panic('first child') }
				first_child.remove(false)
			}
			else {
				mut third := document.get_element_by_id('third')?
				third.set_attribute_value('class', if step % 12 == 5 { 'row flex' } else { 'row' })
			}
		}
		document.update_layout(.debugging)
		below_flagged_check_full_rebuild(mut document)
	}
	_, boxes_after, _ := clean_subtree_reuse_statistics()
	assert boxes_after > boxes_before
}
