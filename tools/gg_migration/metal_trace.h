#ifndef VOX_GG_MIGRATION_METAL_TRACE_H
#define VOX_GG_MIGRATION_METAL_TRACE_H
#ifdef __cplusplus
extern "C" {
#endif
// Install once, before the traced backend creates its Metal device objects.
void vox_metal_trace_install(char const* directory);
void vox_metal_trace_begin(char const* directory, char const* name);
void vox_metal_trace_end(void);
#ifdef __cplusplus
}
#endif
#endif
