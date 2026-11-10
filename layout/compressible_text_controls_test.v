// Copyright (c) 2026-present, the Ladybird developers.
//
// SPDX-License-Identifier: BSD-2-Clause

module layout

import css
import dom
import html

fn compressible_control_values(result &DocumentLayoutResult, id string) &UsedValues {
	mut pending := [result.root]
	for pending.len > 0 {
		node := pending.pop()
		if dom_node := node.dom_node() {
			if element := dom_node.as_element() {
				if element.get_attribute_value('id') == id {
					styled := node.as_node_with_style() or { panic('missing style') }
					return result.used_values_for(styled) or { panic('missing geometry') }
				}
			}
		}
		for child in node.children() { pending << child }
	}
	panic('missing #${id}')
}

// Ladybird 62ab268cecb33eac1c76edc726370d92ba957f5f: width percentages
// compress text controls, while a max-width percentage alone does not.
fn test_text_control_percentage_width_allows_its_flex_item_to_shrink() {
	for policy in [dom.FontRenderingPolicy.libweb, .chromium] {
		for tag in ['input', 'textarea'] {
			mut document := html.parse_document('<!doctype html><style>
				body { margin:0 }
				.row { display:flex; width:40px }
				input, textarea { display:block; padding:0; border:0; font:16px monospace }
				.percentage { width:100% }
				.maximum { max-width:100% }
			</style>
			<div class="row"><div id="percentage"><${tag} class="percentage"></${tag}></div></div>
			<div class="row"><div id="maximum"><${tag} class="maximum"></${tag}></div></div>')
			defer { document.finalize() }
			document.set_font_rendering_policy(policy)
			result := run_document_layout(document, 800, 600) or { panic('layout failed') }
			assert compressible_control_values(&result, 'percentage').content_width().to_double() == 40
			assert compressible_control_values(&result, 'maximum').content_width().to_double() > 40
		}
	}
}

fn test_cyclic_replaced_and_text_control_width_resolves_percentage_against_zero() {
	for tag in ['input', 'textarea', 'img'] {
		for case in [
			['100%', 'content-box', '0'],
			['calc(100% + 12px)', 'content-box', '12'],
			['calc(100% - 12px)', 'content-box', '0'],
			['calc(100% + 12px)', 'border-box', '0'],
		] {
			mut document := dom.Document.create(dom.url_about_blank())
			defer { document.finalize() }
			mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', tag)!
			edges := if case[1] == 'border-box' { 'padding:4px;border:2px solid' } else { 'padding:0;border:0' }
			element.set_attribute_value('style', 'width:${case[0]};box-sizing:${case[1]};margin:0;${edges}')
			style := css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none))
			box := if tag == 'input' {
				unsafe { &Box(TextInputBox.new(document, element, style)) }
			} else if tag == 'textarea' {
				unsafe { &Box(TextAreaBox.new(document, element, style)) }
			} else {
				unsafe { &Box(ImageBox.new(document, element, style)) }
			}
			mut state := LayoutState.new()
			mut used := state.get_mutable(unsafe { &NodeWithStyle(box) })
			resolve_box_model_edges(style, mut used, 0)
			assert calculate_min_content_width(mut state, box).to_double() == case[2].f64()
			assert intrinsic_outer_width_contribution(mut state, box, .min_content).to_double() == case[2].f64() + if case[1] == 'border-box' { f64(12) } else { f64(0) }
			assert !should_treat_width_as_auto(state, box, AvailableSpace.new(AvailableSize.make_min_content(), AvailableSize.make_indefinite()))
			assert should_treat_width_as_auto(state, box, AvailableSpace.new(AvailableSize.make_max_content(), AvailableSize.make_indefinite()))
		}
	}
}

fn test_text_control_max_width_keeps_its_intrinsic_minimum() {
	for tag in ['input', 'textarea'] {
		mut document := dom.Document.create(dom.url_about_blank())
		defer { document.finalize() }
		mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', tag)!
		element.set_attribute_value('style', 'max-width:100%;padding:0;border:0')
		style := css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none))
		box := if tag == 'input' {
			unsafe { &Box(TextInputBox.new(document, element, style)) }
		} else {
			unsafe { &Box(TextAreaBox.new(document, element, style)) }
		}
		mut state := LayoutState.new()
		assert calculate_min_content_width(mut state, box) == box.auto_content_box_size().width?
		assert should_treat_max_width_as_none(state, unsafe { &Node(box) }, AvailableSize.make_min_content())
	}
}
