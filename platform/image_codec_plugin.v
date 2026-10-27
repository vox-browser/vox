// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Platform/ImageCodecPlugin.{h,cpp}.
module platform

__global platform_image_codec_plugin &ImageCodecPlugin

pub struct Frame {
pub:
	bitmap   []u8
	duration uint
}

pub struct DecodedImage {
pub mut:
	is_animated   bool
	loop_count    u32
	frame_count   u32
	frames        []Frame
	all_durations []u32
	color_space   string
	session_id    i64
}

pub type DecodeImageHook = fn ([]u8) !DecodedImage

pub type DecodeResolvedHook = fn (mut DecodedImage) !

pub type DecodeRejectedHook = fn (string)

pub type AnimationFramesHook = fn (i64, u32, u32)

pub type StopAnimationHook = fn (i64)

pub type AnimationFramesDecodedHook = fn (i64, [][]u8)

pub type AnimationDecodeFailedHook = fn (i64)

@[heap]
pub struct ImageCodecPlugin {
pub:
	decode_image_hook             ?DecodeImageHook
	request_animation_frames_hook ?AnimationFramesHook
	stop_animation_decode_hook    ?StopAnimationHook
	on_animation_frames_decoded   ?AnimationFramesDecodedHook
	on_animation_decode_failed    ?AnimationDecodeFailedHook
}

pub fn ImageCodecPlugin.the() &ImageCodecPlugin {
	if platform_image_codec_plugin == unsafe { nil } {
		panic('ImageCodecPlugin is not installed')
	}
	return platform_image_codec_plugin
}

pub fn ImageCodecPlugin.is_initialized() bool {
	return platform_image_codec_plugin != unsafe { nil }
}

pub fn ImageCodecPlugin.install(plugin &ImageCodecPlugin) {
	if platform_image_codec_plugin != unsafe { nil } {
		panic('ImageCodecPlugin already installed')
	}
	platform_image_codec_plugin = plugin
}

pub fn (plugin &ImageCodecPlugin) decode_image(bytes []u8) !DecodedImage {
	hook := plugin.decode_image_hook or { return error('Image decoder unavailable') }
	return hook(bytes.clone())
}

// Mirrors the native virtual's resolver/rejector callbacks. The resolver may
// normalize the DecodedImage before it is returned to the caller.
pub fn (plugin &ImageCodecPlugin) decode_image_with_callbacks(bytes []u8, on_resolved DecodeResolvedHook, on_rejected DecodeRejectedHook) !DecodedImage {
	mut decoded := plugin.decode_image(bytes) or {
		on_rejected(err.msg())
		return err
	}
	on_resolved(mut decoded) or {
		on_rejected(err.msg())
		return err
	}
	return decoded
}

pub fn (plugin &ImageCodecPlugin) request_animation_frames(session_id i64, start_frame_index u32, count u32) {
	if hook := plugin.request_animation_frames_hook { hook(session_id, start_frame_index, count) }
}

pub fn (plugin &ImageCodecPlugin) stop_animation_decode(session_id i64) {
	if hook := plugin.stop_animation_decode_hook { hook(session_id) }
}

pub fn (plugin &ImageCodecPlugin) animation_frames_decoded(session_id i64, bitmaps [][]u8) {
	if callback := plugin.on_animation_frames_decoded {
		callback(session_id, bitmaps.clone())
	}
}

pub fn (plugin &ImageCodecPlugin) animation_decode_failed(session_id i64) {
	if callback := plugin.on_animation_decode_failed {
		callback(session_id)
	}
}

pub struct ImageCodecPluginRegistry {
mut:
	plugin ?&ImageCodecPlugin
}

pub fn (registry &ImageCodecPluginRegistry) is_initialized() bool {
	return registry.plugin != none
}

pub fn (mut registry ImageCodecPluginRegistry) install(plugin &ImageCodecPlugin) {
	if registry.plugin != none { panic('ImageCodecPlugin already installed') }
	registry.plugin = plugin
}

pub fn (registry &ImageCodecPluginRegistry) get() &ImageCodecPlugin {
	return registry.plugin or { panic('ImageCodecPlugin is not installed') }
}
