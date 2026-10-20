module layout

import dom
import html
import css
import platform

fn test_prepared_dom_attachment_commits_geometry_without_replacing_fresh_mirrors() {
	mut document := html.parse_document('<!doctype html><style>html,body,div{margin:0}div{font:16px/20px SerenityMono}</style><div id="host">a b</div>')
	defer { document.finalize() }
	root := build_layout_tree(document) or { panic('tree') }
	prepared := prepare_dom_layout_attachment(root)
	host := document.get_element_by_id('host') or { panic('host') }
	text := host.as_node().first_child() or { panic('text') }
	initial_host := host.as_node().layout_node() or { panic('mirror') }
	initial_text := text.layout_node() or { panic('mirror') }
	root_children_data := prepared.root.children_.data
	assert !initial_host.has_geometry_
	assert initial_text.rendered_text_chunks_.len == 0
	document.set_layout_viewport(&dom.LayoutViewport{ root_node: prepared.root })
	mut state := LayoutState.new()
	viewport := root.as_viewport() or { panic('viewport') }
	layout_viewport(mut state, viewport, 200, 100)
	committed := commit_dom_layout_attachment(root, state, prepared)
	assert voidptr(committed) == voidptr(prepared.root)
	assert committed.children_.data == root_children_data
	assert voidptr(host.as_node().layout_node() or { panic('host') }) == voidptr(initial_host)
	assert voidptr(text.layout_node() or { panic('text') }) == voidptr(initial_text)
	assert initial_host.has_geometry_
	assert initial_host.content_width_ == 200
	assert initial_text.rendered_text_chunks_.join('') == 'a b'
	assert initial_text.visual_lines().len > 0
	assert initial_text.containing_block() != none
	assert voidptr(initial_text.parent() or { panic('parent') }) == voidptr(initial_host)
}

fn test_prepared_dom_attachment_reuses_live_nodes_and_keeps_previous_layout_state() {
 mut document := html.parse_document('<!doctype html><style>html,body{margin:0}</style><div id="host">snapshot</div>')
 defer { document.finalize() }
 root := build_layout_tree(document) or { panic('tree') }
 initial := prepare_dom_layout_attachment(root)
 document.set_layout_viewport(&dom.LayoutViewport{ root_node: initial.root })
 mut first_state := LayoutState.new()
 viewport := root.as_viewport() or { panic('viewport') }
 layout_viewport(mut first_state, viewport, 200, 100)
 previous := commit_dom_layout_attachment(root, first_state, initial)
 host := document.get_element_by_id('host') or { panic('host') }
 previous_host := host.as_node().layout_node() or { panic('host') }
 typed := unsafe { &Node(previous_host.layout_handle) }.as_node_with_style() or { panic('typed') }
 old_used := first_state.get(typed)
 previous_paintable := host.as_node().paintable() or { panic('paintable') }
 prepared := prepare_dom_layout_attachment(root)
 assert !previous_host.has_geometry_
 assert previous_host.border_box_ == dom.Rect{}
 assert previous_host.content_width_ == 0
 assert first_state.get(typed).content_width().to_double() == 200
 assert voidptr(prepared.root) == voidptr(previous)
 assert voidptr(host.as_node().layout_node() or { panic('host') }) == voidptr(previous_host)
 mut second_state := LayoutState.new()
 layout_viewport(mut second_state, viewport, 300, 100)
 _ = commit_dom_layout_attachment(root, second_state, prepared)
 current := host.as_node().layout_node() or { panic('host') }
 assert voidptr(current) == voidptr(previous_host)
 assert current.content_width_ == 300
 assert old_used.content_width().to_double() == 200
 assert first_state.get(typed).content_width().to_double() == 200
 assert second_state.get(typed).content_width().to_double() == 300
 assert voidptr(host.as_node().paintable() or { panic('paintable') }) == voidptr(previous_paintable)
}

fn test_prepared_dom_attachment_allocates_mirrors_for_nodes_added_during_layout() {
	mut document := html.parse_document('<!doctype html><p>before</p>')
	defer { document.finalize() }
	mut root := build_layout_tree(document) or { panic('tree') }
	prepared := prepare_dom_layout_attachment(root)
	original_count := prepared.root.children_.len
	late := BlockContainer.new(document, none, css.ComputedProperties.new())
	root.append_child(unsafe { &Node(late) })
	state := LayoutState.new()
	committed := commit_dom_layout_attachment(root, state, prepared)
	assert voidptr(committed) == voidptr(prepared.root)
	assert committed.children_.len == original_count + 1
	mirror := committed.children_.last()
	assert mirror.layout_handle == voidptr(late)
	assert voidptr(mirror.parent() or { panic('parent') }) == voidptr(committed)
	assert !mirror.has_geometry_
	assert voidptr(late.dom_layout_node_) == voidptr(mirror)
}

fn test_retained_dom_paintables_retarget_callbacks_and_keep_prior_paint_snapshots() {
 mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#host{width:120px;height:40px;overflow:auto;font:16px/20px SerenityMono}#wide{width:240px;height:100px}</style><div id="host"><div id="wide">retained glyphs</div></div>')
 defer { document.finalize() }
 old_paint_tree := layout_document_typed_in_viewport(document, 300, 160)
 host := document.get_element_by_id('host') or { panic('host') }
 wide := document.get_element_by_id('wide') or { panic('wide') }
 old_result := document_layout_result(document) or { panic('result') }
 old_state := old_result.state
 old_root := old_result.root
 mirror := host.as_node().layout_node() or { panic('mirror') }
 mut paintable := host.paintable_box() or { panic('paintable') }
 assert paintable.set_scroll_offset(dom.CSSPixelPoint_{x_:30,y_:20})
 old_commands := old_paint_tree.paint_commands()
 text_command := old_commands.filter(it.kind == 'draw_text' && it.text == 'retained glyphs')[0]
 run := text_command.glyph_run or { panic('glyph run') }
 old_glyphs := run.glyphs().clone()
 old_font := run.font()
 text := wide.as_node().first_child() or { panic('text') }
 mut selection := document.get_selection() or { panic('selection') }
 selection.add_range(dom.Range.create_from_boundary_points(text,1,text,5))
 (document.paintable() or { panic('viewport paintable') }).recompute_selection_states(selection.range() or { panic('range') })
 text_paintable := text.paintable() or { panic('text paintable') }
 assert text_paintable.selection_state == .start_and_end
 old_box := old_paint_tree.find_box(i64(wide.as_node().unique_id())) or { panic('box') }
 old_width := old_box.width
 mut host_node := host.as_node()
 host_node.set_needs_layout_update(.style_change)
 _ = layout_document_typed_in_viewport(document, 300, 160)
 mut current_result := document_layout_result(document) or { panic('current result') }
 assert voidptr(current_result) != voidptr(old_result)
 assert voidptr(current_result.root) == voidptr(old_root)
 assert voidptr(current_result.state) != voidptr(old_state)
 assert voidptr(host.as_node().layout_node() or { panic('mirror') }) == voidptr(mirror)
 assert voidptr(host.paintable_box() or { panic('paintable') }) == voidptr(paintable)
 assert paintable.repaint_callback_target == voidptr(current_result)
 assert voidptr(text.paintable() or { panic('text paintable') }) == voidptr(text_paintable)
 assert text_paintable.selection_state == .start_and_end
 assert paintable.scroll_offset() == dom.CSSPixelPoint_{x_:30,y_:20}
 old_result_address := voidptr(old_result)
 mut mutable_old := unsafe { &DocumentLayoutResult(old_result_address) }
 mutable_old.needs_repaint = false
 current_result.needs_repaint = false
 paintable.set_needs_repaint(.paint_commands)
 assert current_result.needs_repaint
 assert !old_result.needs_repaint
 assert old_box.width == old_width
 assert old_commands.any(it.kind == 'draw_text' && it.text == 'retained glyphs')
 assert run.glyphs() == old_glyphs
 assert voidptr(run.font()) == voidptr(old_font)
 assert voidptr(old_result.state) == voidptr(old_state)
}

fn test_retained_dom_inline_paintable_slots_follow_reflow_and_clear_removed_entries() {
 mut document := html.parse_document('<!doctype html><style>html,body{margin:0}span{font:16px/20px SerenityMono}</style><span id="host">one two three four five six seven eight nine ten</span>')
 defer { document.finalize() }
 root := build_layout_tree(document) or { panic('root') }
 host := document.get_element_by_id('host') or { panic('host') }
 viewport := root.as_viewport() or { panic('viewport') }
 initial := prepare_dom_layout_attachment(root)
 document.set_layout_viewport(&dom.LayoutViewport{root_node:initial.root})
 mut first := LayoutState.new()
 layout_viewport(mut first,viewport,100,200)
 _ = commit_dom_layout_attachment(root,first,initial)
 mirror := host.as_node().layout_node() or { panic('mirror') }
 previous := mirror.paintables_.clone()
 assert previous.len > 1
 prepared := prepare_dom_layout_attachment(root)
 mut second := LayoutState.new()
 layout_viewport(mut second,viewport,900,200)
 _ = commit_dom_layout_attachment(root,second,prepared)
 assert mirror.paintables_.len == 1
 assert voidptr(mirror.paintables_[0]) == voidptr(previous[0])
 assert voidptr(host.as_node().paintable() or { panic('primary') }) == voidptr(previous[0])
 for paintable in mirror.paintables_ { assert paintable.layout_handle == mirror.layout_handle }
 third_prepared := prepare_dom_layout_attachment(root)
 mut third := LayoutState.new()
 layout_viewport(mut third,viewport,100,200)
 _ = commit_dom_layout_attachment(root,third,third_prepared)
 assert mirror.paintables_.len == previous.len
 assert voidptr(mirror.paintables_[0]) == voidptr(previous[0])
 for index in 1 .. mirror.paintables_.len {
  assert voidptr(mirror.paintables_[index]) != voidptr(previous[index])
 }
}

fn test_dom_live_boundaries_are_replaced_after_layout_tree_regeneration() {
 mut document := html.parse_document('<!doctype html><style>#host::before{content:"prefix"}</style><div id="host">text</div>')
 defer { document.finalize() }
 _ = layout_document_typed_in_viewport(document,300,160)
 mut host := document.get_element_by_id('host') or { panic('host') }
 old := host.as_node().layout_node() or { panic('old') }
 old_paintable := host.as_node().paintable() or { panic('old paintable') }
 old_pseudo := (host.get_pseudo_element_node(int(dom.PseudoElement.before)) or { panic('before') }).layout_node_ or { panic('before mirror') }
 host.set_attribute_value('style','display:none')
 document.set_needs_full_layout_tree_update(true)
 _ = layout_document_typed_in_viewport(document,300,160)
 assert host.as_node().layout_node() == none
 assert host.as_node().paintable() == none
 assert host.get_pseudo_element_node(int(dom.PseudoElement.before)) == none
 host.set_attribute_value('style','display:block')
 document.set_needs_full_layout_tree_update(true)
 _ = layout_document_typed_in_viewport(document,300,160)
 updated := host.as_node().layout_node() or { panic('updated') }
 assert updated.layout_handle != old.layout_handle
 assert voidptr(updated) != voidptr(old)
 assert voidptr(host.as_node().paintable() or { panic('new paintable') }) != voidptr(old_paintable)
 new_pseudo := (host.get_pseudo_element_node(int(dom.PseudoElement.before)) or { panic('before') }).layout_node_ or { panic('before mirror') }
 assert new_pseudo.layout_handle != old_pseudo.layout_handle
 assert voidptr(new_pseudo) != voidptr(old_pseudo)
}

fn test_live_dom_geometry_reflow_keeps_published_paint_glyph_and_used_value_snapshots() {
 mut document := html.parse_document('<!doctype html><style>html,body,div{margin:0}div{font:16px/20px SerenityMono}</style><div id="host">one two three four five six seven eight nine ten</div>')
 defer { document.finalize() }
 root := build_layout_tree(document) or { panic('root') }
 first := finish_document_layout(document,root,120,200,0) or { panic('first layout') }
 previous := renderer_box_from_document_layout_result(first,120,200)
 host := document.get_element_by_id('host') or { panic('host') }
 identity := i64(host.as_node().unique_id())
 previous_box := previous.find_box(identity) or { panic('previous box') }
 previous_mirror := host.as_node().layout_node() or { panic('mirror') }
 typed := unsafe { &Node(previous_mirror.layout_handle) }.as_node_with_style() or { panic('typed') }
 previous_used := first.state.try_get(typed) or { panic('used') }
 previous_height := previous_used.content_height().to_double()
 previous_lines := previous_box.lines.len
 commands := previous.paint_commands()
 text_commands := commands.filter(it.kind == 'draw_text')
 mut glyph_snapshots := [][]platform.Glyph{}
 for command in text_commands {
  run := command.glyph_run or { panic('glyph run') }
  glyph_snapshots << run.glyphs().clone()
 }
 assert previous_lines > 1
 second := finish_document_layout(document,root,800,200,0) or { panic('second layout') }
 current := renderer_box_from_document_layout_result(second,800,200)
 current_box := current.find_box(identity) or { panic('current box') }
 assert current_box.lines.len == 1
 assert current_box.height < previous_height
 assert previous_box.lines.len == previous_lines
 assert previous_box.width == 120
 assert previous_box.height == previous_height
 assert previous_used.content_width().to_double() == 120
 assert previous_used.content_height().to_double() == previous_height
 assert voidptr(host.as_node().layout_node() or { panic('mirror') }) == voidptr(previous_mirror)
 assert previous_mirror.content_width_ == 800
 assert voidptr(first.state) != voidptr(second.state)
 for index, command in text_commands {
  run := command.glyph_run or { panic('glyph run') }
  assert run.glyphs() == glyph_snapshots[index]
 }
 assert commands.filter(it.kind == 'draw_text').len == text_commands.len
 assert previous.paint_commands().filter(it.kind == 'draw_text').len == text_commands.len
}
