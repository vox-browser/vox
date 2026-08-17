// Copyright (c) 2024-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/Animations/Animatable.{h,cpp}.
module animations

import css
import dom

pub struct KeyframeAnimationOptions {
	KeyframeEffectOptions
pub mut:
	id       string
	timeline ?&AnimationTimeline
}

pub struct GetAnimationsOptions {
pub mut:
	subtree        bool
	pseudo_element ?string
}

pub struct TransitionAttributes {
pub:
	delay               f64
	duration            f64
	timing_function     css.EasingFunction
	transition_behavior css.TransitionBehavior
}

struct AnimatableTransition {
mut:
	attribute_indices      map[css.PropertyID]int
	attributes             []TransitionAttributes
	associated_transitions map[css.PropertyID]&css.CSSTransition
}

@[heap]
pub struct Animatable {
pub mut:
	target_                       ?&dom.Element
	associated_animations_        []&Animation
	is_sorted_by_composite_order_ bool = true
	has_css_defined_animations_   bool
	css_defined_animations_       map[string]&css.CSSAnimation
	transitions_                  map[int]&AnimatableTransition
	descendants_                  []&Animatable
	next_animation_order_         u64
}

pub fn Animatable.new(target ?&dom.Element) &Animatable {
	return &Animatable{
		target_: target
	}
}

pub fn (mut animatable Animatable) animate(keyframes []BaseKeyframe, options KeyframeAnimationOptions) !&Animation {
	effect := KeyframeEffect.construct_impl(animatable.target_, keyframes,
		options.KeyframeEffectOptions)!
	mut timeline := options.timeline or {
		mut default_timeline := new_document_timeline(none, 0, 0)
		default_timeline.set_document_active(true)
		default_timeline
	}

	mut animation := Animation.construct_impl(effect.as_animation_effect(), timeline)!
	animation.id_ = options.id
	animatable.next_animation_order_++
	animation.global_animation_list_order_ = animatable.next_animation_order_
	animatable.associate_with_animation(animation)
	animation.play()!
	return animation
}

pub fn (mut animatable Animatable) animate_with_duration(keyframes []BaseKeyframe, duration f64) !&Animation {
	mut timing := OptionalEffectTiming{}
	timing.duration = IterationDuration(duration)
	return animatable.animate(keyframes, KeyframeAnimationOptions{
		KeyframeEffectOptions: KeyframeEffectOptions{
			timing: timing
		}
	})
}

pub fn (mut animatable Animatable) get_animations(options GetAnimationsOptions) ![]&Animation {
	if pseudo := options.pseudo_element {
		_ = pseudo_element_parsing(pseudo)!
	}
	mut result := []&Animation{}
	for animation in animatable.associated_animations_ {
		if animation.is_relevant() { result << animation }
	}
	if options.subtree {
		for mut descendant in animatable.descendants_ {
			result << descendant.get_animations(GetAnimationsOptions{
				pseudo_element: options.pseudo_element
			})!
		}
	}
	for i := 0; i < result.len; i++ {
		for j := i + 1; j < result.len; j++ {
			a_effect := result[i].effect_ or { continue }
			b_effect := result[j].effect_ or { continue }
			if !a_effect.is_keyframe_effect_ || !b_effect.is_keyframe_effect_ { continue
			 }
			order := keyframe_effect_composite_order(unsafe { &KeyframeEffect(a_effect) },
				unsafe { &KeyframeEffect(b_effect) })
			if order > 0 {
				temporary := result[i]
				result[i] = result[j]
				result[j] = temporary
			}
		}
	}
	return result
}

pub fn (mut animatable Animatable) add_descendant(value &Animatable) {
	animatable.descendants_ << value
}

pub fn (mut animatable Animatable) associate_with_animation(animation &Animation) {
	for existing in animatable.associated_animations_ {
		if existing == animation { return }
	}
	animatable.associated_animations_ << animation
	animatable.is_sorted_by_composite_order_ = false
}

pub fn (mut animatable Animatable) disassociate_with_animation(animation &Animation) {
	for index, existing in animatable.associated_animations_ {
		if existing == animation {
			animatable.associated_animations_.delete(index)
			return
		}
	}
}

fn pseudo_index(pseudo ?css.PseudoElement) ?int {
	value := pseudo or { return 0 }
	if !css.is_known_pseudo_element_type(value) { return none }
	return int(value) + 1
}

fn (mut animatable Animatable) ensure_transition(pseudo ?css.PseudoElement) ?&AnimatableTransition {
	index := pseudo_index(pseudo) or { return none }
	if existing := animatable.transitions_[index] { return existing }
	transition := &AnimatableTransition{}
	unsafe {
		animatable.transitions_[index] = transition
	}
	return transition
}

pub fn (mut animatable Animatable) add_transitioned_properties(pseudo ?css.PseudoElement, transitions []css.TransitionProperties) {
	mut bucket := animatable.ensure_transition(pseudo) or { return }
	for transition in transitions {
		index := bucket.attributes.len
		bucket.attributes << TransitionAttributes{
			delay:               transition.delay
			duration:            transition.duration
			timing_function:     transition.timing_function
			transition_behavior: transition.transition_behavior
		}
		for property in transition.properties {
			bucket.attribute_indices[property] = index
		}
	}
}

pub fn (mut animatable Animatable) property_ids_with_matching_transition_property_entry(pseudo ?css.PseudoElement) []css.PropertyID {
	bucket := animatable.ensure_transition(pseudo) or { return [] }
	return bucket.attribute_indices.keys()
}

pub fn (mut animatable Animatable) property_transition_attributes(pseudo ?css.PseudoElement, property css.PropertyID) ?TransitionAttributes {
	bucket := animatable.ensure_transition(pseudo) or { return none }
	index := bucket.attribute_indices[property] or { return none }
	return bucket.attributes[index]
}

pub fn (mut animatable Animatable) set_transition(pseudo ?css.PseudoElement, property css.PropertyID, animation &css.CSSTransition) {
	mut bucket := animatable.ensure_transition(pseudo) or { return }
	unsafe {
		bucket.associated_transitions[property] = animation
	}
}

pub fn (mut animatable Animatable) remove_transition(pseudo ?css.PseudoElement, property css.PropertyID) {
	mut bucket := animatable.ensure_transition(pseudo) or { return }
	bucket.associated_transitions.delete(property)
}

pub fn (mut animatable Animatable) property_ids_with_existing_transitions(pseudo ?css.PseudoElement) []css.PropertyID {
	bucket := animatable.ensure_transition(pseudo) or { return [] }
	return bucket.associated_transitions.keys()
}

pub fn (mut animatable Animatable) property_transition(pseudo ?css.PseudoElement, property css.PropertyID) ?&css.CSSTransition {
	bucket := animatable.ensure_transition(pseudo) or { return none }
	return bucket.associated_transitions[property] or { none }
}

pub fn (mut animatable Animatable) clear_registered_transitions(pseudo ?css.PseudoElement) {
	mut bucket := animatable.ensure_transition(pseudo) or { return }
	bucket.attribute_indices.clear()
	bucket.attributes.clear()
}

pub fn (mut animatable Animatable) set_has_css_defined_animations() {
	animatable.has_css_defined_animations_ = true
}

pub fn (animatable &Animatable) has_css_defined_animations() bool {
	return animatable.has_css_defined_animations_
}

pub fn (mut animatable Animatable) add_css_animation(name string, pseudo ?css.PseudoElement, animation &css.CSSAnimation) {
	index := pseudo_index(pseudo) or { return }
	unsafe {
		animatable.css_defined_animations_['${index}:${name}'] = animation
	}
	animatable.has_css_defined_animations_ = true
}

pub fn (mut animatable Animatable) remove_css_animation(name string, pseudo ?css.PseudoElement) {
	index := pseudo_index(pseudo) or { return }
	animatable.css_defined_animations_.delete('${index}:${name}')
}

pub fn (animatable &Animatable) css_defined_animations(pseudo ?css.PseudoElement) map[string]&css.CSSAnimation {
	index := pseudo_index(pseudo) or { return map[string]&css.CSSAnimation{} }
	mut result := map[string]&css.CSSAnimation{}
	prefix := '${index}:'
	for key, animation in animatable.css_defined_animations_ {
		if key.starts_with(prefix) {
			unsafe {
				result[key[prefix.len..]] = animation
			}
		}
	}
	return result
}
