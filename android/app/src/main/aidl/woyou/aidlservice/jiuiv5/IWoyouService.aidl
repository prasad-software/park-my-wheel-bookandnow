package woyou.aidlservice.jiuiv5;

interface IWoyouService {
    int printText(String text);
    int printTextWithFont(String text, int type, int size);
    int printBitmap(in Bitmap bitmap);
    int printBarCode(String data, int width, int height, int align);
    int printQRCode(String data, int moduleSize, int errorCorrectionLevel);
    int printTable(in String[] text, int align);
    int printColumnsText(in String[] text, in int[] align, in int[] columnWidth);
    int printRawData(in byte[] data);
    int setAlignment(int alignment);
    int setFontSize(float size);
    int setFontStyle(int style);
    int setLineSpacing(float spacing);
    int setGray(int level);
    int walkPaper(int steps);
    int cutPaper(int mode);
    int initPrinter();
    int getPrinterSerialNo();
    int getPrinterVersion();
    int getPrinterModel();
    int getPrinterStatus();
    int getPrintedLength();
    int hasPrinter();
    int getPrinterHead();
}
