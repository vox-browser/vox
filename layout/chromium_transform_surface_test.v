module layout

import html
import css
import dom

fn test_chromium_3d_transform_retains_full_opacity_surface() {
	for chromium in [false, true] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}#outer{transform:translate3d(0,0,0);width:100px;height:40px;box-shadow:0 4px 20px #0002;background:rgb(1 2 3)}#inner{width:100%;height:100%;box-shadow:0 0 1px #0002;background:rgb(4 5 6)}</style><div id="outer"><div id="inner"></div></div>')
		defer { document.finalize() }
		if chromium { document.set_font_rendering_policy(.chromium) }
		_ = layout_document_typed_in_viewport(document, 300, 200)
		commands := display_list_commands(document.record_display_list() or { panic('missing paint') })
		groups := commands.filter(it.kind == 'begin_css_effect_layer')
		assert groups.len == if chromium { 1 } else { 0 }
		if !chromium { continue }
		assert groups[0].visual_layer().opacity == 1.0
		mut depth := 0
		mut painted := 0
		for command in commands {
			if command.kind == 'begin_css_effect_layer' { depth++ }
			if command.color in ['rgb(1 2 3)', 'rgb(4 5 6)'] {
				assert depth == 1
				painted++
			}
			if command.kind == 'end_css_effect_layer' { depth-- }
		}
		assert painted == 2 && depth == 0
	}
}

fn test_chromium_surface_distinguishes_3d_operations_from_2d_and_perspective() {
	for transform, expected in {
		'none':                                      false
		'translate(0,0)':                            false
		'rotateZ(0deg)':                             false
		'perspective(100px)':                        false
		'translateZ(0)':                             true
		'scale3d(1,1,1)':                            true
		'rotateX(0deg)':                             true
		'rotate3d(0,0,1,0deg)':                      true
		'matrix3d(1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1)': true
	} {
		mut document := html.parse_document('<!doctype html><div style="width:20px;height:20px;background:red;transform:${transform}"></div>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		_ = layout_document_typed_in_viewport(document, 100, 100)
		commands := display_list_commands(document.record_display_list() or { panic('missing paint') })
		assert commands.any(it.kind == 'begin_css_effect_layer') == expected, transform
	}
}

fn test_chromium_3d_surface_coalesces_with_existing_opacity() {
	mut document := html.parse_document('<!doctype html><div style="width:20px;height:20px;background:red;transform:translateZ(0);opacity:.5"></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 100, 100)
	commands := display_list_commands(document.record_display_list() or { panic('missing paint') })
	groups := commands.filter(it.kind == 'begin_css_effect_layer')
	assert groups.len == 1
	assert groups[0].visual_layer().opacity == .5
}

fn test_chromium_transform_hints_retain_surface_without_a_transform() {
	for chromium in [false, true] {
		for hint in ['transform', 'translate', 'rotate', 'scale', 'perspective', 'transform-style',
			'opacity', 'auto', 'contents', 'scroll-position', 'width', 'z-index'] {
			mut document := html.parse_document('<!doctype html><div style="will-change:${hint};width:40px;height:40px;background:rgb(1 2 3)"><div style="width:20px;height:20px;background:rgb(4 5 6)"></div></div>')
			defer { document.finalize() }
			if chromium { document.set_font_rendering_policy(.chromium) }
			_ = layout_document_typed_in_viewport(document, 100, 100)
			commands := display_list_commands(document.record_display_list() or { panic('missing paint') })
			groups := commands.filter(it.kind == 'begin_css_effect_layer')
			expected := chromium && hint in ['transform', 'translate', 'rotate', 'scale', 'perspective',
				'transform-style', 'opacity']
			assert groups.len == if expected { 1 } else { 0 }, hint
			if !expected { continue }
			assert groups[0].visual_layer().opacity == 1
			mut depth := 0
			mut painted := 0
			for command in commands {
				if command.kind == 'begin_css_effect_layer' { depth++ }
				if command.color in ['rgb(1 2 3)', 'rgb(4 5 6)'] {
					assert depth == 1
					painted++
				}
				if command.kind == 'end_css_effect_layer' { depth-- }
			}
			assert painted == 2 && depth == 0
		}
	}
}

fn test_chromium_contents_hint_suppresses_transform_hints_but_keeps_3d_surface() {
	for display in ['block', 'contents'] {
		for transform in ['none', 'translateZ(0)'] {
			mut document := html.parse_document('<!doctype html><div style="display:${display};will-change:contents"><div style="width:20px;height:20px;background:red;will-change:transform;transform:${transform}"></div></div>')
			defer { document.finalize() }
			document.set_font_rendering_policy(.chromium)
			_ = layout_document_typed_in_viewport(document, 100, 100)
			commands := display_list_commands(document.record_display_list() or { panic('missing paint') })
			assert commands.filter(it.kind == 'begin_css_effect_layer').len == if transform == 'none' {
				0
			} else {
				1
			}
		}
	}
}

fn test_chromium_contents_hint_follows_slot_ancestry() {
	for hint in ['auto', 'contents'] {
		mut document := html.parse_document('<!doctype html><div id="host"><div style="will-change:transform;width:20px;height:20px;background:red"></div></div>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		mut host := document.get_element_by_id('host') or { panic('missing host') }
		shadow := host.attach_shadow(dom.ShadowRootInit{ mode: .open }) or { panic(err) }
		mut slot := document.create_element_ns(dom.namespace_html_uri, 'slot') or { panic(err) }
		slot.set_attribute_value('style', 'display:contents;will-change:${hint}')
		mut shadow_node := shadow.as_node()
		shadow_node.append_child(slot.as_node()) or { panic(err) }
		_ = layout_document_typed_in_viewport(document, 100, 100)
		commands := display_list_commands(document.record_display_list() or { panic('missing paint') })
		assert commands.filter(it.kind == 'begin_css_effect_layer').len == if hint == 'contents' {
			0
		} else {
			1
		}
	}
}

fn test_chromium_transform_hint_does_not_composite_non_transformable_inline() {
	mut document := html.parse_document('<!doctype html><span style="will-change:transform;background:red">text</span>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 100, 100)
	commands := display_list_commands(document.record_display_list() or { panic('missing paint') })
	assert !commands.any(it.kind == 'begin_css_effect_layer')
}

fn test_chromium_transform_hint_coalesces_with_opacity_surface() {
	mut document := html.parse_document('<!doctype html><div style="will-change:transform;opacity:.5;width:20px;height:20px;background:red"></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 100, 100)
	commands := display_list_commands(document.record_display_list() or { panic('missing paint') })
	groups := commands.filter(it.kind == 'begin_css_effect_layer')
	assert groups.len == 1
	assert groups[0].visual_layer().opacity == .5
}

fn test_chromium_surface_changes_when_animated_transform_has_the_same_matrix() {
	for opacity in ['1', '.5'] {
		mut document := html.parse_document('<!doctype html><div id="target" style="width:20px;height:20px;background:red;transform:translateX(0);opacity:${opacity}"></div>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		_ = layout_document_typed_in_viewport(document, 100, 100)
		mut result := document_layout_result(document) or { panic('missing layout') }
		target := document.get_element_by_id('target') or { panic('missing target') }
		placeholder := target.as_node().layout_node() or { panic('missing layout node') }
		computed := css.computed_properties_for_element(target) or { panic('missing style') }
		mut mutable_computed := unsafe { &css.ComputedProperties(computed) }
		_ = record_retained_display_list(mut document) or { panic('missing initial paint') }
		for transform in ['translateZ(0)', 'translateX(0)'] {
			old_children := result.paint_tree.children.data
			mutable_computed.set_animated_property(.transform, &dom.StyleValue{ css_text: transform }, .no, .no)
			placeholder.apply_animated_style(voidptr(computed), true)
			document.set_needs_repaint_with_invalidation(.paint_commands_and_hit_test_list)
			document.set_needs_accumulated_visual_contexts_update(true)
			local := record_retained_display_list(mut document) or { panic('missing updated paint') }
			assert result.paint_tree.children.data != old_children
			commands := display_list_commands(local)
			assert commands.filter(it.kind == 'begin_css_effect_layer').len == if transform == 'translateZ(0)' || opacity == '.5' {
				1
			} else {
				0
			}
			local_dump := local.dump()
			refresh_document_paint_tree(document, mut result, 100, 100)
			assert (record_retained_display_list(mut document) or { panic('missing full paint') }).dump() == local_dump
		}
	}
}
