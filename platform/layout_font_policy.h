#ifndef VOX_LAYOUT_FONT_POLICY_H
#define VOX_LAYOUT_FONT_POLICY_H

// A synchronous layout pass uses one environment/filesystem policy snapshot.
// Other threads and calls outside that pass continue to query live settings.
static _Thread_local unsigned vox_layout_font_policy_depth;
static _Thread_local int vox_layout_font_policy_configured;

static inline int vox_layout_font_policy_cached(void)
{
    return vox_layout_font_policy_depth ? vox_layout_font_policy_configured : -1;
}

static inline void vox_layout_font_policy_push(int configured)
{
    if (!vox_layout_font_policy_depth)
        vox_layout_font_policy_configured = configured;
    ++vox_layout_font_policy_depth;
}

static inline void vox_layout_font_policy_pop(void)
{
    if (vox_layout_font_policy_depth)
        --vox_layout_font_policy_depth;
}

#endif
