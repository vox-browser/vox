// Native request adapter for SVGDecodedImageData. Vector painting is recorded
// by layout from the isolated document, without manufacturing bitmap pixels.
module html

import dom

@[heap]
pub struct SVGDecodedImageData {
pub:
	svg_document &dom.Document
	width        ?f64
	height       ?f64
	aspect_ratio ?f64
mut:
	clients map[u64]DecodedImageClientUpdateCallback
	is_cors_cross_origin_ bool
}

pub fn SVGDecodedImageData.create(document &dom.Document, width ?f64, height ?f64, aspect_ratio ?f64) &SVGDecodedImageData {
	return &SVGDecodedImageData{
		svg_document: document
		width: width
		height: height
		aspect_ratio: aspect_ratio
		clients: map[u64]DecodedImageClientUpdateCallback{}
	}
}

pub fn (data &SVGDecodedImageData) intrinsic_width() ?f64 { return data.width }
pub fn (data &SVGDecodedImageData) intrinsic_height() ?f64 { return data.height }
pub fn (data &SVGDecodedImageData) intrinsic_aspect_ratio() ?f64 { return data.aspect_ratio }
pub fn (_ &SVGDecodedImageData) frame_count() uint { return 1 }
pub fn (_ &SVGDecodedImageData) frame(_ uint) ?&dom.DecodedImageFrame_ { return none }
pub fn (_ &SVGDecodedImageData) frame_rect(_ uint) ?BitmapRect { return none }
pub fn (_ &SVGDecodedImageData) frame_duration(_ uint) int { return 0 }
pub fn (_ &SVGDecodedImageData) loop_count() uint { return 0 }
pub fn (_ &SVGDecodedImageData) is_animated() bool { return false }
pub fn (_ &SVGDecodedImageData) external_memory_size() uint { return 0 }
pub fn (data &SVGDecodedImageData) has_clients() bool { return data.clients.len != 0 }
pub fn (data &SVGDecodedImageData) is_cors_cross_origin() bool { return data.is_cors_cross_origin_ }

pub fn (data &SVGDecodedImageData) set_is_cors_cross_origin(value bool) {
	mut mutable_data := unsafe { &SVGDecodedImageData(data) }
	mutable_data.is_cors_cross_origin_ = value
}

pub fn (data &SVGDecodedImageData) register_client(client_id u64, callback DecodedImageClientUpdateCallback) {
	mut mutable_data := unsafe { &SVGDecodedImageData(data) }
	mutable_data.clients[client_id] = callback
}

pub fn (data &SVGDecodedImageData) unregister_client(client_id u64) {
	mut mutable_data := unsafe { &SVGDecodedImageData(data) }
	mutable_data.clients.delete(client_id)
}
