#ifndef MACUTILS_H
#define MACUTILS_H

class QMenu;
class QAction;

void setRegularApp();
void setDockBadge(int count);
void markAsAlternate(QMenu *menu, QAction *altAction);

#endif // MACUTILS_H
