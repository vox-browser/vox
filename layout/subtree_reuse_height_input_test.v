module layout

import dom
import html
import os

fn stale_height_check_full_rebuild(mut document dom.Document) {
	before := (document.record_display_list() or { panic('missing paint') }).dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert (document.record_display_list() or { panic('missing full paint') }).dump() == before
}

// An indefinite content height left by an earlier call of the same pass is
// not an input of the inner layout; a definite one is.
fn test_stale_indefinite_height_does_not_change_the_recorded_inputs() {
	if os.getenv('VOX_RETAIN_INDEFINITE_HEIGHT_INPUT') != '' { return }
	mut recorded := UsedValues{}
	mut current := UsedValues{}
	recorded.content_width_ = CSSPixels.new(100)
	current.content_width_ = CSSPixels.new(100)
	recorded.content_height_ = CSSPixels.new(40)
	assert subtree_layout_inputs_match(&recorded, &current)
	assert subtree_layout_inputs_difference(&recorded, &current) == ''
	current.has_definite_height_ = true
	assert !subtree_layout_inputs_match(&recorded, &current)
	recorded.has_definite_height_ = true
	assert !subtree_layout_inputs_match(&recorded, &current)
	assert subtree_layout_inputs_difference(&recorded, &current) == 'content-height'
	current.content_height_ = CSSPixels.new(40)
	assert subtree_layout_inputs_match(&recorded, &current)
	current.content_width_ = CSSPixels.new(101)
	assert !subtree_layout_inputs_match(&recorded, &current)
	// The recorded result supplies the height when the inputs did not carry it.
	mut restored := UsedValues{}
	restored.content_width_ = CSSPixels.new(100)
	before := UsedValues{content_width_: CSSPixels.new(100), content_height_: CSSPixels.new(40)}
	after := UsedValues{content_width_: CSSPixels.new(100), content_height_: CSSPixels.new(40)}
	apply_recorded_inner_layout(mut restored, &before, &after)
	assert restored.content_height_ == CSSPixels.new(40)
}

// A stretched flex item is laid out with an automatic height and again with
// the stretched one, and so is every box inside it; the second call starts
// from the height the first one produced. Both calls of the next pass restore
// the committed layout of a clean box inside a changed item.
fn test_both_layouts_inside_a_stretched_item_restore_a_clean_box() {
	for stable in ['<p>stable text</p><ul><li>one</li><li>two</li></ul>',
		'<table><tbody><tr><td>cell</td><td>next</td></tr></tbody></table>',
		'<div style="display:flex"><span>a</span><b>b</b></div><p>below</p>'] {
		mut document := html.parse_document('<!doctype html><style>.row{display:flex}.row>div{flex:1}</style><body><div class="row"><div><p>tall<br>tall<br>tall<br>tall<br>tall<br>tall<br>tall<br>tall</p></div><div><p id="changed">first</p><section style="display:flow-root">${stable}</section></div></div><p>tail</p></body>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 400, 300)
		mut changed := document.get_element_by_id('changed')?
		for index in 0 .. 4 {
			reused_before := incremental_layout_reused_subtree_count()
			if index % 2 == 0 {
				changed.set_inner_html('line ${index}<br>second line') or { panic(err) }
			} else {
				changed.set_inner_html('short ${index}') or { panic(err) }
			}
			document.update_layout(.debugging)
			reused := incremental_layout_reused_subtree_count() - reused_before
			// The item, and the section in each of the item's two layouts.
			if os.getenv('VOX_RETAIN_INDEFINITE_HEIGHT_INPUT') == '' {
				assert reused >= 3, stable
			}
			stale_height_check_full_rebuild(mut document)
		}
	}
}
