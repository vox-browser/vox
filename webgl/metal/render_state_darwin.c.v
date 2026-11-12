module metal

#include "@DIR/render_state_darwin.h"

@[typedef]
struct C.VoxMetalStencilFace {
	compare u32
	fail u32
	depth_fail u32
	pass u32
	reference u32
	read_mask u32
	write_mask u32
}

@[typedef]
struct C.VoxMetalRenderState {
	depth_stencil voidptr
	x f64
	y f64
	width f64
	height f64
	near_depth f64
	far_depth f64
	scissor_x u64
	scissor_y u64
	scissor_width u64
	scissor_height u64
	color_mask u32
	blend u32
	rgb_operation u32
	alpha_operation u32
	source_rgb u32
	destination_rgb u32
	source_alpha u32
	destination_alpha u32
	blend_red f32
	blend_green f32
	blend_blue f32
	blend_alpha f32
	cull u32
	front_ccw u32
	depth_test u32
	depth_write u32
	depth_compare u32
	stencil_test u32
	depth_bias f32
	depth_slope f32
	front C.VoxMetalStencilFace
	back C.VoxMetalStencilFace
    color_targets [8]voidptr
    colors_configured u32
    visibility_buffer voidptr
}
