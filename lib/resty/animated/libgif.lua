-- Copyright (C) by Kwanhur Huang


local ffi = require("ffi")

ffi.cdef([[
  typedef void GifColorType;

  typedef unsigned char GifPixelType;
  typedef unsigned char *GifRowType;
  typedef unsigned char GifByteType;
  typedef unsigned int GifPrefixType;
  typedef int GifWord;

  typedef enum {
    UNDEFINED_RECORD_TYPE,
    SCREEN_DESC_RECORD_TYPE,
    IMAGE_DESC_RECORD_TYPE, /* Begin with ',' */
    EXTENSION_RECORD_TYPE,  /* Begin with '!' */
    TERMINATE_RECORD_TYPE   /* Begin with ';' */
  } GifRecordType;

  typedef struct ExtensionFunctionCode {
    static const int CONTINUE_EXT_FUNC_CODE    = 0x00;   /* continuation subblock */
    static const int COMMENT_EXT_FUNC_CODE     = 0xfe;   /* comment */
    static const int GRAPHICS_EXT_FUNC_CODE    = 0xf9;   /* graphics control (GIF89) */
    static const int PLAINTEXT_EXT_FUNC_CODE   = 0x01;   /* plaintext */
    static const int APPLICATION_EXT_FUNC_CODE = 0xff;  /* application block */
  }ExtensionFunctionCode;

  typedef struct ExtensionBlock {
    int ByteCount;
    GifByteType *Bytes; /* on malloc(3) heap */
    int Function;       /* The block function code */
  } ExtensionBlock;

  typedef struct ColorMapObject {
    int ColorCount;
    int BitsPerPixel;
    bool SortFlag;
    GifColorType *Colors;    /* on malloc(3) heap */
  } ColorMapObject;

  typedef struct GifImageDesc {
    GifWord Left, Top, Width, Height;   /* Current image dimensions. */
    bool Interlace;                     /* Sequential/Interlaced lines. */
    ColorMapObject *ColorMap;           /* The local color map */
  } GifImageDesc;

  typedef struct SavedImage {
    GifImageDesc ImageDesc;
    GifByteType *RasterBits;         /* on malloc(3) heap */
    int ExtensionBlockCount;         /* Count of extensions before image */
    ExtensionBlock *ExtensionBlocks; /* Extensions before image */
  } SavedImage;

  typedef struct GifFileType {
    GifWord SWidth, SHeight;         /* Size of virtual canvas */
    GifWord SColorResolution;        /* How many colors can we generate? */
    GifWord SBackGroundColor;        /* Background color for virtual canvas */
    GifByteType AspectByte;	     /* Used to compute pixel aspect ratio */
    ColorMapObject *SColorMap;       /* Global colormap, NULL if nonexistent. */
    int ImageCount;                  /* Number of current image (both APIs) */
    GifImageDesc Image;              /* Current image (low-level API) */
    SavedImage *SavedImages;         /* Image sequence (high-level API) */
    int ExtensionBlockCount;         /* Count extensions past last image */
    ExtensionBlock *ExtensionBlocks; /* Extensions past last image */
    int Error;			     /* Last error condition reported */
    void *UserData;                  /* hook to attach user data (TVT) */
    void *Private;                   /* Don't mess with this! */
  } GifFileType;

  const char *GifErrorString(int ErrorCode);
  GifFileType *DGifOpenFileName(const char *GifFileName, int *Error);
  int DGifSlurp(GifFileType * GifFile);
  int DGifCloseFile(GifFileType * GifFile, int *ErrorCode);

  int DGifGetRecordType(GifFileType *GifFile, GifRecordType *GifType);
  int DGifGetImageDesc(GifFileType *GifFile);
  int DGifGetExtension(GifFileType *GifFile, int *GifExtCode, GifByteType **GifExtension);
  int DGifGetExtensionNext(GifFileType *GifFile, GifByteType **GifExtension);
]])

return ffi.load("libgif.so")