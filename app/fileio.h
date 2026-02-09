#ifndef FILEIO_H
#define FILEIO_H

#include <QObject>
#include <QFile>
#include <QTextStream>
#include <QUrl>
#include <QGuiApplication>

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

public slots:
    bool write(const QString& sourceUrl, const QString& data);
    QString read(const QString& sourceUrl);
};

#endif // FILEIO_H
