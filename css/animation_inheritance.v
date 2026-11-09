module css

import dom

fn keyframe_effect_uses_inherited_endpoints(effect &KeyframeEffect) bool {
	frames := effect.key_frame_set or { return false }
	for _,frame in frames.keyframes_by_key {
		for id,value in frame.properties {
			if computed_interpolation_style_value_is_inherit(value)
				|| (computed_interpolation_style_value_is_unset(value) && is_inherited_property(id)) { return true }
		}
	}
	return false
}

// An inherited-style refresh normally preserves the target's own animation
// overlay. Explicit inherit/unset keyframes need that overlay sampled again
// against the newly computed parent, even while the animation is paused.
fn (computer &StyleComputer) target_animation_uses_inherited_endpoints(target dom.AbstractElement) bool {
	for effect in web_animation_effects_for_style(target) {
		if keyframe_effect_uses_inherited_endpoints(effect) { return true }
	}
	if computer.css_animation_storage_ != unsafe { nil } {
		for entry in computer.css_animation_storage_.entries {
			if !abstract_elements_equal(entry.abstract_element,target) { continue }
			if effect := entry.animation.effect() {
				if keyframe_effect_uses_inherited_endpoints(effect) { return true }
			}
		}
	}
	return false
}
