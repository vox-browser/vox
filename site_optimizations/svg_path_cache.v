module main

import os

const disable_github_svg_path_cache = os.getenv('VOX_DISABLE_GITHUB_SVG_PATH_CACHE') != ''
const github_svg_path_cache_diagnostics = os.getenv('VOX_GITHUB_SVG_PATH_CACHE_DIAGNOSTICS') != ''

fn C.native_set_small_svg_path_cache(enabled i32) i32
fn C.native_small_svg_path_cache_hits() u64

// Scope the graphics service to this document's draw, including nested native
// frames. Exact descriptors and backdrop bytes govern reuse inside the cache.
fn (app &BrowserApp) begin_site_svg_path_cache() i32 {
	$if macos {
		enabled := !disable_github_svg_path_cache && app.document != unsafe { nil }
			&& site_batches_image_completion_layout(app.document.url.serialize())
		return C.native_set_small_svg_path_cache(i32(int(enabled)))
	}
	return 0
}

fn finish_site_svg_path_cache(previous i32) {
	$if macos {
		C.native_set_small_svg_path_cache(previous)
		if github_svg_path_cache_diagnostics {
			eprintln('Vox site SVG raster cache: hits=${C.native_small_svg_path_cache_hits()}')
		}
	}
}
