module css

import dom

pub struct CompositorAnimationProperties {
pub mut:
	transform bool
	opacity bool
}

// Pausing a CSS animation preserves its compositor property identity, even
// when its sampled transform is the identity or its sampled opacity is one.
pub fn compositor_animation_properties(target dom.AbstractElement) CompositorAnimationProperties {
	if !target.element().has_css_defined_animations_flag { return CompositorAnimationProperties{} }
	bridge := target.document().style_computer
	if bridge == unsafe { nil } || bridge.css_handle == unsafe { nil } {
		return CompositorAnimationProperties{}
	}
	computer := unsafe { &StyleComputer(bridge.css_handle) }
	mut result := CompositorAnimationProperties{}
	if computer.css_animation_storage_ == unsafe { nil } { return result }
	for entry in computer.css_animation_storage_.entries {
		if !abstract_elements_equal(entry.abstract_element, target)
			|| entry.animation.play_state() !in [.running, .paused] { continue }
		effect := entry.animation.effect() or { continue }
		if effect.iteration_count <= 0 { continue }
		if effect.specified_iteration_duration <= 0 {
			timeline := entry.animation.timeline() or { continue }
			if timeline.kind != .scroll || timeline.scroll_subject_id == none
				|| effect.output_progress == none { continue }
		}
		// CSSAnimation keeps its playback state after sampling the end. An
		// unfilled effect on a monotonic timeline no longer contributes paint
		// and must not leave a stale surface or overlap barrier behind.
		if effect.current_phase == .after && effect.output_progress == none {
			if timeline := entry.animation.timeline() {
				if timeline.kind == .document { continue }
			}
		}
		result.opacity = result.opacity || keyframe_effect_animates_property(effect, .opacity)
		for property in [PropertyID.transform, .translate, .rotate, .scale] {
			result.transform = result.transform || keyframe_effect_animates_property(effect, property)
		}
	}
	return result
}
