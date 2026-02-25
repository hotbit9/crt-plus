#ifndef MACUTILS_H
#define MACUTILS_H

class QMenu;
class QAction;
class QObject;

void setRegularApp();
void setDockBadge(int count);
void markAsAlternate(QMenu *menu, QAction *altAction);
void registerServiceProvider(QObject *rootObject);
#ifdef HAVE_SPARKLE
void initSparkle();
void sparkleCheckForUpdates();
void sparkleStartUpdater();
void insertCheckForUpdatesMenuItem();
#endif

#endif // MACUTILS_H
