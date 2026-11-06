// Compares the native borrowed-frame glyph path with and without the V GG callback.
module main

import ggtext
import os

fn C.dlopen(path &char, mode int) voidptr
fn C.dlsym(handle voidptr, symbol &char) voidptr

type CheckClippedText = fn (callback voidptr, count i32) i32

fn main() {
	if os.args.len < 2 {
		eprintln('usage: clipped_text_check NATIVE_ORACLE [COUNT]')
		exit(2)
	}
	library := C.dlopen(os.args[1].str, 2)
	if library == unsafe { nil } {
		panic('could not load the native text oracle')
	}
	symbol := C.dlsym(library, c'vox_check_clipped_gg_text')
	if symbol == unsafe { nil } {
		panic('native text oracle entry point missing')
	}
	check := unsafe { CheckClippedText(symbol) }
	count := if os.args.len > 2 { os.args[2].int() } else { 2000 }
	if count <= 0 || check(voidptr(ggtext.glyph_run), i32(count)) != 0 {
		exit(1)
	}
}
