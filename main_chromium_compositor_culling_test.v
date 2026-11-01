module main

import layout
import math

fn test_compositor_shadow_rejection_includes_the_native_blur_margin_and_fringe() {
	viewport := layout.LayoutRect{0,0,1024,768}
	shadow := layout.PaintCommand{kind:'paint_outer_box_shadow',x:688,y:3749,width:304,height:171,blur:20}
	assert chromium_compositor_leaf_is_culled(&shadow,viewport)
	for y in [f64(700),800,811] {
		near := layout.PaintCommand{...shadow,y:y}
		assert !chromium_compositor_leaf_is_culled(&near,viewport)
	}
	for changed in [layout.PaintCommand{...shadow,blur:math.nan()},
		layout.PaintCommand{...shadow,blur:math.inf(1)},
		layout.PaintCommand{...shadow,transform:[f64(1),0,0,1,0,-3749]!},
		layout.PaintCommand{...shadow,transform:[f64(1),0,0,1,0,1e8]!},
		layout.PaintCommand{...shadow,kind:'begin_css_filter_layer'},
	] {
		assert !chromium_compositor_leaf_is_culled(&changed,viewport)
	}
}

fn test_compositor_shadow_culling_retains_inner_bounds_and_empty_clip_scopes() {
	viewport := layout.LayoutRect{0,0,1024,768}
	shadow := layout.PaintCommand{kind:'paint_inner_box_shadow',y:4000,width:100,height:20,
		box_shadow_data:&layout.PaintBoxShadowData{content_rect:layout.LayoutRect{0,100,100,20}}}
	assert !chromium_compositor_leaf_is_culled(&shadow,viewport)
	for kind in ['fill_rect','paint_outer_box_shadow'] {
		leaf := layout.PaintCommand{kind:kind,has_clip:true,clip_width:0,clip_height:10}
		assert chromium_compositor_leaf_is_culled(&leaf,viewport)
	}
	boundary := layout.PaintCommand{kind:'begin_svg_mask_layer',has_clip:true,clip_width:0,clip_height:10}
	assert !chromium_compositor_leaf_is_culled(&boundary,viewport)
}
