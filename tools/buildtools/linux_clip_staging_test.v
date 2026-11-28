module buildtools

import os

fn test_linux_canvas_keeps_portable_document_clip_without_metal_uploads() ! {
	root := temporary(os.temp_dir(), 'vox-linux-clip-')!
	defer { remove(root) or {} }
	source := join(root, 'source')
	target := join(root, 'target')
	mkdir(join(source, 'canvas'))!
	mkdir(join(target, 'canvas'))!
	os.write_file(join(source, 'canvas/geometry.v'), 'module canvas\n')!
	os.write_file(join(target, 'canvas/vox_document_image.v'), 'Metal-only image upload adapter\n')!
	stage_linux_module(source, target, 'gg')!
	clip := read(join(target, 'canvas/vox_document_clip.v'))!
	assert clip == read(join(root_dir(), 'tools/ui2/gg_document_clip.v'))!
	assert clip.contains('pub fn document_image_clip_requires_msaa(')
	assert !clip.contains('GpuSurface')
	assert !exists(join(target, 'canvas/vox_document_image.v'))
	assert read(join(target, 'canvas/geometry.v'))! == 'module canvas\n'
}
