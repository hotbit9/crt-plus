#import <Cocoa/Cocoa.h>

void setRegularApp() {
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
}

void setDockBadge(int count) {
    if (count > 0)
        [[NSApp dockTile] setBadgeLabel:[NSString stringWithFormat:@"%d", count]];
    else
        [[NSApp dockTile] setBadgeLabel:nil];
}
