module buildtools

import os
import json2 as json

fn test_gg_staging_keeps_portable_headers_in_c() ! {
	root := temporary(os.temp_dir(), 'vox-gg-native-language-')!
	defer { remove(root) or {} }
	vlib := join(root, 'vlib')
	source := join(vlib, 'gg/canvas')
	modules := join(root, 'modules')
	mkdir(source)!
	os.write_file(join(source, 'gpu_gradient.v'), 'module canvas\n')!
	portable := 'module canvas\n#include "@DIR/path_math.h"\nfn C.gg_canvas_sincosf(f32, &f32, &f32)\n'
	os.write_file(join(source, 'path.v'), portable)!
	os.write_file(join(source, 'path_math.h'), 'static inline int portable_math(void) { return 7; }\n')!
	os.write_file(join(source, 'context.v'), 'module canvas\n#include "@DIR/gpu_metal_darwin.h"\nfn C.native_metal()\n')!
	os.write_file(join(source, 'gpu_metal_darwin.h'), '// Darwin native integration\n')!
	prepare_gg_gradient(modules, vlib)!
	canvas := join(modules, 'gg/canvas')
	assert read(join(canvas, 'path.v'))! == portable
	assert real(join(canvas, 'path_math.h')) == real(join(source, 'path_math.h'))
	assert !os.exists(join(canvas, 'vox_path_math.m'))
	assert read(join(canvas, 'context.v'))!.contains('#include "@DIR/vox_gpu_metal_darwin.m"')
	assert read(join(canvas, 'vox_gpu_metal_darwin.m'))! == '#include ' + json.encode(real(join(source, 'gpu_metal_darwin.h'))) + '\n'
}
