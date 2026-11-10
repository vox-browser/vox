// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module animations

import dom

// A custom property can make display change through var().
fn (effect &KeyframeEffect) may_animate_display() bool {
	for _, keyframe in effect.key_frame_set_.keyframes_by_key {
		if keyframe.custom_properties.len > 0 || css_property_display_in_keyframe(keyframe) {
			return true
		}
	}
	return false
}

fn css_property_display_in_keyframe(keyframe ResolvedKeyframe) bool {
	for property, _ in keyframe.properties {
		if property == .display { return true }
	}
	return false
}

fn svg_element_is_referenceable_in_display_none_subtree(element &dom.Element) bool {
	if !element.is_svg_element() { return false }
	if element.local_name() in ['circle', 'ellipse', 'line', 'path', 'polygon', 'polyline', 'rect']
		&& element.has_attribute('id') {
		return true
	}
	mut current := ?&dom.Element(element)
	for current != none {
		ancestor := current or { break }
		if !ancestor.is_svg_element() { break }
		if ancestor.local_name() in ['linearGradient', 'radialGradient', 'pattern', 'clipPath', 'mask', 'filter'] {
			return true
		}
		current = ancestor.as_node().parent_or_shadow_host_element()
	}
	return false
}

fn target_is_unseen_in_display_none_subtree(target &dom.Element) bool {
	if target.as_node().unsafe_layout_node() != none
		|| !target.as_node().has_inclusive_ancestor_with_display_none_ignoring_animations() {
		return false
	}
	mut pending := [target.as_node()]
	for pending.len > 0 {
		node := pending.pop()
		if element := node.as_element() {
			if svg_element_is_referenceable_in_display_none_subtree(element) {
				return false
			}
		}
		pending << node.children_as_vector()
	}
	return true
}
