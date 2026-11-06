// Exercise the actual probe callbacks: a queued frame cannot acknowledge input
// received after its raster scroll was set, or count before installation.
#include "measure_precise_scroll_darwin.m"
#include <assert.h>
int main(void) { @autoreleasepool {
    frame_capacity=16;
    frame_samples=calloc(frame_capacity,sizeof(Frame));
    prepared_samples=calloc(frame_capacity,sizeof(PreparedFrame));
    page_view=[[NSView alloc] initWithFrame:NSMakeRect(0,0,10,10)];
    started=CACurrentMediaTime()-.1;
    active=YES;
    inputs=2; rendered_inputs=1; rendered_scroll=8; rendered_last_input=started+.01;
    prepared_frame((__bridge void *)page_view,17,started+.02);
    assert(!publications);
    inputs=3; rendered_inputs=3; rendered_scroll=24; rendered_last_input=started+.03;
    completed_frame((__bridge void *)page_view,17);
    assert(publications==1 && frame_samples[0].inputs==1 && frame_samples[0].scroll==8);
    assert(frame_samples[0].elapsed>=.08 && frame_samples[0].age>=.09);
    completed_frame((__bridge void *)page_view,17);
    completed_frame((__bridge void *)page_view,18); // Never prepared.
    assert(publications==1);
    rendered_inputs=0;
    prepared_frame((__bridge void *)page_view,19,started+.02);
    completed_frame((__bridge void *)page_view,19); // No represented input.
    assert(publications==1);
    rendered_inputs=3;
    prepared_frame((__bridge void *)page_view,20,started+.02);
    prepared_frame((__bridge void *)page_view,36,started+.02); // Bounded slot reuse.
    completed_frame((__bridge void *)page_view,20);
    assert(publications==1);
    completed_frame((__bridge void *)page_view,36);
    assert(publications==2 && frame_samples[1].inputs==3 && frame_samples[1].scroll==24);
    active=NO;
    prepared_frame((__bridge void *)page_view,37,started+.02);
    active=YES;
    completed_frame((__bridge void *)page_view,37);
    assert(publications==2);
    free(frame_samples); free(prepared_samples);
    puts("Native publication observer: source input stamps, installation endpoint, duplicate/stale/missing frames passed");
} }
