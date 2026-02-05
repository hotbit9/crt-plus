#include "fileio.h"

FileIO::FileIO()
{
}

bool FileIO::write(const QString& sourceUrl, const QString& data) {
    if (sourceUrl.isEmpty())
        return false;

    QUrl url(sourceUrl);
    QFile file(url.toLocalFile());
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
    QFile file(url.toLocalFile());
    if (!file.open(QFile::ReadOnly))
        return "";

    QTextStream in(&file);
    QString result = in.readAll();

    file.close();

    return result;
}

void FileIO::launchNewInstance(const QString& profileString, int x, int y) {
    QStringList args;
    args << "--child";
    if (!profileString.isEmpty()) {
        args << "--profile-string" << profileString;
    }
    if (x >= 0 && y >= 0) {
        args << "--x" << QString::number(x) << "--y" << QString::number(y);
    }
    QProcess::startDetached(QCoreApplication::applicationFilePath(), args);
}
