module platform

#pkgconfig fontconfig
#include "fontconfig_linux.h"

fn C.vox_fontconfig_path(family &char, weight int, exact bool) &char
fn C.free(voidptr)

fn linux_font_path(family string, weight int, exact bool) ?string {
	path := C.vox_fontconfig_path(family.str, weight, exact)
	if path == unsafe { nil } { return none }
	defer { unsafe { C.free(path) } }
	return unsafe { cstring_to_vstring(path) }
}
