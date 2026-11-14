"""Stage GG's floating-color alpha-mask draw without editing the V checkout."""
from pathlib import Path
from prepare_http_compat import write_if_changed


def replace_once(source, old, new):
    if source.count(old) != 1:
        raise RuntimeError('Unsupported GG alpha-mask adapter source: ' + old[:70])
    return source.replace(old, new, 1)


def prepare(canvas):
    canvas = Path(canvas)
    layer_path = canvas / 'gpu_layer.v'
    layer = layer_path.read_text()
    if 'mask_color' in layer:
        return
    layer = replace_once(layer, '\tmode           f32\n',
                         '\tmask_color     Color4f = Color4f{1, 1, 1, 1}\n')
    layer = replace_once(layer, 'a.mode == b.mode', 'a.mask_color == b.mask_color')
    layer = replace_once(layer, '\tout << u.mode\n\tout << 0\n\tout << 0\n\tout << 0',
                         '\tout << u.mask_color.r\n\tout << u.mask_color.g\n\tout << u.mask_color.b\n\tout << u.mask_color.a')
    layer = replace_once(layer, '\ttexture_height int\n}',
                         '\ttexture_height int\n\tmask_color Color4f = Color4f{1, 1, 1, 1}\n}')
    surface_path = canvas / 'gpu_surface.v'
    surface = replace_once(surface_path.read_text(),
                           '\t\t\tinv_dimensions: [f32(1) / f32(layer.texture_width), f32(1) / f32(layer.texture_height)]!',
                           '\t\t\tinv_dimensions: [f32(1) / f32(layer.texture_width), f32(1) / f32(layer.texture_height)]!\n\t\t\tmask_color: layer.mask_color')
    snippets_path = canvas / 'shaders/paint_snippets.metal'
    snippets = replace_once(snippets_path.read_text(), 'float mode_6;\n// @@ vertex_image',
                             'float4 maskColor_6;\n// @@ vertex_image')
    marker = '// @@ main_image\n'
    before, body = snippets.split(marker, 1)
    # This is the final snippet. Layer images already hold premultiplied data;
    # the old mode=0 colorspace branch was an identity for these draws.
    if not body.rstrip().endswith('float4 outColor_1 = _10_sk_csxform_prealpha;'):
        raise RuntimeError('Unsupported GG image shader tail')
    snippets = before + marker + '''float4 _10_mask = sample(_globals.image_4, _in.CoordNormalize_3_Var);
float4 outColor_1 = _10_mask * _globals._anonInterface0->combinedUniformData[_globals.uniformSsboIndex].maskColor_6;
'''
    for path, text in [(layer_path, layer), (surface_path, surface), (snippets_path, snippets)]:
        if path.is_symlink():
            path.unlink()
        write_if_changed(path, text)
    helper = Path(__file__).parent / 'ui2/gg_shadow_mask.v'
    target = canvas / 'vox_shadow_mask.v'
    if target.is_symlink():
        target.unlink()
    write_if_changed(target, helper.read_text())
