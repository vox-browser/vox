module layout

import css
import dom
import html
import http
import loader
import platform
import painting

const static_background_test_source = '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="10" viewBox="0 0 20 10"><defs><linearGradient id="paint"><stop offset="0" stop-color="lime"/></linearGradient></defs><path d="M0 0H20V10H0Z" fill="url(#paint)"/></svg>'

fn static_background_test_publish(address string, source string) {
	if !loader.is_initialized() { loader.initialize() }
	mut resource_loader := loader.ResourceLoader.the()
	resource_loader.register_network_response(address, loader.NetworkResponse{
		data:    source.bytes()
		headers: [http.Header{ name: 'Content-Type', value: 'image/svg+xml' }]
	})
}

fn static_background_test_host() &dom.Document {
	mut host := html.parse_document('<!doctype html><div style="width:20px;height:10px"></div>')
	host.enable_native_storage()
	enable_native_static_svg_backgrounds(host)
	mut scope := host.enter_native_storage()
	_ = layout_document_typed_in_viewport(host, 100, 100)
	scope.finish()
	return host
}

fn static_background_test_image(host &dom.Document, address string) SVGBackgroundImage {
	result := document_layout_result(host) or { panic('missing host layout') }
	return svg_background_image_for_source_in_viewport(result.root, address, .light)
}

fn static_background_test_stop(commands []PaintCommand) painting.Color {
	for command in commands {
		if gradient := command.fill_linear_gradient() {
			return gradient.gradient.color_stops[0].color
		}
	}
	panic('missing SVG gradient')
}

fn test_static_background_rechecks_exact_bytes_and_keeps_owned_old_pictures() {
	$if !prealloc {
		return
	}
	address := 'https://static-background.test/replaced.svg'
	static_background_test_publish(address, static_background_test_source)
	mut host := static_background_test_host()
	before_image := static_background_test_image(host, address)
	before := before_image.resource or { panic('missing static resource') }
	has_before_document := before_image.document != none
	assert !has_before_document
	repeated_image := static_background_test_image(host, address)
	repeated := repeated_image.resource?
	assert voidptr(repeated) == voidptr(before)
	mut frame := platform.new_arena('static background replay scratch')
	entry := frame.enter()
	old_commands := static_svg_background_commands(before, 20, 10)?
	frame.leave(entry)
	frame.release()
	assert before.owner.arena.contains(old_commands.data)
	assert static_background_test_stop(old_commands) == painting.Color{0, 255, 0, 255}
	changed := static_background_test_source.replace('lime', 'blue')
	assert changed.len == static_background_test_source.len
	static_background_test_publish(address, changed)
	after_image := static_background_test_image(host, address)
	after := after_image.resource?
	assert voidptr(before) != voidptr(after)
	new_commands := static_svg_background_commands(after, 20, 10)?
	assert static_background_test_stop(new_commands) == painting.Color{0, 0, 255, 255}
	assert static_background_test_stop(old_commands) == painting.Color{0, 255, 0, 255}
	mut resource_loader := loader.ResourceLoader.the()
	resource_loader.register_network_response(address, loader.NetworkResponse{ status_code: 404 })
	failed := static_background_test_image(host, address)
	has_failed_document := failed.document != none
	has_failed_resource := failed.resource != none
	assert !has_failed_document && !has_failed_resource
	assert static_background_test_stop(old_commands) == painting.Color{0, 255, 0, 255}
	host.finalize()
	host.release_native_storage()
}

fn test_static_background_keys_fragment_scheme_and_font_policy() {
	$if !prealloc {
		return
	}
	address := 'https://static-background.test/keys.svg'
	static_background_test_publish(address, static_background_test_source)
	mut host := static_background_test_host()
	one_image := static_background_test_image(host, address + '#one')
	two_image := static_background_test_image(host, address + '#two')
	one := one_image.resource?
	two := two_image.resource?
	assert voidptr(one) != voidptr(two)
	assert one.source.url.serialize() == address + '#one'
	assert two.source.url.serialize() == address + '#two'
	assert one.owner.arena.contains(one.source.source.str)
	assert voidptr(one.source.source.str) == voidptr(two.source.source.str)
	result := document_layout_result(host)?
	dark_image := svg_background_image_for_source_in_viewport(result.root, address + '#one', .dark)
	dark := dark_image.resource?
	assert voidptr(one) != voidptr(dark)
	assert dark.color_scheme == 'dark'
	assert voidptr(one.source.source.str) == voidptr(dark.source.source.str)
	host.set_font_rendering_policy(.chromium)
	other_image := static_background_test_image(host, address + '#one')
	other_policy := other_image.resource?
	assert voidptr(other_policy) != voidptr(one)
	assert other_policy.font_policy == .chromium
	assert voidptr(one.source.source.str) == voidptr(other_policy.source.source.str)
	host.finalize()
	host.release_native_storage()
}

fn test_static_background_shared_source_keeps_replacements_and_late_pictures_independent() {
	$if !prealloc {
		return
	}
	address := 'https://static-background.test/shared-source.svg'
	alias := 'https://static-background.test/shared-source-alias.svg'
	static_background_test_publish(address, static_background_test_source)
	static_background_test_publish(alias, static_background_test_source)
	mut host := static_background_test_host()
	mut scratch := platform.new_arena('shared static background source scratch')
	entry := scratch.enter()
	one_image := static_background_test_image(host, address)
	two_image := static_background_test_image(host, alias + '#sprite')
	one := one_image.resource?
	two := two_image.resource?
	scratch.leave(entry)
	scratch.release()
	assert voidptr(one) != voidptr(two)
	assert one.owner.arena.contains(one.source.source.str)
	assert voidptr(one.source.source.str) == voidptr(two.source.source.str)
	assert two.source.url.serialize() == alias + '#sprite'
	assert one.scenes.len == 0 && two.scenes.len == 0
	changed := static_background_test_source.replace('lime', 'blue')
	static_background_test_publish(address, changed)
	after_image := static_background_test_image(host, address)
	after := after_image.resource?
	assert voidptr(after) != voidptr(one)
	assert voidptr(after.source.source.str) != voidptr(one.source.source.str)
	assert after.source.source == changed
	assert two.source.source == static_background_test_source
	old_commands := static_svg_background_commands(two, 20, 10)?
	new_commands := static_svg_background_commands(after, 20, 10)?
	assert static_background_test_stop(old_commands) == painting.Color{0, 255, 0, 255}
	assert static_background_test_stop(new_commands) == painting.Color{0, 0, 255, 255}
	// Restoring earlier bytes can reuse another key's immutable source without
	// reviving the replaced resource or its independently keyed picture cache.
	static_background_test_publish(address, static_background_test_source)
	restored_image := static_background_test_image(host, address)
	restored := restored_image.resource?
	assert voidptr(restored) != voidptr(one)
	assert voidptr(restored) != voidptr(after)
	assert voidptr(restored.source.source.str) == voidptr(two.source.source.str)
	restored_commands := static_svg_background_commands(restored, 20, 10)?
	assert static_background_test_stop(restored_commands) == painting.Color{0, 255, 0, 255}
	assert static_background_test_stop(new_commands) == painting.Color{0, 0, 255, 255}
	mut resource_loader := loader.ResourceLoader.the()
	resource_loader.register_network_response(address, loader.NetworkResponse{ status_code: 404 })
	failed := static_background_test_image(host, address)
	has_failed_resource := failed.resource != none
	has_failed_document := failed.document != none
	assert !has_failed_resource && !has_failed_document
	assert static_background_test_stop(old_commands) == painting.Color{0, 255, 0, 255}
	host.finalize()
	host.release_native_storage()
}

fn test_static_background_late_first_paint_survives_host_retirement_with_scene_lease() {
	$if !prealloc {
		return
	}
	address := 'https://static-background.test/late.svg'
	static_background_test_publish(address, static_background_test_source)
	mut host := static_background_test_host()
	image := static_background_test_image(host, address)
	resource := image.resource?
	assert resource.scenes.len == 0
	mut reader_owner := host.native_storage()
	reader_owner.retain()
	host.finalize()
	host.release_native_storage()
	assert host.native_storage() == unsafe { nil }
	commands := static_svg_background_commands(resource, 20, 10)?
	assert static_background_test_stop(commands) == painting.Color{0, 255, 0, 255}
	has_fallback_document := resource.fallback_document != none
	assert !has_fallback_document
	assert resource.scenes.len == 1
	reader_owner.release()
	assert reader_owner.arena.usage().used == 0
}

fn test_static_background_bounds_size_cache_and_preserves_earlier_owned_picture() {
	$if !prealloc {
		return
	}
	address := 'https://static-background.test/resize.svg'
	static_background_test_publish(address, static_background_test_source)
	mut host := static_background_test_host()
	image := static_background_test_image(host, address)
	resource := image.resource?
	first := static_svg_background_commands(resource, 20, 10)?
	for width in [30, 40, 50, 60, 70] {
		commands := static_svg_background_commands(resource, width, 10)?
		assert static_background_test_stop(commands) == painting.Color{0, 255, 0, 255}
	}
	assert resource.scenes.len == 4
	fallback := resource.fallback_document?
	assert fallback.viewport_rect().width == 70
	assert static_background_test_stop(first) == painting.Color{0, 255, 0, 255}
	repeated := static_svg_background_commands(resource, 20, 10)?
	assert voidptr(repeated.data) == voidptr(first.data)
	host.finalize()
	host.release_native_storage()
	assert fallback.native_storage() == unsafe { nil }
}

fn test_static_background_keeps_optional_natural_size_and_generic_unsupported_images() {
	$if !prealloc {
		return
	}
	address := 'https://static-background.test/natural.svg'
	static_background_test_publish(address, '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 100"><rect width="200" height="100"/></svg>')
	mut host := static_background_test_host()
	image := static_background_test_image(host, address)
	resource := image.resource?
	natural := resource.natural_metrics()
	assert natural.width == none && natural.height == none
	assert natural.aspect_ratio?.to_double() == 2
	layer := css.BackgroundLayerData{ size_type: .contain, repeat_x: .no_repeat, repeat_y: .no_repeat }
	resolved := painting.resolve_background_layer_with_natural_size(layer, 'image',
		painting.Rect{0, 0, 200, 60}, css.LengthResolutionContext.default(), natural)?
	assert resolved.image_rect == painting.Rect{0, 0, 120, 60}
	static_background_test_publish(address, '<svg xmlns="http://www.w3.org/2000/svg"><text id="text">live text</text></svg>')
	unsupported := static_background_test_image(host, address)
	has_unsupported_resource := unsupported.resource != none
	assert !has_unsupported_resource
	mut document := unsupported.document?
	has_text := document.get_element_by_id('text') != none
	assert has_text
	repeated_image := static_background_test_image(host, address)
	repeated_document := repeated_image.document?
	assert voidptr(repeated_document) == voidptr(document)
	host.finalize()
	host.release_native_storage()
}

fn test_early_svg_retirement_is_idempotent_at_host_cleanup_after_poison() {
	$if !prealloc {
		return
	}
	mut host := dom.Document.create(dom.URL{ value: 'https://static-background.test/' })
	host.enable_native_storage()
	mut image := parse_svg_image_document(SVGImageSource{
		source: static_background_test_source
		url:    dom.URL{ value: 'https://static-background.test/early.svg' }
	}, 'light', host)?
	child_owner := image.native_storage()
	retire_svg_image_document(image)
	assert image.native_storage() == unsafe { nil }
	assert child_owner.arena.usage().used == 0
	retire_svg_image_document(image)
	host.finalize()
	host.release_native_storage()
}
