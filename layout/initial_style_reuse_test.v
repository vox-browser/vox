module layout

import css
import dom
import html

fn initial_style_reuse_document(markup string) &dom.Document {
	address := dom.URL{value: 'https://initial-style.test/'}
	mut document := html.parse_navigation_document(markup, address, address.origin(), none) or {
		panic(err)
	}
	document.set_scripting_enabled_by_embedder(false)
	document.set_viewport_rect(dom.Rect{width: 320, height: 200})
	return document
}

fn initial_style_reuse_preflight(mut document dom.Document) {
	css.sync_document_style_elements(document)
	root := document.document_element() or { panic('missing root') }
	_ = css.up_to_date_computed_properties_for_element(root)
	assert !document.needs_full_style_update()
	assert document.style_invalidation_counters().element_style_recomputations > 0
	document.reset_style_invalidation_counters()
}

fn test_first_layout_reuses_clean_preflight_style_without_another_cascade() {
	mut document := initial_style_reuse_document('<!doctype html><style>html,body { margin:0 } #target { width:25vw; height:20px }</style><div id="target"></div>')
	defer { document.finalize() }
	initial_style_reuse_preflight(mut document)
	target := document.get_element_by_id('target') or { panic('missing target') }
	style := css.computed_properties_for_element(target) or { panic('missing preflight style') }
	_ = run_document_layout(document, 320, 200) or { panic('missing layout') }
	assert document.style_invalidation_counters().element_style_recomputations == 0
	retained := css.computed_properties_for_element(target) or { panic('missing retained style') }
	assert voidptr(retained) == voidptr(style)
	assert target.get_bounding_client_rect().width == 80
}

fn test_first_layout_computes_style_without_a_preflight() {
	mut document := initial_style_reuse_document('<!doctype html><div id="target" style="width:25vw;height:20px"></div>')
	defer { document.finalize() }
	_ = run_document_layout(document, 320, 200) or { panic('missing layout') }
	assert document.style_invalidation_counters().element_style_recomputations > 0
	target := document.get_element_by_id('target') or { panic('missing target') }
	assert target.get_bounding_client_rect().width == 80
}

fn test_first_layout_recascades_for_a_viewport_changed_after_preflight() {
	for install_rect_first in [false, true] {
		mut document := initial_style_reuse_document('<!doctype html><style>#target { width:25vw; height:20px } @media (min-width:400px) { #target { width:30vw } }</style><div id="target"></div>')
		initial_style_reuse_preflight(mut document)
		if install_rect_first {
			// A matching document rect does not mean its retained style was
			// computed at this size.
			document.set_viewport_rect(dom.Rect{width: 500, height: 200})
		}
		_ = run_document_layout(document, 500, 200) or { panic('missing resized layout') }
		assert document.style_invalidation_counters().element_style_recomputations > 0, 'viewport rect installed: ${install_rect_first}'
		target := document.get_element_by_id('target') or { panic('missing target') }
		assert target.get_bounding_client_rect().width == 150
		document.finalize()
	}
}

fn test_first_layout_preserves_pending_style_dom_and_sheet_invalidations() {
	for mutation in ['inline', 'sheet', 'insert', 'full'] {
		mut document := initial_style_reuse_document('<!doctype html><style>#target,.new { width:20px; height:10px }</style><div id="target"></div>')
		initial_style_reuse_preflight(mut document)
		mut target := document.get_element_by_id('target') or { panic('missing target') }
		mut expected_width := f64(20)
		match mutation {
			'inline' {
				target.set_attribute_value('style', 'width:90px')
				expected_width = 90
			}
			'sheet' {
				owner := css.query_selector(document.as_node(), 'style') or { panic('missing sheet owner') }
				mut sheet := css.style_sheet_for_owner_node(document, owner) or { panic('missing live sheet') }
				sheet.insert_rule('#target { width:70px }', 1) or { panic(err) }
				expected_width = 70
			}
			'insert' {
				mut child := document.create_element('div') or { panic(err) }
				child.set_attribute_value('class', 'new')
				mut target_node := target.as_node()
				target_node.append_child(child.as_node()) or { panic(err) }
			}
			else { document.set_needs_full_style_update(true) }
		}
		_ = run_document_layout(document, 320, 200) or { panic('missing updated layout') }
		assert document.style_invalidation_counters().element_style_recomputations > 0, mutation
		assert target.get_bounding_client_rect().width == expected_width
		if mutation == 'insert' {
			child := target.as_node().first_child() or { panic('missing inserted child') }
			child_element := child.as_element() or { panic('inserted child is not an element') }
			assert css.computed_properties_for_element(child_element) != none
			assert child_element.get_bounding_client_rect().width == 20
		}
		document.finalize()
	}
}

fn test_first_layout_styles_ua_and_svg_subtrees_created_after_preflight() {
	mut document := initial_style_reuse_document('<!doctype html><svg width="50" height="40"><defs><rect id="source" width="25" height="20"/></defs><use id="copy" href="#source"/></svg><video id="media" controls></video>')
	defer { document.finalize() }
	initial_style_reuse_preflight(mut document)
	media := document.get_element_by_id('media') or { panic('missing media') }
	assert media.shadow_root() == none
	_ = run_document_layout(document, 320, 200) or { panic('missing shadow layout') }
	shadow := media.shadow_root() or { panic('missing media shadow') }
	container := css.query_selector(shadow.as_node(), '.container') or { panic('missing controls') }
	assert css.computed_properties_for_element(container) != none
	assert container.as_node().unsafe_layout_node() != none
	copy := document.get_element_by_id('copy') or { panic('missing SVG use') }
	destination := if use_shadow := copy.shadow_root() { use_shadow.as_node() } else { copy.as_node() }
	clone := css.query_selector(destination, 'rect') or { panic('missing SVG clone') }
	assert css.computed_properties_for_element(clone) != none
	assert clone.as_node().unsafe_layout_node() != none
}
