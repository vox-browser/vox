module main

import crypto.sha256
import os

struct CnnWebpPlaneReference {
	body   string
	width  int
	height int
	planes [3]string
}

// Independent ImageDecoder/WebCodecs I420 output from Brave 157.1.99.57.
// These pin decoder bytes, not HTML image filtering or screenshot equality.
// See docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md for the capture scope.
fn test_cnn_complete_webp_planes_match_brave_decoder_output() {
	$if macos {
		if C.native_webp_yuv_decoder_available() == 0 {
			eprintln('SKIP: optional libwebp YUV decoder unavailable')
			return
		}
		references := [
			CnnWebpPlaneReference{
				body:   '781d2b9c3ec6b401a4b2e9dbdce964f4ba3f6ecdb9880466d85dc30df6227139'
				width:  960
				height: 540
				planes: [
					'25f79bfccaded1fefd2f5e284bdbfa25450e81130aa34d9f7a0b6a25561253b0',
					'd3fae7d53a17ab9012e81936f47f2645eeb0e09e25dd6e2ae5967def3b5e432a',
					'76e7691386258c91f0f59b0868893e8dc7457a0e9ed68450bdcd54a17f56470e',
				]!
			},
			CnnWebpPlaneReference{
				body:   '4eac45cddbcdce864f86204bc16e05da0609cd75345110e8a1ff1a088324463f'
				width:  1280
				height: 720
				planes: [
					'0765b755b2f16b611ca5c45dcc05318cc20bffa12a7fbc931ddb6398aecb63e1',
					'105df6010e60e17f5d17b2535157e4b5196eb0ee11401fc889200446e73663f2',
					'370555239bcf0c20398ae7dd0aa2eda4593c85c679e9c581ccbbb6f958d504f2',
				]!
			},
			CnnWebpPlaneReference{
				body:   'c528c3f7032614459d9dbfeefc807d9c7f1a27911f08f49c2bc5aff7f0370bad'
				width:  960
				height: 540
				planes: [
					'5c6b1ca1afeb70e87307853faa70e22af60c4a9d4b4ab90a0217266a003419cc',
					'0bddcb3353bb52efeabac7b0bf78b6bc8504410e4030aeab70b0670fcf3e2f1c',
					'b6b532892f4db0d0471f52a5429d163b4f2b66b296e3aa8335870753b681e714',
				]!
			},
			CnnWebpPlaneReference{
				body:   '1444e339bc56ef6ab975fec31809dc616a22015d1c730037d5550af5759cd1dc'
				width:  1280
				height: 720
				planes: [
					'465d21f81c9f6bd4569ce13891db63c766b761918f98d05b3b582dfd461fb595',
					'82ea4bf628ed4f41c4b1af73998f3f37e64bf1c04a7b74170274d30d5b2ecea3',
					'80884fdde53dd179e5beb168dea308fce9eaf88e4753a5fccb26950e2273ce5a',
				]!
			},
			CnnWebpPlaneReference{
				body:   '64c0bec89a02c6abf49a57bc3a3723f395d6cb2b7ef76ab0a0d429bf33b2dd8f'
				width:  256
				height: 144
				planes: [
					'91842375cfb02f3071520446b1a2d2feaae206b5f4922597d6931f1d169fdef1',
					'14796cd951388b4b18d81a8254df9fa933653d9f72b8e2d342f8afa99c24e538',
					'c67a7f68660a7ad9e8462ffe8bff4acec4dedf2a0c37fc5d6cc611d798677ecb',
				]!
			},
		]
		for reference in references {
			assert_cnn_webp_reference(reference)
		}
	}
}

fn assert_cnn_webp_reference(reference CnnWebpPlaneReference) {
	bytes := os.read_bytes(os.join_path(@VMODROOT, 'Tests/Browser/Brave/sites/cnn/bodies', reference.body)) or { panic('CNN fixture: ${err}') }
	assert sha256.sum(bytes).hex() == reference.body
	mut width, mut height, mut size := 0, 0, 0
	decoded := C.native_decode_webp_yuv(bytes.data, uint(bytes.len), &width, &height, &size)
	assert decoded != unsafe { nil }
	defer { C.native_free_webp_pixels(decoded) }
	assert width == reference.width && height == reference.height
	y_size, uv_size := width * height, ((width + 1) / 2) * ((height + 1) / 2)
	assert size == y_size + 2 * uv_size
	planes := unsafe { decoded.vbytes(size) }
	for index, expected in reference.planes {
		offset, count := if index == 0 { 0 } else { y_size + (index - 1) * uv_size }, if index == 0 {
			y_size
		} else {
			uv_size
		}
		assert sha256.sum(planes[offset..offset + count]).hex() == expected, 'CNN ${reference.body}, plane ${index}'
	}
}
