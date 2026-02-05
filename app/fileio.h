#ifndef FILEIO_H
#define FILEIO_H

#include <QObject>
#include <QFile>
#include <QTextStream>
#include <QUrl>
#include <QProcess>
#include <QCoreApplication>

class FileIO : public QObject
{
    Q_OBJECT

public:
    FileIO();

public slots:
    bool write(const QString& sourceUrl, const QString& data);
    QString read(const QString& sourceUrl);
    void launchNewInstance(const QString& profileString, int x = -1, int y = -1);
};

#endif // FILEIO_H
