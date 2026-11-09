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
	assert frames[0].parsed_custom_properties['--MixedCase'].css_text == 'red'
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
