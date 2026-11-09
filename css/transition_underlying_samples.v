module css

import dom

struct TransitionUnderlyingSample {
	value                ?&dom.StyleValue
	result_of_transition bool
	inherited            bool
}

fn capture_transition_underlying_samples(style &ComputedProperties, element dom.AbstractElement, storage &CSSTransitionStorage) map[PropertyID]TransitionUnderlyingSample {
	mut samples := map[PropertyID]TransitionUnderlyingSample{}
	if storage == unsafe { nil } { return samples }
	for transition in storage.transitions_for(element) {
		property := transition.transition_property_
		samples[property] = TransitionUnderlyingSample{ value: style.animated_property_value(property), result_of_transition: style.is_animated_property_result_of_transition(property), inherited: style.is_animated_property_inherited(property) }
	}
	return samples
}

// Registration can move a logical transition to another physical property.
// Cancel its old sample in this same style update, restoring any animation
// beneath it rather than leaving the transition's sampled value installed.
fn restore_cancelled_transition_samples(mut style ComputedProperties, element dom.AbstractElement, storage &CSSTransitionStorage, samples map[PropertyID]TransitionUnderlyingSample) {
	for property, sample in samples {
		if !style.is_animated_property_result_of_transition(property) { continue }
		if transition := storage.property_transition(element, property) {
			if !transition.is_idle() { continue }
		}
		if value := sample.value {
			style.set_animated_property(property, value, if sample.result_of_transition {
				.yes
			} else {
				.no
			}, if sample.inherited { .yes } else { .no })
		} else {
			style.remove_animated_property(property)
		}
	}
}
