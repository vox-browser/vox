module main

import css
import dom
import animations

fn site_wakeup_fixture(extra string) &dom.Document {
	mut document := parse_browser_navigation_document('<!doctype html><style>html,body{margin:0}@keyframes prc-Skeleton-shimmer---lzU{from{mask-position:200%}to{mask-position:0}}.prc-Skeleton-SkeletonBox-e93nW{width:100px;height:14px;mask-image:linear-gradient(75deg,black,transparent);animation:prc-Skeleton-shimmer---lzU 1s linear infinite}${extra}</style><div style="height:900px"></div><div id="skeleton" class="prc-Skeleton-SkeletonBox-e93nW"></div>', dom.URL{value:'https://github.com/vlang/v'}, none)
	mut app := BrowserApp{document:document,viewport_width:320,viewport_height:200}
	app.relayout(320,200+app.chrome_height())
	document.update_animations_and_send_events(500)
	document.update_layout(.debugging)
	return document
}

fn test_github_active_effects_keep_grants_in_every_visibility_state() {
	for extra in ['', '.prc-Skeleton-SkeletonBox-e93nW{position:fixed;top:0}',
		'body{backdrop-filter:blur(500px)}', 'body{transform:scale(2)}'] {
		mut document := site_wakeup_fixture(extra)
		app := BrowserApp{document:document}
		assert app.site_animation_wakeup_delay_for_frame() == 16, extra
		document.finalize()
	}
}

fn test_github_completed_effect_keeps_clock_and_can_seek_back_into_activity() {
	mut document := site_wakeup_fixture('.prc-Skeleton-SkeletonBox-e93nW{animation-duration:0s;animation-iteration-count:1}body{backdrop-filter:blur(500px)}')
	defer { document.finalize() }
	assert css.document_has_running_css_animations(document)
	assert site_animation_wakeup_delay(document) == if disable_github_animation_wakeup_throttling {16} else {-1}
	record := css.document_css_animations(document)[0]
	assert css.document_css_animation_current_time(document,record.handle)? == 500
	document.update_animations_and_send_events(750)
	document.update_layout(.debugging)
	assert css.document_css_animation_current_time(document,record.handle)? == 750
	assert css.document_css_animation_set_current_time(document,record.handle,-250)
	document.update_animations_and_send_events(750)
	document.update_layout(.debugging)
	assert site_animation_wakeup_delay(document) == 16
	document.url = dom.URL{value:'https://example.org/'}
	assert site_animation_wakeup_delay(document) == 16
}

fn test_github_scroll_animation_waits_for_input_instead_of_wall_time() {
	mut document := parse_browser_navigation_document('<!doctype html><style>@keyframes progress{from{opacity:0.2}to{opacity:1}}#nav{overflow:auto;width:100px;height:20px;animation:progress 1ms linear both;animation-timeline:scroll(self);scrollbar-width:none}#nav span{display:block;width:300px;height:100px}</style><div id="nav"><span>scroll me</span></div>',dom.URL{value:'https://github.com/vlang/v'},none)
	defer { document.finalize() }
	mut app := BrowserApp{document:document}
	app.relayout(320,312)
	record := css.document_css_animations(document).filter(it.name=='progress')[0]
	animation := unsafe { &css.CSSAnimation(record.handle) }
	assert animation.timeline_?.kind == .scroll
	assert site_animation_wakeup_delay(document) == if disable_github_animation_wakeup_throttling {16} else {-1}
}

fn test_github_empty_animation_registry_keeps_relevant_web_effects_conservative() {
	mut document := site_wakeup_fixture('.prc-Skeleton-SkeletonBox-e93nW{animation-duration:0s;animation-iteration-count:1}')
	defer { document.finalize() }
	target := document.get_element_by_id('skeleton')?
	_ = animations.Animatable.new(target)
	hook := document.animations_hook_?
	assert hook.effect_targets(hook.target).len > 0
	assert site_animation_wakeup_delay(document) == if disable_github_animation_wakeup_throttling {16} else {-1}
	document.set_animations_hook(dom.DocumentAnimationsHook{
		target:hook.target
		effect_targets:hook.effect_targets
		calculate_get_animations:fn (_ voidptr,_ &dom.Node) ![]&dom.Animation {
			return [&dom.Animation{concrete_kind_:.web_animation}]
		}
	})
	assert site_animation_wakeup_delay(document) == 16
}
