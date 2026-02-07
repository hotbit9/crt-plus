#include "fileio.h"
#include <QStandardPaths>

FileIO::FileIO()
{
}

// Reject paths outside the user's home directory to prevent misuse
static bool isPathAllowed(const QString& path) {
    if (path.isEmpty())
        return false;
    QString home = QStandardPaths::writableLocation(QStandardPaths::HomeLocation);
    return !home.isEmpty() && path.startsWith(home);
}

bool FileIO::write(const QString& sourceUrl, const QString& data) {
    if (sourceUrl.isEmpty())
        return false;

    QUrl url(sourceUrl);
    QString path = url.toLocalFile();
    if (!isPathAllowed(path))
        return false;

    QFile file(path);
    if (!file.open(QFile::WriteOnly | QFile::Truncate))
        return false;

    QTextStream out(&file);
    out << data;
    file.close();
    return true;
}

QString FileIO::read(const QString& sourceUrl) {
    if (sourceUrl.isEmpty())
        return "";

    QUrl url(sourceUrl);
    QString path = url.toLocalFile();
    if (!isPathAllowed(path))
        return "";

    QFile file(path);
    if (!file.open(QFile::ReadOnly))
        return "";

    QTextStream in(&file);
    QString result = in.readAll();

    file.close();

    return result;
}
