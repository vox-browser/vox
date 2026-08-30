module platform

fn successful_decode(bytes []u8) !DecodedImage {
	return DecodedImage{
		frame_count: 1
		frames:      [Frame{ bitmap: bytes, duration: 10 }]
	}
}

fn no_op() {}

fn normalize_decode(mut image DecodedImage) ! {
	image.is_animated = true
	image.loop_count = 2
}

fn ignore_decode_error(_ string) {}

fn test_font_plugin_fallbacks_and_layout_mode() {
	plugin := FontPlugin.new(false, ['Courier New', 'Noto Sans', 'Times New Roman'], false)
	assert plugin.generic_font_name(.monospace) == 'Courier New'
	assert plugin.generic_font_name(.sans_serif) == 'Noto Sans'
	assert plugin.default_font(16) or { panic('missing default') }.family == 'Noto Sans'
	assert plugin.symbol_font_names() == ['Noto Color Emoji', 'Noto Sans Symbols']
	layout := FontPlugin.new(true, [], false)
	assert layout.generic_font_name(.cursive) == 'SerenitySans'
	assert layout.symbol_font_names() == ['Noto Emoji']
}

fn test_timer_state_and_single_shot_fire() {
	mut timer := Timer.create_single_shot(10, no_op)
	assert timer.interval() == 10
	timer.start()
	assert timer.is_active()
	timer.fire()
	assert !timer.is_active()
	timer.set_single_shot(false)
	timer.restart_with_interval(20)
	timer.fire()
	assert timer.is_active()
	assert timer.interval() == 20
}

fn test_image_codec_and_plugin_registries() {
	codec := &ImageCodecPlugin{
		decode_image_hook: successful_decode
	}
	mut codecs := ImageCodecPluginRegistry{}
	assert !codecs.is_initialized()
	codecs.install(codec)
	assert codecs.is_initialized()
	assert codecs.get().decode_image([u8(1), 2])!.frames[0].bitmap == [u8(1), 2]
	normalized := codecs.get().decode_image_with_callbacks([u8(3)], normalize_decode,
		ignore_decode_error)!
	assert normalized.is_animated
	assert normalized.loop_count == 2
	mut fonts := FontPluginRegistry{}
	font := FontPlugin.new(true, [], false)
	fonts.install(font)
	assert fonts.get().is_layout_test_mode()
}

fn test_platform_plugins_expose_upstream_process_singletons() {
	event_loop := EventLoopPlugin.new()
	EventLoopPlugin.install(event_loop)
	assert EventLoopPlugin.the() == event_loop
	font := FontPlugin.new(true, [], false)
	FontPlugin.install(font)
	assert FontPlugin.the() == font
	assert FontPlugin.the().is_layout_test_mode()
	codec := &ImageCodecPlugin{}
	assert !ImageCodecPlugin.is_initialized()
	ImageCodecPlugin.install(codec)
	assert ImageCodecPlugin.is_initialized()
	assert ImageCodecPlugin.the() == codec
}
