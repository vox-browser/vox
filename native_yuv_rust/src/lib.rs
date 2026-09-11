use yuv::{YuvPlanarImage, YuvRange, YuvStandardMatrix};

#[repr(u8)]
pub enum NativeYuvRange {
    Limited = 0,
    Full = 1,
}

#[repr(u8)]
pub enum NativeYuvMatrix {
    Bt709 = 0,
    Fcc = 1,
    Bt470Bg = 2,
    Bt601 = 3,
    Smpte240 = 4,
    Bt2020 = 5,
}

impl From<NativeYuvRange> for YuvRange {
    fn from(range: NativeYuvRange) -> Self {
        match range {
            NativeYuvRange::Limited => Self::Limited,
            NativeYuvRange::Full => Self::Full,
        }
    }
}

impl From<NativeYuvMatrix> for YuvStandardMatrix {
    fn from(matrix: NativeYuvMatrix) -> Self {
        match matrix {
            NativeYuvMatrix::Bt709 => Self::Bt709,
            NativeYuvMatrix::Fcc => Self::Fcc,
            NativeYuvMatrix::Bt470Bg => Self::Bt470_6,
            NativeYuvMatrix::Bt601 => Self::Bt601,
            NativeYuvMatrix::Smpte240 => Self::Smpte240,
            NativeYuvMatrix::Bt2020 => Self::Bt2020,
        }
    }
}

/// Convert an 8-bit planar YUV frame using the same yuv crate and conversion
/// entry points as upstream LibGfx::YUVData.
///
/// # Safety
/// Every plane and destination pointer must cover its stride times its height.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ladybird_v_yuv_u8_to_rgba(
    y_plane: *const u8,
    y_stride: u32,
    u_plane: *const u8,
    u_stride: u32,
    v_plane: *const u8,
    v_stride: u32,
    width: u32,
    height: u32,
    subsampling_x: bool,
    subsampling_y: bool,
    dst: *mut u8,
    dst_stride: u32,
    range: NativeYuvRange,
    matrix: NativeYuvMatrix,
) -> bool {
    let y_len = y_stride as usize * height as usize;
    let uv_height = if subsampling_y { height.div_ceil(2) } else { height } as usize;
    let uv_len = u_stride as usize * uv_height;
    let image = YuvPlanarImage {
        y_plane: unsafe { core::slice::from_raw_parts(y_plane, y_len) },
        y_stride,
        u_plane: unsafe { core::slice::from_raw_parts(u_plane, uv_len) },
        u_stride,
        v_plane: unsafe { core::slice::from_raw_parts(v_plane, uv_len) },
        v_stride,
        width,
        height,
    };
    let destination = unsafe {
        core::slice::from_raw_parts_mut(dst, dst_stride as usize * height as usize)
    };
    let result = match (subsampling_x, subsampling_y) {
        (true, true) => yuv::yuv420_to_rgba(
            &image,
            destination,
            dst_stride,
            range.into(),
            matrix.into(),
        ),
        (true, false) => yuv::yuv422_to_rgba(
            &image,
            destination,
            dst_stride,
            range.into(),
            matrix.into(),
        ),
        (false, true) => return false,
        (false, false) => yuv::yuv444_to_rgba(
            &image,
            destination,
            dst_stride,
            range.into(),
            matrix.into(),
        ),
    };
    result.is_ok()
}
