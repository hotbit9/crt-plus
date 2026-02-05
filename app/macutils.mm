#import <Cocoa/Cocoa.h>

void setAccessoryApp() {
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
}

void setRegularApp() {
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
}
