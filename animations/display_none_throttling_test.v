// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module animations

import dom
import math

fn hidden_subtree_effect(target &dom.Element, property string, first string, last string, duration f64) &KeyframeEffect {
	return KeyframeEffect.construct_impl(target, [
		BaseKeyframe{offset: 0, properties: {property: first}},
		BaseKeyframe{offset: 1, properties: {property: last}},
	], KeyframeEffectOptions{
		timing: OptionalEffectTiming{iterations: math.inf(1), duration: IterationDuration(duration)}
	}) or { panic(err) }
}

// Ladybird 8a1eda843c44cf4521264badf573da2932009ce7.
fn test_hidden_subtrees_skip_style_updates_unless_display_can_change() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut parent := document.create_element('div')!
	mut target := document.create_element('span')!
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(parent.as_node())!
	mut parent_node := parent.as_node()
	parent_node.append_child(target.as_node())!
	parent.set_computed_properties(none, &dom.CSSComputedProperties_{display_: dom.CSSDisplay_{is_none_: true}})
	assert hidden_subtree_effect(target, 'color', 'red', 'blue', 1000).can_skip_per_frame_style_update()
	assert !hidden_subtree_effect(target, 'display', 'none', 'block', 1000).can_skip_per_frame_style_update()
	assert !hidden_subtree_effect(target, '--display', 'none', 'block', 1000).can_skip_per_frame_style_update()
	parent.set_computed_properties(none, &dom.CSSComputedProperties_{})
	assert !hidden_subtree_effect(target, 'color', 'red', 'blue', 1000).can_skip_per_frame_style_update()
}

fn test_hidden_svg_resources_keep_their_style_updates() {
	for tag in ['rect', 'linearGradient', 'filter', 'mask', 'clipPath', 'pattern'] {
		mut document := dom.Document.create(dom.url_about_blank())
		defer { document.finalize() }
		mut parent := document.create_element('div')!
		mut resource := document.create_element_ns('http://www.w3.org/2000/svg', tag)!
		mut document_node := unsafe { &dom.Node(document) }
		document_node.append_child(parent.as_node())!
		mut parent_node := parent.as_node()
		parent_node.append_child(resource.as_node())!
		parent.set_computed_properties(none, &dom.CSSComputedProperties_{display_: dom.CSSDisplay_{is_none_: true}})
		resource.set_attribute_value('id', 'resource')
		assert !hidden_subtree_effect(parent, 'color', 'red', 'blue', 1000).can_skip_per_frame_style_update()
		assert !hidden_subtree_effect(resource, 'color', 'red', 'blue', 1000).can_skip_per_frame_style_update()
		if tag == 'rect' {
			resource.remove_attribute('id')
			assert hidden_subtree_effect(parent, 'color', 'red', 'blue', 1000).can_skip_per_frame_style_update()
		}
	}
}

fn test_infinite_effects_with_finite_finish_boundaries_keep_animation_ticks() {
	target := &dom.Element{}
	mut backwards := hidden_subtree_effect(target, 'transform', 'translateX(0px)', 'translateX(10px)', 1000)
	backwards.set_is_compositor_driven(true)
	mut animation := Animation.create(backwards.as_animation_effect(), none)
	animation.set_playback_rate(-1)!
	assert !backwards.can_skip_per_frame_animation_tick()
	mut instantaneous := hidden_subtree_effect(target, 'transform', 'translateX(0px)', 'translateX(10px)', 0)
	instantaneous.set_is_compositor_driven(true)
	_ = Animation.create(instantaneous.as_animation_effect(), none)
	assert !instantaneous.can_skip_per_frame_animation_tick()
}
