module main

import css
import dom
import math
import os
import platform

const disable_github_animation_wakeup_throttling = os.getenv('VOX_DISABLE_GITHUB_ANIMATION_WAKEUP_THROTTLING') != ''
const github_animation_wakeup_diagnostics = os.getenv('VOX_GITHUB_ANIMATION_WAKEUP_DIAGNOSTICS') != ''

fn (app &BrowserApp) site_animation_wakeup_delay_for_frame() int {
	if app.document == unsafe { nil } || app.paint_commands_have_backdrop_filter { return 16 }
	return site_animation_wakeup_delay(app.document)
}

// This controls native display grants, never animation sampling or clocks.
// Input, script tasks, screenshots and scrolling still grant normal rendering
// opportunities, at which every effect samples the current document timeline.
fn site_animation_wakeup_delay(document &dom.Document) int {
	if disable_github_animation_wakeup_throttling
		|| !site_batches_image_completion_layout(document.url.serialize()) {
		return 16
	}
	if hook := document.animations_hook_ {
		if hook.effect_targets != unsafe { nil } && hook.effect_targets(hook.target).len > 0 {
			return 16
		}
	}
	if !document.layout_is_up_to_date() { return 16 }
	// Client rectangles consume the current scroll snapshot and visual contexts.
	// A scroll can leave both stale even though layout geometry is still valid.
	mut current_document := unsafe { &dom.Document(document) }
	current_document.update_paint_and_hit_testing_properties_if_needed()
	workspace := platform.begin_thread_scratch('site animation wakeups')
	records := css.document_css_animations(document)
	workspace.leave()
	defer { workspace.finish() }
	mut delay := -1
	for record in records {
		if record.play_state != 'running' { continue }
		if record.is_transition { return 16 }
		animation := unsafe { &css.CSSAnimation(record.handle) }
		if timeline := animation.timeline_ {
			// A scroll timeline advances with scrolling or geometry, both of
			// which already request a display grant. Wall time cannot advance it.
			if timeline.kind == .scroll { continue }
		}
		if !site_offscreen_skeleton_animation(document, record, animation) { return 16 }
		mut observed := false
		for event_name in ['animationiteration', 'webkitAnimationIteration'] {
			if record.element.as_node().has_inclusive_ancestor_with_event_listener(event_name) {
				observed = true
			}
		}
		if observed {
			// The effect is infinite and already active. Its next iteration is
			// the next observable boundary; no visual update is needed meanwhile.
			duration := animation.effect_.specified_iteration_duration
			current := css.document_css_animation_current_time(document, record.handle) or { return 16 }
			active := current - animation.effect_.specified_start_delay
			if active < 0 || !math.is_finite(active) { return 16 }
			next := int(math.ceil(duration - math.fmod(active, duration)))
			if next <= 16 { return 16 }
			if delay < 0 || next < delay { delay = next }
		}
	}
	if github_animation_wakeup_diagnostics && delay != 16 {
		eprintln('Vox site animation wakeup: delay_ms=${delay}')
	}
	return delay
}

fn site_offscreen_skeleton_animation(document &dom.Document, record css.DocumentCSSAnimation,
	animation &css.CSSAnimation) bool {
	if !document.layout_is_up_to_date() || record.pseudo_element != ''
		|| record.name != 'prc-Skeleton-shimmer---lzU'
		|| record.element.namespace_uri() or { '' } != 'http://www.w3.org/1999/xhtml'
		|| record.element.as_node().children.len != 0
		|| 'prc-Skeleton-SkeletonBox-e93nW' !in record.element.get_attribute_value('class').split_any(' \t\r\n') {
		return false
	}
	effect := animation.effect_
	if effect == unsafe { nil } || effect.current_phase != .active
		|| !math.is_inf(effect.iteration_count, 1)
		|| !math.is_finite(effect.specified_iteration_duration) || effect.specified_iteration_duration <= 0 {
		return false
	}
	keyframes := effect.key_frame_set or { return false }
	mut has_position := false
	for _, keyframe in keyframes.keyframes_by_key {
		if keyframe.custom_properties.len > 0 || keyframe.use_initial_custom_properties.len > 0 {
			return false
		}
		for property, _ in keyframe.properties {
			if property != .mask_position { return false }
			has_position = true
		}
		for property, _ in keyframe.use_initial_properties {
			if property != .mask_position { return false }
			has_position = true
		}
	}
	if !has_position { return false }
	style := css.computed_properties_for_element(record.element) or { return false }
	for property in [css.PropertyID.transform, .filter, .box_shadow] {
		value := style.property(property, .no) or { return false }
		if value.css_text != 'none' { return false }
	}
	clip := style.property(.mask_clip, .no) or { return false }
	if clip.css_text != 'border-box' { return false }
	outline := style.property(.outline_style, .no) or { return false }
	if outline.css_text != 'none' { return false }
	mut ancestor := record.element.as_node().parent_element()
	for ancestor != none {
		parent := ancestor or { break }
		parent_style := css.computed_properties_for_element(parent) or { return false }
		filter := parent_style.property(.filter, .no) or { return false }
		if filter.css_text != 'none' { return false }
		ancestor = parent.as_node().parent_element()
	}
	rects := record.element.client_rects_assuming_layout_clean()
	if rects.len != 1 || rects[0].width_ <= 0 || rects[0].height_ <= 0 { return false }
	r := rects[0]
	viewport := document.viewport_rect()
	// The reviewed empty skeleton's mask is clipped to its border box. Keep a
	// generous fringe and reject effects whose ink could escape that box.
	return r.y_ > viewport.height + 32 || r.y_ + r.height_ < -32
		|| r.x_ > viewport.width + 32 || r.x_ + r.width_ < -32
}
