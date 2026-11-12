module webgl

$if macos {
	$if arm64 {
		#flag -I/opt/homebrew/opt/glslang/include
		#flag -Wl,-rpath,/opt/homebrew/opt/glslang/lib
	} $else {
		#flag -I/usr/local/opt/glslang/include
		#flag -Wl,-rpath,/usr/local/opt/glslang/lib
	}
} $else $if windows {
	#flag -lglslang -lglslang-default-resource-limits -lstdc++
} $else {
	#pkgconfig glslang
	#flag -lglslang-default-resource-limits -lstdc++ -lpthread
}
#include "@DIR/native_gl_shader_validation.h"

fn C.vox_essl_validate(&char, int, int, int, voidptr, &char, u64) int
