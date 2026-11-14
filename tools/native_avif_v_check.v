// Checks that Vox's V libyuv conversion of libVoxAVIF's packed planes matches
// Brave's RGBA bytes for the Slate photos, as images/avif.v decodes them.
// Run by tools/test_native_avif.py beside the helper it builds.
module main

import os
import yuv

#include "@VMODROOT/native/include/native_avif.h"

fn C.vox_avif_available() int
fn C.vox_avif_release(&u8)
fn C.vox_avif_decode_planes(&u8, u64, &i32, &i32, &i32, &i32, &i32) &u8

fn main() {
	if os.args.len != 2 || C.vox_avif_available() == 0 {
		eprintln('usage: native_avif_v_check RESOURCES (beside libVoxAVIF.dylib)')
		exit(2)
	}
	mut exact := 0
	for stem in ['slate-hero', 'slate-card'] {
		encoded := os.read_bytes(os.join_path(os.args[1], stem + '.jpeg')) or { panic(err) }
		expected := os.read_bytes(os.join_path(os.args[1], stem + '-rgba.rgba')) or { panic(err) }
		mut width := i32(0)
		mut height := i32(0)
		mut size := i32(0)
		mut layout := i32(0)
		mut matrix := i32(-1)
		planes := C.vox_avif_decode_planes(encoded.data, u64(encoded.len), &width, &height, &size,
			&layout, &matrix)
		if planes == unsafe { nil } {
			eprintln('${stem}: no packed planes')
			exit(1)
		}
		pixels := yuv.libyuv_packed_to_rgba(planes, int(size), int(width), int(height),
			int(layout), int(matrix)) or {
			eprintln('${stem}: conversion failed')
			exit(1)
		}
		C.vox_avif_release(planes)
		if pixels != expected {
			mut differing := 0
			for i in 0 .. pixels.len {
				if i >= expected.len || pixels[i] != expected[i] {
					differing++
				}
			}
			eprintln('${stem}: ${differing} of ${pixels.len} bytes differ from Brave')
			exit(1)
		}
		exact++
	}
	println('AVIF: ${exact} exact Brave RGBA photo decodes through the V libyuv conversion')
}
