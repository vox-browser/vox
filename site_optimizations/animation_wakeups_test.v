module main

import css
import dom
import animations

fn site_wakeup_fixture(extra string) &dom.Document {
	mut document := parse_browser_navigation_document('<!doctype html><style>html,body{margin:0}@keyframes prc-Skeleton-shimmer---lzU{from{mask-position:200%}to{mask-position:0}}.prc-Skeleton-SkeletonBox-e93nW{width:100px;height:14px;mask-image:linear-gradient(75deg,black,transparent);animation:prc-Skeleton-shimmer---lzU 1s linear infinite}${extra}</style><div style="height:900px"></div><div id="skeleton" class="prc-Skeleton-SkeletonBox-e93nW"></div>', dom.URL{ value: 'https://github.com/vlang/v' }, none)
	mut app := BrowserApp{ document: document, viewport_width: 320, viewport_height: 200 }
	app.relayout(320, 200 + app.chrome_height())
	document.update_animations_and_send_events(500)
	document.update_layout(.debugging)
	return document
}

fn test_github_offscreen_skeleton_keeps_timeline_and_resumes_visible_wakeups() {
	mut document := site_wakeup_fixture('')
	defer { document.finalize() }
	assert css.document_has_running_css_animations(document)
	backdrop := BrowserApp{ document: document, paint_commands_have_backdrop_filter: true }
	assert backdrop.site_animation_wakeup_delay_for_frame() == if disable_github_animation_wakeup_throttling { 16 } else { -1 }
	assert site_animation_wakeup_delay(document) == if disable_github_animation_wakeup_throttling {
		16
	} else {
		-1
	}
	record := css.document_css_animations(document).filter(it.name == 'prc-Skeleton-shimmer---lzU')[0]
	assert css.document_css_animation_current_time(document, record.handle)? == 500
	viewport := document.viewport_rect()
	document.set_viewport_rect(dom.Rect{viewport.x, 850, viewport.width, viewport.height})
	document.update_animations_and_send_events(750)
	document.update_layout(.debugging)
	assert site_animation_wakeup_delay(document) == 16
	assert css.document_css_animation_current_time(document, record.handle)? == 750
	assert css.document_css_animations(document)[0].play_state == 'running'
	document.url = dom.URL{ value: 'https://example.org/' }
	assert site_animation_wakeup_delay(document) == 16
}

fn test_github_offscreen_skeleton_retains_observed_iteration_boundary() {
	mut document := site_wakeup_fixture('')
	defer { document.finalize() }
	target := document.get_element_by_id('skeleton')?
	unsafe { &dom.EventTarget(document.as_node()) }.add_event_listener_without_options('animationiteration', dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			return dom.js_undefined()
		}
	}))
	assert target.as_node().has_inclusive_ancestor_with_event_listener('animationiteration')
	assert site_animation_wakeup_delay(document) == if disable_github_animation_wakeup_throttling {
		16
	} else {
		500
	}
}

fn test_github_animation_wakeup_retains_unreviewed_ink_effects_and_finite_animations() {
	for extra in ['.prc-Skeleton-SkeletonBox-e93nW{filter:blur(10px)}',
		'.prc-Skeleton-SkeletonBox-e93nW{transform:translateY(-500px)}',
		'.prc-Skeleton-SkeletonBox-e93nW{box-shadow:0 -900px red}',
		'.prc-Skeleton-SkeletonBox-e93nW{mask-clip:no-clip}',
		'.prc-Skeleton-SkeletonBox-e93nW{outline:solid 200px red}', 'body{filter:blur(900px)}',
		'.prc-Skeleton-SkeletonBox-e93nW{animation-iteration-count:1}',
		'@keyframes prc-Skeleton-shimmer---lzU{from{width:100px}to{width:200px}}'] {
		mut document := site_wakeup_fixture(extra)
		assert site_animation_wakeup_delay(document) == 16, extra
		document.finalize()
	}
}

fn test_github_scroll_animation_waits_for_input_instead_of_wall_time() {
	mut document := parse_browser_navigation_document('<!doctype html><style>@keyframes progress{from{opacity:0.2}to{opacity:1}}#nav{overflow:auto;width:100px;height:20px;animation:progress 1ms linear both;animation-timeline:scroll(self);scrollbar-width:none}#nav span{display:block;width:300px;height:100px}</style><div id="nav"><span>scroll me</span></div>', dom.URL{ value: 'https://github.com/vlang/v' }, none)
	defer { document.finalize() }
	mut app := BrowserApp{ document: document }
	app.relayout(320, 312)
	record := css.document_css_animations(document).filter(it.name == 'progress')[0]
	animation := unsafe { &css.CSSAnimation(record.handle) }
	timeline := animation.timeline_?
	assert timeline.kind == .scroll
	assert site_animation_wakeup_delay(document) == if disable_github_animation_wakeup_throttling {
		16
	} else {
		-1
	}
}

fn test_github_completed_finite_effect_does_not_keep_waking_offscreen_skeletons() {
	mut document := site_wakeup_fixture('@keyframes pulse-in{from{opacity:0.2}to{opacity:1}}body{animation:pulse-in 1s both}')
	defer { document.finalize() }
	document.update_animations_and_send_events(750)
	document.update_layout(.debugging)
	assert site_animation_wakeup_delay(document) == 16
	document.update_animations_and_send_events(1500)
	document.update_layout(.debugging)
	record := css.document_css_animations(document).filter(it.name == 'pulse-in')[0]
	animation := unsafe { &css.CSSAnimation(record.handle) }
	assert animation.effect_.current_phase == .after
	assert record.play_state == 'running'
	assert site_animation_wakeup_delay(document) == if disable_github_animation_wakeup_throttling { 16 } else { -1 }
	// A script seek can make the visible effect active again.
	assert css.document_css_animation_set_current_time(document, record.handle, 250)
	document.update_animations_and_send_events(1500)
	document.update_layout(.debugging)
	assert site_animation_wakeup_delay(document) == 16
}

fn test_github_empty_animation_target_registry_keeps_relevant_effects_conservative() {
	mut document := site_wakeup_fixture('')
	defer { document.finalize() }
	target := document.get_element_by_id('skeleton')?
	_ = animations.Animatable.new(target)
	hook := document.animations_hook_?
	assert hook.effect_targets(hook.target).len > 0
	assert site_animation_wakeup_delay(document) == if disable_github_animation_wakeup_throttling { 16 } else { -1 }
	document.set_animations_hook(dom.DocumentAnimationsHook{
		target: hook.target
		effect_targets: hook.effect_targets
		calculate_get_animations: fn (_ voidptr, _ &dom.Node) ![]&dom.Animation {
			return [&dom.Animation{ concrete_kind_: .web_animation }]
		}
	})
	assert site_animation_wakeup_delay(document) == 16
}

fn test_github_backdrop_dependencies_keep_only_interacting_effects_awake() {
	for extra in ['body::before{content:"";position:fixed;left:0;top:0;width:100px;height:20px;backdrop-filter:blur(5px)}',
		'body::before{content:"";position:fixed;left:0;top:0;width:100px;height:20px;backdrop-filter:blur(5px);transform:scale(2)}',
		'body::before{content:"";position:fixed;inset:0;backdrop-filter:blur(500px);opacity:0}',
		'body::before{content:"";position:fixed;inset:0;backdrop-filter:blur(500px);visibility:hidden}'] {
		mut document := site_wakeup_fixture(extra)
		app := BrowserApp{document: document, paint_commands_have_backdrop_filter: true}
		assert app.site_animation_wakeup_delay_for_frame() == if disable_github_animation_wakeup_throttling {16} else {-1}, extra
		document.finalize()
	}
	for extra in ['body{backdrop-filter:blur(500px)}',
		'body::before{content:"";position:fixed;left:0;bottom:0;width:100px;height:20px;backdrop-filter:blur(100px)}',
		'body::before{content:"";position:fixed;left:0;top:0;width:100px;height:20px;backdrop-filter:blur(5px);transform:rotate(15deg)}',
		'body::before{content:"";position:fixed;left:0;top:0;width:100px;height:20px;backdrop-filter:drop-shadow(0 0 1px black)}'] {
		mut document := site_wakeup_fixture(extra)
		app := BrowserApp{document: document, paint_commands_have_backdrop_filter: true}
		assert app.site_animation_wakeup_delay_for_frame() == 16, extra
		document.finalize()
	}
	mut fresh := site_wakeup_fixture('body{backdrop-filter:blur(500px)}')
	defer { fresh.finalize() }
	// The app has not adopted the new filter's display list yet.
	app := BrowserApp{document: fresh, paint_commands_have_backdrop_filter: false}
	assert app.site_animation_wakeup_delay_for_frame() == 16
}
