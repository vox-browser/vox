module css

import dom

fn test_sampled_animation_compositor_classification_checks_changed_and_removed_keys() {
	one := &dom.StyleValue{css_text: '1'}
	half := &dom.StyleValue{css_text: '0.5'}
	old := {PropertyID.opacity: one, PropertyID.width: one}
	assert animated_changes_are_compositor_only(old, {PropertyID.opacity: half, PropertyID.width: one})
	assert !animated_changes_are_compositor_only(old, {PropertyID.opacity: half})
	assert !animated_changes_are_compositor_only({PropertyID.opacity: one}, {PropertyID.opacity: half, PropertyID.filter: one})
	assert !animated_changes_are_compositor_only({PropertyID.width: one}, {PropertyID.width: half})
	assert animated_changes_are_compositor_only({PropertyID.transform: one}, map[PropertyID]&dom.StyleValue{})
}
