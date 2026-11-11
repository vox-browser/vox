// Copyright (c) 2026-present, the Ladybird developers.
//
// SPDX-License-Identifier: BSD-2-Clause

module layout

import dom
import css
import html

fn document_tree_builder_node_with_id(root &Node, id string) ?&Node {
	if dom_node := root.dom_node() {
		if element := dom_node.as_element() {
			if element.id() or { '' } == id {
				return root
			}
		}
	}
	for child in root.children() {
		if found := document_tree_builder_node_with_id(child, id) {
			return found
		}
	}
	return none
}

fn document_tree_builder_node_for_dom(root &Node, target &dom.Node) ?&Node {
	if dom_node := root.dom_node() {
		if dom_node.unique_id() == target.unique_id() {
			return root
		}
	}
	for child in root.children() {
		if found := document_tree_builder_node_for_dom(child, target) {
			return found
		}
	}
	return none
}

fn document_tree_builder_first_image(root &Node) ?&Node {
	if root.is_image_box() {
		return root
	}
	for child in root.children() {
		if found := document_tree_builder_first_image(child) {
			return found
		}
	}
	return none
}

fn test_broken_image_alt_text_uses_shadow_content_and_non_replaced_layout() {
	document := html.parse_document('<!doctype html><body><img id="image" alt="image fallback"><input id="input" type="image" alt="input fallback">')
	root := build_layout_tree(document) or { panic('no layout tree') }
	for id in ['image', 'input'] {
		element := document.get_element_by_id(id) or { panic('missing ${id}') }
		assert element.shadow_root() != none
		node := document_tree_builder_node_with_id(root, id) or { panic('missing ${id} box') }
		assert !node.is_image_box()
		wrapper := node.first_child() or { panic('missing ${id} alt wrapper') }
		assert wrapper.is_inline_node()
		text := (wrapper.first_child() or { panic('missing ${id} alt text') }).as_text_node() or {
			panic('${id} alt child is not text')
		}
		assert text.text_for_rendering() == '${id} fallback'
	}
}

fn test_pending_and_decoded_images_keep_replaced_layout_nodes() {
	document := html.parse_document('<!doctype html><body><img id="pending" src="pending.png" alt="fallback"><img id="decoded" src="${content_replacement_green_image}" alt="fallback"><input id="input-pending" type="image" src="pending.png" alt="fallback"><input id="input-decoded" type="image" src="${content_replacement_green_image}" alt="fallback">')
	root := build_layout_tree(document) or { panic('no layout tree') }
	for id in ['pending', 'decoded', 'input-pending', 'input-decoded'] {
		element := document.get_element_by_id(id) or { panic('missing ${id}') }
		assert element.shadow_root() == none
		node := document_tree_builder_node_with_id(root, id) or { panic('missing ${id} box') }
		assert node.is_image_box()
	}
}

fn test_select_fallback_button_keeps_the_chevron_out_of_flow() {
	document := html.parse_document('<!doctype html><select id="select"><optgroup><option>First</option><option selected label="Chosen label">ignored</option></optgroup></select>')
	root := build_layout_tree(document) or { panic('no layout tree') }
	select_layout_node := document_tree_builder_node_with_id(root, 'select') or {
		panic('missing select')
	}
	outer := select_layout_node.first_child() or { panic('missing select fallback button') }
	label := outer.children()[0]
	chevron := outer.children()[1]
	assert outer.is_positioned()
	assert label.computed_values().flex_grow() == 1
	assert label.computed_values().length_percentage_to_px(.margin_right, 0) or { -1.0 } == 20
	label_text := (label.first_child() or { panic('missing label text') }).as_text_node() or {
		panic('label child is not text')
	}
	assert label_text.text_for_rendering() == 'Chosen label'
	assert chevron.is_absolutely_positioned()
	assert chevron.computed_values().length_percentage_to_px(.right, 0) or { -1.0 } == 0

	appearance_none_document := html.parse_document('<!doctype html><select id="select" style="appearance:none"><option>Only label</option></select>')
	appearance_none_root := build_layout_tree(appearance_none_document) or {
		panic('no appearance:none layout tree')
	}
	appearance_none_select := document_tree_builder_node_with_id(appearance_none_root, 'select') or {
		panic('missing appearance:none select')
	}
	appearance_none_outer := appearance_none_select.first_child() or {
		panic('missing appearance:none fallback button')
	}
	assert appearance_none_outer.child_count() == 1
}

const content_replacement_green_image = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAD0lEQVR4nGNgaGBAIOI4ANA0CAF5jtVRAAAAAElFTkSuQmCC'
const content_replacement_red_image = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAEElEQVR4nGP4z8AARwzEcQCukw/x0F8jngAAAABJRU5ErkJggg=='

fn test_single_content_image_replaces_an_element_and_ignores_source_updates() {
	document := html.parse_document('<!doctype html><style>
		#target { display:block; width:100px; height:100px; content:url(${content_replacement_green_image}) }
		#contents { display:contents; content:url(${content_replacement_green_image}) }
	</style><img id="target"><div id="contents"><span id="contents-child"></span></div>')
	root := build_layout_tree(document) or { panic('no layout tree') }
	mut target := document.get_element_by_id('target') or { panic('missing target') }
	target_node := document_tree_builder_node_for_dom(root, target.as_node()) or {
		panic('missing target layout node')
	}
	mut image_box := unsafe { &ImageBox(target_node) }
	assert target_node.is_image_box()
	assert image_box.source() == content_replacement_green_image

	target.set_attribute_value('src', content_replacement_red_image)
	image_box.reset_for_relayout()
	assert image_box.source() == content_replacement_green_image
	assert document_tree_builder_node_with_id(root, 'contents') == none
	assert document_tree_builder_node_with_id(root, 'contents-child') != none
}

fn test_single_pseudo_content_image_becomes_the_pseudo_box() {
	document := html.parse_document('<!doctype html><style>
		#block::before { content:url(${content_replacement_green_image}); display:block }
		#table::before { content:url(${content_replacement_green_image}); display:table }
		#cell::before { content:url(${content_replacement_green_image}); display:table-cell }
		#list::before { content:url(${content_replacement_green_image}); display:list-item }
		#contents::before { content:url(${content_replacement_green_image}); display:contents }
		#quote::before { content:no-open-quote url(${content_replacement_green_image}); display:flex }
	</style><div id="block"></div><div id="table"></div><div id="cell"></div><div id="list"></div><div id="contents"></div><div id="quote"></div>')
	root := build_layout_tree(document) or { panic('no layout tree') }
	for id in ['block', 'table', 'cell'] {
		host := document_tree_builder_node_with_id(root, id) or { panic('missing ${id}') }
		pseudo := host.first_child() or { panic('missing ${id} pseudo') }
		assert pseudo.is_image_box()
		assert pseudo.child_count() == 0
		assert (pseudo.as_image_box() or { panic('missing ${id} image box') }).source() == content_replacement_green_image
	}
	block := document_tree_builder_node_with_id(root, 'block') or { panic('missing block') }
	table := document_tree_builder_node_with_id(root, 'table') or { panic('missing table') }
	cell := document_tree_builder_node_with_id(root, 'cell') or { panic('missing cell') }
	assert (block.first_child() or { panic('missing block pseudo') }).display().is_block_outside()
	assert (table.first_child() or { panic('missing table pseudo') }).display().is_block_outside()
	assert (cell.first_child() or { panic('missing cell pseudo') }).display().is_inline_outside()

	for id in ['list', 'contents'] {
		host := document_tree_builder_node_with_id(root, id) or { panic('missing ${id}') }
		pseudo := host.first_child() or { panic('missing ${id} pseudo') }
		assert !pseudo.is_image_box()
		image := document_tree_builder_first_image(pseudo) or { panic('missing ${id} image child') }
		assert image.display().is_inline_outside()
	}
	contents_host := document_tree_builder_node_with_id(root, 'contents') or {
		panic('missing contents')
	}
	assert (contents_host.first_child() or { panic('missing contents pseudo') }).is_inline_node()
	quote_host := document_tree_builder_node_with_id(root, 'quote') or { panic('missing quote') }
	quote_pseudo := quote_host.first_child() or { panic('missing quote pseudo') }
	assert !quote_pseudo.is_image_box()
	assert quote_pseudo.display().is_flex_inside()
	assert document_tree_builder_first_image(quote_pseudo) != none
}

// build_layout_tree walks the DOM and produces a real layout tree rooted at the Viewport (whose DOM node is
// the Document); the root element's box is the viewport's child. display:none elements (and their subtrees)
// get no box.
fn test_build_layout_tree() {
	mut doc := dom.Document.create(dom.url_about_blank())
	mut html_el := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic('${err}')
	}
	mut body := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'body') or { panic('${err}') }
	mut div := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	mut hidden := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'p') or { panic('${err}') }
	hidden.set_attribute_value('style', 'display: none')

	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(html_el.as_node()) or { panic('append html: ${err}') }
	mut html_node := html_el.as_node()
	html_node.append_child(body.as_node()) or { panic('append body: ${err}') }
	mut body_node := body.as_node()
	body_node.append_child(div.as_node()) or { panic('append div: ${err}') }
	body_node.append_child(hidden.as_node()) or { panic('append p: ${err}') }

	root := build_layout_tree(doc) or { panic('no layout tree') }
	// The root is the Viewport; its DOM node is the Document, and <html> is its single box child.
	assert root.is_viewport()
	assert root.child_count() == 1
	html_box := root.first_child() or { panic('no html box') }
	assert html_box.is_block_container()
	root_el := (html_box.dom_node() or { panic('html box has no dom node') }).as_element() or {
		panic('html box dom node not element')
	}
	assert root_el.local_name() == 'html'

	// html has one layout child: body.
	assert html_box.child_count() == 1
	body_box := html_box.first_child() or { panic('no body box') }

	// body's children: div is boxed, the display:none <p> is not.
	assert body_box.child_count() == 1
	div_box := body_box.first_child() or { panic('no div box') }
	div_el := (div_box.dom_node() or { panic('div box has no dom node') }).as_element() or {
		panic('div box dom node not element')
	}
	assert div_el.local_name() == 'div'
	assert div_box.is_block_container()
}

fn test_svg_resource_mutation_invalidates_referencing_layout_subtrees() {
	document := html.parse_document('<!doctype html><svg><defs><mask id="mask"><rect width="1" height="1"/></mask><pattern id="pattern" width="1" height="1"><rect width="1" height="1"/></pattern></defs><rect id="masked" width="10" height="10" mask="url(#mask)"/><rect id="patterned" y="20" width="10" height="10" fill="url(#pattern)"/></svg>')
	_ := run_document_layout(document, 200, 100) or { panic('layout failed') }
	masked := document.get_element_by_id('masked') or { panic('missing masked element') }
	masked_layout := masked.as_node().unsafe_layout_node() or { panic('missing masked layout node') }
	assert !masked_layout.needs_layout_update()

	mut mask := document.get_element_by_id('mask') or { panic('missing mask') }
	mask.set_attribute_value('maskUnits', 'userSpaceOnUse')
	assert masked_layout.needs_layout_update()

	patterned := document.get_element_by_id('patterned') or { panic('missing patterned element') }
	assert !patterned.as_node().needs_layout_tree_update_()
	mut pattern := document.get_element_by_id('pattern') or { panic('missing pattern') }
	mut pattern_parent := pattern.as_node().parent_node() or { panic('missing pattern parent') }
	pattern_parent.remove_child(pattern.as_node()) or { panic('failed to remove pattern') }
	assert patterned.as_node().needs_layout_tree_update_()
}

// run_document_layout packages tree-building + block layout into one document entry point.
fn test_run_document_layout() {
	mut doc := dom.Document.create(dom.url_about_blank())
	mut html_el := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic('${err}')
	}
	mut div1 := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	div1.set_attribute_value('style', 'height: 30px')
	mut div2 := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	div2.set_attribute_value('style', 'height: 40px')
	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(html_el.as_node()) or { panic('${err}') }
	mut html_node := html_el.as_node()
	html_node.append_child(div1.as_node()) or { panic('${err}') }
	html_node.append_child(div2.as_node()) or { panic('${err}') }

	result := run_document_layout(doc, 800.0, 600.0) or { panic('layout produced no result') }

	// The viewport's content box is pinned to the viewport rectangle.
	viewport_nws := result.root.as_node_with_style() or { panic('viewport not nws') }
	viewport_uv := result.used_values_for(viewport_nws) or { panic('no viewport used values') }
	assert viewport_uv.content_width().to_double() == 800.0
	assert viewport_uv.content_height().to_double() == 600.0

	// <html> fills the viewport width; its auto height = 30 + 40 = 70.
	html_box := result.root.first_child() or { panic('no html box') }
	html_nws := html_box.as_node_with_style() or { panic('html not nws') }
	html_uv := result.used_values_for(html_nws) or { panic('no html used values') }
	assert html_uv.content_width().to_double() == 800.0
	assert html_uv.content_height().to_double() == 70.0

	div2_nws := html_box.children()[1].as_node_with_style() or { panic('div2 not nws') }
	div2_uv := result.used_values_for(div2_nws) or { panic('no div2 used values') }
	assert div2_uv.content_height().to_double() == 40.0
	assert div2_uv.offset.y().to_double() == 30.0
}

fn test_tree_dump_layout_does_not_build_renderer_transport() {
	mut doc := dom.Document.create(dom.url_about_blank())
	mut html_el := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic('${err}')
	}
	mut body := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'body') or {
		panic('${err}')
	}
	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(html_el.as_node()) or { panic('${err}') }
	mut html_node := html_el.as_node()
	html_node.append_child(body.as_node()) or { panic('${err}') }

	result := run_document_layout_for_tree_dump(doc, 320, 200) or {
		panic('layout produced no result')
	}
	assert result.paint_tree.tag_name == ''
	assert result.paint_tree.width == 0
	assert result.paint_tree.height == 0
	tree_text := dump_current_document_layout_tree(doc) or {
		panic('layout tree was not retained')
	}
	assert tree_text.contains('Viewport')
	assert tree_text.contains('BlockContainer <html>')
}

fn test_layout_snapshot_uses_current_upstream_sections() {
	mut doc := html.parse_document('<!doctype html><div>snapshot</div>')
	snapshot := dump_document_layout_snapshot(doc, 320, 200) or {
		panic('layout snapshot was not produced')
	}
	sections := snapshot.split('\n\n')
	// Since 980be4b6b2d, LayoutTest no longer includes the intermediate
	// paintable-tree dump. The second and final section is the stacking tree.
	assert sections.len == 2
	assert sections[0].starts_with('Viewport <#document>')
	assert sections[1].starts_with('SC for Viewport<#document>')
	assert !sections[1].contains('[children:')
}

fn test_hidden_document_element_keeps_an_empty_viewport_bfc() {
	doc := html.parse_document('<!doctype html><html hidden><body>hidden</body></html>')
	snapshot := dump_document_layout_snapshot(doc, 320, 200) or {
		panic('layout snapshot was not produced')
	}
	assert snapshot.starts_with('Viewport <#document> at [0,0] [0+0+0 320 0+0+0] [0+0+0 200 0+0+0] [BFC] children: not-inline\n\n')
	assert !snapshot.contains('BlockContainer <html>')
}

fn test_layout_tree_dump_includes_scrollable_overflow() {
	mut doc := html.parse_document('<!doctype html><style>
		html, body { margin: 0 }
		#scroller { width: 100px; height: 50px; overflow: auto }
		#content { width: 200px; height: 100px }
	</style><div id="scroller"><div id="content"></div></div>')
	tree := dump_document_layout_tree(doc, 320, 200) or {
		panic('layout tree was not produced')
	}
	scroller_line := tree.split_into_lines().filter(it.contains('<div#scroller>'))[0]
	assert scroller_line.ends_with(' overflow: [0,0 200x100]')
}

fn test_layout_tree_dump_includes_viewport_overflow() {
	mut doc := html.parse_document('<!doctype html><style>
		html, body { margin: 0 }
		#content { width: 400px; height: 300px }
	</style><div id="content"></div>')
	tree := dump_document_layout_tree(doc, 320, 200) or {
		panic('layout tree was not produced')
	}
	assert tree.split_into_lines()[0].ends_with(' overflow: [0,0 400x300]')
}

fn test_layout_tree_dump_includes_svg_viewport_transforms() {
	mut doc := html.parse_document('<!doctype html><style>html, body, svg { margin: 0; display: block }</style>
		<svg id="outer" width="200" height="100" viewBox="0 0 10 10">
			<svg id="inner" width="8" height="8" viewBox="-1 -1 10 10"></svg>
		</svg>')
	tree := dump_document_layout_tree(doc, 320, 200) or {
		panic('layout tree was not produced')
	}
	outer_line := tree.split_into_lines().filter(it.contains('<svg#outer>'))[0]
	inner_line := tree.split_into_lines().filter(it.contains('<svg#inner>'))[0]
	assert outer_line.contains(' viewport-transform=[10 0 0 10 50 0] [SVG]')
	assert inner_line.contains(' viewport-transform=[')
}

fn test_scrollable_overflow_preserves_end_padding() {
	mut doc := html.parse_document('<!doctype html><style>
		html, body { margin: 0 }
		#scroller { width: 100px; height: 50px; padding: 25px; overflow: auto }
		#content { box-sizing: content-box; width: 100px; height: 100px; border: 1px solid }
	</style><div id="scroller"><div id="content"></div></div>')
	result := run_document_layout(doc, 320, 200) or { panic('layout failed') }
	scroller := document_tree_builder_node_with_id(result.root, 'scroller') or {
		panic('missing #scroller')
	}
	styled := scroller.as_node_with_style() or { panic('#scroller has no style') }
	used := result.state.try_get(styled) or { panic('#scroller has no used values') }
	overflow := used.scrollable_overflow_rect() or { panic('#scroller has no overflow rect') }
	assert used.has_scrollable_overflow()
	assert layout_debug_css_rect(overflow) == '[0,0 152x152]'
}

// A DOM text node becomes a Layout::TextNode carrying offset-preserving rendered text.
fn test_text_node_layout() {
	mut doc := dom.Document.create(dom.url_about_blank())
	mut html_el := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic('${err}')
	}
	mut para := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'p') or { panic('${err}') }
	text := doc.create_text_node('  Hello    world  ')

	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(html_el.as_node()) or { panic('${err}') }
	mut html_node := html_el.as_node()
	html_node.append_child(para.as_node()) or { panic('${err}') }
	mut para_node := para.as_node()
	para_node.append_child(text.as_node()) or { panic('${err}') }

	root := build_layout_tree(doc) or { panic('no layout tree') }
	html_box := root.first_child() or { panic('no html box') }
	para_box := html_box.first_child() or { panic('no p box') }
	assert para_box.is_block_container()

	text_box := para_box.first_child() or { panic('no text box') }
	assert text_box.is_text_node()
	assert !text_box.is_box()
	text_node := text_box.as_text_node() or { panic('text box is not a TextNode') }
	// TextNode::compute_text_for_rendering converts collapsible tabs/newlines
	// without destroying code-unit offsets; repeated spaces are collapsed later
	// by ChunkIterator.
	assert text_node.text_for_rendering() == '  Hello    world  '
	text_dom := text_box.dom_node() or { panic('text box has no dom node') }
	assert text_dom.is_text()

	// The bridge marks it as a text node on the DOM side too.
	result := run_document_layout(doc, 800.0, 600.0) or { panic('no layout result') }
	attach_layout_nodes(result.root)
	text_layout := text.as_node().layout_node() or { panic('text has no layout node') }
	assert text_layout.is_text_node()
	assert text.as_node().accessible_name(doc, .no)! == '  Hello    world  '
}

// A block whose content is inline (text) gets the computed line-height.
fn test_inline_content_height() {
	mut doc := dom.Document.create(dom.url_about_blank())
	mut html_el := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic('${err}')
	}
	mut para := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'p') or { panic('${err}') }
	text := doc.create_text_node('Hello world')
	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(html_el.as_node()) or { panic('${err}') }
	mut html_node := html_el.as_node()
	html_node.append_child(para.as_node()) or { panic('${err}') }
	mut para_node := para.as_node()
	para_node.append_child(text.as_node()) or { panic('${err}') }

	result := run_document_layout(doc, 800.0, 600.0) or { panic('no layout result') }
	html_box := result.root.first_child() or { panic('no html box') }
	para_box := html_box.first_child() or { panic('no p box') }
	para_nws := para_box.as_node_with_style() or { panic('p not nws') }
	para_uv := result.used_values_for(para_nws) or { panic('no p used values') }
	// Compare with ComputedProperties::line_height(), rather than duplicating
	// the engine's current normal-line-height scale.
	height := para_uv.content_height().to_double()
	assert height == para_nws.computed_values().line_height().to_double()
}

// Mixed inline + block content in one container: a text node beside a block element. The text is wrapped in
// an anonymous block box (CSS 2.1 §9.2.1.1) so the container's children are all block-level, and the block
// sibling is not dropped.
fn test_anonymous_block_wrapping_for_mixed_content() {
	mut doc := dom.Document.create(dom.url_about_blank())
	mut html_el := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic('${err}')
	}
	mut div := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	div.set_attribute_value('style', 'color: rgb(1, 2, 3); margin-top: 33px')
	text := doc.create_text_node('hello')
	mut para := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'p') or { panic('${err}') }

	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(html_el.as_node()) or { panic('${err}') }
	mut html_node := html_el.as_node()
	html_node.append_child(div.as_node()) or { panic('${err}') }
	mut div_node := div.as_node()
	div_node.append_child(text.as_node()) or { panic('${err}') }
	div_node.append_child(para.as_node()) or { panic('${err}') }

	// Build + lay out once, then navigate that single tree (build_layout_tree runs again internally, so a
	// tree built separately would hold different node pointers than the laid-out one).
	result := run_document_layout(doc, 800.0, 600.0) or { panic('no layout result') }
	html_box := result.root.first_child() or { panic('no html box') }
	div_box := html_box.first_child() or { panic('no div box') }

	// The div has mixed content, so it is block-level with two block children: an anonymous wrapper (holding
	// the text) followed by the <p> box.
	assert !div_box.children_are_inline()
	assert div_box.child_count() == 2

	wrapper := div_box.first_child() or { panic('no wrapper') }
	assert wrapper.is_anonymous()
	assert wrapper.children_are_inline()
	assert wrapper.child_count() == 1
	wrapper_style := wrapper.as_node_with_style() or { panic('wrapper has no style') }
	assert wrapper_style.computed_values().display().is_block_outside()
	assert (wrapper_style.computed_values().property(.margin_top, .yes) or {
		panic('missing margin-top')
	}).css_text != '33px'
	assert (wrapper_style.computed_values().property(.color, .yes) or { panic('missing color') }).css_text == (div_box.computed_values().property(.color, .yes) or { panic('missing parent color') }).css_text
	wrapper_child := wrapper.first_child() or { panic('no wrapper child') }
	assert wrapper_child.is_text_node()

	para_box := div_box.children()[1]
	assert !para_box.is_anonymous()
	para_el := (para_box.dom_node() or { panic('p box has no dom node') }).as_element() or {
		panic('p box dom node not element')
	}
	assert para_el.local_name() == 'p'

	// The block sibling is laid out (not dropped): it sits below the anonymous text line box (~19.2px).
	para_uv := result.used_values_for(para_box.as_node_with_style() or { panic('p not nws') }) or {
		panic('no p used values')
	}
	assert para_uv.offset.y().to_double() > 19.0
}

fn test_flex_children_are_blockified_and_marked_as_items() {
	mut doc := dom.Document.create(dom.url_about_blank())
	mut html_el := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic('${err}')
	}
	mut flex := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	flex.set_attribute_value('style', 'display:flex')
	text := doc.create_text_node('text')
	mut child := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }

	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(html_el.as_node()) or { panic('${err}') }
	mut html_node := html_el.as_node()
	html_node.append_child(flex.as_node()) or { panic('${err}') }
	mut flex_node := flex.as_node()
	flex_node.append_child(text.as_node()) or { panic('${err}') }
	flex_node.append_child(child.as_node()) or { panic('${err}') }

	result := run_document_layout(doc, 800, 600) or { panic('layout failed') }
	root := result.root
	flex_box := (root.first_child() or { panic('html') }).first_child() or { panic('flex') }
	assert flex_box.display().is_flex_inside()
	assert flex_box.child_count() == 2
	assert flex_box.children()[0].is_anonymous()
	assert flex_box.children()[0].is_flex_item()
	assert flex_box.children()[1].is_flex_item()
}

// The initial containing block is the viewport, so a root-level percentage height resolves against the
// viewport height (CSS 2.1 §10.5): `html { height: 50% }` in a 600px-tall viewport is 300px.
fn test_root_percentage_height_resolves_against_viewport() {
	mut doc := dom.Document.create(dom.url_about_blank())
	mut html_el := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic('${err}')
	}
	html_el.set_attribute_value('style', 'height: 50%')
	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(html_el.as_node()) or { panic('${err}') }

	result := run_document_layout(doc, 800.0, 600.0) or { panic('no layout result') }
	html_box := result.root.first_child() or { panic('no html box') }
	html_nws := html_box.as_node_with_style() or { panic('html not nws') }
	html_uv := result.used_values_for(html_nws) or { panic('no html used values') }
	// 50% of the 600px viewport height.
	assert html_uv.content_height().to_double() == 300.0
}

fn test_display_type_selects_literal_layout_node_subclass() {
	doc := dom.Document.create(dom.url_about_blank())
	style_computer := css.css_style_computer_for(doc)

	span := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or { panic('${err}') }
	span_style := style_computer.compute_style(dom.AbstractElement.new(span, none))
	span_node := create_layout_node_for_element(doc, span, span_style) or { panic('no span node') }
	assert span_node.is_inline_node()
	assert span_node.is_inline()
	assert !span_node.is_box()

	mut flex := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	flex.set_attribute_value('style', 'display: flex')
	flex_style := style_computer.compute_style(dom.AbstractElement.new(flex, none))
	flex_node := create_layout_node_for_element(doc, flex, flex_style) or { panic('no flex node') }
	assert flex_node.is_box()
	assert !flex_node.is_block_container()

	list_item := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'li') or { panic('${err}') }
	list_style := style_computer.compute_style(dom.AbstractElement.new(list_item, none))
	list_node := create_layout_node_for_element(doc, list_item, list_style) or {
		panic('no list-item node')
	}
	assert list_node.is_list_item_box()
	assert list_node.is_block_container()

	br := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'br') or { panic('${err}') }
	br_style := style_computer.compute_style(dom.AbstractElement.new(br, none))
	br_node := create_layout_node_for_element(doc, br, br_style) or { panic('no br node') }
	assert br_node.is_break_node()
	assert !br_node.can_have_children()

	mut checkbox := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'input') or {
		panic('${err}')
	}
	checkbox.set_attribute_value('type', 'checkbox')
	checkbox_style := style_computer.compute_style(dom.AbstractElement.new(checkbox, none))
	checkbox_node := create_layout_node_for_element(doc, checkbox, checkbox_style) or {
		panic('no checkbox node')
	}
	assert checkbox_node.is_replaced_box()
	assert !checkbox_node.can_have_children()
	checkbox_box := checkbox_node.as_box() or { panic('checkbox is not a box') }
	checkbox_width := checkbox_box.auto_content_box_size().width or { CSSPixels.new(0) }
	assert checkbox_width.to_double() == 13

	mut hidden_input := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'input') or {
		panic('${err}')
	}
	hidden_input.set_attribute_value('type', 'hidden')
	hidden_style := style_computer.compute_style(dom.AbstractElement.new(hidden_input, none))
	assert create_layout_node_for_element(doc, hidden_input, hidden_style) == none

	mut primitive_input := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'input') or {
		panic('${err}')
	}
	primitive_input.set_attribute_value('style', 'appearance:none;display:inline')
	primitive_style := style_computer.compute_style(dom.AbstractElement.new(primitive_input, none))
	primitive_node := create_layout_node_for_element(doc, primitive_input, primitive_style) or {
		panic('no primitive input node')
	}
	assert primitive_node.is_block_container()
	assert !primitive_node.is_text_input_box()

	media_document := html.parse_document('<!doctype html><audio id="audio" controls><span id="audio-fallback">fallback</span></audio><video id="video" controls><span id="video-fallback">fallback</span></video>')
	media_root := build_layout_tree(media_document) or { panic('no media layout tree') }
	attach_layout_nodes(media_root)
	assert tree_builder_node_with_id(media_root, 'audio') or { panic('no audio box') }.is_replaced_box()
	assert tree_builder_node_with_id(media_root, 'video') or { panic('no video box') }.is_replaced_box()
	assert tree_builder_node_with_id(media_root, 'audio-fallback') == none
	assert tree_builder_node_with_id(media_root, 'video-fallback') == none
	audio_dom := media_document.get_element_by_id('audio') or { panic('audio DOM') }
	video_dom := media_document.get_element_by_id('video') or { panic('video DOM') }
	assert html_audio_element_layout_node(unsafe { &dom.HTMLAudioElement(audio_dom) }) != none
	assert html_video_element_layout_node(unsafe { &dom.HTMLVideoElement(video_dom) }) != none
	audio_shadow := audio_dom.shadow_root() or { panic('audio controls shadow root') }
	controls_container := css.query_selector(audio_shadow.as_node(), '.container') or {
		panic('audio controls container')
	}
	controls_container_layout := document_tree_builder_node_for_dom(media_root,
		controls_container.as_node()) or { panic('audio controls container layout node') }
	assert controls_container_layout.computed_values().text_align() == .left
	timeline := css.query_selector(audio_shadow.as_node(), '.timeline') or {
		panic('audio controls timeline')
	}
	timeline_layout := document_tree_builder_node_for_dom(media_root, timeline.as_node()) or {
		panic('audio controls timeline layout node')
	}
	assert timeline_layout.computed_values().text_align() == .left
	timeline_track := css.query_selector(audio_shadow.as_node(), '.timeline-track') or {
		panic('audio controls timeline track')
	}
	timeline_track_parent := timeline_track.parent_element() or { panic('timeline track parent') }
	assert timeline_track_parent == timeline
	timeline_fill := css.query_selector(audio_shadow.as_node(), '.timeline-fill') or {
		panic('audio controls timeline fill')
	}
	timeline_fill_parent := timeline_fill.parent_element() or { panic('timeline fill parent') }
	assert timeline_fill_parent == timeline_track
	video_shadow := video_dom.shadow_root() or { panic('video controls shadow root') }
	video_container := css.query_selector(video_shadow.as_node(), '.container.video') or {
		panic('video controls container')
	}
	assert css.query_selector(video_container.as_node(), '.video-overlay') != none
	assert css.query_selector(video_container.as_node(), '.fullscreen-button') != none
	video_snapshot := dump_document_layout_snapshot(media_document, 800, 600) or {
		panic('video controls layout snapshot')
	}
	assert video_snapshot.contains('BlockContainer <div.container.video> at [308,8] positioned [0+0+0 300 0+0+0] [0+0+0 150 0+0+0]')

	textarea := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'textarea') or {
		panic('${err}')
	}
	textarea_style := style_computer.compute_style(dom.AbstractElement.new(textarea, none))
	textarea_node := create_layout_node_for_element(doc, textarea, textarea_style) or {
		panic('no textarea node')
	}
	assert textarea_node.is_textarea_box()
	assert textarea_node.is_block_container()

	fieldset := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'fieldset') or {
		panic('${err}')
	}
	fieldset_style := style_computer.compute_style(dom.AbstractElement.new(fieldset, none))
	fieldset_node := create_layout_node_for_element(doc, fieldset, fieldset_style) or {
		panic('no fieldset node')
	}
	assert fieldset_node.is_fieldset_box()
	assert html_field_set_element_layout_node(fieldset_node) != none
	assert creates_block_formatting_context(fieldset_node.as_node_with_style() or {
		panic('fieldset has no style')
	})

	legend := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'legend') or {
		panic('${err}')
	}
	legend_style := style_computer.compute_style(dom.AbstractElement.new(legend, none))
	legend_node := create_layout_node_for_element(doc, legend, legend_style) or {
		panic('no legend node')
	}
	assert legend_node.is_legend_box()
	assert html_legend_element_layout_node(legend_node) != none

	iframe := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'iframe') or {
		panic('${err}')
	}
	iframe_style := style_computer.compute_style(dom.AbstractElement.new(iframe, none))
	iframe_node := html_iframe_element_create_layout_node(doc, unsafe {
		&dom.HTMLIFrameElement(iframe)
	}, iframe_style)
	assert iframe_node.is_navigable_container_viewport()

	canvas := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'canvas') or {
		panic('${err}')
	}
	canvas_style := style_computer.compute_style(dom.AbstractElement.new(canvas, none))
	canvas_node := html_canvas_element_create_layout_node(doc, unsafe {
		&dom.HTMLCanvasElement(canvas)
	}, canvas_style)
	assert canvas_node.is_replaced_box()
}

fn test_object_unknown_representation_runs_fallback_steps_and_keeps_inline_display() {
	mut document := html.parse_document('<!doctype html><body><object id="object" data="https://example.test/missing.html" type="text/html">fallback</object></body>')
	mut navigable := &dom.Navigable{
		active_document_: document
		is_top_level_traversable_: true
	}
	navigable.traversable_navigable_ = navigable
	document.set_cached_navigable(navigable)

	root := build_layout_tree(document) or { panic('no object fallback layout tree') }
	object_node := tree_builder_node_with_id(root, 'object') or { panic('no object layout node') }
	assert object_node.is_inline_node()
	fallback_text := object_node.first_child() or { panic('no object fallback text') }
	assert fallback_text.is_text_node()
	object_element := document.get_element_by_id('object') or { panic('no object element') }
	model := html.html_object_element_model_for_dom_element(unsafe {
		&dom.HTMLObjectElement(object_element)
	})
	assert model.representation() == .children
}

fn tree_builder_node_with_id(node &Node, id string) ?&Node {
	if dom_node := node.dom_node() {
		if element := dom_node.as_element() {
			if element.get_attribute_value('id') == id {
				return node
			}
		}
	}
	for child in node.children() {
		if found := tree_builder_node_with_id(child, id) {
			return found
		}
	}
	return none
}

fn test_before_and_after_pseudo_elements_generate_layout_content_in_tree_order() {
	document := html.parse_document('<!doctype html><style>
		#target::before { content:"before" }
		#target::after { content:"after" }
</style><div id="target" role="button">middle</div>')
	root := build_layout_tree(document) or { panic('no layout tree') }
	target := tree_builder_node_with_id(root, 'target') or { panic('no target') }
	assert target.children_are_inline()
	assert target.child_count() == 3
	assert target.children()[0].is_generated_for_before_pseudo_element()
	before_text_node := target.children()[0].first_child() or { panic('before has no text') }
	assert before_text_node.is_generated_text_node()
	assert before_text_node.dom_node() == none
	assert before_text_node.as_text_node() or {
		panic('before child is not text')
	}.text_for_rendering() == 'before'
	assert target.children()[1].as_text_node() or { panic('middle is not text') }.text_for_rendering() == 'middle'
	assert target.children()[2].is_generated_for_after_pseudo_element()
	assert (target.children()[2].first_child() or { panic('after has no text') }).as_text_node() or {
		panic('after child is not text')
	}.text_for_rendering() == 'after'
	attach_layout_nodes(root)
	target_element := document.get_element_by_id('target') or { panic('no target element') }
	assert target_element.as_node().accessible_name(document, .yes)! == 'before middleafter'
}

fn test_generated_content_retains_its_effective_counter_style_dependencies() {
	document := html.parse_document('<!doctype html><style>
		@counter-style custom { system: cyclic; symbols: "tracked"; suffix: "" }
		#target::before { content: counter(item, custom) }
	</style><div id="target"></div>')
	root := build_layout_tree(document) or { panic('no layout tree') }
	target := tree_builder_node_with_id(root, 'target') or { panic('no target') }
	generated := target.first_child() or { panic('no generated content') }
	generated_style := generated.as_node_with_style() or { panic('generated node has no style') }
	content := generated_style.computed_values().computed_content() or {
		panic('generated content was not retained')
	}
	assert content.counter_style_dependencies.len == 1
	assert (content.counter_style_dependencies[0] or {
		panic('counter style dependency did not resolve')
	}).name() == 'custom'
}

fn test_generated_inline_content_is_laid_out_inside_mixed_content_wrappers() {
	document := html.parse_document('<!doctype html><style>
		span { display:list-item }
		span::before { content:"before" }
		span::after { content:"after" }
	</style><span id="target"><div></div></span>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	target := tree_builder_node_with_id(result.root, 'target') or { panic('no target') }
	assert target.child_count() == 4
	before_wrapper := target.children()[1]
	after_wrapper := target.children()[3]
	assert before_wrapper.is_anonymous() && before_wrapper.children_are_inline()
	assert after_wrapper.is_anonymous() && after_wrapper.children_are_inline()
	before_generated := before_wrapper.first_child() or { panic('no generated before') }
	after_generated := after_wrapper.first_child() or { panic('no generated after') }
	assert before_generated.is_inline_node()
	assert before_generated.display().is_inline_outside()
	assert before_generated.display().is_flow_inside()
	assert (before_generated.first_child() or { panic('before child') }).display().is_inline_outside()
	assert (before_generated.first_child() or { panic('before text') }).as_text_node() or {
		panic('before text node')
	}.text_for_rendering() == 'before'
	assert (after_generated.first_child() or { panic('after text') }).as_text_node() or {
		panic('after text node')
	}.text_for_rendering() == 'after'
	before_used := result.used_values_for(before_wrapper.as_node_with_style() or {
		panic('before wrapper style')
	}) or { panic('before wrapper used values') }
	after_used := result.used_values_for(after_wrapper.as_node_with_style() or {
		panic('after wrapper style')
	}) or { panic('after wrapper used values') }
	mut mutable_state := unsafe { &LayoutState(result.state) }
	manual_iterator := InlineLevelIterator.new(mut mutable_state, before_wrapper.as_block_container() or {
		panic('before wrapper block')
	}, before_used, .normal, AvailableSpace.new(AvailableSize.make_definite(before_used.content_width()), AvailableSize.make_indefinite()), none)
	assert manual_iterator.items().len > 0
	assert before_used.line_boxes.len == 1
	assert after_used.line_boxes.len == 1
	assert before_used.content_height().to_double() > 0
	assert after_used.content_height().to_double() > 0
}

fn test_normal_list_marker_is_created_and_laid_out() {
	document := html.parse_document('<!doctype html><ol><li id="item">item</li></ol>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	item_node := tree_builder_node_with_id(result.root, 'item') or { panic('no list item') }
	list_item := item_node.as_list_item_box() or { panic('item is not ListItemBox') }
	marker_node := list_item.marker() or { panic('list item has no marker') }
	marker := marker_node.as_list_item_marker_box() or { panic('marker has wrong node type') }
	assert marker.text() or { '' } == '1. '
	assert marker_node.is_block_container()
	assert marker_node.children_are_inline()
	assert marker_node.child_count() == 1
	assert (marker_node.first_child() or { panic('marker has no content') }).is_generated_text_node()
	marker_used := result.used_values_for(marker_node.as_node_with_style() or {
		panic('marker has no style')
	}) or { panic('marker was not laid out') }
	assert marker_used.content_width().to_double() > 0
	assert marker_used.content_height().to_double() >= 16
	assert marker_used.line_boxes.len == 1
	assert marker_used.offset.x().to_double() < 0
}

fn test_right_to_left_list_marker_is_positioned_after_the_inline_end_edge() {
	document := html.parse_document('<!doctype html><ul dir="rtl"><li id="item">___________</li></ul>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	item_node := tree_builder_node_with_id(result.root, 'item') or { panic('no list item') }
	list_item := item_node.as_list_item_box() or { panic('item is not ListItemBox') }
	marker_node := list_item.marker() or { panic('list item has no marker') }
	item_used := result.used_values_for(item_node.as_node_with_style() or {
		panic('item has no style')
	}) or { panic('item was not laid out') }
	marker_used := result.used_values_for(marker_node.as_node_with_style() or {
		panic('marker has no style')
	}) or { panic('marker was not laid out') }
	assert item_node.computed_values().direction() == .rtl
	assert marker_used.offset.x().raw_value() >= item_used.content_width().raw_value()
	assert marker_used.cumulative_offset().x().raw_value() >= item_used.cumulative_offset().x().plus(item_used.content_width()).raw_value()
}

fn test_predefined_symbol_marker_uses_generated_text_layout() {
	document := html.parse_document('<!doctype html><ul><li id="item">item</li></ul>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	item_node := tree_builder_node_with_id(result.root, 'item') or { panic('no list item') }
	list_item := item_node.as_list_item_box() or { panic('item is not ListItemBox') }
	marker_node := list_item.marker() or { panic('list item has no marker') }
	marker := marker_node.as_list_item_marker_box() or { panic('marker has wrong node type') }
	assert marker.list_style_type_.name == 'disc'
	assert marker.text() or { '' } == '• '
	generated_text := (marker_node.first_child() or { panic('marker has no content') }).as_text_node() or {
		panic('marker content is not text')
	}
	assert generated_text.text_for_rendering() == '• '
	marker_used := result.used_values_for(marker_node.as_node_with_style() or {
		panic('marker has no style')
	}) or { panic('marker was not laid out') }
	assert marker_used.line_boxes.len == 1
	assert marker_used.line_boxes[0].fragments().len == 1
	fragment := marker_used.line_boxes[0].fragments()[0]
	assert marker_used.content_width() == fragment.width()
	assert marker_used.content_height().to_double() >= 16
}

fn test_authored_marker_content_uses_the_list_item_marker_box() {
	document := html.parse_document('<!doctype html><style>li::marker { content: "marker" }</style><ul><li id="item">item</li></ul>')
	root := build_layout_tree(document) or { panic('no layout tree') }
	item_node := document_tree_builder_node_with_id(root, 'item') or { panic('no list item') }
	marker_node := (item_node.as_list_item_box() or { panic('item is not ListItemBox') }).marker() or {
		panic('list item has no marker')
	}
	marker := marker_node.as_list_item_marker_box() or { panic('marker has wrong node type') }
	assert marker.has_authored_content()
	assert marker.text() == none
	assert marker_node.child_count() == 1
	generated_text := (marker_node.first_child() or { panic('marker has no content') }).as_text_node() or {
		panic('marker content is not text')
	}
	assert generated_text.text_for_rendering() == 'marker'
}

fn test_list_style_image_uses_a_generated_image_child() {
	image_url := "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='8'%3E%3Crect width='12' height='8' fill='green'/%3E%3C/svg%3E"
	document_url := dom.dom_url_parse('https://example.test/test.html', dom.url_about_blank(), 'UTF-8') or {
		panic('invalid document URL')
	}
	document := html.parse_document_with_url('<!doctype html><style>li { list-style-image: url("${image_url}") }</style><ul><li id="item">item</li></ul>',
		document_url)
	root := build_layout_tree(document) or { panic('no layout tree') }
	item_node := document_tree_builder_node_with_id(root, 'item') or { panic('no list item') }
	marker_node := (item_node.as_list_item_box() or { panic('item is not ListItemBox') }).marker() or {
		panic('list item has no marker')
	}
	marker := marker_node.as_list_item_marker_box() or { panic('marker has wrong node type') }
	assert marker.text() == none
	assert marker_node.child_count() == 1
	image := (marker_node.first_child() or { panic('marker has no image') }).as_image_box() or {
		panic('marker content is not an image')
	}
	assert image.source() == image_url
}

// Ladybird e479099ae2e95969a75b5429cbef2fe5759fa795.
fn test_inside_marker_precedes_block_children_and_joins_the_leading_inline_run() {
	for contents in ['<div id="block">block</div>',
		'inline first<div id="block">block</div>',
		'<div id="block">block</div>then inline'] {
		mut document := html.parse_document('<!doctype html><style>li { list-style-position: inside }</style><ul><li id="item">${contents}</li></ul>')
		defer { document.finalize() }
		root := build_layout_tree(document) or { panic('no layout tree') }
		item_node := document_tree_builder_node_with_id(root, 'item') or { panic('no list item') }
		marker := (item_node.as_list_item_box() or { panic('item is not ListItemBox') }).marker() or {
			panic('list item has no marker')
		}
		assert item_node.child_count() == if contents.ends_with('then inline') { 3 } else { 2 }
		wrapper := item_node.children()[0]
		assert wrapper.is_anonymous()
		assert wrapper.children_are_inline()
		assert voidptr(wrapper) == voidptr(marker.parent() or { panic('marker has no parent') })
		assert voidptr(marker) == voidptr(wrapper.first_child() or { panic('wrapper has no marker') })
		block := document_tree_builder_node_with_id(root, 'block') or { panic('no block child') }
		assert voidptr(item_node.children()[1]) == voidptr(block)
		assert wrapper.child_count() == if contents.starts_with('inline') { 2 } else { 1 }
	}
}

fn test_summary_inside_marker_precedes_its_nested_list_item() {
	mut document := html.parse_document('<!doctype html><details><summary id="summary"><li id="nested">hello</li></summary></details>')
	defer { document.finalize() }
	root := build_layout_tree(document) or { panic('no layout tree') }
	summary := document_tree_builder_node_with_id(root, 'summary') or { panic('no summary') }
	nested := document_tree_builder_node_with_id(root, 'nested') or { panic('no nested item') }
	marker := (summary.as_list_item_box() or { panic('summary is not a list item') }).marker() or {
		panic('summary has no marker')
	}
	assert summary.child_count() == 2
	wrapper := summary.children()[0]
	assert wrapper.is_anonymous() && wrapper.children_are_inline()
	assert voidptr(wrapper.first_child() or { panic('wrapper has no marker') }) == voidptr(marker)
	assert voidptr(summary.children()[1]) == voidptr(nested)
}

fn test_marker_preserves_literal_string_list_style_type() {
	document := html.parse_document('<!doctype html><style>li { list-style-type: "->" }</style><ul><li id="item">item</li></ul>')
	root := build_layout_tree(document) or { panic('no layout tree') }
	item_node := tree_builder_node_with_id(root, 'item') or { panic('no list item') }
	marker := (item_node.as_list_item_box() or { panic('item is not ListItemBox') }).marker() or {
		panic('list item has no marker')
	}
	marker_box := marker.as_list_item_marker_box() or { panic('marker has wrong node type') }
	assert marker_box.list_style_type_.kind == .string
	assert marker_box.text() or { '' } == '->'
}

fn test_marker_uses_resolved_custom_counter_style() {
	document := html.parse_document('<!doctype html><style>
		@counter-style custom { system: fixed; symbols: "A" "B"; prefix: "["; suffix: "]"; }
		li { list-style-type: custom }
	</style><ol><li id="item">item</li></ol>')
	root := build_layout_tree(document) or { panic('no layout tree') }
	item_node := tree_builder_node_with_id(root, 'item') or { panic('no list item') }
	marker := (item_node.as_list_item_box() or { panic('item is not ListItemBox') }).marker() or {
		panic('list item has no marker')
	}
	marker_box := marker.as_list_item_marker_box() or { panic('marker has wrong node type') }
	assert marker_box.list_style_type_.kind == .counter_style
	assert (marker_box.list_style_type_.counter_style or { panic('counter style did not resolve') }).name() == 'custom'
	item_style := item_node.as_node_with_style() or { panic('item has no computed values') }
	assert (item_style.computed_values().computed_list_style_type().counter_style or {
		panic('effective list counter style was not retained')
	}).name() == 'custom'
	assert marker_box.text() or { '' } == '[A]'
}

fn test_marker_missing_counter_style_falls_back_to_decimal() {
	document := html.parse_document('<!doctype html><style>li { list-style-type: missing }</style><ol><li id="item">item</li></ol>')
	root := build_layout_tree(document) or { panic('no layout tree') }
	item_node := tree_builder_node_with_id(root, 'item') or { panic('no list item') }
	marker := (item_node.as_list_item_box() or { panic('item is not ListItemBox') }).marker() or {
		panic('list item has no marker')
	}
	marker_box := marker.as_list_item_marker_box() or { panic('marker has wrong node type') }
	assert marker_box.list_style_type_.kind == .counter_style
	assert marker_box.list_style_type_.counter_style == none
	assert marker_box.text() or { '' } == '1. '
}

fn test_list_markers_resolve_counter_styles_in_their_shadow_tree_scope() {
	document := html.parse_document('<!doctype html><style>@counter-style scoped { system: cyclic; symbols: "DOCUMENT"; suffix: "" } li { list-style-type: scoped }</style><ol><li id="outside">outside</li></ol><div id="host"></div>')
	mut host := document.get_element_by_id('host') or { panic('missing host') }
	shadow_root := host.attach_shadow(dom.ShadowRootInit{ mode: .open }) or { panic(err) }
	mut style := document.create_element_ns('http://www.w3.org/1999/xhtml', 'style') or {
		panic(err)
	}
	mut style_node := style.as_node()
	style_node.append_child(document.create_text_node('@counter-style scoped { system: cyclic; symbols: "SHADOW"; suffix: "" } li { list-style-type: scoped }').as_node()) or {
		panic(err)
	}
	mut list := document.create_element_ns('http://www.w3.org/1999/xhtml', 'ol') or {
		panic(err)
	}
	mut item := document.create_element_ns('http://www.w3.org/1999/xhtml', 'li') or {
		panic(err)
	}
	item.set_attribute_value('id', 'inside')
	mut item_node := item.as_node()
	item_node.append_child(document.create_text_node('inside').as_node()) or { panic(err) }
	mut list_node := list.as_node()
	list_node.append_child(item.as_node()) or { panic(err) }
	mut shadow_node := unsafe { &dom.Node(shadow_root) }
	shadow_node.append_child(style.as_node()) or { panic(err) }
	shadow_node.append_child(list.as_node()) or { panic(err) }

	root := build_layout_tree(document) or { panic('no layout tree') }
	outside := tree_builder_node_with_id(root, 'outside') or { panic('missing outer list item') }
	inside := tree_builder_node_with_id(root, 'inside') or { panic('missing shadow list item') }
	outside_marker := (outside.as_list_item_box() or { panic('outer item is not a list item') }).marker() or {
		panic('outer marker missing')
	}
	inside_marker := (inside.as_list_item_box() or { panic('inner item is not a list item') }).marker() or {
		panic('inner marker missing')
	}
	assert (outside_marker.as_list_item_marker_box() or { panic('outer marker box missing') }).text() or {
		''
	} == 'DOCUMENT'
	assert (inside_marker.as_list_item_marker_box() or { panic('inner marker box missing') }).text() or {
		''
	} == 'SHADOW'
}

fn test_table_fixup_generates_wrapper_rows_and_cells() {
	document := html.parse_document('<!doctype html><style>
		#misparented { display:table-cell }
	</style><div id="misparented">cell</div><div id="table" style="display:table">text</div>')
	root := build_layout_tree(document) or { panic('no layout tree') }
	misparented := tree_builder_node_with_id(root, 'misparented') or { panic('no cell') }
	assert misparented.display().is_table_cell()
	row := misparented.parent() or { panic('cell has no row') }
	assert row.is_anonymous()
	assert row.display().is_table_row()
	anonymous_table := row.parent() or { panic('row has no table') }
	assert anonymous_table.is_anonymous()
	assert anonymous_table.display().is_table_inside()
	assert (anonymous_table.parent() or { panic('table has no wrapper') }).is_table_wrapper()
	assert anonymous_table.has_been_wrapped_in_table_wrapper()

	table := tree_builder_node_with_id(root, 'table') or { panic('no explicit table') }
	assert (table.parent() or { panic('explicit table has no wrapper') }).is_table_wrapper()
	assert table.has_been_wrapped_in_table_wrapper()
	generated_row := table.first_child() or { panic('table text has no generated row') }
	assert generated_row.is_anonymous()
	assert generated_row.display().is_table_row()
	assert !table.children_are_inline()
	assert !generated_row.children_are_inline()
	generated_cell := generated_row.first_child() or { panic('row has no generated cell') }
	assert generated_cell.is_anonymous()
	assert generated_cell.display().is_table_cell()
	assert generated_cell.children_are_inline()
	assert (generated_cell.first_child() or { panic('cell has no text') }).is_text_node()
}

fn test_table_fixup_discards_irrelevant_whitespace() {
	document := html.parse_document('<!doctype html><style>
		.cell { display: table-cell }
	</style>
	<table id="table">
		<tbody id="group"><tr><td>cell</td></tr></tbody>
	</table>
	<div id="host"><span id="one" class="cell">one</span> <span id="two" class="cell">two</span> tail</div>')
	root := build_layout_tree(document) or { panic('no layout tree') }
	table := tree_builder_node_with_id(root, 'table') or { panic('no table') }
	assert table.child_count() == 1
	group := tree_builder_node_with_id(root, 'group') or { panic('no row group') }
	assert voidptr(table.first_child() or { panic('table is empty') }) == voidptr(group)
	one := tree_builder_node_with_id(root, 'one') or { panic('no first cell') }
	two := tree_builder_node_with_id(root, 'two') or { panic('no second cell') }
	row := one.parent() or { panic('first cell has no row') }
	assert voidptr(row) == voidptr(two.parent() or { panic('second cell has no row') })
	assert row.child_count() == 2
	generated_table := row.parent() or { panic('cells have no generated table') }
	assert generated_table.display().is_table_inside()
	assert (generated_table.parent() or { panic('generated table has no wrapper') }).next_sibling() != none
}

fn test_fieldset_moves_non_legend_content_into_flow_root_wrapper() {
	document := html.parse_document('<!doctype html><style>
		#fieldset { width:200px; border:2px solid; padding:10px }
		#legend { width:50px; height:20px }
		#content { height:30px }
	</style><fieldset id="fieldset"><legend id="legend">Legend</legend><div id="content"></div></fieldset>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	fieldset_node := tree_builder_node_with_id(result.root, 'fieldset') or { panic('no fieldset') }
	assert fieldset_node.is_fieldset_box()
	assert fieldset_node.child_count() == 2
	legend_node := fieldset_node.children()[0]
	assert legend_node.is_legend_box()
	wrapper := fieldset_node.children()[1]
	assert wrapper.is_anonymous()
	assert wrapper.display().is_flow_root_inside()
	assert tree_builder_node_with_id(wrapper, 'content') != none
	fieldset_used := result.used_values_for(fieldset_node.as_node_with_style() or {
		panic('fieldset has no style')
	}) or { panic('fieldset has no used values') }
	legend_used := result.used_values_for(legend_node.as_node_with_style() or {
		panic('legend has no style')
	}) or { panic('legend has no used values') }
	assert fieldset_used.padding_top.to_double() == 10
	assert legend_used.offset.y().to_double() < 0
	assert fieldset_used.content_height().to_double() >= 48
}

fn tree_builder_before_pseudo_element(node &Node) ?&Node {
	for child in node.children() {
		if child.generated_for_pseudo_element() or { continue } == .before && !child.is_text_node() {
			return child
		}
		if found := tree_builder_before_pseudo_element(child) {
			return found
		}
	}
	return none
}

fn tree_builder_before_pseudo_for_id(result DocumentLayoutResult, id string) &Node {
	host := tree_builder_node_with_id(result.root, id) or { panic('missing #${id}') }
	return tree_builder_before_pseudo_element(host) or { panic('#${id} has no ::before box') }
}

fn test_empty_generated_strings_only_create_text_in_inline_pseudo_elements() {
	document := html.parse_document('<!doctype html><style>
		#inline::before { content:""; padding:5px }
		#quote { quotes:none }
		#quote::before { content:open-quote }
		#block::before { content:""; display:block; height:10px }
		#inline-block::before { content:""; display:inline-block; width:20px; height:20px }
		#text::before { content:"x"; display:block }
	</style><div id="inline">a</div><div id="quote">q</div><div id="block">b</div><div id="inline-block">c</div><div id="text">d</div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	// The empty text node carries an ordinary inline pseudo-element's fragment.
	inline := tree_builder_before_pseudo_for_id(result, 'inline')
	assert inline.child_count() == 1
	assert inline.children()[0].is_text_node()
	geometry := inline_box_absolute_geometry(inline, result.state) or {
		panic('empty inline pseudo-element has no retained geometry')
	}
	assert geometry.content_rect.width.to_double() == 0
	assert geometry.content_rect.height.to_double() == 0
	assert geometry.padding_rect.width.to_double() == 10
	// A quote control resolving to no text keeps its tree child but contributes
	// no fragment at the current insertion point.
	quote := tree_builder_before_pseudo_for_id(result, 'quote')
	assert quote.child_count() == 1
	quote_text := quote.children()[0].as_text_node() or { panic('quote child is not text') }
	assert !quote_text.retains_empty_generated_fragment_
	quote_geometry := inline_box_absolute_geometry(quote, result.state) or {
		panic('empty quote pseudo-element has no retained geometry')
	}
	assert quote_geometry.content_rect.x.to_double() == 8
	assert quote_geometry.content_rect.width.to_double() == 0
	assert quote_geometry.content_rect.height.to_double() == 0
	// Other pseudo-element boxes exist independently of their contents.
	for id in ['block', 'inline-block'] {
		pseudo := tree_builder_before_pseudo_for_id(result, id)
		assert pseudo.child_count() == 0
		assert !pseudo.children_are_inline()
	}
	text := tree_builder_before_pseudo_for_id(result, 'text')
	assert text.child_count() == 1
	assert text.children_are_inline()
}

fn test_fieldset_lays_out_as_flow_root_without_changing_its_computed_display() {
	document := html.parse_document('<!doctype html><style>
		fieldset { margin:0; padding:0 }
		#inline { display:inline }
	</style><fieldset id="block"><div></div></fieldset><div id="line"><fieldset id="inline"><span id="content">text</span></fieldset></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	block := tree_builder_node_with_id(result.root, 'block') or { panic('no block fieldset') }
	assert block.display().is_block_outside()
	assert block.display().is_flow_root_inside()
	inline := tree_builder_node_with_id(result.root, 'inline') or { panic('no inline fieldset') }
	assert inline.display().is_inline_block()
	inline_style := inline.as_node_with_style() or { panic('fieldset has no style') }
	computed := unsafe { &css.ComputedProperties(inline_style.computed_values()) }
	assert computed.display().is_inline_outside()
	assert computed.display().is_flow_inside()
	// The first anonymous wrapper of a childless inline-block is itself an
	// inline-block (NodeWithStyle::create_anonymous_wrapper()).
	wrapper := inline.first_child() or { panic('inline fieldset has no wrapper') }
	assert wrapper.is_anonymous()
	assert wrapper.display().is_inline_block()
	assert tree_builder_node_with_id(wrapper, 'content') != none
	// The fieldset joins its parent's line as one atomic inline instead of
	// exposing its anonymous wrapper to that inline formatting context.
	line := tree_builder_node_with_id(result.root, 'line') or { panic('no line container') }
	line_used := result.used_values_for(line.as_node_with_style() or {
		panic('line container has no style')
	}) or { panic('line container has no used values') }
	assert line_used.line_boxes.len == 1
	fragments := line_used.line_boxes[0].fragments()
	assert fragments.len == 1
	assert voidptr(fragments[0].layout_node()) == voidptr(inline)
}

fn test_root_styles_propagate_to_the_viewport() {
	document := html.parse_document('<!doctype html><style>
		html { scrollbar-width:thin; overflow:visible }
		body { writing-mode:vertical-rl; direction:rtl; overflow:scroll }
	</style><body id="body"></body>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	viewport := result.root.as_node_with_style() or { panic('viewport has no style') }
	html_node := result.root.first_child() or { panic('missing html layout node') }
	html_style := html_node.as_node_with_style() or { panic('html has no style') }
	body_node := tree_builder_node_with_id(result.root, 'body') or { panic('missing body') }
	body_style := body_node.as_node_with_style() or { panic('body has no style') }

	assert viewport.computed_values().scrollbar_width() == .thin
	assert viewport.computed_values().writing_mode() == .vertical_rl
	assert viewport.computed_values().direction() == .rtl
	assert viewport.computed_values().overflow_x() == .scroll
	assert viewport.computed_values().overflow_y() == .scroll
	assert html_style.computed_values().writing_mode() == .vertical_rl
	assert html_style.computed_values().direction() == .rtl
	assert body_style.computed_values().overflow_x() == .visible
	assert body_style.computed_values().overflow_y() == .visible

	contained_document := html.parse_document('<!doctype html><style>
		html { overflow:hidden; writing-mode:horizontal-tb; direction:ltr }
		body { contain:layout; overflow:scroll; writing-mode:vertical-rl; direction:rtl }
	</style><body></body>')
	contained_result := run_document_layout(contained_document, 800, 600) or {
		panic('contained layout failed')
	}
	contained_viewport := contained_result.root.as_node_with_style() or {
		panic('viewport has no style')
	}
	assert contained_viewport.computed_values().writing_mode() == .horizontal_tb
	assert contained_viewport.computed_values().direction() == .ltr
	assert contained_viewport.computed_values().overflow_x() == .hidden
	assert contained_viewport.computed_values().overflow_y() == .hidden
}

// An in-flow block inside an inline stays where the DOM puts it. The inline
// keeps inline children and is not split into anonymous continuation wrappers.
fn test_block_inside_inline_remains_an_interrupting_child_of_the_inline() {
	document := html.parse_document('<!doctype html><div id="outer">before<span id="inline">one<div id="block" style="height:20px">block</div>two</span>after</div>')
	root := build_layout_tree(document) or { panic('no layout tree') }
	outer := tree_builder_node_with_id(root, 'outer') or { panic('no outer') }
	assert outer.children_are_inline()
	for child in outer.children() {
		assert !child.is_anonymous()
	}
	inline_node := tree_builder_node_with_id(outer, 'inline') or { panic('no inline node') }
	inline_parent := inline_node.parent() or { panic('inline node has no parent') }
	assert layout_nodes_same(inline_parent, outer)
	assert inline_node.is_inline_node()
	assert inline_node.children_are_inline()
	assert inline_node.child_count() == 3
	block := inline_node.children()[1]
	block_dom := block.dom_node() or { panic('block has no DOM node') }
	assert (block_dom.as_element() or { panic('block DOM node is not element') }).get_attribute_value('id') == 'block'
	block_metrics := block.as_node_with_style_and_box_model_metrics() or {
		panic('block has no box metrics')
	}
	assert block_metrics.is_inline_flow_interrupting_block()
	inline_metrics := inline_node.as_node_with_style_and_box_model_metrics() or {
		panic('inline node has no box metrics')
	}
	assert inline_metrics.continuation_of_node() == none
	assert tree_builder_count_nodes_with_id(root, 'inline') == 1
}

fn tree_builder_count_nodes_with_id(node &Node, id string) int {
	mut count := 0
	if dom_node := node.dom_node() {
		if element := dom_node.as_element() {
			if element.get_attribute_value('id') == id {
				count++
			}
		}
	}
	for child in node.children() {
		count += tree_builder_count_nodes_with_id(child, id)
	}
	return count
}

fn test_svg_elements_create_their_concrete_layout_node_types_without_html_wrappers() {
	document := html.parse_document('<!doctype html><svg id="root-svg" width="200" height="100" viewBox="0 0 100 50"><g id="group"><rect id="shape" x="20" y="10" width="30" height="15"/><text id="label">hello</text></g><foreignObject id="foreign" x="5" y="6" width="40" height="20"><div id="html-child">x</div></foreignObject><defs><rect id="definition"/></defs></svg>')
	root := build_layout_tree(document) or { panic('no layout tree') }
	svg_root := tree_builder_node_with_id(root, 'root-svg') or { panic('no SVG root') }
	assert svg_root.is_svg_svg_box()
	assert svg_root.is_replaced_box_with_children()
	group := tree_builder_node_with_id(svg_root, 'group') or { panic('no SVG group') }
	assert group.is_svg_graphics_box()
	assert layout_nodes_same(group.parent() or { panic('group has no parent') }, svg_root)
	shape := tree_builder_node_with_id(group, 'shape') or { panic('no SVG shape') }
	assert shape.is_svg_geometry_box()
	assert layout_nodes_same(shape.parent() or { panic('shape has no parent') }, group)
	label := tree_builder_node_with_id(group, 'label') or { panic('no SVG text') }
	assert label.is_svg_text_box()
	foreign := tree_builder_node_with_id(svg_root, 'foreign') or { panic('no foreignObject') }
	assert foreign.is_svg_foreign_object_box()
	assert tree_builder_node_with_id(foreign, 'html-child') != none
	assert tree_builder_node_with_id(svg_root, 'definition') == none
}

fn test_block_svg_appends_foreign_object_and_text_without_html_wrappers() {
	document := html.parse_document('<!doctype html><svg id="root-svg" style="display:block">\n<foreignObject id="foreign" style="display:block"></foreignObject></svg>')
	root := build_layout_tree(document) or { panic('no layout tree') }
	svg_root := tree_builder_node_with_id(root, 'root-svg') or { panic('no SVG root') }
	assert svg_root.is_svg_svg_box()
	assert svg_root.child_count() == 2
	assert (svg_root.first_child() or { panic('no leading SVG text') }).is_text_node()
	foreign := tree_builder_node_with_id(svg_root, 'foreign') or { panic('no foreignObject') }
	assert layout_nodes_same(foreign.parent() or { panic('foreignObject has no parent') }, svg_root)
	assert !svg_root.children_are_inline()
}

fn test_inline_svg_keeps_inline_children_flag_around_block_foreign_object() {
	document := html.parse_document('<!doctype html><svg id="root-svg">\n<foreignObject id="foreign" style="display:block"></foreignObject></svg>')
	root := build_layout_tree(document) or { panic('no layout tree') }
	svg_root := tree_builder_node_with_id(root, 'root-svg') or { panic('no SVG root') }
	foreign := tree_builder_node_with_id(svg_root, 'foreign') or { panic('no foreignObject') }
	assert layout_nodes_same(foreign.parent() or { panic('foreignObject has no parent') }, svg_root)
	assert svg_root.children_are_inline()
}

fn test_svg_switch_creates_a_graphics_box_for_only_its_first_svg_child() {
	document := html.parse_document('<!doctype html><svg><switch id="chooser">ignored text<rect id="selected" width="10" height="10"/><circle id="bypassed" r="5"/></switch></svg>')
	root := build_layout_tree(document) or { panic('no layout tree') }
	chooser := tree_builder_node_with_id(root, 'chooser') or { panic('no switch box') }
	assert chooser.is_svg_graphics_box()
	assert chooser.child_count() == 1
	assert tree_builder_node_with_id(chooser, 'selected') != none
	assert tree_builder_node_with_id(chooser, 'bypassed') == none
	bypassed := document.get_element_by_id('bypassed') or { panic('no bypassed DOM element') }
	assert bypassed.as_node().unsafe_layout_node() == none
}

fn test_document_layout_caches_only_paintable_boxes_with_auto_content_visibility() {
	document := html.parse_document('<!doctype html><style>#near, #far { content-visibility: auto } #gone { content-visibility: auto; display: none }</style><div id="near"></div><div id="ordinary"></div><div id="far"></div><div id="gone"></div>')
	_ = run_document_layout(document, 800, 600) or { panic('layout failed') }
	viewport_paintable := document.paintable() or { panic('no viewport paintable') }
	paintable_boxes := viewport_paintable.paintable_boxes_with_auto_content_visibility()
	assert paintable_boxes.len == 2
	assert (paintable_boxes[0].dom_node_.as_element() or { panic('first box has no element') }).id() or {
		''
	} == 'near'
	assert (paintable_boxes[1].dom_node_.as_element() or { panic('second box has no element') }).id() or {
		''
	} == 'far'

	// The getter is a readonly-span equivalent: mutating the returned slice must
	// not alter the cache owned by the viewport paintable.
	mut returned_boxes := paintable_boxes.clone()
	returned_boxes.clear()
	assert viewport_paintable.paintable_boxes_with_auto_content_visibility().len == 2
}

fn test_content_visibility_hidden_clears_stale_descendant_layout_and_paint_nodes() {
	document := html.parse_document('<!doctype html><div id="hidden"><span id="child">text</span></div><div id="shadow-host"></div>')
	mut shadow_host := document.get_element_by_id('shadow-host') or { panic('missing shadow host') }
	shadow_host.attach_a_shadow_root(.open, false, false, false, .named) or { panic(err) }
	mut shadow_root := unsafe { &dom.Node(shadow_host.shadow_root() or { panic('missing shadow root') }) }
	mut shadow_child := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic(err)
	}
	shadow_root.append_child(shadow_child.as_node()) or { panic(err) }
	_ = run_document_layout(document, 800, 600) or { panic('initial layout failed') }
	mut hidden := document.get_element_by_id('hidden') or { panic('missing hidden element') }
	child := document.get_element_by_id('child') or { panic('missing child element') }
	text := child.as_node().first_child() or { panic('missing text node') }
	assert hidden.as_node().layout_node() != none
	assert child.as_node().layout_node() != none
	assert child.as_node().paintable() != none
	assert text.layout_node() != none
	assert shadow_child.as_node().layout_node() != none

	hidden.set_attribute_value('style', 'content-visibility: hidden')
	shadow_host.set_attribute_value('style', 'content-visibility: hidden')
	_ = run_document_layout(document, 800, 600) or { panic('updated layout failed') }

	assert hidden.as_node().layout_node() != none
	assert child.as_node().layout_node() == none
	assert child.as_node().paintable() == none
	assert text.layout_node() == none
	assert text.paintable() == none
	assert shadow_child.as_node().layout_node() == none
	assert shadow_child.as_node().paintable() == none
}

fn test_display_none_clears_stale_shadow_descendant_layout_and_paint_nodes() {
	document := html.parse_document('<!doctype html><div id="host"></div>')
	mut host := document.get_element_by_id('host') or { panic('missing shadow host') }
	host.attach_a_shadow_root(.open, false, false, false, .named) or { panic(err) }
	mut shadow_root := unsafe { &dom.Node(host.shadow_root() or { panic('missing shadow root') }) }
	mut shadow_child := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic(err)
	}
	shadow_text := document.create_text_node('text')
	mut shadow_child_node := shadow_child.as_node()
	shadow_child_node.append_child(shadow_text.as_node()) or { panic(err) }
	shadow_root.append_child(shadow_child.as_node()) or { panic(err) }

	_ = run_document_layout(document, 800, 600) or { panic('initial layout failed') }
	assert host.as_node().layout_node() != none
	assert shadow_child.as_node().layout_node() != none
	assert shadow_child.as_node().paintable() != none
	assert shadow_text.as_node().layout_node() != none

	host.set_attribute_value('style', 'display: none')
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_needs_full_layout_tree_update(true)
	_ = run_document_layout(document, 800, 600) or { panic('updated layout failed') }

	assert host.as_node().layout_node() == none
	assert host.as_node().paintable() == none
	assert shadow_child.as_node().layout_node() == none
	assert shadow_child.as_node().paintable() == none
	assert shadow_text.as_node().layout_node() == none
	assert shadow_text.as_node().paintable() == none
}

fn test_content_visibility_hidden_slot_clears_stale_assigned_layout_and_paint_nodes() {
	document := html.parse_document('<!doctype html><div id="host"><div id="assigned"><span id="nested">text</span></div></div>')
	mut host := document.get_element_by_id('host') or { panic('missing shadow host') }
	host.attach_a_shadow_root(.open, false, false, false, .named) or { panic(err) }
	mut shadow_root := unsafe { &dom.Node(host.shadow_root() or { panic('missing shadow root') }) }
	mut slot_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'slot') or {
		panic(err)
	}
	shadow_root.append_child(slot_element.as_node()) or { panic(err) }
	slot := unsafe { &dom.HTMLSlotElement(slot_element) }
	assert slot.assigned_nodes_internal().len == 1

	_ = run_document_layout(document, 800, 600) or { panic('initial layout failed') }
	assigned := document.get_element_by_id('assigned') or { panic('missing assigned element') }
	nested := document.get_element_by_id('nested') or { panic('missing nested element') }
	text := nested.as_node().first_child() or { panic('missing text node') }
	assert assigned.as_node().layout_node() != none
	assert assigned.as_node().paintable() != none
	assert nested.as_node().layout_node() != none
	assert nested.as_node().paintable() != none
	assert text.layout_node() != none

	slot_element.set_attribute_value('style', 'content-visibility: hidden')
	_ = run_document_layout(document, 800, 600) or { panic('updated layout failed') }

	assert assigned.as_node().layout_node() == none
	assert assigned.as_node().paintable() == none
	assert nested.as_node().layout_node() == none
	assert nested.as_node().paintable() == none
	assert text.layout_node() == none
	assert text.paintable() == none
}

// Upstream insertion_parent_for_block_node(): generated pseudo-element boxes
// are anonymous, so block-level ones climb out of InlineNode ancestors. An
// abspos ::after is appended to the nearest block ancestor after the inline;
// a block ::before is prepended to it.
fn test_block_level_pseudo_elements_climb_out_of_inline_ancestors() {
	document := html.parse_document('<!doctype html><style>
		#inline::after { content:"X"; position:absolute }
		#inline::before { content:"B"; display:block }
	</style><div id="outer">first<span id="inline">text</span>last</div>')
	root := build_layout_tree(document) or { panic('no layout tree') }
	outer := tree_builder_node_with_id(root, 'outer') or { panic('no outer') }
	inline_node := tree_builder_node_with_id(root, 'inline') or { panic('no inline') }
	for child in inline_node.children() {
		assert !child.is_generated_for_after_pseudo_element()
		assert !child.is_generated_for_before_pseudo_element()
	}
	// The block ::before wraps the existing inline siblings; the abspos ::after
	// and the trailing text then join that trailing anonymous wrapper.
	assert !outer.children_are_inline()
	children := outer.children()
	assert children.len == 2
	assert children[0].is_generated_for_before_pseudo_element()
	assert children[1].is_anonymous() && children[1].children_are_inline()
	mut after_parent_found := false
	for child in children[1].children() {
		if child.is_generated_for_after_pseudo_element() {
			after_parent_found = true
			assert child.is_absolutely_positioned()
		}
	}
	assert after_parent_found
}

// Table-internal pseudo-element boxes stay in their inline so table fixup can
// group them with the inline's table-internal siblings.
fn test_table_internal_pseudo_element_stays_in_its_inline() {
	document := html.parse_document('<!doctype html><style>
		#inline::after { content:"X"; display:table-cell }
	</style><div id="outer"><span id="inline">text</span></div>')
	root := build_layout_tree(document) or { panic('no layout tree') }
	outer := tree_builder_node_with_id(root, 'outer') or { panic('no outer') }
	assert outer.children_are_inline()
	inline_node := tree_builder_node_with_id(root, 'inline') or { panic('no inline') }
	assert inline_node.child_count() >= 2
}

// Upstream content-image-set: image-set() is an <image> in <content-list>. The
// selected candidate's resolution scales the generated image's natural size.
fn test_generated_content_image_set_uses_candidate_resolution() {
	document := html.parse_document('<!doctype html><style>
		#set::before { content:image-set(url(${content_replacement_green_image}) 2x) }
		#plain::before { content:url(${content_replacement_green_image}) }
	</style><div id="set"></div><div id="plain"></div>')
	root := build_layout_tree(document) or { panic('no layout tree') }
	set_host := document_tree_builder_node_with_id(root, 'set') or { panic('missing set') }
	plain_host := document_tree_builder_node_with_id(root, 'plain') or { panic('missing plain') }
	set_image := (set_host.first_child() or { panic('missing set pseudo') }).as_image_box() or {
		panic('image-set pseudo is not an image box')
	}
	plain_image := (plain_host.first_child() or { panic('missing plain pseudo') }).as_image_box() or {
		panic('url pseudo is not an image box')
	}
	assert set_image.source() == content_replacement_green_image
	plain_width := plain_image.natural_size_.width or { panic('missing plain width') }
	set_width := set_image.natural_size_.width or { panic('missing image-set width') }
	set_height := set_image.natural_size_.height or { panic('missing image-set height') }
	assert plain_width.to_double() == 4
	assert set_width.to_double() == 2
	assert set_height.to_double() == 2
}

fn test_svg_animation_elements_do_not_generate_layout_boxes() {
	document := html.parse_document('<!doctype html><svg><set id="set">ignored</set><animate id="animate">ignored</animate></svg>')
	root := build_layout_tree(document) or { panic('no SVG layout tree') }
	assert tree_builder_node_with_id(root, 'set') == none
	assert tree_builder_node_with_id(root, 'animate') == none
}

fn test_display_contents_text_keeps_an_anonymous_style_wrapper() {
	document := html.parse_document('<!doctype html><div id="host"><span style="display:contents">text</span></div>')
	root := build_layout_tree(document) or { panic('no layout tree') }
	host := tree_builder_node_with_id(root, 'host') or { panic('no host layout node') }
	assert host.child_count() == 1
	wrapper := host.first_child() or { panic('no display:contents text wrapper') }
	assert wrapper.is_inline_node()
	assert wrapper.is_anonymous()
	text := wrapper.first_child() or { panic('no wrapped text') }
	assert text.is_text_node()
}

fn test_foreign_object_requires_a_nested_svg_rendering_context() {
	document := html.parse_document('<!doctype html><svg id="root"><foreignObject id="foreign"></foreignObject></svg>')
	foreign := document.get_element_by_id('foreign') or { panic('no foreignObject') }
	mut orphan_group := document.create_element_ns('http://www.w3.org/2000/svg', 'g') or {
		panic(err)
	}
	orphan_group.set_attribute_value('id', 'orphan')
	mut nested_svg := document.create_element_ns('http://www.w3.org/2000/svg', 'svg') or {
		panic(err)
	}
	nested_svg.set_attribute_value('id', 'nested')
	mut nested_rect := document.create_element_ns('http://www.w3.org/2000/svg', 'rect') or {
		panic(err)
	}
	nested_rect.set_attribute_value('id', 'nested-rect')
	mut nested_node := nested_svg.as_node()
	nested_node.append_child(nested_rect.as_node()) or { panic(err) }
	mut foreign_node := foreign.as_node()
	foreign_node.append_child(orphan_group.as_node()) or { panic(err) }
	foreign_node.append_child(nested_svg.as_node()) or { panic(err) }

	root := build_layout_tree(document) or { panic('no layout tree') }
	assert tree_builder_node_with_id(root, 'orphan') == none
	assert tree_builder_node_with_id(root, 'nested') != none
	assert tree_builder_node_with_id(root, 'nested-rect') != none
}
