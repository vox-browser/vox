"""Stage document image filtering at GG's existing image shader boundary."""
from pathlib import Path
from prepare_http_compat import write_if_changed
from prepare_gg_shadow import replace_once
from prepare_gg_gamma import prepare as prepare_gamma


def prepare(canvas):
    canvas = Path(canvas)
    layer_path = canvas / 'gpu_layer.v'
    layer = layer_path.read_text()
    if 'document_linear_filter' in layer:
        prepare_gamma(canvas)
        return
    layer = replace_once(layer, '\timage gfx.Image\n}',
                         '\timage gfx.Image\n\tdocument_linear_filter bool\n}')
    layer = replace_once(layer, 'a.image.id == b.image.id',
                         'a.image.id == b.image.id && a.document_linear_filter == b.document_linear_filter')
    layer = replace_once(layer, '\ttexture_height int\n',
                         '\ttexture_height int\n\tdocument_scale [2]f32 = [f32(1),1]!\n\tdocument_linear_filter bool\n')
    surface_path = canvas / 'gpu_surface.v'
    surface = surface_path.read_text()
    surface = replace_once(surface, '\t\t\tupper2x2:       [f32(1), 0, 0, 1]!',
                           '\t\t\tupper2x2:       [layer.document_scale[0],f32(0),0,layer.document_scale[1]]!')
    surface = replace_once(surface, '\t\t\timage: layer.image\n',
                           '\t\t\timage: layer.image\n\t\t\tdocument_linear_filter: layer.document_linear_filter\n')
    surface = replace_once(surface, 'bindings.fs.samplers[0] = ctx.layer_sampler()',
                           'bindings.fs.samplers[0] = if draw.texture.document_linear_filter { document_image_sampler() } else { ctx.layer_sampler() }')
    for path, value in [(layer_path, layer), (surface_path, surface)]:
        if path.is_symlink():
            path.unlink()
        write_if_changed(path, value)
    prepare_gamma(canvas)
