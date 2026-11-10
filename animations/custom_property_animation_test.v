module animations

import css
import dom

fn animated_style_value(target &dom.Element, id css.PropertyID) string {
	properties := css.up_to_date_computed_properties_for_element(target)
	return (properties.property(id, .yes) or { panic('missing animated property') }).css_text
}

fn custom_style_value(target &dom.Element, name string) string {
	data := dom.AbstractElement.new(target, none).custom_property_data() or { panic('missing custom property data') }
	return (data.get(name) or { panic('missing ${name}') }).css_text
}

fn connected_animation_target(style string) !(&dom.Document, &dom.Element) {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{active_document_: document})
	mut root := document.create_element_ns('http://www.w3.org/1999/xhtml', 'html')!
	mut target := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	target.set_attribute_value('style', style)
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(root.as_node())!
	mut root_node := root.as_node()
	root_node.append_child(target.as_node())!
	css.css_style_computer_for(document)
	document.needs_full_style_update = true
	document.update_style()
	return document, target
}

fn test_custom_names_survive_processing_installation_copy_and_boundary_generation() {
	mut effect := KeyframeEffect.with_duration(none, [BaseKeyframe{
		offset: 0.5
		properties: {'--MixedCase': 'red', '--': 'ignored', 'opacity': '0.4'}
	}], 100)!
	frames := effect.get_keyframes()
	custom := frames[0].parsed_custom_properties['--MixedCase'] or { panic('missing custom keyframe') }
	assert custom.css_text == 'red'
	assert '--' !in frames[0].parsed_custom_properties
	assert '--MixedCase' in effect.target_custom_properties()
	assert effect.key_frame_set_.keyframes_by_key[0].custom_properties['--MixedCase'].use_initial
	assert effect.key_frame_set_.keyframes_by_key[100_000].custom_properties['--MixedCase'].use_initial
	copy := KeyframeEffect.copy(effect)
	assert '--MixedCase' in copy.target_custom_properties()
	copy_frame := copy.key_frame_set_.keyframes_by_key[50_000] or { panic('missing copied frame') }
	copy_property := copy_frame.custom_properties['--MixedCase'] or { panic('missing copied property') }
	assert (copy_property.value or { panic('missing copied value') }).css_text == 'red'
	effect.set_keyframes([]BaseKeyframe{})!
	assert effect.target_custom_properties().len == 0
}

fn test_web_animation_samples_registered_custom_property_in_real_style_updates() {
	mut document, target := connected_animation_target('width: var(--animated-width); opacity: 1')!
	css.register_property_for_document(mut document, css.PropertyDefinition{
		name: '--animated-width'
		syntax: '<length>'
		inherits: false
		initial_value: '0px'
	})!
	mut timeline := AnimationTimeline.new()
	timeline.monotonic_ = true
	timeline.current_time_ = TimeValue.milliseconds(0)
	mut animatable := Animatable.new(target)
	mut animation := animatable.animate([
		BaseKeyframe{properties: {'--animated-width': '0px', 'opacity': '0'}},
		BaseKeyframe{properties: {'--animated-width': '100px', 'opacity': '1'}},
	], KeyframeAnimationOptions{
		KeyframeEffectOptions: KeyframeEffectOptions{
			timing: OptionalEffectTiming{duration: IterationDuration(1000.0), fill: .none_}
		}
		timeline: timeline
	})!
	animation.update()
	assert (animation.current_time() or { panic('missing animation time') }).value == 0
	raw_effect := animation.effect_ or { panic('missing animation effect') }
	assert (raw_effect.transformed_progress() or { panic('missing progress') }) == 0
	assert animation_effects_for_style(voidptr(document), dom.AbstractElement.new(target, none)).len == 1
	document.needs_full_style_update = true
	document.update_style()
	assert animated_style_value(target, .opacity) == '0'
	timeline.set_current_time(TimeValue.milliseconds(500))
	assert document.needs_animated_style_update
	document.update_animated_style_if_needed()
	assert (css.computed_value_for(target, .width) or { panic('missing width') }) == '50px'
	assert animated_style_value(target, .opacity) == '0.5'
	data := dom.AbstractElement.new(target, none).custom_property_data() or { panic('missing custom property data') }
	assert data.is_animation_overlay()
	assert custom_style_value(target, '--animated-width') == '50px'
	animation.cancel()
	document.update_animated_style_if_needed()
	assert (css.computed_value_for(target, .width) or { panic('missing width') }) == '0px'
	assert animated_style_value(target, .opacity) == '1'
	if final_data := dom.AbstractElement.new(target, none).custom_property_data() {
		assert !final_data.is_animation_overlay()
	}
}

fn test_property_indexed_custom_animation_uses_discrete_case_sensitive_names() {
	mut document, target := connected_animation_target('--Color: blue; --color: yellow')!
	frames := process_property_indexed_keyframes(BasePropertyIndexedKeyframe{
		properties: {'--Color': ['red', 'green']}
	})!
	mut effect := KeyframeEffect.with_duration(target, frames, 100)!
	mut timeline := AnimationTimeline.new()
	timeline.current_time_ = TimeValue.milliseconds(0)
	mut animation := Animation.create(effect.as_animation_effect(), timeline)
	animation.start_time_ = TimeValue.milliseconds(0)
	timeline.set_current_time(TimeValue.milliseconds(25))
	document.update_animated_style_if_needed()
	assert custom_style_value(target, '--Color') == 'red'
	assert custom_style_value(target, '--color') == 'yellow'
	timeline.set_current_time(TimeValue.milliseconds(75))
	document.update_animated_style_if_needed()
	assert custom_style_value(target, '--Color') == 'green'
}

fn test_web_animation_effect_stack_composites_custom_and_standard_properties_in_order() {
	mut document, target := connected_animation_target('opacity: 1')!
	css.register_property_for_document(mut document, css.PropertyDefinition{
		name: '--n'
		syntax: '<number>'
		inherits: false
		initial_value: '10'
	})!
	mut timeline := AnimationTimeline.new()
	timeline.current_time_ = TimeValue.milliseconds(50)
	mut first_effect := KeyframeEffect.with_duration(target, [
		BaseKeyframe{properties: {'--n': '20', 'opacity': '0.2'}},
		BaseKeyframe{properties: {'--n': '30', 'opacity': '0.2'}},
	], 100)!
	mut first := Animation.create(first_effect.as_animation_effect(), timeline)
	first.start_time_ = TimeValue.milliseconds(0)
	mut second_effect := KeyframeEffect.with_duration(target, [
		BaseKeyframe{properties: {'--n': '2', 'opacity': '0.1'}},
		BaseKeyframe{properties: {'--n': '4', 'opacity': '0.1'}},
	], 100)!
	second_effect.set_composite(.add)
	mut second := Animation.create(second_effect.as_animation_effect(), timeline)
	second.start_time_ = TimeValue.milliseconds(0)
	document.update_animated_style_if_needed()
	assert custom_style_value(target, '--n') == '28'
	computed := animated_style_value(target, .opacity)
	assert computed.f64() > 0.299 && computed.f64() < 0.301
}

fn finished_custom_animation(target &dom.Element, timeline &AnimationTimeline, name string) !&Animation {
	mut effect := KeyframeEffect.construct_impl(target, [
		BaseKeyframe{properties: {name: 'red'}},
		BaseKeyframe{properties: {name: 'green'}},
	], KeyframeEffectOptions{
		timing: OptionalEffectTiming{duration: IterationDuration(100.0), fill: .both}
	})!
	mut animation := Animation.create(effect.as_animation_effect(), timeline)
	animation.start_time_ = TimeValue.milliseconds(0)
	return animation
}

fn test_replacement_coverage_includes_case_sensitive_custom_property_targets() {
	document, target := connected_animation_target('')!
	mut timeline := AnimationTimeline.new()
	timeline.monotonic_ = true
	timeline.current_time_ = TimeValue.milliseconds(100)
	first := finished_custom_animation(target, timeline, '--Color')!
	second := finished_custom_animation(target, timeline, '--color')!
	remove_replaced_animations_for_dom_root(voidptr(document), unsafe { &dom.Node(document) })
	assert first.replace_state() == .active
	assert second.replace_state() == .active
	third := finished_custom_animation(target, timeline, '--Color')!
	remove_replaced_animations_for_dom_root(voidptr(document), unsafe { &dom.Node(document) })
	assert first.replace_state() == .removed
	assert second.replace_state() == .active
	assert third.replace_state() == .active
}

fn test_registered_angle_list_neutral_add_and_iteration_accumulation() {
 for comma in [false,true] {
  for accumulate in [false,true] {
   mut document,target := connected_animation_target('')!
   defer { document.finalize() }
   separator := if comma { ', ' } else { ' ' }
   initial := if accumulate { '0deg'+separator+'0deg' } else { '50deg'+separator+'100deg' }
   css.register_property_for_document(mut document,css.PropertyDefinition{name:'--angles',syntax:if comma { '<angle>#' } else { '<angle>+' },inherits:false,initial_value:initial})!
   frames := if accumulate {
    [BaseKeyframe{properties:{'--angles':'0deg'+separator+'50deg'}},BaseKeyframe{properties:{'--angles':'100deg'+separator+'100deg'}}]
   } else { [BaseKeyframe{properties:{'--angles':'150deg'+separator+'200deg'}}] }
   mut effect := KeyframeEffect.construct_impl(target,frames,KeyframeEffectOptions{
    timing:OptionalEffectTiming{duration:IterationDuration(1000.0),iterations:3,fill:.both}
    composite:if accumulate { .replace } else { .add }
    iteration_composite_accumulate:accumulate
   })!
   mut timeline := AnimationTimeline.new()
   timeline.current_time_ = TimeValue.milliseconds(2500)
   mut animation := Animation.create(effect.as_animation_effect(),timeline)
   animation.start_time_ = TimeValue.milliseconds(0)
   animation.update()
   document.needs_full_style_update = true
   document.update_style()
   actual := custom_style_value(target,'--angles')
   expected := if accumulate { '250deg'+separator+'275deg' } else { '125deg'+separator+'200deg' }
   assert actual == expected,actual
  }
 }
}

fn iteration_animation(target &dom.Element, timeline &AnimationTimeline, frames []BaseKeyframe, composite css.CompositeOperation) !&Animation {
	mut effect := KeyframeEffect.construct_impl(target, frames, KeyframeEffectOptions{
		timing: OptionalEffectTiming{duration: IterationDuration(1000.0), iterations: 10, fill: .both}
		composite: match composite { .replace { CompositeOperation.replace } .add { CompositeOperation.add } .accumulate { CompositeOperation.accumulate } }
		iteration_composite_accumulate: true
	})!
	mut animation := Animation.create(effect.as_animation_effect(), timeline)
	animation.start_time_ = TimeValue.milliseconds(0)
	return animation
}

fn test_iteration_composition_accumulates_ordinary_numeric_properties() {
	mut document, target := connected_animation_target('')!
	defer { document.finalize() }
	mut timeline := AnimationTimeline.new()
	mut animation := iteration_animation(target, timeline, [
		BaseKeyframe{properties: {'margin-left': '10px', 'flex-grow': '0', 'opacity': '0'}},
		BaseKeyframe{properties: {'margin-left': '20px', 'flex-grow': '10', 'opacity': '0.4'}},
	], .replace)!
	for index, sample in [500.0, 2000, 2500] {
		timeline.set_current_time(TimeValue.milliseconds(sample))
		animation.update()
		document.update_animated_style_if_needed()
		assert animated_style_value(target, .margin_left) == ['15px', '50px', '55px'][index]
		assert animated_style_value(target, .flex_grow) == ['5', '20', '25'][index]
		assert animated_style_value(target, .opacity).f64() == [0.2, 0.8, 1.0][index]
	}
}

fn test_iteration_composition_preserves_unresolved_percentage_components() {
	mut document, target := connected_animation_target('')!
	defer { document.finalize() }
	mut timeline := AnimationTimeline.new()
	mut animation := iteration_animation(target, timeline, [
		BaseKeyframe{properties: {'margin-left': 'calc(10% + 5px)'}},
		BaseKeyframe{properties: {'margin-left': 'calc(20% + 10px)'}},
	], .replace)!
	timeline.set_current_time(TimeValue.milliseconds(2500))
	animation.update()
	document.update_animated_style_if_needed()
	assert animated_style_value(target, .margin_left) == 'calc(55% + 27.5px)'
}

fn test_iteration_composition_keeps_color_endpoints_unclamped_until_sampling() {
	mut document, target := connected_animation_target('')!
	defer { document.finalize() }
	mut timeline := AnimationTimeline.new()
	mut animation := iteration_animation(target, timeline, [
		BaseKeyframe{properties: {'color': 'rgb(0, 120, 0)'}},
		BaseKeyframe{properties: {'color': 'rgb(60, 60, 60)'}},
	], .replace)!
	timeline.set_current_time(TimeValue.milliseconds(2500))
	animation.update()
	document.update_animated_style_if_needed()
	assert animated_style_value(target, .color) == 'rgb(150, 210, 150)'
}

fn test_iteration_composition_adds_after_underlying_keyframe_composition() {
	mut document, target := connected_animation_target('margin-left:5px')!
	defer { document.finalize() }
	mut timeline := AnimationTimeline.new()
	mut animation := iteration_animation(target, timeline, [
		BaseKeyframe{properties: {'margin-left': '10px'}},
		BaseKeyframe{properties: {'margin-left': '20px'}},
	], .add)!
	timeline.set_current_time(TimeValue.milliseconds(2500))
	animation.update()
	document.update_animated_style_if_needed()
	assert animated_style_value(target, .margin_left) == '60px'
}

fn test_iteration_composition_keeps_discrete_values_and_filter_identity() {
	mut document, target := connected_animation_target('')!
	defer { document.finalize() }
	mut timeline := AnimationTimeline.new()
	mut animation := iteration_animation(target, timeline, [
		BaseKeyframe{properties: {'border-top-style': 'solid', 'filter': 'brightness(0)'}},
		BaseKeyframe{properties: {'border-top-style': 'dashed', 'filter': 'brightness(1)'}},
	], .replace)!
	for index, sample in [2000.0, 2500] {
		timeline.set_current_time(TimeValue.milliseconds(sample))
		animation.update()
		document.update_animated_style_if_needed()
		assert animated_style_value(target, .border_top_style) == ['solid', 'dashed'][index]
		assert animated_style_value(target, .filter) == ['brightness(0)', 'brightness(0.5)'][index]
	}
}

fn test_iteration_composition_uses_the_final_keyframe_for_interior_intervals() {
	mut document, target := connected_animation_target('')!
	defer { document.finalize() }
	mut timeline := AnimationTimeline.new()
	mut animation := iteration_animation(target, timeline, [
		BaseKeyframe{offset: 0, properties: {'margin-left': '0px'}},
		BaseKeyframe{offset: 0.5, properties: {'margin-left': '100px'}},
		BaseKeyframe{offset: 1, properties: {'margin-left': '10px'}},
	], .replace)!
	timeline.set_current_time(TimeValue.milliseconds(2250))
	animation.update()
	document.update_animated_style_if_needed()
	assert animated_style_value(target, .margin_left) == '70px'
}

fn test_drop_shadow_iteration_composition_clamps_color_after_interpolation() {
	mut document, target := connected_animation_target('')!
	defer { document.finalize() }
	mut timeline := AnimationTimeline.new()
	mut animation := iteration_animation(target, timeline, [
		BaseKeyframe{properties: {'filter': 'drop-shadow(rgb(0, 0, 0) 0px 0px 0px)'}},
		BaseKeyframe{properties: {'filter': 'drop-shadow(rgb(120, 120, 120) 10px 10px 10px)'}},
	], .replace)!
	timeline.set_current_time(TimeValue.milliseconds(2500))
	animation.update()
	document.update_animated_style_if_needed()
	assert animated_style_value(target, .filter) == 'drop-shadow(rgb(255, 255, 255) 25px 25px 25px)'
}

fn test_drop_shadow_accumulation_uses_premultiplied_color_channels() {
	mut document, target := connected_animation_target('filter:drop-shadow(rgba(100,20,0,0.5) 4px 6px)')!
	defer { document.finalize() }
	mut timeline := AnimationTimeline.new()
	mut animation := iteration_animation(target, timeline, [
		BaseKeyframe{properties: {'filter': 'drop-shadow(rgba(0,0,100,0.5) 2px 4px)'}},
		BaseKeyframe{properties: {'filter': 'drop-shadow(rgba(0,0,100,0.5) 2px 4px)'}},
	], .accumulate)!
	timeline.set_current_time(TimeValue.milliseconds(500))
	animation.update()
	document.update_animated_style_if_needed()
	assert animated_style_value(target, .filter) == 'drop-shadow(rgb(50, 10, 50) 6px 10px)'
}

fn transform_at(frames []BaseKeyframe, underlying string, composite css.CompositeOperation, milliseconds f64) !string {
	mut document, target := connected_animation_target(underlying)!
	defer { document.finalize() }
	mut timeline := AnimationTimeline.new()
	mut animation := iteration_animation(target, timeline, frames, composite)!
	timeline.set_current_time(TimeValue.milliseconds(milliseconds))
	animation.update()
	document.update_animated_style_if_needed()
	return animated_style_value(target, .transform)
}

fn transform_frames(from string, to string) []BaseKeyframe {
	return [BaseKeyframe{properties: {'transform': from}}, BaseKeyframe{properties: {'transform': to}}]
}

fn test_transform_iteration_composition_accumulates_matching_functions() {
	// Scale factors accumulate as Va + Vb - 1; other arguments add.
	assert transform_at(transform_frames('scale(1)', 'scale(2)'), '', .replace, 2000)! == 'scale(3, 3)'
	assert transform_at(transform_frames('scale(1)', 'scale(2)'), '', .replace, 2500)! == 'scale(3.5, 3.5)'
	assert transform_at(transform_frames('scale(0)', 'scale(2)'), '', .replace, 2500)! == 'scale(3, 3)'
	assert transform_at(transform_frames('none', 'translateX(10px)'), '', .replace, 2500)! == 'translate(25px, 0px)'
	assert transform_at(transform_frames('rotate3d(1, 1, 0, 0deg)', 'rotate3d(1, 1, 0, 90deg)'), '', .replace, 2500)! == 'rotate3d(0.707107, 0.707107, 0, 225deg)'
}

fn test_transform_iteration_composition_accumulates_mismatched_lists_as_matrices() {
	// The final list's matrix is accumulated once per iteration, even when the
	// final list itself would accumulate function by function.
	frames := transform_frames('translateX(0px) scale(2)', 'scale(3) translateX(10px)')
	assert transform_at(frames, '', .replace, 2000)! == 'matrix3d(6, 0, 0, 0, 0, 6, 0, 0, 0, 0, 1, 0, 60, 0, 0, 1)'
	assert transform_at(frames, '', .replace, 2500)! == 'matrix3d(6.5, 0, 0, 0, 0, 6.5, 0, 0, 0, 0, 1, 0, 135, 0, 0, 1)'
	assert transform_at(transform_frames('translateX(0px)', 'scale(2) translateX(10px)'), '', .replace, 2500)! == 'matrix3d(3.5, 0, 0, 0, 0, 3.5, 0, 0, 0, 0, 1, 0, 80, 0, 0, 1)'
	assert transform_at(transform_frames('matrix3d(1,0,0,0,0,1,0,0,0,0,1,0,0,0,30,1)', 'matrix3d(1,0,0,0,0,1,0,0,0,0,1,0,0,0,50,1)'), '', .replace, 2500)! == 'matrix3d(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 140, 1)'
}

fn test_transform_keyframe_composition_adds_and_accumulates_lists() {
	frames := transform_frames('rotate(90deg)', 'rotate(90deg)')
	assert transform_at(frames, 'transform: translateX(10px)', .add, 0)! == 'translate(10px, 0px) rotate(90deg)'
	assert transform_at(transform_frames('scale(2) rotate(90deg)', 'scale(2) rotate(90deg)'), 'transform: scale(3) translateX(10px)', .accumulate, 0)! == 'scale(4, 4) matrix3d(0, 1, 0, 0, -1, 0, 0, 0, 0, 0, 1, 0, 10, 0, 0, 1)'
	assert transform_at(transform_frames('rotate(90deg) scale(2)', 'rotate(90deg) scale(2)'), 'transform: scale(3) translateX(10px)', .accumulate, 0)! == 'matrix3d(0, 4, 0, 0, -4, 0, 0, 0, 0, 0, 1, 0, 30, 0, 0, 1)'
}

fn box_shadow_at(from string, to string, underlying string, composite css.CompositeOperation, milliseconds f64) !string {
	mut document, target := connected_animation_target(underlying)!
	defer { document.finalize() }
	mut timeline := AnimationTimeline.new()
	mut animation := iteration_animation(target, timeline, [
		BaseKeyframe{properties: {'box-shadow': from}},
		BaseKeyframe{properties: {'box-shadow': to}},
	], composite)!
	timeline.set_current_time(TimeValue.milliseconds(milliseconds))
	animation.update()
	document.update_animated_style_if_needed()
	return animated_style_value(target, .box_shadow)
}

fn test_box_shadow_iteration_composition_accumulates_and_clamps_after_sampling() {
	from := 'rgb(0, 0, 0) 0px 0px 0px 0px'
	to := 'rgb(120, 120, 120) 10px 10px 10px 0px'
	assert box_shadow_at(from, to, '', .replace, 2000)! == 'rgb(240, 240, 240) 20px 20px 20px 0px'
	assert box_shadow_at(from, to, '', .replace, 2500)! == 'rgb(255, 255, 255) 25px 25px 25px 0px'
}

fn test_box_shadow_keyframe_composition_adds_and_accumulates_lists() {
	shadow := 'rgb(120, 120, 120) 10px 10px 10px 0px'
	assert box_shadow_at(shadow, shadow, 'box-shadow: rgb(0, 0, 0) 0px 0px 0px 0px', .add, 0)! == 'rgb(0, 0, 0) 0px 0px 0px 0px, rgb(120, 120, 120) 10px 10px 10px 0px'
	assert box_shadow_at(shadow, shadow, 'box-shadow: ${shadow}', .accumulate, 0)! == 'rgb(240, 240, 240) 20px 20px 20px 0px'
	// Shadows with different inset keywords cannot accumulate and replace.
	assert box_shadow_at(shadow, shadow, 'box-shadow: ${shadow} inset', .accumulate, 0)! == shadow
	// The shorter list is padded with transparent blank shadows.
	list := 'rgb(10, 20, 30) 1px 2px 3px 4px, rgb(0, 0, 0) 5px 5px'
	assert box_shadow_at(list, list, 'box-shadow: rgb(100, 100, 100) 10px 10px 10px 10px', .accumulate, 0)! == 'rgb(110, 120, 130) 11px 12px 13px 14px, rgb(0, 0, 0) 5px 5px 0px 0px'
}

fn filter_at(from string, to string, milliseconds f64) !string {
	mut document, target := connected_animation_target('')!
	defer { document.finalize() }
	mut timeline := AnimationTimeline.new()
	mut animation := iteration_animation(target, timeline, [
		BaseKeyframe{properties: {'filter': from}},
		BaseKeyframe{properties: {'filter': to}},
	], .replace)!
	timeline.set_current_time(TimeValue.milliseconds(milliseconds))
	animation.update()
	document.update_animated_style_if_needed()
	return animated_style_value(target, .filter)
}

fn test_filter_lists_with_mismatched_functions_are_discrete() {
	from := 'brightness(1) contrast(1)'
	to := 'contrast(2) brightness(2)'
	assert filter_at(from, to, 500)! == to
	// The final list cannot accumulate onto the mismatched first list.
	assert filter_at(from, to, 2000)! == from
	assert filter_at(from, to, 2500)! == 'contrast(4) brightness(4)'
	assert filter_at('brightness(1) contrast(1)', 'brightness(2) contrast(2)', 500)! == 'brightness(1.5) contrast(1.5)'
}
