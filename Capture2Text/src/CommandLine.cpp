/*
Copyright (C) 2010-2017 Christopher Brochtrup

This file is part of Capture2Text.

Capture2Text is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Capture2Text is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Capture2Text.  If not, see <http://www.gnu.org/licenses/>.
*/

#include <QClipboard>
#include <QCommandLineParser>
#include <QDebug>
#include <QDir>
#include <QGuiApplication>
#include <QPixmap>
#include <QScreen>
#include <QTextStream>
#include <QRegularExpression>
#include "CommandLine.h"
#include "UtilsImg.h"
#include "UtilsCommon.h"
#include "UtilsLang.h"
#include "PostProcess.h"

#include <QList>
#include <QThread>
#include <QFuture>
#include <QtConcurrent>

CommandLine::CommandLine()
    : outputFilePath(""),
      outputFormat("${capture}${linebreak}"),
      debug(false),
      debugAppendTimestamp(false),
      keepLineBreaks(false)
{
    ocrEngine = new OcrEngine();
}

CommandLine::~CommandLine()
{
    delete ocrEngine;
}

/*
Options:
  -?, -h, --help                     Displays this help.
  -v, --version                      Displays version information.
  -b, --line-breaks                  Do not remove line breaks from OCR text.
  -d, --debug                        Output captured image and pre-processed
                                     image for debugging purposes.
  --debug-timestamp                  Append timestamp to debug images when
                                     using the -d option.
  -f, --images-file <file>           File that contains paths of image files to
                                     OCR. One path per line.
  -i, --image <file>                 Image file to OCR. You may OCR multiple
                                     image files like so: "-i <img1> -i <img2>
                                     -i <img3>"
  -l, --language <language>          OCR language to use. Case-sensitive.
                                     Default is "English". Use the
                                     --show-languages option to list installed
                                     OCR languages.
  -o, --output-file <file>           Output OCR text to this file. If not
                                     specified, stdout will be used.
  --output-file-append               Append to file when using the -o option.
  -s, --screen-rect <"x1 y1 x2 y2">  Coordinates of rectangle that defines area
                                     of screen to OCR.
  -t, --vertical                     OCR vertical text. If not specified,
                                     horizontal text is assumed.
  -w, --show-languages               Show installed languages that may be used
                                     with the "--language" option.
  --output-format <format>           Format to use when outputting OCR text.
                                     You may use these tokens:
                                     ${capture}   : OCR Text.
                                     ${linebreak} : Line break (\r\n).
                                     ${tab}       : Tab character.
                                     ${timestamp} : Time that screen or each
                                     file was processed.
                                     ${file}      : File that was processed or
                                     screen rect.
                                     Default format is "${capture}${linebreak}".
  --whitelist <characters>           Only recognize the provided characters.
                                     Example: "0123456789".
  --blacklist <characters>           Do not recognize the provided characters.
                                     Example: "0123456789".
  --clipboard                        Output OCR text to the clipboard.
  --trim-capture                     During OCR preprocessing, trim captured
                                     image to foreground pixels and add a thin
                                     border.
  --deskew                           During OCR preprocessing, attempt to
                                     compensate for slanted text.
  --scale-factor <factor>            Scale factor to use during pre-processing.
                                     Range: [0.71, 5.0]. Default is 3.5.
  --tess-config-file <file>          (Advanced) Path to Tesseract configuration
                                     file.
  --portable                         Store .ini settings file in same directory
                                     as the .exe file.
*/
bool CommandLine::process(QCoreApplication &app)
{
    QCommandLineParser parser;
    parser.setApplicationDescription(
                "Capture2Text may be used to OCR image files or part of the screen.\n"
                "Examples:\n"
                "  Capture2Text_CLI.exe --screen-rect \"400 200 600 300\"\n"
                "  Capture2Text_CLI.exe --vertical -l \"Chinese - Simplified\" -i img1.png\n"
                "  Capture2Text_CLI.exe -i img1.png -i img2.jpg -o result.txt\n"
                "  Capture2Text_CLI.exe -l Japanese -f \"C:\\Temp\\image_files.txt\"\n"
                "  Capture2Text_CLI.exe --show-languages");
    parser.addHelpOption();
    parser.addVersionOption();

    QCommandLineOption lineBreaksOption(QStringList() << "b" << "line-breaks",
                                        "Do not remove line breaks from OCR text.");
    parser.addOption(lineBreaksOption);

    QCommandLineOption debugOption(QStringList() << "d" << "debug",
                                   "Output captured image and pre-processed image for debugging purposes.");
    parser.addOption(debugOption);

    QCommandLineOption debugAppendTimestampOption("debug-timestamp",
                                                  "Append timestamp to debug images when using the -d option.");
    parser.addOption(debugAppendTimestampOption);

    QCommandLineOption imagesFileOption(QStringList() << "f" << "images-file",
                                        "File that contains paths of image files to OCR. One path per line.",
                                        "file");
    parser.addOption(imagesFileOption);

    QCommandLineOption imagesOption(QStringList() << "i" << "image",
                                    "Image file to OCR. You may OCR multiple image files like so: "
                                    "\"-i <img1> -i <img2> -i <img3>\"",
                                    "file");
    parser.addOption(imagesOption);

    QCommandLineOption langOption(QStringList() << "l" << "language",
                                  "OCR language to use. Case-sensitive. Default is \"English\". "
                                  "Use the --show-languages option to list installed OCR languages.",
                                  "language", "English");
    parser.addOption(langOption);

    QCommandLineOption outputFileOption(QStringList() << "o" << "output-file",
                                        "Output OCR text to this file. If not specified, stdout will be used.",
                                        "file");
    parser.addOption(outputFileOption);

    QCommandLineOption fileAppendOption("output-file-append",
                                        "Append to file when using the -o option.");
    parser.addOption(fileAppendOption);

    QCommandLineOption screenRectOption(QStringList() << "s" << "screen-rect",
                                        "Coordinates of rectangle that defines area of screen to OCR.",
                                        "\"x1 y1 x2 y2\"");
    parser.addOption(screenRectOption);
    //Options for PoE Harvest
    QCommandLineOption poeHarvestOption(QStringList() << "poe-harvest",
                                        "special mode for harvest poe");
    parser.addOption(poeHarvestOption);

    QCommandLineOption levelPatternOption(QStringList() << "level-pattern",
                                          "pattern for level",
                                          "\"pattern\"");
    parser.addOption(levelPatternOption);

    QCommandLineOption aspectRatioForLevelOption(QStringList() << "aspectratio-Level",
                                          "aspectRatio for Level area. Range: [0.1, 0.3] Default is 0.18",
                                          "aspectratio", "0.18");
    parser.addOption(aspectRatioForLevelOption);
    //

    QCommandLineOption verticalOption(QStringList() << "t" << "vertical",
                                      "OCR vertical text. If not specified, horizontal text is assumed.");
    parser.addOption(verticalOption);

    QCommandLineOption listLangOption(QStringList() << "w" << "show-languages",
                                      "Show installed languages that may be used with the \"--language\" option.");
    parser.addOption(listLangOption);

    QCommandLineOption outputFormatOption("output-format",
                                          "Format to use when outputting OCR text. You may use these tokens:\n"
                                          "${capture}   : OCR Text.\n"
                                          "${linebreak} : Line break (\\r\\n).\n"
                                          "${tab}       : Tab character.\n"
                                          "${timestamp} : Time that screen or each file was processed.\n"
                                          "${file}      : File that was processed or screen rect.\n"
                                          "Default format is \"${capture}${linebreak}\".",
                                          "format");
    parser.addOption(outputFormatOption);

    QCommandLineOption whitelistOption("whitelist",
                                       "Only recognize the provided characters. Example: \"0123456789\".",
                                       "characters");
    parser.addOption(whitelistOption);

    QCommandLineOption blacklistOption("blacklist",
                                       "Do not recognize the provided characters. Example: \"0123456789\".",
                                       "characters");
    parser.addOption(blacklistOption);

    QCommandLineOption clipboardOption(QStringList() << "clipboard",
                                      "Output OCR text to the clipboard.");
    parser.addOption(clipboardOption);

    QCommandLineOption preprocessTrimOption(QStringList() << "trim-capture",
                                            "During OCR preprocessing, trim captured image to foreground pixels and add a thin border.");
    parser.addOption(preprocessTrimOption);

    QCommandLineOption preprocessDeskewOption(QStringList() << "deskew",
                                            "During OCR preprocessing, attempt to compensate for slanted text.");
    parser.addOption(preprocessDeskewOption);

    QCommandLineOption scaleFactorOption(QStringList() << "scale-factor",
                                            "Scale factor to use during pre-processing. Range: [0.71, 5.0]. Default is 3.5.",
                                            "factor", "3.5");
    parser.addOption(scaleFactorOption);

    QCommandLineOption tessConfigFileOption("tess-config-file",
                                            "(Advanced) Path to Tesseract configuration file.",
                                            "file");
    parser.addOption(tessConfigFileOption);

    parser.process(app);

    if(app.arguments().length() <= 1)
    {
        parser.showHelp();
        return true;
    }

    if(parser.isSet(listLangOption))
    {
        showInstalledLanguages();
        return true;
    }

    debug = parser.isSet(debugOption);
    debugAppendTimestamp = parser.isSet(debugAppendTimestampOption);

    QTextStream errStream(stderr);

    QStringList imagePaths = parser.values(imagesOption);
    QString screenRectStr = parser.value(screenRectOption);
    QString imagesFile = parser.value(imagesFileOption).trimmed();

    if(imagePaths.size() == 0
            && screenRectStr.size() == 0
            && imagesFile.size() == 0)
    {
        errStream << "At least one of the following options must be specified:" << Qt::endl
                  << "  -i, --image" << Qt::endl
                  << "  -f, --images-file" << Qt::endl
                  << "  -s, --screen-rect" << Qt::endl;
        qCritical() << "At least one of the following options must be specified:" << Qt::endl
                  << "  -i, --image" << Qt::endl
                  << "  -f, --images-file" << Qt::endl
                  << "  -s, --screen-rect";
        return false;
    }

    captureTimestamp = QDateTime::currentDateTime();

    bool verticalOrientation = parser.isSet(verticalOption);
    whitelist = parser.value(whitelistOption);
    QString blacklist = parser.value(blacklistOption);
    QString tessConfigFile = parser.value(tessConfigFileOption);
    QString lang = parser.value(langOption);

    imagePreprocessor.setVerticalOrientation(verticalOrientation);
    imagePreprocessor.setRemoveFurigana(UtilsLang::languageSupportsFurigana(lang));

    ocrEngine->setVerticalOrientation(verticalOrientation);
    ocrEngine->setWhitelist(whitelist);
    ocrEngine->setBlacklist(blacklist);
    ocrEngine->setConfigFile(tessConfigFile);

    if(!ocrEngine->setLang(lang))
    {
        errStream << "Error, specified OCR language not found." << Qt::endl;
        qCritical() << "Error, specified OCR language not found.";
        showInstalledLanguages();
        return false;
    }

    QString outputFormatStr = parser.value(outputFormatOption);

    if(outputFormatStr.length() > 0)
    {
        outputFormat = outputFormatStr;
    }

    keepLineBreaks = parser.isSet(lineBreaksOption);
    copyToClipboard = parser.isSet(clipboardOption);
    preprocessTrim = parser.isSet(preprocessTrimOption);
    preprocessDeskew = parser.isSet(preprocessDeskewOption);
    bool scaleFactorOk = true;
    double scaleFactor = parser.value(scaleFactorOption).toDouble(&scaleFactorOk);

    if(!scaleFactorOk)
    {
        scaleFactor = 3.5;
    }

    imagePreprocessor.setScaleFactor(scaleFactor);

    outputFilePath = parser.value(outputFileOption);
    bool outputFileAppend = parser.isSet(fileAppendOption);

    // If output file specified, open/create it here
    if(outputFilePath.size() > 0)
    {
        QIODevice::OpenMode openMode = QIODevice::WriteOnly | QIODevice::Text;

        if(outputFileAppend)
        {
            openMode |= QIODevice::Append;
        }

        outputFile.setFileName(outputFilePath);
        if(!outputFile.open(openMode))
        {
            errStream << "Error, unable to create output file:" << Qt::endl
                                << "\"" << outputFilePath << "\"" << Qt::endl;
            qCritical() << "Error, unable to create output file:" << Qt::endl
                                << "\"" << outputFilePath << "\"";
        }
    }

    if(imagePaths.size() != 0)
    {
        ocrImageFiles(imagePaths);
    }
    else if(screenRectStr.size() != 0)
    {
        QRect rect;
        if(!convertStringToRect(screenRectStr, rect))
        {
            return false;
        }
        currentImageFile = "(" + screenRectStr + ")";
        if(parser.isSet(poeHarvestOption))
        {
            QString pattern = parser.value(levelPatternOption);
            if(pattern.size() == 0)
            {
                qCritical() << "Error, levelPattern for PoE Harvest not found.";
                return false;
            }
            bool aspectRatioForLevelOk = true;
            double aspectRatioForLevel = parser.value(aspectRatioForLevelOption).toDouble(&aspectRatioForLevelOk);

            if(!aspectRatioForLevelOk)
            {
                aspectRatioForLevel = 0.18;
            }
            ocrScreenHarvest(rect, pattern, aspectRatioForLevel);
        }
        else
        {
            ocrScreenRectAndOutput(rect);
        }

    }
    else if(imagesFile.size() != 0)
    {
        ocrFileOfImages(imagesFile);
    }

    if(outputFile.isOpen())
    {
        outputFile.close();
    }

    if(copyToClipboard)
    {
        QGuiApplication::clipboard()->setText(allOcrText);
    }

    return true;
}

QString CommandLine::postProcessText(QString ocrText)
{
    PostProcess postProcess(ocrEngine->getLang(), keepLineBreaks);
    return postProcess.postProcessOcrText(ocrText);
}

void CommandLine::ocrScreenRectAndOutput(QRect rect)
{
    QString ocrText = ocrScreenRect(rect);
    ocrText = postProcessText(ocrText);
    outputOcrText(ocrText);
}

struct OcrTaskInput {
    QImage srcImg;
    QString lang;
    QString textLevel;
};

struct HarvestThread
 {
     HarvestThread(QString wl) : m_wl(wl) { }

     typedef QString result_type;

     QString operator()(const OcrTaskInput &ocrInput)
     {
         OcrEngine *ocrE = new OcrEngine();
         ocrE->setLang(ocrInput.lang);
         ocrE->setWhitelist(m_wl);
         ocrE->setVerticalOrientation(false);
         tesseract::PageSegMode mode = tesseract::PageSegMode::PSM_SINGLE_COLUMN;
         QString m_lang = ocrInput.lang;
         if(m_lang == "Chinese - Traditional" or
                 m_lang == "Chinese - Simplified" or m_lang == "Korean")
         {
             mode = tesseract::PageSegMode::PSM_SINGLE_BLOCK;
         }
         ocrE->setPageSegMode(mode);

         if(ocrInput.srcImg.width() == 0 || ocrInput.srcImg.height() == 0)
         {
             qCritical() << "Error, screenshot failure.";
             return QString("<Error>");
         }
         PreProcess imagePp;
         imagePp.setScaleFactor(3.5);
         QImage img = ocrInput.srcImg;
         PIX *inPixs = imagePp.convertImageToPix(img);
         PIX *pixs = imagePp.processImage(inPixs, false, false);
         pixDestroy(&inPixs);

         if(pixs == nullptr)
         {
             qCritical() << "Error, pre-processing failure.";
             return QString("<Error>");
         }

         QString ocrText = ocrE->performOcrEx(pixs);

         pixDestroy(&pixs);

         if(ocrText.size() == 0)
         {
             qCritical() << "Error, OCR failure.";
             return QString("<Error>");
         }

         delete ocrE;

         PostProcess postProcess(m_lang, false);
         if (m_lang == "English" or m_lang == "Russian") {
             return postProcess.postProcessOcrText(ocrText);
         }
         return postProcess.postProcessOcrText(ocrText) + "#" + ocrInput.textLevel; // + "||";
     }
     QString m_wl;
 };

void addToCrafts(QString &result, const QString &craft)
{
    result += craft + "||";
}

void addToCrafts2(QString &result, const QString &craft)
{
    result += craft + "#";
}

void CommandLine::ocrScreenHarvest(QRect rect, QString pattern, double aspectRatioForLevel)
{
    QImage img = UtilsImg::takeScreenshot(rect);
    if(img.width() == 0 || img.height() == 0)
    {
        qCritical() << "Error, screenshot failure.";
        return;
    }
    int areaWidthLevel = qFloor(aspectRatioForLevel * img.width());
    int areaWidthCraft = img.width() - areaWidthLevel;
    int x_areaLevelStart = areaWidthCraft;
    int y_areaLevelStart = 0;

    QString ocrLevelText = "";
    qsizetype count = 1;
    QStringList lvllist;
    QString lang = ocrEngine->getLang();
    if(lang == "Korean" or lang == "Chinese - Traditional" or lang == "Chinese - Simplified")
    {
        QImage imageLevel = img.copy(x_areaLevelStart, y_areaLevelStart, areaWidthLevel, img.height());
        if(debug)
        {
            imageLevel.save(getDebugImagePath("debug_level.png"));
        }
        ocrEngine->setPageSegMode(tesseract::PageSegMode::PSM_SINGLE_COLUMN);
        ocrLevelText = postProcessText(ocrScreenImage(imageLevel));
        QRegularExpression re(pattern);
        lvllist =  QString(ocrLevelText).replace(re, "#\\1").split("#", Qt::SkipEmptyParts);
        count = lvllist.length();
        if(count == 0)
        {
            count = 1;
        }
    }

    size_t newHeight = 0;
    size_t newX = 0;
    size_t newY = 0;
    QString ocrText = "";
    if(lang == "Korean")
    {
        newHeight = qFloor(img.height() / count);
        QList< OcrTaskInput > tasks;
        for(int i = 0; i < count; i++)
        {
            QImage imageCraft = img.copy(newX, newY, areaWidthCraft, newHeight);
            QString textLevel = lvllist.value(i);
            tasks << OcrTaskInput {imageCraft, lang, textLevel};
            newY += newHeight;
        }
        ocrText = QtConcurrent::blockingMappedReduced(tasks, HarvestThread(""), addToCrafts, QtConcurrent::OrderedReduce);
        ocrText.chop(2); //remove last "||"
        ocrText.replace(QRegularExpression("[^0-9\\x{AC00}-\\x{D7A3} %\\-#\\|]"), " ");
    }
    else if(lang == "Chinese - Traditional" or lang == "Chinese - Simplified")
    {
        newHeight = qFloor(img.height() / count);
        QList< OcrTaskInput > tasks;
        for(int i = 0; i < count; i++)
        {
            QImage imageCraft = img.copy(newX, newY, areaWidthCraft, newHeight);
            QString textLevel = lvllist.value(i);
            tasks << OcrTaskInput {imageCraft, lang, textLevel};
            newY += newHeight;
        }
        ocrText = QtConcurrent::blockingMappedReduced(tasks, HarvestThread(""), addToCrafts, QtConcurrent::OrderedReduce);
        if (debug)
        {
            ocrText += ocrLevelText + "#debug||";
        }
        ocrText.chop(2); //remove last "||"
    }
    else if(lang == "English")
    {
        QList< OcrTaskInput > tasks;
        QImage imageLevel = img.copy(x_areaLevelStart, y_areaLevelStart, areaWidthLevel, img.height());
        if(debug)
        {
            imageLevel.save(getDebugImagePath("debug_level.png"));
        }
        QImage imageCraft = img.copy(newX, newY, areaWidthCraft, img.height());
        if(debug)
        {
            imageCraft.save(getDebugImagePath("debug_craft.png"));
        }
        tasks << OcrTaskInput {imageCraft, lang, ""};
        tasks << OcrTaskInput {imageLevel, lang, ""};
        ocrText = QtConcurrent::blockingMappedReduced(tasks, HarvestThread(whitelist), addToCrafts2, QtConcurrent::OrderedReduce);
        ocrText.chop(1); //remove last "#"
        //ocrText.replace(QRegularExpression("[^0-9a-zA-Z %-+#]"), " ");
    }
    else if(lang == "Russian")
    {
        QList< OcrTaskInput > tasks;
        QImage imageLevel = img.copy(x_areaLevelStart, y_areaLevelStart, areaWidthLevel, img.height());
        if(debug)
        {
            imageLevel.save(getDebugImagePath("debug_level.png"));
        }
        QImage imageCraft = img.copy(newX, newY, areaWidthCraft, img.height());
        if(debug)
        {
            imageCraft.save(getDebugImagePath("debug_craft.png"));
        }
        tasks << OcrTaskInput {imageCraft, lang, ""};
        tasks << OcrTaskInput {imageLevel, lang, ""};
        ocrText = QtConcurrent::blockingMappedReduced(tasks, HarvestThread(whitelist), addToCrafts2, QtConcurrent::OrderedReduce);
        ocrText.chop(1); //remove last "#"
    }

    if(outputFilePath.size() > 0)
    {
        outputToFile(ocrText);
    }
}

QString CommandLine::ocrScreenImage(QImage img)
{
    if(img.width() == 0 || img.height() == 0)
    {
        qCritical() << "Error, screenshot failure.";
        return QString("<Error>");
    }
    PIX *inPixs = imagePreprocessor.convertImageToPix(img);
    PIX *pixs = imagePreprocessor.processImage(inPixs, preprocessDeskew, preprocessTrim);
    pixDestroy(&inPixs);

    if(pixs == nullptr)
    {
        qCritical() << "Error, pre-processing failure.";
        return QString("<Error>");
    }

    QString ocrText = ocrEngine->performOcrEx(pixs);

    pixDestroy(&pixs);

    if(ocrText.size() == 0)
    {
        qCritical() << "Error, OCR failure.";
        return QString("<Error>");
    }

    return ocrText;
}

QString CommandLine::ocrScreenRect(QRect rect)
{
    QImage img = UtilsImg::takeScreenshot(rect);

    if(img.width() == 0 || img.height() == 0)
    {
        QTextStream(stderr) << "Error, screenshot failure." << Qt::endl;
        return QString("<Error>");
    }

    if(debug)
    {
        img.save(getDebugImagePath("debug_capture.png"));
    }

    PIX *inPixs = imagePreprocessor.convertImageToPix(img);
    PIX *pixs = imagePreprocessor.processImage(inPixs, preprocessDeskew, preprocessTrim);
    pixDestroy(&inPixs);

    if(pixs == nullptr)
    {
        QTextStream(stderr) << "Error, pre-processing failure." << Qt::endl;
        return QString("<Error>");
    }

    if(debug)
    {
        QString savePath = getDebugImagePath("debug_enhanced.png");
        QByteArray byteArray = savePath.toLocal8Bit();
        pixWriteImpliedFormat(byteArray.constData(), pixs, 0, 0);
    }

    bool singleLine = false;

    if(UtilsLang::languageSupportsFurigana(ocrEngine->getLang()))
    {
        singleLine = (imagePreprocessor.getJapNumTextLines() == 1);
    }

    QString ocrText = ocrEngine->performOcr(pixs, singleLine);

    pixDestroy(&pixs);

    if(ocrText.size() == 0)
    {
        QTextStream(stderr) << "Error, OCR failure." << Qt::endl;
        return QString("<Error>");
    }

    return ocrText;
}

bool CommandLine::convertStringToRect(QString str, QRect &rect)
{
    QStringList fields = str.split(" ", Qt::SkipEmptyParts);

    if(fields.size() != 4)
    {
        QTextStream(stderr) << "Error, need to specify 4 values for rectangle:" << Qt::endl
                            << "\"" << str << "\"" << Qt::endl;
        qCritical() << "Error, need to specify 4 values for rectangle:" << Qt::endl
                            << "\"" << str << "\"" << Qt::endl;
        return false;
    }

    bool status = false;
    int coords[4];

    for(int i = 0; i < 4; i++)
    {
        coords[i] = fields[i].toInt(&status);

        if(!status)
        {
            QTextStream(stderr) << "Error, rectangle value must be an integer:" << Qt::endl
                                << "\"" << fields[i] << "\"" << Qt::endl;
            qCritical() << "Error, rectangle value must be an integer:" << Qt::endl
                                << "\"" << fields[i] << "\"" << Qt::endl;
            return false;
        }
    }

    rect.setCoords(coords[0], coords[1], coords[2], coords[3]);

    return true;
}

void CommandLine::ocrFileOfImages(QString imagesFile)
{
    if(!QFile::exists(imagesFile))
    {
        QTextStream(stderr) << "Error, file does not exist:" << Qt::endl
                            << "\"" << imagesFile << "\"" << Qt::endl;
        return;
    }

    QFile file(imagesFile);

    if(!file.open(QIODevice::ReadOnly))
    {
        QTextStream(stderr) << "Error, could not open file:" << Qt::endl
                            << "\"" << imagesFile << "\"" << Qt::endl;
        return;
    }

    QTextStream in(&file);
    QStringList imgPaths;

    while(!in.atEnd())
    {
        QString imgPath = in.readLine().trimmed();

        if(imgPath.size() > 0)
        {
            imgPaths.append(imgPath);
        }
    }

    file.close();

    ocrImageFiles(imgPaths);
}

void CommandLine::ocrImageFiles(QStringList &imgList)
{
    for(auto img : imgList)
    {
        ocrImageFileAndOutput(img);
    }
}

void CommandLine::ocrImageFileAndOutput(QString img)
{
    currentImageFile = img;
    captureTimestamp = QDateTime::currentDateTime();
    QString ocrText = ocrImageFile(img);
    ocrText = postProcessText(ocrText);
    outputOcrText(ocrText);
}

QString CommandLine::ocrImageFile(QString img)
{
    if(!QFile::exists(img))
    {
        QTextStream(stderr) << "Error, file does not exist:" << Qt::endl
                            << "\"" << img << "\"" << Qt::endl;
        return QString("<Error>");
    }

    PIX *inPixs = imagePreprocessor.convertImageToPix(img);
    PIX *pixs = imagePreprocessor.processImage(inPixs, preprocessDeskew, preprocessTrim);
    pixDestroy(&inPixs);

    if(pixs == nullptr)
    {
        QTextStream(stderr) << "Error, pre-processing failure:" << Qt::endl
                            << "\"" << img << "\"" << Qt::endl;
        return QString("<Error>");
    }

    if(debug)
    {
        QString savePath = getDebugImagePath("debug_enhanced.png");
        QByteArray byteArray = savePath.toLocal8Bit();
        pixWriteImpliedFormat(byteArray.constData(), pixs, 0, 0);
    }

    bool singleLine = false;

    if(UtilsLang::languageSupportsFurigana(ocrEngine->getLang()))
    {
        singleLine = (imagePreprocessor.getJapNumTextLines() == 1);
    }

    QString ocrText = ocrEngine->performOcr(pixs, singleLine);
    pixDestroy(&pixs);

    if(ocrText.size() == 0)
    {
        QTextStream(stderr) << "Error, OCR failure:" << Qt::endl
                            << "\"" << img << "\"" << Qt::endl;
        return QString("<Error>");
    }

    return ocrText;
}

void CommandLine::outputOcrText(QString ocrText)
{
    QString formattedOcrText = UtilsCommon::formatLogLine(outputFormat, ocrText, captureTimestamp, "", currentImageFile);

    if(outputFilePath.size() > 0)
    {
        outputToFile(formattedOcrText);
    }

    outputToConsole(formattedOcrText);

    if(copyToClipboard)
    {
        allOcrText.append(formattedOcrText);
    }
}

void CommandLine::outputToFile(QString ocrText)
{
    QTextStream stream(&outputFile);
    stream.setEncoding(QStringConverter::Utf8);
    stream.setGenerateByteOrderMark(true);
    stream << ocrText;
    stream.flush();
}

void CommandLine::outputToConsole(QString ocrText)
{
    QTextStream stream(stdout);
    stream.setEncoding(QStringConverter::Utf8);
    stream << ocrText;
}

void CommandLine::showInstalledLanguages()
{
    QStringList installedLangs = ocrEngine->getInstalledLangs();
    QTextStream outStream(stdout);

    outStream << "Installed OCR Languages:" << Qt::endl;

    for(auto item : installedLangs)
    {
        outStream << item << Qt::endl;
    }
}

QString CommandLine::getDebugImagePath(QString filename)
{
    return UtilsImg::getDebugScreenshotPath(filename, debugAppendTimestamp, captureTimestamp);
}




