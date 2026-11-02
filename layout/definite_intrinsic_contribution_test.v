module layout

import css
import dom

fn definite_contribution_test_box(document &dom.Document, extra string) &BlockContainer {
	mut element := document.create_element('div') or { panic(err) }
	element.set_attribute_value('style', 'display:block;font:16px/20px monospace;${extra}')
	style := css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none))
	mut box := BlockContainer.new(document, none, style)
	box.set_children_are_inline(true)
	text := 'several words with a considerablylongerword'
	box.append_child(unsafe { &Node(TextNode.new(document, document.create_text_node(text).as_node(), text)) })
	assign_layout_indexes(unsafe { &Node(box) })
	return box
}

fn test_definite_preferred_width_excludes_overflow_and_preserves_outer_edges() {
	for chromium in [false, true] {
		for sizing in ['content-box', 'border-box'] {
			mut document := dom.Document.create(dom.url_about_blank())
			defer { document.finalize() }
			if chromium { document.set_font_rendering_policy(.chromium) }
			box := definite_contribution_test_box(document, 'width:90px;box-sizing:${sizing};padding:0 7px 0 11px;border-left:2px solid;border-right:4px solid;margin:0 3px 0 5px')
			mut state := LayoutState.new()
			for constraint in [SizeConstraint.min_content, .max_content] {
				actual := intrinsic_outer_width_contribution(mut state, unsafe { &Box(box) }, constraint)
				assert actual.to_double() == if sizing == 'content-box' { f64(122) } else { f64(98) }
			}
		}
	}
}

fn test_definite_intrinsic_preference_keeps_minimum_precedence_and_zero_content_floor() {
	for pair in [ ['width:90px;min-width:120px;max-width:100px', '120'],
		['width:calc(130px - 20px);max-width:95px', '95'],
		['width:5px;box-sizing:border-box;padding:0 10px', '20'] ] {
		mut document := dom.Document.create(dom.url_about_blank())
		defer { document.finalize() }
		box := definite_contribution_test_box(document, pair[0])
		mut state := LayoutState.new()
		for constraint in [SizeConstraint.min_content, .max_content] {
			assert intrinsic_outer_width_contribution(mut state, unsafe { &Box(box) }, constraint).to_double() == pair[1].f64()
		}
	}
}

fn test_cyclic_percentage_preference_still_measures_content_with_definite_ancestor_basis() {
	for preferred in ['50%', 'calc(50% + 10px)'] {
		mut document := dom.Document.create(dom.url_about_blank())
		defer { document.finalize() }
		box := definite_contribution_test_box(document, 'width:${preferred}')
		mut state := LayoutState.new()
		values := state.get_mutable(unsafe { &NodeWithStyle(box) })
		minimum := calculate_min_content_width(mut state, unsafe { &Box(box) })
		maximum := calculate_max_content_width(mut state, unsafe { &Box(box) })
		assert maximum.raw_value() > minimum.raw_value()
		for constraint in [SizeConstraint.min_content, .max_content] {
			actual := intrinsic_outer_width_contribution_with_resolved_box_model(mut state, unsafe { &Box(box) }, constraint, values, CSSPixels.new(400))
			assert actual == if constraint == .min_content { minimum } else { maximum }
		}
	}
}

fn test_definite_preference_still_measures_intrinsic_minimum_and_maximum() {
	for limit in ['min-width:min-content', 'max-width:min-content', 'min-width:max-content', 'max-width:max-content'] {
		mut document := dom.Document.create(dom.url_about_blank())
		defer { document.finalize() }
		box := definite_contribution_test_box(document, 'width:90px;${limit}')
		mut state := LayoutState.new()
		measured := if limit.contains('max-content') { calculate_max_content_width(mut state, unsafe { &Box(box) }) } else { calculate_min_content_width(mut state, unsafe { &Box(box) }) }
		expected := if limit.starts_with('min-') { css_pixels_max(CSSPixels.new(90), measured) } else { css_pixels_min(CSSPixels.new(90), measured) }
		for constraint in [SizeConstraint.min_content, .max_content] {
			assert intrinsic_outer_width_contribution(mut state, unsafe { &Box(box) }, constraint) == expected
		}
	}
}
