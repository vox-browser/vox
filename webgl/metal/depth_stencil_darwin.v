module metal

@[heap]
pub struct DepthStencil {
mut:
	handle voidptr
	owner &DrawingBuffer
	width int
	height int
    samples int = 1
}

pub fn DepthStencil.create(owner &DrawingBuffer, width int, height int) !&DepthStencil {
	if owner.handle == unsafe { nil } || width < 1 || height < 1 || width > 16384 || height > 16384 { return error('Invalid Metal depth/stencil owner or dimensions') }
	handle := C.vox_metal_depth_stencil_create(owner.handle, i32(width), i32(height))
	if handle == unsafe { nil } { return error('Metal depth/stencil allocation failed') }
	return &DepthStencil{handle: handle, owner: owner, width: width, height: height}
}

pub fn (mut storage DepthStencil) clear(depth f64, stencil u32) ! {
	if C.vox_metal_depth_stencil_clear(storage.handle, clear_component(depth), stencil & 255) != 1 { return error('Metal depth/stencil clear failed or resource is closed') }
}

pub fn (mut storage DepthStencil) close() {
	C.vox_metal_depth_stencil_destroy(storage.handle)
	storage.handle = unsafe { nil }
	storage.width = 0
	storage.height = 0
}

pub fn DepthStencil.from_attachments(owner &DrawingBuffer,depth &Texture2D,stencil &Texture2D) !&DepthStencil {
    if owner.handle==unsafe { nil } || (depth==unsafe { nil } && stencil==unsafe { nil }) { return error('Missing Metal depth/stencil attachment') }
    if depth!=unsafe { nil } && (depth.handle==unsafe { nil } || depth.owner.handle!=owner.handle || depth.format !in [.depth16,.depth32,.depth_stencil]) { return error('Invalid Metal depth attachment') }
    if stencil!=unsafe { nil } && (stencil.handle==unsafe { nil } || stencil.owner.handle!=owner.handle || stencil.format !in [.stencil8,.depth_stencil]) { return error('Invalid Metal stencil attachment') }
    source:=if depth!=unsafe { nil } { depth } else { stencil }
    if depth!=unsafe { nil } && stencil!=unsafe { nil } && (depth.width!=stencil.width || depth.height!=stencil.height || depth.samples!=stencil.samples) { return error('Metal depth/stencil attachment dimensions differ') }
    handle:=C.vox_metal_depth_stencil_from_textures(if depth!=unsafe { nil } { depth.handle } else { unsafe { nil } },if stencil!=unsafe { nil } { stencil.handle } else { unsafe { nil } })
    if handle==unsafe { nil } { return error('Metal depth/stencil attachment allocation failed') }
    return &DepthStencil{handle:handle,owner:owner,width:source.width,height:source.height,samples:source.samples}
}

pub fn (source &DepthStencil) texture_view(stencil bool) !&Texture2D {
    mut format:=u32(0)
    handle:=C.vox_metal_depth_stencil_view(source.handle,i32(stencil),&format)
    if handle==unsafe { nil } { return error('Metal depth/stencil aspect is unavailable') }
    return &Texture2D{handle:handle,owner:source.owner,width:source.width,height:source.height,samples:source.samples,format:unsafe { TextureFormat(format) }}
}
