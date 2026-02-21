#ifndef FILEIO_H
#define FILEIO_H

#include <QObject>
#include <QFile>
#include <QTextStream>
#include <QUrl>
#include <QGuiApplication>
#include <QClipboard>
#include <QQuickItem>

class FileIO : public QObject
{
    Q_OBJECT

public:
    FileIO();

    /** Returns true if the Option/Alt key is currently held. Used by context
     *  menus to toggle "New Pane" vs "New Pane Right" while the menu is open. */
    Q_INVOKABLE bool isOptionPressed() {
        return QGuiApplication::queryKeyboardModifiers() & Qt::AltModifier;
    }

    /** Returns true if the system clipboard contains text. */
    Q_INVOKABLE bool clipboardHasText() {
        return QGuiApplication::clipboard() && !QGuiApplication::clipboard()->text().isEmpty();
    }

    /** Transfer QObject ownership of an item to a new parent.
     *  QML's item.parent only changes the visual parent — the QObject parent
     *  stays with the original creator, causing cascade-delete on destroy().
     *  This explicitly sets the QObject parent so reparented items survive. */
    Q_INVOKABLE void reparentObject(QObject *item, QObject *newParent) {
        if (item) item->setParent(newParent);
    }

    /** Reparent a QQuickItem: sets both visual parent and QObject parent,
     *  then forces update() on the entire subtree to refresh scene graph
     *  nodes (critical for QQuickPaintedItem + ShaderEffectSource chains). */
    Q_INVOKABLE void reparentItem(QQuickItem *item, QQuickItem *newParent) {
        if (!item || !newParent) return;
        item->setVisible(false);
        item->setParentItem(newParent);
        item->setParent(newParent);
        forceUpdateSubtree(item);
        item->setVisible(true);
    }

public slots:
    bool write(const QString& sourceUrl, const QString& data);
    QString read(const QString& sourceUrl);

private:
    void forceUpdateSubtree(QQuickItem *item) {
        if (!item) return;
        item->update();
        item->polish();
        const auto children = item->childItems();
        for (auto *child : children)
            forceUpdateSubtree(child);
    }
};

#endif // FILEIO_H
