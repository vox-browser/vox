"""Apply limited-range YUV conversion after document texture filtering."""
from pathlib import Path
from prepare_http_compat import write_if_changed
from prepare_gg_shadow import replace_once


def prepare(canvas):
    canvas = Path(canvas)
    layer_path = canvas / 'gpu_layer.v'
    layer = layer_path.read_text()
    if 'u.color_transform.yuv_rec601_limited' not in layer:
        layer = replace_once(layer, '\tout << u.color_transform.gamma\n\tout << 0\n',
                         '\tout << u.color_transform.gamma\n\tout << if u.color_transform.yuv_rec601_limited { f32(1) } else { f32(0) }\n')
    if 'fn document_image_yuv_upload_supported()' not in layer:
        layer = replace_once(layer, 'const image_uniform_size = 112',
                             'const image_uniform_size = 112' + "\n\nfn document_image_yuv_upload_supported() bool {\n\treturn gradient_snippet_file.to_string().contains('gammaParameters_7.y > 0.0f')\n}\n")
    snippets_path = canvas / 'shaders/paint_snippets.metal'
    snippets = snippets_path.read_text()
    marker = 'float4 _10_mask = sample(_globals.image_4, _in.CoordNormalize_3_Var);\n'
    if 'gammaParameters_7.y > 0.0f' not in snippets:
        snippets = replace_once(snippets, marker, marker + '''if (_globals._anonInterface0->combinedUniformData[_globals.uniformSsboIndex].gammaParameters_7.y > 0.0f) {
    float3 yuv = _10_mask.xyz;
    _10_mask = float4(clamp(float3(1.164384f * yuv.x + 1.596027f * yuv.z - 0.874202f,
                                  1.164384f * yuv.x - 0.391762f * yuv.y - 0.812968f * yuv.z + 0.531668f,
                                  1.164384f * yuv.x + 2.017232f * yuv.y - 1.085631f), 0.0f, 1.0f), 1.0f);
}
''')
    for path, value in [(layer_path, layer), (snippets_path, snippets)]:
        if path.is_symlink():
            path.unlink()
        write_if_changed(path, value)
