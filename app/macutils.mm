#import <Cocoa/Cocoa.h>
#import <QMenu>
#import <QAction>
#import <QMetaObject>

// Finder Services provider: handles "New CRT Plus at Folder" and
// "New CRT Plus Tab at Folder" from Finder's right-click → Services menu.
@interface ServiceProvider : NSObject
@property (assign) QObject *rootObject;
- (void)openFolderInTerminal:(NSPasteboard *)pboard
                    userData:(NSString *)userData
                       error:(NSString **)error;
- (void)openFolderInTab:(NSPasteboard *)pboard
               userData:(NSString *)userData
                  error:(NSString **)error;
@end

@implementation ServiceProvider

- (NSString *)folderPathFromPasteboard:(NSPasteboard *)pboard
{
    NSArray<NSURL *> *urls = [pboard readObjectsForClasses:@[[NSURL class]]
                                                   options:@{NSPasteboardURLReadingFileURLsOnlyKey: @YES}];
    if (urls.count == 0) return nil;
    return urls.firstObject.path;
}

- (void)openFolderInTerminal:(NSPasteboard *)pboard
                    userData:(NSString *)userData
                       error:(NSString **)error
{
    Q_UNUSED(userData);
    NSString *path = [self folderPathFromPasteboard:pboard];
    if (!path) {
        if (error) *error = @"No folder URL on pasteboard";
        return;
    }

    QMetaObject::invokeMethod(_rootObject, "createWindowAtFolder",
                              Q_ARG(QVariant, QString::fromNSString(path)));
}

- (void)openFolderInTab:(NSPasteboard *)pboard
               userData:(NSString *)userData
                  error:(NSString **)error
{
    Q_UNUSED(userData);
    NSString *path = [self folderPathFromPasteboard:pboard];
    if (!path) {
        if (error) *error = @"No folder URL on pasteboard";
        return;
    }

    QMetaObject::invokeMethod(_rootObject, "createTabInActiveWindow",
                              Q_ARG(QVariant, QString::fromNSString(path)));
}
@end

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

void registerServiceProvider(QObject *rootObject)
{
    ServiceProvider *provider = [[ServiceProvider alloc] init];
    provider.rootObject = rootObject;
    [NSApp setServicesProvider:provider];
    [NSApp registerServicesMenuSendTypes:@[NSPasteboardTypeFileURL]
                             returnTypes:@[]];
}
