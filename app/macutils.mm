#import <Cocoa/Cocoa.h>
#include <QMenu>
#include <QAction>
#include <QMetaObject>
#ifdef HAVE_SPARKLE
#import <Sparkle/Sparkle.h>
static SPUStandardUpdaterController *s_sparkleController = nil;
#endif

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

#ifdef HAVE_SPARKLE
void initSparkle() {
    s_sparkleController = [[SPUStandardUpdaterController alloc]
        initWithStartingUpdater:NO updaterDelegate:nil userDriverDelegate:nil];
}

void sparkleStartUpdater() {
    if (!s_sparkleController) return;
    NSError *error = nil;
    if (![s_sparkleController.updater startUpdater:&error]) {
        NSLog(@"Sparkle startUpdater failed: %@", error);
    }
}

void sparkleCheckForUpdates() {
    if (!s_sparkleController) return;
    [s_sparkleController checkForUpdates:nil];
}

void insertCheckForUpdatesMenuItem() {
    if (!s_sparkleController) return;
    NSMenu *appMenu = [[NSApp mainMenu] itemAtIndex:0].submenu;
    NSInteger aboutIndex = -1;
    for (NSInteger i = 0; i < appMenu.numberOfItems; i++) {
        // NOTE: This string match assumes English locale.
        if ([[appMenu itemAtIndex:i].title containsString:@"About"]) {
            aboutIndex = i;
            break;
        }
    }
    NSInteger insertIndex = (aboutIndex >= 0) ? aboutIndex + 1 : 1;
    [appMenu insertItem:[NSMenuItem separatorItem] atIndex:insertIndex];
    NSMenuItem *item = [[NSMenuItem alloc]
        initWithTitle:@"Check for Updates…"
        action:@selector(checkForUpdates:)
        keyEquivalent:@""];
    item.target = s_sparkleController;
    [appMenu insertItem:item atIndex:insertIndex + 1];
}
#endif

