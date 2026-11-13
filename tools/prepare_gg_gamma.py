"""Stage the document image shader's source gamma conversion."""
from pathlib import Path
from prepare_http_compat import write_if_changed
from prepare_gg_shadow import replace_once


def prepare(canvas):
    canvas = Path(canvas)
    layer_path = canvas / 'gpu_layer.v'
    layer = layer_path.read_text()
    if 'color_transform' in layer:
        return
    field = '\tmask_color Color4f = Color4f{1, 1, 1, 1}\n'
    uniform = '\tmask_color     Color4f = Color4f{1, 1, 1, 1}\n'
    layer = replace_once(layer, field, field + '\tcolor_transform DocumentImageColorTransform\n')
    layer = replace_once(layer, uniform, uniform + '\tcolor_transform DocumentImageColorTransform\n')
    layer = replace_once(layer, 'const image_uniform_size = 48', 'const image_uniform_size = 112')
    layer = replace_once(layer, 'a.mask_color == b.mask_color',
                         'a.mask_color == b.mask_color && a.color_transform == b.color_transform')
    layer = replace_once(layer, '\tout << u.mask_color.a\n',
                         '\tout << u.mask_color.a\n\tout << u.color_transform.gamma\n\tout << 0\n\tout << 0\n\tout << 0\n\tfor column in 0 .. 3 {\n\t\tfor row in 0 .. 3 { out << u.color_transform.gamut[column * 3 + row] }\n\t\tout << 0\n\t}\n')
    surface_path = canvas / 'gpu_surface.v'
    surface = replace_once(surface_path.read_text(), '\t\t\tmask_color: layer.mask_color',
                           '\t\t\tmask_color: layer.mask_color\n\t\t\tcolor_transform: layer.color_transform')
    snippets_path = canvas / 'shaders/paint_snippets.metal'
    snippets = replace_once(snippets_path.read_text(), 'float4 maskColor_6;\n',
                            'float4 maskColor_6;\nfloat4 gammaParameters_7;\nfloat4 gamutColumn0_8;\nfloat4 gamutColumn1_8;\nfloat4 gamutColumn2_8;\n')
    marker = 'float4 _10_mask = sample(_globals.image_4, _in.CoordNormalize_3_Var);\n'
    snippets = replace_once(snippets, marker, marker + '''float _11_gamma = _globals._anonInterface0->combinedUniformData[_globals.uniformSsboIndex].gammaParameters_7.x;
if (_11_gamma > 0.0f) {
    float3 _12_rgb = _10_mask.xyz / max(_10_mask.w, 0.0001f);
    float3 _13_linear = powr(max(_12_rgb, 0.0f), float3(_11_gamma));
    _13_linear = float3x3(_globals._anonInterface0->combinedUniformData[_globals.uniformSsboIndex].gamutColumn0_8.xyz,
                         _globals._anonInterface0->combinedUniformData[_globals.uniformSsboIndex].gamutColumn1_8.xyz,
                         _globals._anonInterface0->combinedUniformData[_globals.uniformSsboIndex].gamutColumn2_8.xyz) * _13_linear;
    float3 _14_abs = abs(_13_linear);
    float3 _15_encoded = select(powr(as_type<float>(0x3f919280u) * _14_abs, float3(as_type<float>(0x3ed55555u))) + as_type<float>(0xbd612800u),
                               as_type<float>(0x414eb852u) * _14_abs, _14_abs < as_type<float>(0x3b4d2e31u));
    _10_mask = float4(clamp(sign(_13_linear) * _15_encoded * _10_mask.w, 0.0f, _10_mask.w), _10_mask.w);
}
''')
    for path, text in [(layer_path, layer), (surface_path, surface), (snippets_path, snippets)]:
        if path.is_symlink():
            path.unlink()
        write_if_changed(path, text)
