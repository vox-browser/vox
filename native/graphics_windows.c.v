module main

import gg
import gg.render
import sokol.gfx

$if windows && sokol_d3d11 ? {
	#flag windows -include @VMODROOT/native_browser_windows_graphics.h

	const windows_browser_vertex_shader = r'
cbuffer vs_params : register(b0) { float4 columns[8]; };
struct Input {
    float3 position : TEXCOORD0;
    float2 uv : TEXCOORD1;
    float4 color : TEXCOORD2;
    float size : TEXCOORD3;
};
struct Output {
    float4 uv : TEXCOORD0;
    float4 color : TEXCOORD1;
    float4 position : SV_Position;
    float size : PSIZE;
};
Output main(Input input) {
    Output output;
    // GG uploads column-major matrices. HLSL float4x4(vector,...) constructs
    // rows, irrespective of the matrix storage qualifier. Multiply columns
    // explicitly so translations and texture transforms retain their meaning.
    output.position = input.position.x * columns[0] + input.position.y * columns[1]
        + input.position.z * columns[2] + columns[3];
    output.uv = input.uv.x * columns[4] + input.uv.y * columns[5] + columns[7];
    output.color = input.color;
    output.size = input.size;
    return output;
}'

	fn make_windows_browser_shader(font bool) gfx.Shader {
		mut desc := gfx.ShaderDesc{}
		for i in 0 .. 4 {
			desc.attrs[i].sem_name = c'TEXCOORD'
			desc.attrs[i].sem_index = i
		}
		desc.vs.uniform_blocks[0].size = 128
		desc.vs.uniform_blocks[0].uniforms[0].type = .float4
		desc.vs.uniform_blocks[0].uniforms[0].array_count = 8
		desc.fs.images[0].used = true
		desc.fs.images[0].image_type = ._2d
		desc.fs.images[0].sample_type = .float
		desc.fs.samplers[0].used = true
		desc.fs.samplers[0].sampler_type = .filtering
		desc.fs.image_sampler_pairs[0].used = true
		desc.fs.image_sampler_pairs[0].image_slot = 0
		desc.fs.image_sampler_pairs[0].sampler_slot = 0
		desc.set_vert_src(windows_browser_vertex_shader)
		fragment_header := r'
Texture2D image : register(t0);
SamplerState image_sampler : register(s0);
struct Input { float4 uv : TEXCOORD0; float4 color : TEXCOORD1; };
float4 main(Input input) : SV_Target0 {
    float4 sampled = image.Sample(image_sampler, input.uv.xy);
'
		fragment := fragment_header + if font {
			'    return float4(1.0, 1.0, 1.0, sampled.r) * input.color;\n}'
		} else {
			'    return sampled * input.color;\n}'
		}
		desc.set_frag_src(fragment)
		shader := gfx.make_shader(&desc)
		if gfx.query_shader_state(shader) != .valid {
			panic('Vox: Windows browser shader compilation failed')
		}
		return shader
	}

	fn replace_windows_browser_pipeline(ctx &gg.Context, old render.Pipeline, shader gfx.Shader) render.Pipeline {
		desc := gfx.query_pipeline_desc(old.pips[3])
		replacement := ctx.r.make_pipeline_with_shader(desc, shader)
		ctx.r.destroy_pipeline(old)
		return replacement
	}

	fn configure_windows_browser_renderer(ctx &gg.Context) {
		shader := make_windows_browser_shader(false)
		font_shader := make_windows_browser_shader(true)
		mut pipelines := ctx.pipeline
		pipelines.alpha = replace_windows_browser_pipeline(ctx, pipelines.alpha, shader)
		pipelines.add = replace_windows_browser_pipeline(ctx, pipelines.add, shader)
		pipelines.multiply = replace_windows_browser_pipeline(ctx, pipelines.multiply, shader)
		pipelines.screen = replace_windows_browser_pipeline(ctx, pipelines.screen, shader)
		pipelines.font = replace_windows_browser_pipeline(ctx, pipelines.font, font_shader)
	}
}
