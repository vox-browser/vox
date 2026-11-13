// Copyright (c) 2026, Vox contributors
// SPDX-License-Identifier: BSD-2-Clause
module main

import os
import webgl.shader

$if windows {
    #pkgconfig vox-mesa-egl
} $else {
    #pkgconfig egl glesv2 gl x11
    #flag -lm -ldl
}
#define main vox_native_gles_main
$if vox_gles_host ? {
    #include "@VMODROOT/tools/native_gles_host_linux_test.c"
} $else {
    #include "@VMODROOT/tools/native_gles_test.c"
}
#undef main
$if vox_gles_host ? {
    fn C.vox_native_gles_main(i32, &&char) i32
} $else {
    fn C.vox_native_gles_main() i32
}

fn main() {
    // Explicitly retain the V validator used by the native C service.
    shader.validate_source('void main(){}', .vertex, 2) or { panic(err) }
    $if vox_gles_host ? {
        mut args := []&char{}
        for arg in os.args { args << &char(arg.str) }
        args << &char(unsafe { nil })
        exit(int(C.vox_native_gles_main(i32(os.args.len), args.data)))
    } $else {
        exit(int(C.vox_native_gles_main()))
    }
}
