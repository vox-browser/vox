Module {
	name: 'vox'
	description: 'Vox web browser'
	version: '0.0.0'
	dependencies: ['https://github.com/vlang/harfbuzz@v15.1.0']
	backend: 'fastc'
	vflags: ['-enable-globals']
	subdirs: ['blocking', 'browserapp', 'capture', 'chromium', 'compact', 'document', 'fonts', 'images', 'initial', 'media', 'memorymgmt', 'native', 'navigation', 'paint', 'resources', 'script', 'scroll', 'sites', 'site_optimizations', 'webapi']
}
