module main

import os

fn C.native_begin_deferred_layer_frame(i32)
fn C.native_finish_deferred_layer_frame() i32

// Same-binary control: keep every leaf raster immediate in frames that qualify
// for viewport scroll reuse, even inside compositor layers.
const disable_reused_frame_layer_deferral = os.getenv('VOX_DISABLE_REUSED_FRAME_LAYER_DEFERRAL') != ''
