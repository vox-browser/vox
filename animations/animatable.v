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

pub fn get_animations_options_from_bindings(options GetAnimationsOptions) !GetAnimationsOptions {
	if pseudo_element := options.pseudo_element {
		_ = pseudo_element_parsing(pseudo_element)!
	}
	return options
}

pub fn keyframe_animation_options_from_bindings(options KeyframeAnimationOptions) !KeyframeAnimationOptions {
	return options
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
	css_defined_animations_       map[int][]&css.CSSAnimation
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
		if element.document() != unsafe { nil } {
			mut document := unsafe { &dom.Document(element.document()) }
			install_document_animations_hook(mut document)
		}
	}
	return animatable
}

fn install_document_animations_hook(mut document dom.Document) {
	document.set_animations_hook(dom.DocumentAnimationsHook{
		target: voidptr(document)
		calculate_get_animations: calculate_get_animations_for_dom_root
		update_animations: update_animations_for_dom_root
		remove_replaced_animations: remove_replaced_animations_for_dom_root
		compare_animations: compare_dom_animations
		effect_targets: animation_effect_targets_for_document
		effects_for_style: animation_effects_for_style
	})
}

fn append_animation_effect_targets(node &dom.Node, mut result []dom.AbstractElement) {
	if node.is_element() {
		element := unsafe { &dom.Element(node) }
		if element.animations_animatable_handle_ != unsafe { nil } {
			// Keep the target in the update set after cancellation/removal so its
			// previous animated overlay can be reset even with no active effects.
			result << dom.AbstractElement.new(element, none)
			for raw := 0; raw < int(dom.PseudoElement.known_pseudo_element_count); raw++ {
				pseudo := unsafe { dom.PseudoElement(raw) }
				abstract_element := dom.AbstractElement.new(element, pseudo)
				if abstract_element.computed_properties() != none {
					result << abstract_element
				}
			}
		}
	}
	for child in node.children_as_vector() {
		append_animation_effect_targets(child, mut result)
	}
	if node.is_element() {
		element := unsafe { &dom.Element(node) }
		if shadow := element.shadow_root() {
			append_animation_effect_targets(shadow.as_node(), mut result)
		}
	}
}

fn animation_effect_targets_for_document(target voidptr) []dom.AbstractElement {
	document := unsafe { &dom.Document(target) }
	mut targets := []dom.AbstractElement{}
	append_animation_effect_targets(unsafe { &dom.Node(document) }, mut targets)
	return targets
}

fn animation_effects_for_style(_ voidptr, target dom.AbstractElement) []voidptr {
	element := target.element()
	if element.animations_animatable_handle_ == unsafe { nil } {
		return []voidptr{}
	}
	mut animatable := unsafe { &Animatable(element.animations_animatable_handle_) }
	mut effects := []voidptr{}
	for animation in animatable.associated_animations_in_composite_order() {
		if animation.replace_state() == .removed { continue }
		associated_effect := animation.effect_ or { continue }
		if !associated_effect.is_keyframe_effect_ { continue }
		mut effect := unsafe { &KeyframeEffect(associated_effect) }
		abstract_target := effect.target_abstract_element() or { continue }
		effect_pseudo := abstract_target.pseudo_element()
		target_pseudo := target.pseudo_element()
		if effect_pseudo != target_pseudo { continue }
		effects << voidptr(effect.css_effect_for_style())
	}
	return effects
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
	return keyframe_effect_composite_order(unsafe { &KeyframeEffect(a_effect) }, unsafe { &KeyframeEffect(b_effect) })
}

fn compare_associated_animations(a &Animation, b &Animation) int {
	a_effect := a.effect_
	b_effect := b.effect_
	a_is_keyframe_effect := if effect := a_effect { effect.is_keyframe_effect_ } else { false }
	b_is_keyframe_effect := if effect := b_effect { effect.is_keyframe_effect_ } else { false }
	if a_is_keyframe_effect && b_is_keyframe_effect {
		return compare_animations(a, b)
	}
	if a_is_keyframe_effect != b_is_keyframe_effect {
		return if a_is_keyframe_effect { 1 } else { -1 }
	}
	if a.global_animation_list_order() < b.global_animation_list_order() {
		return -1
	}
	if a.global_animation_list_order() > b.global_animation_list_order() {
		return 1
	}
	return 0
}

// Composite order of the animation classes: CSS transitions, then CSS
// animations, then animations created through the API.
fn dom_animation_class_rank(kind dom.ConcreteAnimationKind) int {
	return match kind {
		.css_transition { 0 }
		.css_animation { 1 }
		.web_animation { 2 }
	}
}

fn compare_dom_animations(_ voidptr, a &dom.Animation, b &dom.Animation) int {
	if a.concrete_handle_ == unsafe { nil } || b.concrete_handle_ == unsafe { nil } {
		return 0
	}
	rank_a := dom_animation_class_rank(a.concrete_kind_)
	rank_b := dom_animation_class_rank(b.concrete_kind_)
	if rank_a != rank_b {
		return rank_a - rank_b
	}
	// Only API animations are Animations.Animation objects. CSS transitions
	// and animations belong to the css module; their events keep the order in
	// which they were queued.
	if a.concrete_kind_ != .web_animation {
		return 0
	}
	return compare_animations(unsafe { &Animation(a.concrete_handle_) }, unsafe { &Animation(b.concrete_handle_) })
}

fn update_animations_for_dom_root(_ voidptr, root &dom.Node, _timestamp f64) {
	collected_animations := all_animations_for_dom_root(root)
	for animation in collected_animations {
		mut mutable_animation := unsafe { &Animation(animation) }
		mutable_animation.update()
		if mutable_animation.css_cancellation_disassociation_pending() {
			mutable_animation.disassociate_from_target_after_css_cancellation()
		}
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
	mut highest_custom_property_composite_orders := map[string]int{}
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
		for name, _ in effect.target_custom_properties() {
			if name !in highest_custom_property_composite_orders {
				has_any_highest_priority_property = true
				highest_custom_property_composite_orders[name] = index
			}
		}
		if has_any_highest_priority_property {
			continue
		}
		animation.set_replace_state(.removed)
		timeline := animation.timeline_ or { continue }
		remove_event := AnimationPlaybackEvent.create('remove', AnimationPlaybackEventInit{
			current_time: if value := animation.current_time() {
				value.as_css_numberish()
			} else {
				none
			}
			timeline_time: if value := timeline.current_time() {
				value.as_css_numberish()
			} else {
				none
			}
		})
		animation.emitted_events_ << remove_event
		if document := animation.document_for_timing() {
			mut mutable_document := unsafe { &dom.Document(document) }
			mutable_document.append_pending_animation_event(dom.PendingAnimationEvent{
				event: unsafe { &dom.Event(remove_event) }
				animation: unsafe { &dom.Animation(animation) }
				target: &animation.EventTarget
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
			// A later document can reuse a destroyed document's address. Only
			// a timeline still associated with this document is its own;
			// the check does not read the possibly released timeline.
			if document.associated_animation_timelines.any(it.target == voidptr(existing)) {
				return existing
			}
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
	effect := KeyframeEffect.construct_impl(animatable.target_, keyframes, options.KeyframeEffectOptions)!
	mut timeline := options.timeline or {
		default_timeline_for_animatable(animatable)
	}

	mut animation := Animation.create(effect.as_animation_effect(), timeline)
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
				if !a_effect.is_keyframe_effect_ || !b_effect.is_keyframe_effect_ {
					continue
				}
				order := keyframe_effect_composite_order(unsafe { &KeyframeEffect(a_effect) }, unsafe { &KeyframeEffect(b_effect) })
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

pub fn (mut animatable Animatable) associated_animations_in_composite_order() []&Animation {
	if !animatable.is_sorted_by_composite_order_ {
		animatable.associated_animations_.sort_with_compare(fn (a &&Animation, b &&Animation) int {
			return compare_associated_animations(*a, *b)
		})
		animatable.is_sorted_by_composite_order_ = true
	}
	return animatable.associated_animations_.clone()
}

pub fn (mut animatable Animatable) invalidate_associated_animation_composite_order() {
	animatable.is_sorted_by_composite_order_ = false
}

pub fn (animatable &Animatable) has_associated_animations() bool {
	return animatable.associated_animations_.len > 0
}

pub fn (animatable &Animatable) has_relevant_animations() bool {
	for animation in animatable.associated_animations_ {
		if animation.is_relevant() {
			return true
		}
	}
	return false
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
		if voidptr(existing) == voidptr(animation) {
			return
		}
	}
	animatable.associated_animations_ << animation
	animatable.is_sorted_by_composite_order_ = false
}

pub fn (mut animatable Animatable) disassociate_with_animation(animation &Animation) {
	for index, existing in animatable.associated_animations_ {
		if voidptr(existing) == voidptr(animation) {
			animatable.associated_animations_.delete(index)
			animatable.invalidate_associated_animation_composite_order()
			return
		}
	}
}

pub fn (mut animatable Animatable) on_document_changed(_ &dom.Document, new_document &dom.Document) {
	mut mutable_document := unsafe { &dom.Document(new_document) }
	install_document_animations_hook(mut mutable_document)
}

pub fn (mut animatable Animatable) cancel_css_animations_and_transitions() {
	for _, css_animations in animatable.css_defined_animations_ {
		for animation in css_animations {
			mut mutable_animation := unsafe { &css.CSSAnimation(animation) }
			mutable_animation.cancel()
		}
	}
	animatable.css_defined_animations_.clear()
	for _, transition in animatable.transitions_ {
		mut mutable_transition := unsafe { &AnimatableTransition(transition) }
		for _, animation in mutable_transition.associated_transitions {
			mut mutable_animation := unsafe { &css.CSSTransition(animation) }
			mutable_animation.cancel()
		}
		mutable_transition.associated_transitions.clear()
		mutable_transition.attribute_indices.clear()
		mutable_transition.attributes.clear()
	}
	animatable.has_css_defined_animations_ = false
}

fn pseudo_index(pseudo ?css.PseudoElement) ?int {
	value := pseudo or { return 0 }
	if !css.is_known_pseudo_element_type(value) {
		return none
	}
	return int(value) + 1
}

fn (mut animatable Animatable) ensure_transition(pseudo ?css.PseudoElement) ?&AnimatableTransition {
	index := pseudo_index(pseudo) or { return none }
	if existing := animatable.transitions_[index] {
		return existing
	}
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
			delay: transition.delay
			duration: transition.duration
			timing_function: transition.timing_function
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

pub fn (animatable &Animatable) has_css_animations_or_transitions() bool {
	if animatable.has_css_defined_animations_ {
		return true
	}
	for _, transition in animatable.transitions_ {
		if transition.associated_transitions.len > 0 {
			return true
		}
	}
	return false
}

pub fn (mut animatable Animatable) add_css_animation(name string, pseudo ?css.PseudoElement, animation &css.CSSAnimation) {
	index := pseudo_index(pseudo) or { return }
	mut css_animations := animatable.css_defined_animations_[index] or { []&css.CSSAnimation{} }
	for existing in css_animations {
		if existing.animation_name() == name && voidptr(existing) == voidptr(animation) {
			return
		}
	}
	css_animations << animation
	animatable.css_defined_animations_[index] = css_animations
	animatable.has_css_defined_animations_ = true
}

pub fn (mut animatable Animatable) remove_css_animation(name string, pseudo ?css.PseudoElement) {
	index := pseudo_index(pseudo) or { return }
	css_animations := animatable.css_defined_animations_[index] or { return }
	animatable.css_defined_animations_[index] = css_animations.filter(it.animation_name() != name)
}

pub fn (animatable &Animatable) css_defined_animations(pseudo ?css.PseudoElement) []&css.CSSAnimation {
	index := pseudo_index(pseudo) or { return [] }
	css_animations := animatable.css_defined_animations_[index] or { return [] }
	return css_animations.clone()
}

pub fn (mut animatable Animatable) set_css_defined_animations(pseudo ?css.PseudoElement, css_animations []&css.CSSAnimation) {
	index := pseudo_index(pseudo) or { return }
	if css_animations.len > 0 {
		animatable.has_css_defined_animations_ = true
	}
	animatable.css_defined_animations_[index] = css_animations.clone()
}
