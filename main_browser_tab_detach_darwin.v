module main

#include "native_browser_tab_detach_darwin.h"

fn C.native_open_tab_window(executable &u8, session &u8) bool
fn C.native_tab_drop_x() f64
fn C.native_tab_drop_y() f64
fn C.native_position_detached_tab(x f64, y f64)
