module metal

pub enum CompareFunction { never less equal less_equal greater not_equal greater_equal always }
pub enum StencilOperation { keep zero replace increment_clamp decrement_clamp invert increment_wrap decrement_wrap }
pub enum BlendOperation { add subtract reverse_subtract min max }
pub enum BlendFactor { zero one source_color one_minus_source_color source_alpha one_minus_source_alpha destination_color one_minus_destination_color destination_alpha one_minus_destination_alpha source_alpha_saturated constant_color one_minus_constant_color constant_alpha one_minus_constant_alpha }
pub enum CullMode { none front back }

pub struct Viewport {
pub:
	x f64
	y f64
	width f64
	height f64
	near_depth f64
	far_depth f64 = 1
}

pub struct ScissorRect {
pub:
	x int
	y int
	width int
	height int
}

pub struct StencilFace {
pub:
	compare CompareFunction = .always
	fail StencilOperation
	depth_fail StencilOperation
	pass StencilOperation
	reference u32
	read_mask u32 = 255
	write_mask u32 = 255
}

pub struct RenderState {
pub:
	viewport ?Viewport
	scissor ?ScissorRect
	color_mask u32 = 15 // R/G/B/A in bits 0/1/2/3.
	blend bool
	rgb_operation BlendOperation
	alpha_operation BlendOperation
	source_rgb BlendFactor = .one
	destination_rgb BlendFactor
	source_alpha BlendFactor = .one
	destination_alpha BlendFactor
	blend_color [4]f32
	cull CullMode
	front_ccw bool = true
	depth_test bool
	depth_write bool = true
	depth_compare CompareFunction = .less
	stencil_test bool
	front_stencil StencilFace
	back_stencil StencilFace
	depth_bias f32
	depth_slope f32
}

fn native_stencil_face(face StencilFace) C.VoxMetalStencilFace {
	return C.VoxMetalStencilFace{compare: u32(face.compare), fail: u32(face.fail), depth_fail: u32(face.depth_fail), pass: u32(face.pass), reference: face.reference & 255, read_mask: face.read_mask & 255, write_mask: face.write_mask & 255}
}

fn native_render_state(target &DrawingBuffer, options DrawOptions) !C.VoxMetalRenderState {
	width, height := if options.color_target != unsafe { nil } { options.color_target.size() } else { target.size() }
	state := options.state
	viewport := state.viewport or { Viewport{width: f64(width), height: f64(height)} }
	if viewport.width != viewport.width || viewport.height != viewport.height || viewport.width < 0 || viewport.height < 0 || viewport.width > 16384 || viewport.height > 16384
		|| viewport.x != viewport.x || viewport.y != viewport.y || viewport.x < -32768 || viewport.y < -32768 || viewport.x > 32767 || viewport.y > 32767 { return error('Invalid Metal viewport') }
	rect := state.scissor or { ScissorRect{width: width, height: height} }
	if rect.width < 0 || rect.height < 0 || rect.width > 0x7fffffff || rect.height > 0x7fffffff || rect.x < -0x80000000 || rect.y < -0x80000000 || rect.x > 0x7fffffff || rect.y > 0x7fffffff { return error('Invalid Metal scissor') }
	x := if rect.x < 0 { 0 } else if rect.x > width { width } else { rect.x }
	y := if rect.y < 0 { 0 } else if rect.y > height { height } else { rect.y }
	right := if rect.x + rect.width < x { x } else if rect.x + rect.width > width { width } else { rect.x + rect.width }
	bottom := if rect.y + rect.height < y { y } else if rect.y + rect.height > height { height } else { rect.y + rect.height }
	mut depth_handle := unsafe { nil }
	if options.depth_stencil != unsafe { nil } {
		depth := options.depth_stencil
		if depth.handle == unsafe { nil } || depth.owner.handle != target.handle || depth.width != width || depth.height != height { return error('Metal depth/stencil attachment has wrong owner or dimensions') }
		depth_handle = depth.handle
	}
    mut colors:=[8]voidptr{}
    mut used:=u32(0)
    for attachment in options.color_targets {
        texture:=attachment.texture
        if attachment.index<0 || attachment.index>=8 || used&(u32(1)<<attachment.index)!=0
            || texture==unsafe { nil } || texture.handle==unsafe { nil } || texture.owner.handle!=target.handle || texture.width!=width || texture.height!=height { return error('Invalid Metal color attachment') }
        used|=u32(1)<<attachment.index
        colors[attachment.index]=texture.handle
    }
    mut visibility:=unsafe { nil }
    if options.visibility!=unsafe { nil } {
        if options.visibility.handle==unsafe { nil } || options.visibility.owner.handle!=target.handle || options.visibility.length<8 { return error('Invalid Metal visibility buffer') }
        visibility=options.visibility.handle
    }
	return C.VoxMetalRenderState{
        color_targets:colors
        colors_configured:u32(options.colors_configured)
        visibility_buffer:visibility
		depth_stencil: depth_handle
		x: viewport.x, y: viewport.y, width: viewport.width, height: viewport.height
		near_depth: clear_component(viewport.near_depth), far_depth: clear_component(viewport.far_depth)
		scissor_x: u64(x), scissor_y: u64(y), scissor_width: u64(right - x), scissor_height: u64(bottom - y)
		color_mask: state.color_mask & 15, blend: u32(state.blend)
		rgb_operation: u32(state.rgb_operation), alpha_operation: u32(state.alpha_operation)
		source_rgb: u32(state.source_rgb), destination_rgb: u32(state.destination_rgb)
		source_alpha: u32(state.source_alpha), destination_alpha: u32(state.destination_alpha)
		blend_red: f32(clear_component(state.blend_color[0])), blend_green: f32(clear_component(state.blend_color[1]))
		blend_blue: f32(clear_component(state.blend_color[2])), blend_alpha: f32(clear_component(state.blend_color[3]))
		cull: u32(state.cull), front_ccw: u32(state.front_ccw)
		depth_test: u32(state.depth_test), depth_write: u32(state.depth_write), depth_compare: u32(state.depth_compare)
		stencil_test: u32(state.stencil_test), front: native_stencil_face(state.front_stencil), back: native_stencil_face(state.back_stencil)
		depth_bias: state.depth_bias, depth_slope: state.depth_slope
	}
}
