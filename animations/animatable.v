// Copyright (c) 2024-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/Animations/Animatable.{h,cpp}.
module animations

import css
import dom

__global (
	document_animation_timelines = map[u64]&AnimationTimeline{}
)

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
	if element := target {
		if element.animations_animatable_handle_ != unsafe { nil } {
			return unsafe { &Animatable(element.animations_animatable_handle_) }
		}
	}
	mut animatable := &Animatable{
		target_: target
	}
	if element := target {
		mut mutable_element := unsafe { &dom.Element(element) }
		mutable_element.animations_animatable_handle_ = voidptr(animatable)
		mut document := unsafe { &dom.Document(element.document()) }
		document.set_animations_hook(dom.DocumentAnimationsHook{
			target:                   voidptr(document)
			calculate_get_animations: calculate_get_animations_for_dom_root
			update_animations:        update_animations_for_dom_root
			remove_replaced_animations: remove_replaced_animations_for_dom_root
			compare_animations:       compare_dom_animations
		})
	}
	return animatable
}

fn append_all_animations_for_dom_subtree(node &dom.Node, mut result []&Animation) {
	if element := node.as_element() {
		if element.animations_animatable_handle_ != unsafe { nil } {
			animatable := unsafe { &Animatable(element.animations_animatable_handle_) }
			result << animatable.associated_animations_
		}
	}
	for child in node.children_as_vector() {
		append_all_animations_for_dom_subtree(child, mut result)
	}
}

fn all_animations_for_dom_root(root &dom.Node) []&Animation {
	mut result := []&Animation{}
	for child in root.children_as_vector() {
		append_all_animations_for_dom_subtree(child, mut result)
	}
	return result
}

fn compare_animations(a &Animation, b &Animation) int {
	a_effect := a.effect_ or { return 0 }
	b_effect := b.effect_ or { return 0 }
	if !a_effect.is_keyframe_effect_ || !b_effect.is_keyframe_effect_ {
		return 0
	}
	return keyframe_effect_composite_order(unsafe { &KeyframeEffect(a_effect) },
		unsafe { &KeyframeEffect(b_effect) })
}

fn compare_dom_animations(_ voidptr, a &dom.Animation, b &dom.Animation) int {
	if a.concrete_handle_ == unsafe { nil } || b.concrete_handle_ == unsafe { nil } {
		return 0
	}
	return compare_animations(unsafe { &Animation(a.concrete_handle_) },
		unsafe { &Animation(b.concrete_handle_) })
}

fn update_animations_for_dom_root(_ voidptr, root &dom.Node, timestamp f64) {
	collected_animations := all_animations_for_dom_root(root)
	mut updated_timelines := map[u64]bool{}
	for animation in collected_animations {
		if mut timeline := animation.timeline_ {
			key := u64(voidptr(timeline))
			if key !in updated_timelines {
				if document := timeline.document_ {
					timeline.set_document_active(document.is_active())
				}
				timeline.update_current_time(timestamp)
				updated_timelines[key] = true
			}
		}
	}
	for animation in collected_animations {
		mut mutable_animation := unsafe { &Animation(animation) }
		mutable_animation.update()
	}
}

fn remove_replaced_animations_for_dom_root(_ voidptr, root &dom.Node) {
	mut replaceable_animations := []&Animation{}
	for animation in all_animations_for_dom_root(root) {
		effect := animation.effect_ or { continue }
		if !effect.is_keyframe_effect_ {
			continue
		}
		target := unsafe { &KeyframeEffect(effect) }.target() or { continue }
		if voidptr(target.document()) != voidptr(root.document()) || !animation.is_replaceable()
			|| animation.replace_state() != .active {
			continue
		}
		replaceable_animations << animation
	}
	replaceable_animations.sort_with_compare(fn (a &&Animation, b &&Animation) int {
		return compare_animations(*a, *b)
	})
	mut highest_property_composite_orders := map[css.PropertyID]int{}
	for index := replaceable_animations.len - 1; index >= 0; index-- {
		mut animation := replaceable_animations[index]
		effect := animation.effect_ or { continue }
		mut has_any_highest_priority_property := false
		for property_id, _ in effect.target_properties() {
			if property_id !in highest_property_composite_orders {
				has_any_highest_priority_property = true
				highest_property_composite_orders[property_id] = index
			}
		}
		if has_any_highest_priority_property {
			continue
		}
		animation.set_replace_state(.removed)
		timeline := animation.timeline_ or { continue }
		remove_event := AnimationPlaybackEvent.create('remove', AnimationPlaybackEventInit{
			current_time:  if value := animation.current_time() { value.as_css_numberish() } else { none }
			timeline_time: if value := timeline.current_time() { value.as_css_numberish() } else { none }
		})
		animation.emitted_events_ << remove_event
		if document := animation.document_for_timing() {
			mut mutable_document := unsafe { &dom.Document(document) }
			mutable_document.append_pending_animation_event(dom.PendingAnimationEvent{
				event:                unsafe { &dom.Event(remove_event) }
				animation:            unsafe { &dom.Animation(animation) }
				target:               &animation.EventTarget
				scheduled_event_time: timeline.convert_a_timeline_time_to_an_origin_relative_time(timeline.current_time())
			})
		} else {
			animation.EventTarget.dispatch_event(unsafe { &dom.Event(remove_event) })
		}
	}
}

fn default_timeline_for_animatable(animatable &Animatable) &AnimationTimeline {
	if element := animatable.target_ {
		document := element.document()
		key := u64(voidptr(document))
		if existing := document_animation_timelines[key] {
			return existing
		}
		mut timeline := new_document_timeline(document, 0, 0)
		timeline.set_document_active(document.is_active())
		unsafe {
			document_animation_timelines[key] = timeline
		}
		return timeline
	}
	mut timeline := new_document_timeline(none, 0, 0)
	timeline.set_document_active(true)
	return timeline
}

fn append_animations_for_dom_subtree(node &dom.Node, mut result []&Animation) ! {
	if element := node.as_element() {
		if element.animations_animatable_handle_ != unsafe { nil } {
			mut animatable := unsafe { &Animatable(element.animations_animatable_handle_) }
			result << animatable.get_animations_internal(false, GetAnimationsOptions{})!
		}
	}
	for child in node.children_as_vector() {
		append_animations_for_dom_subtree(child, mut result)!
	}
}

// DocumentOrShadowRoot::calculate_get_animations(). DOM owns tree traversal;
// this callback supplies Animatable relevance and KeyframeEffect composite
// ordering from the translated Animations module.
fn calculate_get_animations_for_dom_root(_ voidptr, root &dom.Node) ![]&dom.Animation {
	mut collected_animations := []&Animation{}
	for child in root.children_as_vector() {
		append_animations_for_dom_subtree(child, mut collected_animations)!
	}
	collected_animations.sort_with_compare(fn (a &&Animation, b &&Animation) int {
		return compare_animations(*a, *b)
	})
	mut result := []&dom.Animation{cap: collected_animations.len}
	for animation in collected_animations {
		result << unsafe { &dom.Animation(animation) }
	}
	return result
}

pub fn (mut animatable Animatable) animate(keyframes []BaseKeyframe, options KeyframeAnimationOptions) !&Animation {
	effect := KeyframeEffect.construct_impl(animatable.target_, keyframes,
		options.KeyframeEffectOptions)!
	mut timeline := options.timeline or {
		default_timeline_for_animatable(animatable)
	}

	mut animation := Animation.construct_impl(effect.as_animation_effect(), timeline)!
	animation.id_ = options.id
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
	return animatable.get_animations_internal(true, options)
}

pub fn (mut animatable Animatable) get_animations_internal(sorted bool, options GetAnimationsOptions) ![]&Animation {
	if pseudo := options.pseudo_element {
		_ = pseudo_element_parsing(pseudo)!
	}
	mut result := []&Animation{}
	for animation in animatable.associated_animations_ {
		if animation.is_relevant() { result << animation }
	}
	if options.subtree {
		for mut descendant in animatable.descendants_ {
			result << descendant.get_animations_internal(false, GetAnimationsOptions{
				pseudo_element: options.pseudo_element
			})!
		}
	}
	if sorted {
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
	}
	return result
}

// The C++ object lazily allocates a separate Impl. This representation stores
// the same state inline, so ensuring the implementation returns that storage.
pub fn (mut animatable Animatable) ensure_impl() &Animatable {
	return animatable
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
