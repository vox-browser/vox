module metal

pub enum TextureKind { image_2d cube array_2d volume_3d }

pub struct TextureStorageOptions {
pub:
    width int
    height int
    depth int = 1
    levels int = 1
    samples int = 1
    kind TextureKind
    format TextureFormat
}

pub struct TextureRegion {
pub:
    x int
    y int
    z int
    width int
    height int
    depth int = 1
}

pub fn Texture2D.create_storage(owner &DrawingBuffer,options TextureStorageOptions) !&Texture2D {
    if owner.handle==unsafe { nil } || options.width<1 || options.width>16384 || options.height<1 || options.height>16384
        || options.depth<1 || options.depth>2048 || options.levels<1 || options.levels>15 || options.samples !in [1,2,4,8]
        || (options.kind==.cube && options.width!=options.height) || (options.kind in [.image_2d,.cube] && options.depth!=1)
        || (options.format in [.depth16,.depth32,.depth_stencil,.stencil8] && options.kind==.volume_3d)
        || (options.samples>1 && (options.kind!=.image_2d || options.levels!=1)) { return error('Invalid Metal texture storage') }
    mut largest:=if options.width>options.height { options.width } else { options.height }
    if options.kind==.volume_3d && options.depth>largest { largest=options.depth }
    if largest>>(options.levels-1)==0 { return error('Too many Metal mip levels') }
    handle:=C.vox_metal_texture_storage(owner.handle,u32(options.width),u32(options.height),u32(options.depth),u32(options.kind),u32(options.levels),u32(options.format),u32(options.format.pixel_size()),u32(options.samples))
    if handle==unsafe { nil } { return error('Metal texture storage allocation failed') }
    return &Texture2D{handle:handle,owner:owner,width:options.width,height:options.height,depth:options.depth,levels:options.levels,samples:options.samples,kind:options.kind,format:options.format}
}

pub fn (texture &Texture2D) dimensions(level int) !(int,int,int) {
    if texture.handle==unsafe { nil } || level<0 || level>=texture.levels { return error('Invalid Metal mip level') }
    w:=texture.width>>level;h:=texture.height>>level;d:=if texture.kind==.volume_3d { texture.depth>>level } else { texture.depth }
    return if w>0 { w } else { 1 },if h>0 { h } else { 1 },if d>0 { d } else { 1 }
}

fn (texture &Texture2D) region_size(level int,slice int,region TextureRegion) !int {
    w,h,d:=texture.dimensions(level)!
    slices:=if texture.kind==.cube { 6 } else if texture.kind==.array_2d { texture.depth } else { 1 }
    if texture.samples!=1 || slice<0 || slice>=slices || region.x<0 || region.y<0 || region.z<0 || region.width<0 || region.height<0 || region.depth<0
        || region.x>w || region.width>w-region.x || region.y>h || region.height>h-region.y
        || region.z>if texture.kind==.volume_3d { d } else { 1 } || region.depth>(if texture.kind==.volume_3d { d } else { 1 })-region.z { return error('Metal texture region is outside allocation') }
    return region.width*region.height*region.depth*texture.format.pixel_size()
}

pub fn (mut texture Texture2D) write_region(level int,slice int,region TextureRegion,bytes []u8) ! {
    size:=texture.region_size(level,slice,region)!
    if bytes.len!=size { return error('Metal texture region requires exact byte length') }
    if size==0 { return }
    if C.vox_metal_texture_region(texture.handle,u32(level),u32(slice),u32(region.x),u32(region.y),u32(region.z),u32(region.width),u32(region.height),u32(region.depth),u32(texture.format.pixel_size()),bytes.data,u64(bytes.len),1)!=1 { return error('Metal texture region upload failed') }
}

pub fn (texture &Texture2D) read_region(level int,slice int,region TextureRegion) ![]u8 {
    size:=texture.region_size(level,slice,region)!
    mut bytes:=[]u8{len:size}
    if size==0 { return bytes }
    if C.vox_metal_texture_region(texture.handle,u32(level),u32(slice),u32(region.x),u32(region.y),u32(region.z),u32(region.width),u32(region.height),u32(region.depth),u32(texture.format.pixel_size()),bytes.data,u64(bytes.len),0)!=1 { unsafe { bytes.free() };return error('Metal texture region readback failed') }
    return bytes
}

pub fn (texture &Texture2D) attachment(level int,slice int) !&Texture2D {
    w,h,d:=texture.dimensions(level)!
    limit:=if texture.kind==.cube { 6 } else if texture.kind in [.array_2d,.volume_3d] { d } else { 1 }
    if slice<0 || slice>=limit { return error('Invalid Metal attachment slice') }
    handle:=C.vox_metal_texture_attachment(texture.handle,u32(level),u32(slice))
    if handle==unsafe { nil } { return error('Metal texture attachment creation failed') }
    return &Texture2D{handle:handle,owner:texture.owner,width:w,height:h,format:texture.format,samples:texture.samples}
}

pub fn (mut texture Texture2D) generate_mipmaps() ! {
    if texture.format !in [.rgba8,.r8,.rg8,.srgba8,.r8_snorm,.rg8_snorm,.rgba8_snorm,.r16f,.rg16f,.rgba16f,.r32f,.rg32f,.rgba32f,.rgb10a2,.rg11b10f] { return error('Metal texture format cannot generate filtered mipmaps') }
    if texture.samples!=1 || C.vox_metal_texture_mipmaps(texture.handle)!=1 { return error('Metal mipmap generation failed') }
}
