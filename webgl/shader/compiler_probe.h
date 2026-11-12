#ifndef VOX_DIRECT_METAL_PROBE_H
#define VOX_DIRECT_METAL_PROBE_H
#include <stdint.h>
int vox_direct_metal_texture_probe(char const*, char const*, int, uint32_t);
int vox_direct_metal_uniform_probe(char const*, char const*, void const*, uint64_t, void const*, uint64_t);
int vox_direct_metal_probe(char const* vertex, char const* fragment);
#endif
