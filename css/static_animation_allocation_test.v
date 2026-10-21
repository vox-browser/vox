module css

import dom
import platform

fn test_static_styles_do_not_allocate_animation_lists_or_name_tables() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	owner := document.create_element('div')!
	target := dom.AbstractElement.new(owner, none)
	properties := computed_properties_with_initial_values()
	cascaded := CascadedProperties.new()
	computer := StyleComputer.new(document)
	assert computer.css_animation_storage_ != unsafe { nil }
	assert properties.animations(&target).len == 0
	before := platform.thread_arena_usage().used
	for _ in 0 .. 128 {
		assert properties.animations(&target).len == 0
		computer.process_animation_definitions(properties, cascaded, target)
	}
	$if prealloc {
		assert platform.thread_arena_usage().used - before < 4096
	}
	assert computer.css_animation_storage_.entries.len == 0
}

fn test_static_animation_fast_path_cancels_existing_target_animations_only() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	owner := document.create_element('div')!
	other := document.create_element('div')!
	target := dom.AbstractElement.new(owner, none)
	pseudo := dom.AbstractElement.new(owner, .before)
	other_target := dom.AbstractElement.new(other, none)
	computer := StyleComputer.new(document)
	mut storage := computer.css_animation_storage_
	removed := static_allocation_animation(target, 'removed', true)
	retained := static_allocation_animation(other_target, 'retained', false)
	pseudo_animation := static_allocation_animation(pseudo, 'pseudo', true)
	storage.set(target, 'removed', removed)
	storage.set(other_target, 'retained', retained)
	storage.set(pseudo, 'pseudo', pseudo_animation)
	properties := computed_properties_with_initial_values()
	cascaded := CascadedProperties.new()
	computer.process_animation_definitions(properties, cascaded, target)
	assert storage.animation(target, 'removed') == none
	assert removed.play_state() == .idle
	assert voidptr(storage.animation(other_target, 'retained')?) == voidptr(retained)
	assert voidptr(storage.animation(pseudo, 'pseudo')?) == voidptr(pseudo_animation)
	assert retained.play_state() == .running
	assert pseudo_animation.play_state() == .paused
}

fn static_allocation_animation(target dom.AbstractElement, name string, paused bool) &CSSAnimation {
	mut animation := CSSAnimation.create()
	animation.set_animation_name(name)
	animation.set_owning_element(target)
	animation.set_timeline(&AnimationTimeline{})
	mut effect := KeyframeEffect.create()
	effect.set_target(target)
	effect.set_specified_iteration_duration(1000)
	animation.set_effect(effect)
	animation.play() or { panic(err) }
	_ = animation.sample_at(250) or { panic('missing sampled progress') }
	if paused { animation.pause() or { panic(err) } }
	return animation
}

fn test_static_animation_name_probe_distinguishes_none_lists_from_quoted_names() {
 for text in ['none', 'none, none', 'fade, none', '"none"', 'none, "none"'] {
  value := dom_style_value_from_value_logic(parse_css_value_logic(.animation_name, text)?)
  assert computed_animation_names_are_none(value) == (text in ['none', 'none, none']), text
 }
 assert computed_animation_names_are_none(&dom.StyleValue{css_text:'none'})
 assert !computed_animation_names_are_none(&dom.StyleValue{css_text:'"none"'})
}
