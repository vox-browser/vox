//! Complete static 8-bit sRGB/gray JPEG XL decoding for Vox's shared image path.
use jxl::api::{states::Initialized, *};
use std::{
    panic::{AssertUnwindSafe, catch_unwind},
    ptr,
};

fn complete<T, U>(result: ProcessingResult<T, U>) -> Option<T> {
    match result {
        ProcessingResult::Complete { result } => Some(result),
        _ => None,
    }
}

fn decode(mut input: &[u8], premultiply: bool) -> Option<(Box<[u8]>, usize, usize)> {
    let mut options = JxlDecoderOptions::default();
    // The library counts samples, including extra channels, before allocating frames.
    options.sample_limit = Some(64 * 1024 * 1024);
    options.premultiply_output = premultiply;
    let mut decoder = complete(
        JxlDecoder::<Initialized>::new(options)
            .process(&mut input, None)
            .ok()?,
    )?;
    let info = decoder.basic_info();
    let (width, height) = info.size;
    if info.animation.is_some()
        || !matches!(info.bit_depth, JxlBitDepth::Int { bits_per_sample: 8 })
        || width == 0
        || height == 0
        || width > 65536
        || height > 65536
    {
        return None;
    }
    let samples = width.checked_mul(height)?.checked_mul(4)?;
    if samples > 64 * 1024 * 1024 {
        return None;
    }
    // No CMS is installed. Never reinterpret ICC, wide-gamut or HDR data as sRGB.
    let srgb = JxlColorProfile::Simple(JxlColorEncoding::srgb(false));
    let gray = JxlColorProfile::Simple(JxlColorEncoding::srgb(true));
    let profile = decoder.output_color_profile();
    if !profile.same_color_encoding(&srgb) && !profile.same_color_encoding(&gray) {
        return None;
    }
    decoder
        .set_pixel_format(JxlPixelFormat::rgba8(info.extra_channels.len()))
        .ok()?;
    let decoder = complete(decoder.process(&mut input, None).ok()?)?;
    let mut pixels = vec![0u8; samples].into_boxed_slice();
    let mut buffer = [JxlOutputBuffer::new_with_stride(
        &mut pixels,
        height,
        width * 4,
        width * 4,
    )];
    let decoder = complete(decoder.process(&mut input, &mut buffer, None).ok()?)?;
    if decoder.has_more_frames() {
        return None;
    }
    Some((pixels, width, height))
}

#[unsafe(no_mangle)]
pub extern "C" fn vox_jpegxl_rust_api_version() -> u32 {
    1
}

// Shared checked boundary for straight model rows and decoder-premultiplied paint rows.
unsafe fn decode_ffi(
    data: *const u8,
    length: u64,
    width: *mut i32,
    height: *mut i32,
    pitch: *mut i32,
    premultiply: bool,
) -> *mut u8 {
    if width.is_null() || height.is_null() || pitch.is_null() {
        return ptr::null_mut();
    }
    unsafe {
        *width = 0;
        *height = 0;
        *pitch = 0;
    }
    if data.is_null() || length < 2 || length > 64 * 1024 * 1024 {
        return ptr::null_mut();
    }
    catch_unwind(AssertUnwindSafe(|| {
        let Some((pixels, w, h)) = decode(
            unsafe { std::slice::from_raw_parts(data, length as usize) },
            premultiply,
        ) else {
            return ptr::null_mut();
        };
        unsafe {
            *width = w as i32;
            *height = h as i32;
            *pitch = (w * 4) as i32;
        }
        Box::into_raw(pixels) as *mut u8
    }))
    .unwrap_or(ptr::null_mut())
}

/// # Safety
/// The caller supplies readable input and three writable, disjoint output integers.
/// A successful pixel buffer must be released once with its returned pitch * height.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn vox_jpegxl_rust_decode(
    data: *const u8,
    length: u64,
    width: *mut i32,
    height: *mut i32,
    pitch: *mut i32,
) -> *mut u8 {
    unsafe { decode_ffi(data, length, width, height, pitch, false) }
}

/// # Safety
/// `pixels` is null or a live buffer from vox_jpegxl_rust_decode, with its exact length.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn vox_jpegxl_rust_free(pixels: *mut u8, length: u64) {
    if !pixels.is_null() {
        unsafe {
            drop(Box::from_raw(ptr::slice_from_raw_parts_mut(
                pixels,
                length as usize,
            )));
        }
    }
}

/// # Safety
/// The same ownership contract as vox_jpegxl_rust_decode, with premultiplied rows.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn vox_jpegxl_rust_decode_paint(
    data: *const u8,
    length: u64,
    width: *mut i32,
    height: *mut i32,
    pitch: *mut i32,
) -> *mut u8 {
    unsafe { decode_ffi(data, length, width, height, pitch, true) }
}
