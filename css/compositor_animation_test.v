module css

import dom

fn test_completed_scroll_effect_keeps_compositor_identity_for_reverse_scrolling() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	add_document_author_style_sheet(document, '@keyframes move{from{transform:translateX(0)}to{transform:translateX(40px)}}div{animation:move 1s linear}')
	mut element := document.create_element('div') or { panic(err) }
	mut computer := css_style_computer_for(document)
	target := dom.AbstractElement.new(element, none)
	_ = computer.compute_style(target)
	assert computer.css_animation_storage_.entries.len == 1
	mut animation := computer.css_animation_storage_.entries[0].animation
	_ = animation.sample_at(0)
	_ = animation.sample_at(2000)
	assert animation.effect_.current_phase == .after
	assert animation.effect_.output_progress == none
	assert !compositor_animation_properties(target).transform
	mut timeline := &AnimationTimeline{kind: .scroll}
	animation.set_timeline(timeline)
	timeline.update_current_time(2000)
	assert animation.sample_at(2000) == none
	assert animation.effect_.current_phase == .after
	assert compositor_animation_properties(target).transform
	timeline.update_current_time(500)
	assert animation.sample_at(2000) or { -1 } == 0.5
	assert compositor_animation_properties(target).transform
}

fn test_delayed_unfilled_effect_keeps_its_future_compositor_surface() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	add_document_author_style_sheet(document, '@keyframes fade{from{opacity:1}to{opacity:.5}}div{animation:fade 1s 1s linear}')
	mut element := document.create_element('div') or { panic(err) }
	mut computer := css_style_computer_for(document)
	target := dom.AbstractElement.new(element, none)
	_ = computer.compute_style(target)
	mut animation := computer.css_animation_storage_.entries[0].animation
	_ = animation.sample_at(0)
	_ = animation.sample_at(500)
	assert animation.effect_.current_phase == .before
	assert animation.effect_.output_progress == none
	assert compositor_animation_properties(target).opacity
	_ = animation.sample_at(2500)
	assert !compositor_animation_properties(target).opacity
}
