module layout

import animations
import html
import painting

fn test_svg_animated_stop_replaces_retained_gradient_colors_and_restores_them_on_cancel() {
	for hidden in [false, true] {
		wrapper := if hidden { '<defs style="display:none">' } else { '' }
		end := if hidden { '</defs>' } else { '' }
		mut document := html.parse_document('<!doctype html><style>body{margin:0}svg{display:block}</style><svg width="100" height="100">${wrapper}<linearGradient id="paint"><stop id="stop" offset="0" stop-color="red"/><stop offset="1" stop-color="green"/></linearGradient>${end}<rect width="100" height="100" fill="url(#paint)"/></svg>')
		document.set_font_rendering_policy(.chromium)
		_ = layout_document_typed_in_viewport(document, 100, 100)
		first := display_list_commands(document.record_display_list() or { panic('original recording') }).filter(it.kind == 'draw_svg_path')[0]
		original := first.fill_linear_gradient() or { panic('original gradient') }
		assert original.gradient.color_stops[0].color == painting.Color{255, 0, 0, 255}
		stop := document.get_element_by_id('stop') or { panic('stop') }
		mut timeline := animations.AnimationTimeline.new()
		timeline.monotonic_ = true
		timeline.current_time_ = animations.TimeValue.milliseconds(0)
		mut animatable := animations.Animatable.new(stop)
		mut animation := animatable.animate([
			animations.BaseKeyframe{properties: {'stopColor': 'red'}},
			animations.BaseKeyframe{properties: {'stopColor': 'green'}},
		], animations.KeyframeAnimationOptions{
			KeyframeEffectOptions: animations.KeyframeEffectOptions{
				timing: animations.OptionalEffectTiming{duration: animations.IterationDuration(50.0), fill: .forwards}
			}
			timeline: timeline
		}) or { panic(err) }
		animation.update()
		timeline.set_current_time(animations.TimeValue.milliseconds(100))
		document.update_layout(.dump_display_list)
		updated := display_list_commands(document.record_display_list() or { panic('updated recording') }).filter(it.kind == 'draw_svg_path')[0].fill_linear_gradient() or { panic('updated gradient') }
		assert updated.gradient.color_stops[0].color == painting.Color{0, 128, 0, 255}, 'hidden=${hidden}'
		assert original.gradient.color_stops[0].color == painting.Color{255, 0, 0, 255}
		animation.cancel()
		document.update_layout(.dump_display_list)
		restored := display_list_commands(document.record_display_list() or { panic('restored recording') }).filter(it.kind == 'draw_svg_path')[0].fill_linear_gradient() or { panic('restored gradient') }
		assert restored.gradient.color_stops[0].color == painting.Color{255, 0, 0, 255}
		document.finalize()
	}
}
