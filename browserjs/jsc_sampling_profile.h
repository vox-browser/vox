#ifndef VOX_BROWSERJS_JSC_SAMPLING_PROFILE_H
#define VOX_BROWSERJS_JSC_SAMPLING_PROFILE_H
#include <stdbool.h>
// JavaScriptCore's sampling profiler SPI (JSContextRefPrivate.h), exported by
// the system framework. The group and string are opaque references.
extern bool JSContextGroupEnableSamplingProfiler(void *group);
extern void *JSContextGroupTakeSamplesFromSamplingProfiler(void *group);
#endif
