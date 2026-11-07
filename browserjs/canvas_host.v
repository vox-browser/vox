// Synchronous host transport for the translated HTML canvas records.
// Geometry, style validation, state changes and rasterization live in html/.
module browserjs

import css
import dom
import encoding.base64
import geometry
import html
import math
import x.json2

pub type CanvasBeforeDrawHook = fn (&Runtime) !

@[heap]
struct CanvasHostContext {
	context         &html.OffscreenCanvasRenderingContext2D
	element_context ?&html.CanvasRenderingContext2D
}

@[heap]
pub struct CanvasHost {
	document &dom.Document
mut:
	elements    map[string]&dom.Element
	contexts    map[string]&CanvasHostContext
	gradients   map[string]html.CanvasGradient
	patterns    map[string]&html.CanvasPattern
	next_handle int
	before_draw ?CanvasBeforeDrawHook
}

pub fn CanvasHost.create(document &dom.Document) &CanvasHost {
	mut host := &CanvasHost{ document: document }
	root := unsafe { &dom.Node(document) }
	for index, element in css.query_selector_all(root, '*') {
		host.elements['__element_${index}'] = element
	}
	return host
}

pub fn (mut host CanvasHost) install(mut runtime Runtime) ! {
	runtime.define_host_function('__ladybirdCanvas', fn [mut host, mut runtime] (input string) !string {
		request := canvas_host_object(json2.decode[json2.Any](input)!)!
		method := canvas_host_string(request['method'] or { json2.Any('') })
		// Canvas filters and text styles consume the live document synchronously,
		// including compact mutations made after the context state was saved.
		if method in ['fill', 'stroke', 'fillRect', 'strokeRect', 'drawImage',
			'fillText', 'strokeText', 'measureText', 'createPattern'] {
			if hook := host.before_draw { hook(runtime)! }
		}
		runtime.merge_canvas_elements_into(mut host.elements)
		return host.call_request(request)
	})!
	runtime.add_canvas_element_provider_with_merge(fn [mut host] () map[string]&dom.Element {
		return host.elements_for_binding()
	}, fn [mut host] (key string) ?&dom.Element {
		if key !in host.elements { return none }
		return unsafe { host.elements[key] }
	}, fn [host] (element &dom.Element) []string {
		return native_canvas_element_identity_keys(host.elements, element)
	}, fn [mut host] (registry &CanvasElementRegistry) {
		for key, element in host.elements { registry.set(key, element) }
	})
}

pub fn (mut host CanvasHost) set_before_draw(hook ?CanvasBeforeDrawHook) {
	host.before_draw = hook
}

pub fn (host &CanvasHost) elements_for_binding() map[string]&dom.Element {
	return host.elements.clone()
}

fn canvas_host_object(value json2.Any) !map[string]json2.Any {
	if value is map[string]json2.Any { return value }
	return error('TypeError: invalid canvas host request')
}

fn canvas_host_number(value json2.Any) f64 {
	return match value {
		int { f64(value) }
		i32 { f64(value) }
		i64 { f64(value) }
		u32 { f64(value) }
		u64 { f64(value) }
		f64 { value }
		f32 { f64(value) }
		else { math.nan() }
	}
}

fn canvas_host_args(request map[string]json2.Any) []json2.Any {
	value := request['args'] or { return [] }
	if value is []json2.Any { return value }
	return []
}

fn canvas_host_arg(args []json2.Any, index int) f64 {
	if index >= args.len { return math.nan() }
	return canvas_host_number(args[index])
}

fn canvas_host_string(value json2.Any) string {
	if value is string { return value }
	return ''
}

fn canvas_host_bool(value json2.Any) bool {
	if value is bool { return value }
	return false
}

fn canvas_host_matrix(args []json2.Any) html.CanvasAffineTransform {
	return html.CanvasAffineTransform{ a: canvas_host_arg(args, 0), b: canvas_host_arg(args, 1), c: canvas_host_arg(args, 2), d: canvas_host_arg(args, 3), e: canvas_host_arg(args, 4), f: canvas_host_arg(args, 5) }
}

fn canvas_host_numbers(args []json2.Any) []f64 { return args.map(canvas_host_number(it)) }

fn canvas_host_bytes(value json2.Any) []u8 {
	if value is []json2.Any { return value.map(u8(canvas_host_number(it))) }
	return []
}

fn canvas_host_image_data(image &html.ImageData) json2.Any {
	return json2.Any({
		'width':      json2.Any(int(image.width()))
		'height':     json2.Any(int(image.height()))
		'data':       json2.Any(image.data().map(json2.Any(int(it))))
		'colorSpace': json2.Any('srgb')
	})
}

fn canvas_host_settings(request map[string]json2.Any) ?map[string]dom.JSValue {
	value := request['options'] or { return none }
	if value !is map[string]json2.Any { return none }
	mut settings := map[string]dom.JSValue{}
	for key, item in value as map[string]json2.Any {
		settings[key] = match item {
			bool { dom.js_bool(item) }
			string { dom.js_string(item) }
			json2.Null { dom.js_null() }
			else { dom.js_number(canvas_host_number(item)) }
		}
	}
	return settings
}

fn (mut host CanvasHost) context_for(key string, width u32, height u32, settings ?map[string]dom.JSValue) !&CanvasHostContext {
	if existing := host.contexts[key] { return existing }
	if element := host.elements[key] {
		if element.local_name() != 'canvas' { return error('TypeError: expected a canvas element') }
		mut canvas := unsafe { &dom.HTMLCanvasElement(element) }
		if html.html_canvas_element_width(canvas) != width {
			html.html_canvas_element_set_width(mut canvas, width)!
		}
		if html.html_canvas_element_height(canvas) != height {
			html.html_canvas_element_set_height(mut canvas, height)!
		}
		context := html.html_canvas_element_get_context(canvas, '2d', settings)!
		record := &CanvasHostContext{ context: &context.OffscreenCanvasRenderingContext2D, element_context: context }
		host.contexts[key] = record
		return record
	}
	mut element := host.document.create_element_ns('http://www.w3.org/1999/xhtml', 'canvas')!
	mut canvas := unsafe { &dom.HTMLCanvasElement(element) }
	html.html_canvas_element_set_width(mut canvas, width)!
	html.html_canvas_element_set_height(mut canvas, height)!
	context := html.html_canvas_element_get_context(canvas, '2d', settings)!
	record := &CanvasHostContext{ context: &context.OffscreenCanvasRenderingContext2D, element_context: context }
	host.elements[key] = element
	host.contexts[key] = record
	return record
}

fn (mut host CanvasHost) image_source(request map[string]json2.Any) !html.CanvasImageSource {
	source_key := canvas_host_string(request['source'] or { json2.Any('') })
	if record := host.contexts[source_key] {
		bitmap := record.context.canvas().bitmap() or { return error('InvalidStateError: canvas has no bitmap') }
		mut image := html.ImageBitmap.create()
		image.set_bitmap(bitmap.clone())
		return html.CanvasImageSource(html.ImageBitmapCanvasSource{ value: image })
	}
	if element := host.elements[source_key] {
		if element.local_name() == 'canvas' {
			canvas := unsafe { &dom.HTMLCanvasElement(element) }
			if bitmap := html.html_canvas_element_get_bitmap_from_surface(canvas) {
				mut image := html.ImageBitmap.create()
				image.set_bitmap(bitmap.clone())
				return html.CanvasImageSource(html.ImageBitmapCanvasSource{ value: image })
			}
		}
		if element.local_name() == 'img' {
			image := unsafe { &dom.HTMLImageElement(element) }
			model := html.html_image_element_model_for_dom_element(image)
			if data := model.decoded_image_data() {
				return html.CanvasImageSource(html.DecodedImageCanvasSource{ value: data })
			}
		}
		if element.local_name() == 'video' && 'image' !in request {
			video := unsafe { &dom.HTMLVideoElement(element) }
			model := html.html_video_element_model_for_dom_element(video)
			if frame := model.current_decoded_image_frame() {
				mut image := html.ImageBitmap.create()
				image.set_bitmap(frame.bitmap().clone())
				return html.CanvasImageSource(html.ImageBitmapCanvasSource{ value: image })
			}
		}
	}
	if raw := request['image'] {
		image := canvas_host_object(raw)!
		width := int(canvas_host_number(image['width'] or { json2.Any(0) }))
		height := int(canvas_host_number(image['height'] or { json2.Any(0) }))
		pixels := base64.decode(canvas_host_string(image['pixels'] or { json2.Any('') }))
		if width <= 0 || height <= 0 || pixels.len != width * height * 4 {
			return error('InvalidStateError: invalid image pixels')
		}
		mut bitmap := html.ImageBitmap.create()
		bitmap.set_bitmap(&dom.Bitmap_{ width: width, height: height, pitch: width * 4, alpha_type: 1, data: pixels })
		return html.CanvasImageSource(html.ImageBitmapCanvasSource{ value: bitmap })
	}
	return html.CanvasImageSource(html.ImageBitmapCanvasSource{ value: html.ImageBitmap.create() })
}

fn (mut host CanvasHost) paint_style(value json2.Any) !html.CanvasFillStrokeStyleValue {
	if value is string { return html.CanvasFillStrokeStyleValue(value) }
	object := canvas_host_object(value)!
	handle := canvas_host_string(object['handle'] or { json2.Any('') })
	if gradient := host.gradients[handle] { return html.CanvasFillStrokeStyleValue(gradient) }
	if pattern := host.patterns[handle] {
		return html.CanvasFillStrokeStyleValue(html.CanvasPatternStyleValue{ pattern: pattern })
	}
	return error('TypeError: expected a canvas paint style')
}

fn (host &CanvasHost) style_value(style html.FillOrStrokeStyle) json2.Any {
	if gradient := style.gradient {
		for handle, candidate in host.gradients {
			if gradient.is_same_gradient(candidate) {
				return json2.Any({
					'handle': json2.Any(handle)
				})
			}
		}
	}
	if pattern := style.pattern {
		for handle, candidate in host.patterns {
			if voidptr(pattern) == voidptr(candidate) {
				return json2.Any({
					'handle': json2.Any(handle)
				})
			}
		}
	}
	color := style.color
	return json2.Any(css.Color{color.r, color.g, color.b, color.a}.serialize())
}

fn (mut host CanvasHost) set_property(mut record CanvasHostContext, name string, value json2.Any) ! {
	mut context := record.context
	mut path_styles := html.CanvasPathDrawingStyles.create(&context.CanvasState)
	mut text_styles := html.CanvasTextDrawingStyles.create(&context.CanvasState)
	mut paint_styles := html.CanvasFillStrokeStyles.create(&context.CanvasState)
	number := canvas_host_number(value)
	text := canvas_host_string(value)
	match name {
		'fillStyle' { paint_styles.set_fill_style(host.paint_style(value)!) }
		'strokeStyle' { paint_styles.set_stroke_style(host.paint_style(value)!) }
		'font' { context.set_font(text) }
		'globalAlpha' { context.set_global_alpha(number) }
		'globalCompositeOperation' { context.set_global_composite_operation(text) }
		'shadowOffsetX' { context.set_shadow_offset_x(number) }
		'shadowOffsetY' { context.set_shadow_offset_y(number) }
		'shadowBlur' { context.set_shadow_blur(number) }
		'shadowColor' { context.set_shadow_color(text) }
		'filter' {
			if element_context := record.element_context {
				mut actual := unsafe { &html.CanvasRenderingContext2D(element_context) }
				actual.set_filter(text)
			} else {
				context.set_filter(text)
			}
		}
		'lineWidth' { path_styles.set_line_width(number) }
		'miterLimit' { path_styles.set_miter_limit(number) }
		'lineDashOffset' { path_styles.set_line_dash_offset(number) }
		'lineCap' {
			match text {
				'butt' { path_styles.set_line_cap(.butt) }
				'round' { path_styles.set_line_cap(.round) }
				'square' { path_styles.set_line_cap(.square) }
				else {}
			}
		}
		'lineJoin' {
			match text {
				'miter' { path_styles.set_line_join(.miter) }
				'round' { path_styles.set_line_join(.round) }
				'bevel' { path_styles.set_line_join(.bevel) }
				else {}
			}
		}
		'textAlign' {
			match text {
				'start' { text_styles.set_text_align(.start) }
				'end' { text_styles.set_text_align(.end) }
				'left' { text_styles.set_text_align(.left) }
				'right' { text_styles.set_text_align(.right) }
				'center' { text_styles.set_text_align(.center) }
				else {}
			}
		}
		'textBaseline' {
			match text {
				'top' { text_styles.set_text_baseline(.top) }
				'hanging' { text_styles.set_text_baseline(.hanging) }
				'middle' { text_styles.set_text_baseline(.middle) }
				'alphabetic' { text_styles.set_text_baseline(.alphabetic) }
				'ideographic' { text_styles.set_text_baseline(.ideographic) }
				'bottom' { text_styles.set_text_baseline(.bottom) }
				else {}
			}
		}
		'direction' {
			match text {
				'ltr' { text_styles.set_direction(.ltr) }
				'rtl' { text_styles.set_direction(.rtl) }
				'inherit' { text_styles.set_direction(.inherit) }
				else {}
			}
		}
		'letterSpacing' { text_styles.set_letter_spacing(text) }
		'imageSmoothingEnabled' { context.set_image_smoothing_enabled(canvas_host_bool(value)) }
		'imageSmoothingQuality' {
			match text {
				'low' { context.set_image_smoothing_quality(.low) }
				'medium' { context.set_image_smoothing_quality(.medium) }
				'high' { context.set_image_smoothing_quality(.high) }
				else {}
			}
		}
		else { return error('TypeError: unknown canvas property ${name}') }
	}
}

fn (host &CanvasHost) get_property(record &CanvasHostContext, name string) !json2.Any {
	context := record.context
	state := context.drawing_state
	return match name {
		'fillStyle' { host.style_value(state.fill_style) }
		'strokeStyle' { host.style_value(state.stroke_style) }
		'font' { json2.Any(context.font()) }
		'globalAlpha' { json2.Any(context.global_alpha()) }
		'globalCompositeOperation' { json2.Any(context.global_composite_operation()) }
		'shadowOffsetX' { json2.Any(context.shadow_offset_x()) }
		'shadowOffsetY' { json2.Any(context.shadow_offset_y()) }
		'shadowBlur' { json2.Any(context.shadow_blur()) }
		'shadowColor' { json2.Any(context.shadow_color()) }
		'filter' { json2.Any(context.filter()) }
		'lineWidth' { json2.Any(state.line_width) }
		'lineCap' { json2.Any(state.line_cap.str()) }
		'lineJoin' { json2.Any(state.line_join.str()) }
		'miterLimit' { json2.Any(state.miter_limit) }
		'lineDashOffset' { json2.Any(state.line_dash_offset) }
		'textAlign' { json2.Any(state.text_align.str()) }
		'textBaseline' { json2.Any(state.text_baseline.str()) }
		'direction' { json2.Any(state.direction.str()) }
		'letterSpacing' { json2.Any(state.letter_spacing_string) }
		'imageSmoothingEnabled' { json2.Any(state.image_smoothing_enabled) }
		'imageSmoothingQuality' { json2.Any(state.image_smoothing_quality.str()) }
		else { return error('TypeError: unknown canvas property ${name}') }
	}
}

pub fn (mut host CanvasHost) call(input string) !string {
	request := canvas_host_object(json2.decode[json2.Any](input)!)!
	return host.call_request(request)
}

fn (mut host CanvasHost) call_request(request map[string]json2.Any) !string {
	method := canvas_host_string(request['method'] or { json2.Any('') })
	key := canvas_host_string(request['key'] or { json2.Any('') })
	width := u32(canvas_host_number(request['width'] or { json2.Any(300) }))
	height := u32(canvas_host_number(request['height'] or { json2.Any(150) }))
	if method == 'getContext' {
		host.context_for(key, width, height, canvas_host_settings(request)) or { return 'null' }
		return json2.encode(json2.Any({
			'kind': json2.Any('2d')
		}))
	}
	mut record := host.context_for(key, width, height, canvas_host_settings(request))!
	mut context := record.context
	args := canvas_host_args(request)
	mut result := json2.Any(json2.Null{})
	mut did_draw := false
	match method {
		'set' {
			host.set_property(mut record, canvas_host_string(request['property'] or { json2.Any('') }), request['value'] or { json2.Any(json2.Null{}) })!
		}
		'getContextAttributes' {
			attributes := context.get_context_attributes()
			result = json2.Any({
				'alpha':              json2.Any(attributes.alpha)
				'desynchronized':     json2.Any(attributes.desynchronized)
				'colorSpace':         json2.Any(if attributes.color_space == .display_p3 {
					'display-p3'
				} else {
					'srgb'
				})
				'colorType':          json2.Any(attributes.color_type.str())
				'willReadFrequently': json2.Any(attributes.will_read_frequently)
			})
		}
		'get' {
			result = host.get_property(record, canvas_host_string(request['property'] or { json2.Any('') }))!
		}
		'resize' {
			if actual := record.element_context {
				mut canvas := unsafe { &dom.HTMLCanvasElement(actual.element) }
				html.html_canvas_element_set_width(mut canvas, width)!
				html.html_canvas_element_set_height(mut canvas, height)!
			} else {
				mut canvas := context.canvas()
				canvas.set_width(width)!
				canvas.set_height(height)!
			}
		}
		'save' { context.save() }
		'restore' { context.restore() }
		'reset' {
			context.reset()
			did_draw = true
		}
		'fillRect' {
			context.fill_rect(canvas_host_arg(args, 0), canvas_host_arg(args, 1), canvas_host_arg(args, 2), canvas_host_arg(args, 3))
			did_draw = true
		}
		'strokeRect' {
			context.stroke_rect(canvas_host_arg(args, 0), canvas_host_arg(args, 1), canvas_host_arg(args, 2), canvas_host_arg(args, 3))
			did_draw = true
		}
		'clearRect' {
			context.clear_rect(canvas_host_arg(args, 0), canvas_host_arg(args, 1), canvas_host_arg(args, 2), canvas_host_arg(args, 3))
			did_draw = true
		}
		'beginPath' { context.begin_path() }
		'closePath' { context.close_path() }
		'moveTo' { context.move_to(canvas_host_arg(args, 0), canvas_host_arg(args, 1)) }
		'lineTo' { context.line_to(canvas_host_arg(args, 0), canvas_host_arg(args, 1)) }
		'rect' {
			context.rect(canvas_host_arg(args, 0), canvas_host_arg(args, 1), canvas_host_arg(args, 2), canvas_host_arg(args, 3))
		}
		'quadraticCurveTo' {
			context.quadratic_curve_to(canvas_host_arg(args, 0), canvas_host_arg(args, 1), canvas_host_arg(args, 2), canvas_host_arg(args, 3))
		}
		'bezierCurveTo' {
			context.bezier_curve_to(canvas_host_arg(args, 0), canvas_host_arg(args, 1), canvas_host_arg(args, 2), canvas_host_arg(args, 3), canvas_host_arg(args, 4), canvas_host_arg(args, 5))
		}
		'arc' {
			context.arc(canvas_host_arg(args, 0), canvas_host_arg(args, 1), canvas_host_arg(args, 2), canvas_host_arg(args, 3), canvas_host_arg(args, 4), if args.len > 5 {
				canvas_host_bool(args[5])
			} else {
				false
			})!
		}
		'arcTo' {
			context.arc_to(canvas_host_arg(args, 0), canvas_host_arg(args, 1), canvas_host_arg(args, 2), canvas_host_arg(args, 3), canvas_host_arg(args, 4))!
		}
		'ellipse' {
			context.ellipse(canvas_host_arg(args, 0), canvas_host_arg(args, 1), canvas_host_arg(args, 2), canvas_host_arg(args, 3), canvas_host_arg(args, 4), canvas_host_arg(args, 5), canvas_host_arg(args, 6), if args.len > 7 {
				canvas_host_bool(args[7])
			} else {
				false
			})!
		}
		'fill' {
			context.fill(if args.len > 0 { canvas_host_string(args[0]) } else { 'nonzero' })
			did_draw = true
		}
		'stroke' {
			context.stroke()
			did_draw = true
		}
		'clip' { context.clip(if args.len > 0 { canvas_host_string(args[0]) } else { 'nonzero' }) }
		'isPointInPath' {
			result = json2.Any(context.is_point_in_path(canvas_host_arg(args, 0), canvas_host_arg(args, 1), if args.len > 2 {
				canvas_host_string(args[2])
			} else {
				'nonzero'
			}))
		}
		'setLineDash' {
			mut styles := html.CanvasPathDrawingStyles.create(&context.CanvasState)
			styles.set_line_dash(canvas_host_numbers(args))
		}
		'getLineDash' { result = json2.Any(context.drawing_state.dash_list.map(json2.Any(it))) }
		'translate', 'scale', 'rotate', 'transform', 'setTransform', 'resetTransform',
		'getTransform' {
			mut transform := html.CanvasTransform.create(&context.CanvasState, &context.CanvasPath)
			match method {
				'translate' {
					transform.translate(canvas_host_arg(args, 0), canvas_host_arg(args, 1))
				}
				'scale' { transform.scale(canvas_host_arg(args, 0), canvas_host_arg(args, 1)) }
				'rotate' { transform.rotate(canvas_host_arg(args, 0)) }
				'transform' { transform.transform(canvas_host_matrix(args)) }
				'setTransform' {
					if canvas_host_bool(request['dictionary'] or { json2.Any(false) }) {
						transform.set_transform(canvas_host_matrix(args))
					} else if canvas_host_numbers(args).all(!math.is_nan(it) && !math.is_inf(it, 0)) {
						transform.reset_transform()
						transform.transform(canvas_host_matrix(args))
					}
				}
				'resetTransform' { transform.reset_transform() }
				else {
					matrix := transform.get_transform()
					result = json2.Any({
						'a': json2.Any(matrix.a)
						'b': json2.Any(matrix.b)
						'c': json2.Any(matrix.c)
						'd': json2.Any(matrix.d)
						'e': json2.Any(matrix.e)
						'f': json2.Any(matrix.f)
					})
				}
			}
		}
		'createLinearGradient', 'createRadialGradient', 'createConicGradient' {
			numbers := canvas_host_numbers(args)
			if numbers.any(math.is_nan(it) || math.is_inf(it, 0)) {
				return error('TypeError: gradient coordinates must be finite')
			}
			gradient := match method {
				'createLinearGradient' {
					html.CanvasGradient.create_linear(canvas_host_arg(args, 0), canvas_host_arg(args, 1), canvas_host_arg(args, 2), canvas_host_arg(args, 3))
				}
				'createRadialGradient' {
					html.CanvasGradient.create_radial(canvas_host_arg(args, 0), canvas_host_arg(args, 1), canvas_host_arg(args, 2), canvas_host_arg(args, 3), canvas_host_arg(args, 4), canvas_host_arg(args, 5))!
				}
				else {
					html.CanvasGradient.create_conic(canvas_host_arg(args, 0), canvas_host_arg(args, 1), canvas_host_arg(args, 2))
				}
			}
			host.next_handle++
			handle := host.next_handle.str()
			host.gradients[handle] = gradient
			result = json2.Any({
				'handle': json2.Any(handle)
			})
		}
		'addColorStop' {
			handle := canvas_host_string(request['handle'] or { json2.Any('') })
			mut gradient := host.gradients[handle] or { return error('TypeError: unknown gradient') }
			offset := canvas_host_arg(args, 0)
			if math.is_nan(offset) || math.is_inf(offset, 0) {
				return error('TypeError: gradient stop offset must be finite')
			}
			gradient.add_color_stop(offset, canvas_host_string(args[1]))!
			host.gradients[handle] = gradient
		}
		'createPattern' {
			creation := html.CanvasPattern.create(host.image_source(request)!, canvas_host_string(request['repetition'] or { json2.Any('') }))!
			if pattern := creation.pattern {
				host.next_handle++
				handle := host.next_handle.str()
				host.patterns[handle] = pattern
				result = json2.Any({
					'handle': json2.Any(handle)
				})
			}
		}
		'patternSetTransform' {
			handle := canvas_host_string(request['handle'] or { json2.Any('') })
			mut pattern := host.patterns[handle] or { return error('TypeError: unknown pattern') }
			matrix := canvas_host_matrix(args)
			mut init := geometry.DOMMatrix2DInit{ a: matrix.a, b: matrix.b, c: matrix.c, d: matrix.d, e: matrix.e, f: matrix.f }
			pattern.set_transform(mut init)!
		}
		'drawImage' {
			source := host.image_source(request)!
			draw := html.CanvasDrawImage.create(fn [mut context] (request html.CanvasDrawImageRequest) ! {
				context.draw_image_internal(request)!
			})
			match args.len {
				2 { draw.draw_image(source, canvas_host_arg(args, 0), canvas_host_arg(args, 1))! }
				4 {
					draw.draw_image_scaled(source, canvas_host_arg(args, 0), canvas_host_arg(args, 1), canvas_host_arg(args, 2), canvas_host_arg(args, 3))!
				}
				8 {
					draw.draw_image_rect(source, canvas_host_arg(args, 0), canvas_host_arg(args, 1), canvas_host_arg(args, 2), canvas_host_arg(args, 3), canvas_host_arg(args, 4), canvas_host_arg(args, 5), canvas_host_arg(args, 6), canvas_host_arg(args, 7))!
				}
				else { return error('TypeError: invalid drawImage argument count') }
			}
			did_draw = true
		}
		'getImageData', 'createImageData' {
			image := if method == 'getImageData' {
				context.get_image_data(int(canvas_host_arg(args, 0)), int(canvas_host_arg(args, 1)), int(canvas_host_arg(args, 2)), int(canvas_host_arg(args, 3)), none)!
			} else {
				context.create_image_data(int(canvas_host_arg(args, 0)), int(canvas_host_arg(args, 1)), none)!
			}
			result = canvas_host_image_data(image)
		}
		'putImageData' {
			image := canvas_host_object(request['imageData'] or { return error('TypeError: expected ImageData') })!
			data := canvas_host_bytes(image['data'] or { json2.Any([]json2.Any{}) })
			actual := html.ImageData.create_with_data(data, u32(canvas_host_number(image['width'] or { json2.Any(0) })), u32(canvas_host_number(image['height'] or { json2.Any(0) })), none)!
			if args.len == 2 {
				context.put_image_data(actual, int(canvas_host_arg(args, 0)), int(canvas_host_arg(args, 1)))
			} else {
				context.put_image_data_dirty(actual, int(canvas_host_arg(args, 0)), int(canvas_host_arg(args, 1)), int(canvas_host_arg(args, 2)), int(canvas_host_arg(args, 3)), int(canvas_host_arg(args, 4)), int(canvas_host_arg(args, 5)))
			}
			did_draw = true
		}
		'measureText' {
			metrics := context.measure_text(canvas_host_string(args[0]))
			result = json2.Any({
				'width':                    json2.Any(metrics.width())
				'actualBoundingBoxLeft':    json2.Any(metrics.actual_bounding_box_left())
				'actualBoundingBoxRight':   json2.Any(metrics.actual_bounding_box_right())
				'fontBoundingBoxAscent':    json2.Any(metrics.font_bounding_box_ascent())
				'fontBoundingBoxDescent':   json2.Any(metrics.font_bounding_box_descent())
				'actualBoundingBoxAscent':  json2.Any(metrics.actual_bounding_box_ascent())
				'actualBoundingBoxDescent': json2.Any(metrics.actual_bounding_box_descent())
			})
		}
		'fillText', 'strokeText' {
			maximum := if args.len > 3 { ?f64(canvas_host_arg(args, 3)) } else { none }
			if method == 'fillText' {
				context.fill_text(canvas_host_string(args[0]), canvas_host_arg(args, 1), canvas_host_arg(args, 2), maximum)
			} else {
				context.stroke_text(canvas_host_string(args[0]), canvas_host_arg(args, 1), canvas_host_arg(args, 2), maximum)
			}
			did_draw = true
		}
		'snapshot' {
			if bitmap := context.canvas().bitmap() {
				result = json2.Any({
					'pixels':        json2.Any(bitmap.data.map(json2.Any(int(it))))
					'premultiplied': json2.Any(bitmap.alpha_type == 2)
					'topDown':       json2.Any(bitmap.native_rows_are_top_down)
				})
			} else {
				result = json2.Any({
					'pixels':        json2.Any([]json2.Any{})
					'premultiplied': json2.Any(false)
				})
			}
		}
		else { return error('TypeError: unknown canvas method ${method}') }
	}
	if did_draw {
		if actual := record.element_context {
			mut mutable := unsafe { &html.CanvasRenderingContext2D(actual) }
			mutable.did_draw(html.CanvasFloatRect{0, 0, f64(width), f64(height)})
		}
	}
	return json2.encode(result)
}
