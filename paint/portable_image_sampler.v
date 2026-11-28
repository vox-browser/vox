module main

import gg
import sokol.gfx

// All tabs in a portable window share the same Sokol context.
const portable_nearest_sampler = &PortableNearestSampler{}

struct PortableNearestSampler {
mut:
	initialized bool
	sampler gfx.Sampler
}

fn portable_image_sampler(image &gg.Image, nearest bool) gfx.Sampler {
	if !nearest { return image.ssmp }
	mut state := unsafe { portable_nearest_sampler }
	if !state.initialized {
		state.initialized = true
		sampler := gfx.make_sampler(&gfx.SamplerDesc{
			min_filter: .nearest
			mag_filter: .nearest
			mipmap_filter: .none
			wrap_u: .clamp_to_edge
			wrap_v: .clamp_to_edge
			// Sokol reserves zero for its default. Keep D3D11 on the base level.
			max_lod: 0.001
		})
		if gfx.query_sampler_state(sampler) == .valid {
			state.sampler = sampler
		} else if sampler.id != 0 {
			gfx.destroy_sampler(sampler)
		}
	}
	return if state.sampler.id != 0 { state.sampler } else { image.ssmp }
}

fn release_portable_nearest_sampler() {
	mut state := unsafe { portable_nearest_sampler }
	if state.sampler.id != 0 {
		gfx.destroy_sampler(state.sampler)
		state.sampler = gfx.Sampler{}
	}
	state.initialized = false
}
