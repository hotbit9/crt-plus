#import <Cocoa/Cocoa.h>
#import <QMenu>
#import <QAction>

void setRegularApp() {
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
}

void setDockBadge(int count) {
    if (count > 0)
        [[NSApp dockTile] setBadgeLabel:[NSString stringWithFormat:@"%d", count]];
    else
        [[NSApp dockTile] setBadgeLabel:nil];
}

// Marks a QAction's native NSMenuItem as an alternate that appears when
// Option is held. The action must be the item immediately after the primary.
// This is the standard macOS pattern (e.g. Finder's "Open" / "Open in New Tab").
void markAsAlternate(QMenu *menu, QAction *altAction)
{
    NSMenu *nativeMenu = menu->toNSMenu();
    if (!nativeMenu) return;

    NSString *title = altAction->text().toNSString();
    NSInteger idx = [nativeMenu indexOfItemWithTitle:title];
    if (idx == -1) return;

    NSMenuItem *item = [nativeMenu itemAtIndex:idx];
    item.keyEquivalentModifierMask = NSEventModifierFlagOption;
    item.alternate = YES;
}
