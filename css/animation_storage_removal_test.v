module css

import dom

fn animation_storage_removal_target(document &dom.Document) &dom.Element {
	return document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
}

fn animation_storage_removal_animation(target dom.AbstractElement, name string, paused bool) &CSSAnimation {
	mut animation := CSSAnimation.create()
	animation.set_animation_name(name)
	animation.set_owning_element(target)
	animation.set_timeline(&AnimationTimeline{})
	mut effect := KeyframeEffect.create()
	effect.set_target(target)
	effect.set_specified_iteration_duration(1000)
	animation.set_effect(effect)
	animation.play() or { panic(err) }
	assert (animation.sample_at(250) or { panic('missing sampled progress') }) == 0.25
	if paused {
		animation.pause() or { panic(err) }
	}
	return animation
}

fn test_animation_storage_noop_removal_preserves_backing_storage_and_animation_state() {
	document := dom.Document.create(dom.url_about_blank())
	owner := animation_storage_removal_target(document)
	other_owner := animation_storage_removal_target(document)
	unassociated_owner := animation_storage_removal_target(document)
	target := dom.AbstractElement.new(owner, none)
	before := dom.AbstractElement.new(owner, .before)
	other := dom.AbstractElement.new(other_owner, none)
	unassociated := dom.AbstractElement.new(unassociated_owner, none)
	mut storage := CSSAnimationStorage{}
	empty_backing := storage.entries.data
	storage.remove_animations_not_named(target, {})
	assert storage.entries.data == empty_backing

	retained := animation_storage_removal_animation(target, 'spin', true)
	pseudo := animation_storage_removal_animation(before, 'spin', false)
	unrelated := animation_storage_removal_animation(other, 'pulse', false)
	storage.set(target, 'spin', retained)
	storage.set(before, 'spin', pseudo)
	storage.set(other, 'pulse', unrelated)
	backing := storage.entries.data
	capacity := storage.entries.cap
	for _ in 0 .. 8 {
		storage.remove_animations_not_named(target, {
			'spin':   true
			'unused': true
		})
		storage.remove_animations_not_named(before, {
			'spin': true
		})
		storage.remove_animations_not_named(unassociated, {})
		assert storage.entries.data == backing
		assert storage.entries.cap == capacity
		assert storage.entries.len == 3
	}
	assert voidptr(storage.animation(target, 'spin') or { panic('missing retained animation') }) == voidptr(retained)
	assert voidptr(storage.animation(before, 'spin') or { panic('missing pseudo animation') }) == voidptr(pseudo)
	assert voidptr(storage.animation(other, 'pulse') or { panic('missing unrelated animation') }) == voidptr(unrelated)
	assert retained.play_state() == .paused
	assert (retained.last_sample_time_ or { panic('missing sample time') }) == 250
	assert (retained.paused_progress_ or { panic('missing paused progress') }) == 0.25
	assert (retained.effect_.output_progress or { panic('missing effect progress') }) == 0.25
	assert retained.effect_.current_phase == .active
	assert pseudo.play_state() == .running
	assert unrelated.play_state() == .running
}

fn test_animation_storage_real_removal_cancels_only_matching_target_names_in_order() {
	document := dom.Document.create(dom.url_about_blank())
	owner := animation_storage_removal_target(document)
	other_owner := animation_storage_removal_target(document)
	target := dom.AbstractElement.new(owner, none)
	before := dom.AbstractElement.new(owner, .before)
	after := dom.AbstractElement.new(owner, .after)
	other := dom.AbstractElement.new(other_owner, none)
	mut storage := CSSAnimationStorage{}
	pseudo_before := animation_storage_removal_animation(before, 'remove', false)
	removed_running := animation_storage_removal_animation(target, 'remove', false)
	unrelated := animation_storage_removal_animation(other, 'remove', false)
	removed_paused := animation_storage_removal_animation(target, 'also-remove', true)
	pseudo_after := animation_storage_removal_animation(after, 'remove', true)
	retained := animation_storage_removal_animation(target, 'keep', true)
	storage.set(before, 'remove', pseudo_before)
	storage.set(target, 'remove', removed_running)
	storage.set(other, 'remove', unrelated)
	storage.set(target, 'also-remove', removed_paused)
	storage.set(after, 'remove', pseudo_after)
	storage.set(target, 'keep', retained)

	storage.remove_animations_not_named(target, {
		'keep': true
	})
	assert storage.entries.len == 4
	for index, animation in [pseudo_before, unrelated, pseudo_after, retained] {
		assert voidptr(storage.entries[index].animation) == voidptr(animation)
	}
	assert storage.animation(target, 'remove') == none
	assert storage.animation(target, 'also-remove') == none
	for removed in [removed_running, removed_paused] {
		assert removed.play_state() == .idle
		assert removed.effect_.output_progress == none
		assert removed.effect_.current_phase == .idle
		assert removed.last_sample_time_ == none
		assert removed.paused_progress_ == none
	}
	assert pseudo_before.play_state() == .running
	assert unrelated.play_state() == .running
	assert pseudo_after.play_state() == .paused
	assert retained.play_state() == .paused
	assert (retained.effect_.output_progress or { panic('missing effect progress') }) == 0.25
	bindings := target.css_defined_animations() or { panic('retained binding missing') }
	assert bindings.len == 1
	assert 'keep' in bindings
	for pseudo_target in [before, after, other] {
		pseudo_bindings := pseudo_target.css_defined_animations() or {
			panic('unrelated binding removed')
		}
		assert 'remove' in pseudo_bindings
	}

	backing := storage.entries.data
	storage.remove_animations_not_named(target, {
		'keep': true
	})
	assert storage.entries.data == backing
	storage.remove_animations_not_named(target, {})
	assert storage.entries.len == 3
	assert retained.play_state() == .idle
	assert target.css_defined_animations() == none
	assert storage.animation(before, 'remove') != none
	assert storage.animation(after, 'remove') != none
	assert storage.animation(other, 'remove') != none
}
