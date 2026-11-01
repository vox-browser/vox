module css

import dom
import os

const disable_hidden_animation_throttling = os.getenv('VOX_DISABLE_HIDDEN_ANIMATION_THROTTLING') != ''
const hidden_animation_diagnostics = os.getenv('VOX_HIDDEN_ANIMATION_DIAGNOSTICS') != ''

// Use the same eligibility as the animated-style consumer. A hidden subtree
// cannot publish animated pixels; an effect on display itself can reveal it.
// Keep clocks and effects intact so a later style change can reveal the target.
fn (s &StyleComputer) animation_target_needs_rendering(target dom.AbstractElement) bool {
	if disable_hidden_animation_throttling
		|| !is_in_display_none_subtree_ignoring_animations(target)
		|| s.target_has_animation_for_property(target, .display) {
		return true
	}
	if hidden_animation_diagnostics {
		eprintln('Vox animation demand: hidden target class=${target.element().get_attribute_value('class')} pseudo=${target.pseudo_element()}')
	}
	return false
}
