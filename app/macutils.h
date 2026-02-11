#ifndef MACUTILS_H
#define MACUTILS_H

class QMenu;
class QAction;
class QObject;

void setRegularApp();
void setDockBadge(int count);
void markAsAlternate(QMenu *menu, QAction *altAction);
void registerServiceProvider(QObject *rootObject);

#endif // MACUTILS_H
