module layout

import css
import dom
import html
import painting

fn test_svg_background_preserves_optional_natural_dimensions_during_css_sizing() {
	mut embedder := html.parse_document('<!doctype html>')
	defer { embedder.finalize() }
	attributes := [
		'viewBox="0 0 200 100"',
		'width="100" viewBox="0 0 200 100"',
		'height="40" viewBox="0 0 200 100"',
		'width="100"', '',
		'width="100%" height="100%" viewBox="0 0 200 100"',
		'width="100" height="40" viewBox="0 0 200 100"',
	]
	expected := [painting.Rect{0,0,120,60}, painting.Rect{0,0,100,50},
		painting.Rect{0,0,80,40}, painting.Rect{0,0,100,60}, painting.Rect{0,0,200,60},
		painting.Rect{0,0,120,60}, painting.Rect{0,0,100,40}]
	contained := [painting.Rect{0,0,120,60},painting.Rect{0,0,120,60},painting.Rect{0,0,120,60},painting.Rect{0,0,100,60},painting.Rect{0,0,200,60},painting.Rect{0,0,120,60},painting.Rect{0,0,150,60}]
	covered := [painting.Rect{0,0,200,100},painting.Rect{0,0,200,100},painting.Rect{0,0,200,100},painting.Rect{0,0,200,120},painting.Rect{0,0,200,60},painting.Rect{0,0,200,100},painting.Rect{0,0,200,80}]
	for index, attrs in attributes {
		mut document := parse_svg_image_document(SVGImageSource{
			source: '<svg xmlns="http://www.w3.org/2000/svg" ${attrs}><rect width="200" height="100"/></svg>'
			url: dom.URL{value:'https://svg-background.test/image.svg'}
		}, 'light', embedder) or { panic('missing SVG document') }
		defer { document.finalize() }
		natural := svg_background_natural_size(document)
		if index in [0,4,5] { assert natural.width == none && natural.height == none }
		for size_type in [css.BackgroundSize.length_percentage, .contain, .cover] {
			layer := css.BackgroundLayerData{size_type:size_type, repeat_x:.no_repeat, repeat_y:.no_repeat}
			resolved := painting.resolve_background_layer_with_natural_size(layer, 'image',
				painting.Rect{0,0,200,60}, css.LengthResolutionContext.default(), natural) or {
				panic('missing resolved background')
			}
			match size_type {
				.length_percentage { assert resolved.image_rect == expected[index], attrs }
				.contain { assert resolved.image_rect == contained[index], attrs }
				.cover { assert resolved.image_rect == covered[index], attrs }
			}
		}
		for vertical in [false,true] {
			layer := css.BackgroundLayerData{
				size_x: if vertical { css.LengthPercentageOrAuto.make_auto() } else { css.LengthPercentageOrAuto.from_length(css.Length.make_px(80)) }
				size_y: if vertical { css.LengthPercentageOrAuto.from_length(css.Length.make_px(20)) } else { css.LengthPercentageOrAuto.make_auto() }
			}
			resolved := painting.resolve_background_layer_with_natural_size(layer, 'image',
				painting.Rect{0,0,200,60}, css.LengthResolutionContext.default(), natural) or {
				panic('missing explicitly sized background')
			}
			if index in [0,1,2,5] {
				assert resolved.image_rect == if vertical { painting.Rect{0,0,40,20} } else { painting.Rect{0,0,80,40} }
			}
		}
	}
}

fn test_ratio_only_svg_background_resizes_its_viewbox_without_changing_natural_metrics() {
	mut embedder := html.parse_document('<!doctype html>')
	defer { embedder.finalize() }
	mut document := parse_svg_image_document(SVGImageSource{
		source: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 562 316"><rect x="227.07" y="108" width="100" height="100" fill="gray"/></svg>'
		url: dom.URL{value:'https://svg-background.test/ratio.svg'}
	}, 'light', embedder) or { panic('missing SVG document') }
	defer { document.finalize() }
	for scale in [f64(0.5),1,0.5] {
		_ = run_document_layout(document, 562*scale, 316*scale) or { panic('missing SVG layout') }
		list := document.record_display_list()?
		commands := display_list_commands(list).filter(it.kind == 'draw_svg_path')
		assert commands.len == 1
		assert commands[0].svg().path_transform == [scale,f64(0),0,scale,0,0]!
		natural := svg_background_natural_size(document)
		assert natural.width == none && natural.height == none
		assert natural.aspect_ratio?.to_double() == f64(562)/316
	}
}
