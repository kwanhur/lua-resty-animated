-- Copyright (C) by Kwanhur Huang


local ffi = require("ffi")

ffi.cdef([[
  typedef enum GIFDisposeMethod {
    GIF_DISPOSE_NONE,
    GIF_DISPOSE_BACKGROUND,
    GIF_DISPOSE_RESTORE_PREVIOUS
  } GIFDisposeMethod;

  typedef struct GIFFrameRect {
    int x_offset, y_offset, width, height;
  } GIFFrameRect;

  typedef struct WebPConfig WebPConfig;
  typedef struct WebPPicture WebPPicture;   // main structure for I/O
  typedef struct WebPAuxStats WebPAuxStats;
  typedef struct WebPData WebPData;
  typedef struct WebPMux WebPMux;   // main opaque object.
  typedef struct WebPMuxAnimParams WebPMuxAnimParams;
  typedef struct WebPMuxFrameInfo WebPMuxFrameInfo;

  typedef struct WebPAnimEncoder WebPAnimEncoder;  // Main opaque object.
  typedef struct WebPAnimEncoderOptions WebPAnimEncoderOptions;

  typedef int (*WebPWriterFunction)(const uint8_t* data, size_t data_size,
                                  const WebPPicture* picture);
  typedef int (*WebPProgressHook)(int percent, const WebPPicture* picture);

  // Error codes
typedef enum WebPMuxError {
  WEBP_MUX_OK                 =  1,
  WEBP_MUX_NOT_FOUND          =  0,
  WEBP_MUX_INVALID_ARGUMENT   = -1,
  WEBP_MUX_BAD_DATA           = -2,
  WEBP_MUX_MEMORY_ERROR       = -3,
  WEBP_MUX_NOT_ENOUGH_DATA    = -4
} WebPMuxError;

  // Color spaces.
  typedef enum WebPEncCSP {
    // chroma sampling
    WEBP_YUV420  = 0,        // 4:2:0
    WEBP_YUV420A = 4,        // alpha channel variant
    WEBP_CSP_UV_MASK = 3,    // bit-mask to get the UV sampling factors
    WEBP_CSP_ALPHA_BIT = 4   // bit that is set if alpha is present
  } WebPEncCSP;

  // Image characteristics hint for the underlying encoder.
typedef enum WebPImageHint {
  WEBP_HINT_DEFAULT = 0,  // default preset.
  WEBP_HINT_PICTURE,      // digital picture, like portrait, inner shot
  WEBP_HINT_PHOTO,        // outdoor photograph, with natural lighting
  WEBP_HINT_GRAPH,        // Discrete tone image (graph, map-tile etc).
  WEBP_HINT_LAST
} WebPImageHint;

// Encoding error conditions.
typedef enum WebPEncodingError {
  VP8_ENC_OK = 0,
  VP8_ENC_ERROR_OUT_OF_MEMORY,            // memory error allocating objects
  VP8_ENC_ERROR_BITSTREAM_OUT_OF_MEMORY,  // memory error while flushing bits
  VP8_ENC_ERROR_NULL_PARAMETER,           // a pointer parameter is NULL
  VP8_ENC_ERROR_INVALID_CONFIGURATION,    // configuration is invalid
  VP8_ENC_ERROR_BAD_DIMENSION,            // picture has invalid width/height
  VP8_ENC_ERROR_PARTITION0_OVERFLOW,      // partition is bigger than 512k
  VP8_ENC_ERROR_PARTITION_OVERFLOW,       // partition is bigger than 16M
  VP8_ENC_ERROR_BAD_WRITE,                // error while flushing bytes
  VP8_ENC_ERROR_FILE_TOO_BIG,             // file is bigger than 4G
  VP8_ENC_ERROR_USER_ABORT,               // abort request by user
  VP8_ENC_ERROR_LAST                      // list terminator. always last.
} WebPEncodingError;

// Enumerate some predefined settings for WebPConfig, depending on the type
// of source picture. These presets are used when calling WebPConfigPreset().
typedef enum WebPPreset {
  WEBP_PRESET_DEFAULT = 0,  // default preset.
  WEBP_PRESET_PICTURE,      // digital picture, like portrait, inner shot
  WEBP_PRESET_PHOTO,        // outdoor photograph, with natural lighting
  WEBP_PRESET_DRAWING,      // hand or line drawing, with high-contrast details
  WEBP_PRESET_ICON,         // small-sized colorful images
  WEBP_PRESET_TEXT          // text-like
} WebPPreset;

// Compression parameters.
struct WebPConfig {
  int lossless;           // Lossless encoding (0=lossy(default), 1=lossless).
  float quality;          // between 0 and 100. For lossy, 0 gives the smallest
                          // size and 100 the largest. For lossless, this
                          // parameter is the amount of effort put into the
                          // compression: 0 is the fastest but gives larger
                          // files compared to the slowest, but best, 100.
  int method;             // quality/speed trade-off (0=fast, 6=slower-better)

  WebPImageHint image_hint;  // Hint for image type (lossless only for now).

  int target_size;        // if non-zero, set the desired target size in bytes.
                          // Takes precedence over the 'compression' parameter.
  float target_PSNR;      // if non-zero, specifies the minimal distortion to
                          // try to achieve. Takes precedence over target_size.
  int segments;           // maximum number of segments to use, in [1..4]
  int sns_strength;       // Spatial Noise Shaping. 0=off, 100=maximum.
  int filter_strength;    // range: [0 = off .. 100 = strongest]
  int filter_sharpness;   // range: [0 = off .. 7 = least sharp]
  int filter_type;        // filtering type: 0 = simple, 1 = strong (only used
                          // if filter_strength > 0 or autofilter > 0)
  int autofilter;         // Auto adjust filter's strength [0 = off, 1 = on]
  int alpha_compression;  // Algorithm for encoding the alpha plane (0 = none,
                          // 1 = compressed with WebP lossless). Default is 1.
  int alpha_filtering;    // Predictive filtering method for alpha plane.
                          //  0: none, 1: fast, 2: best. Default if 1.
  int alpha_quality;      // Between 0 (smallest size) and 100 (lossless).
                          // Default is 100.
  int pass;               // number of entropy-analysis passes (in [1..10]).

  int show_compressed;    // if true, export the compressed picture back.
                          // In-loop filtering is not applied.
  int preprocessing;      // preprocessing filter:
                          // 0=none, 1=segment-smooth, 2=pseudo-random dithering
  int partitions;         // log2(number of token partitions) in [0..3]. Default
                          // is set to 0 for easier progressive decoding.
  int partition_limit;    // quality degradation allowed to fit the 512k limit
                          // on prediction modes coding (0: no degradation,
                          // 100: maximum possible degradation).
  int emulate_jpeg_size;  // If true, compression parameters will be remapped
                          // to better match the expected output size from
                          // JPEG compression. Generally, the output size will
                          // be similar but the degradation will be lower.
  int thread_level;       // If non-zero, try and use multi-threaded encoding.
  int low_memory;         // If set, reduce memory usage (but increase CPU use).

  int near_lossless;      // Near lossless encoding [0 = max loss .. 100 = off
                          // (default)].
  int exact;              // if non-zero, preserve the exact RGB values under
                          // transparent area. Otherwise, discard this invisible
                          // RGB information for better compression. The default
                          // value is 0.

  int use_delta_palette;  // reserved for future lossless feature
  int use_sharp_yuv;      // if needed, use sharp (and slow) RGB->YUV conversion

  uint32_t pad[2];        // padding for later use
};

  struct WebPAuxStats {
  int coded_size;         // final size

  float PSNR[5];          // peak-signal-to-noise ratio for Y/U/V/All/Alpha
  int block_count[3];     // number of intra4/intra16/skipped macroblocks
  int header_bytes[2];    // approximate number of bytes spent for header
                          // and mode-partition #0
  int residual_bytes[3][4];  // approximate number of bytes spent for
                             // DC/AC/uv coefficients for each (0..3) segments.
  int segment_size[4];    // number of macroblocks in each segments
  int segment_quant[4];   // quantizer values for each segments
  int segment_level[4];   // filtering strength for each segments [0..63]

  int alpha_data_size;    // size of the transparency data
  int layer_data_size;    // size of the enhancement layer data

  // lossless encoder statistics
  uint32_t lossless_features;  // bit0:predictor bit1:cross-color transform
                               // bit2:subtract-green bit3:color indexing
  int histogram_bits;          // number of precision bits of histogram
  int transform_bits;          // precision bits for transform
  int cache_bits;              // number of bits for color cache lookup
  int palette_size;            // number of color in palette, if used
  int lossless_size;           // final lossless size
  int lossless_hdr_size;       // lossless header (transform, huffman etc) size
  int lossless_data_size;      // lossless image data size

  uint32_t pad[2];        // padding for later use
};

  struct WebPPicture {
  //   INPUT
  //////////////
  // Main flag for encoder selecting between ARGB or YUV input.
  // It is recommended to use ARGB input (*argb, argb_stride) for lossless
  // compression, and YUV input (*y, *u, *v, etc.) for lossy compression
  // since these are the respective native colorspace for these formats.
  int use_argb;

  // YUV input (mostly used for input to lossy compression)
  WebPEncCSP colorspace;     // colorspace: should be YUV420 for now (=Y'CbCr).
  int width, height;         // dimensions (less or equal to WEBP_MAX_DIMENSION)
  uint8_t *y, *u, *v;        // pointers to luma/chroma planes.
  int y_stride, uv_stride;   // luma/chroma strides.
  uint8_t* a;                // pointer to the alpha plane
  int a_stride;              // stride of the alpha plane
  uint32_t pad1[2];          // padding for later use

  // ARGB input (mostly used for input to lossless compression)
  uint32_t* argb;            // Pointer to argb (32 bit) plane.
  int argb_stride;           // This is stride in pixels units, not bytes.
  uint32_t pad2[3];          // padding for later use

  //   OUTPUT
  ///////////////
  // Byte-emission hook, to store compressed bytes as they are ready.
  WebPWriterFunction writer;  // can be NULL
  void* custom_ptr;           // can be used by the writer.

  // map for extra information (only for lossy compression mode)
  int extra_info_type;    // 1: intra type, 2: segment, 3: quant
                          // 4: intra-16 prediction mode,
                          // 5: chroma prediction mode,
                          // 6: bit cost, 7: distortion
  uint8_t* extra_info;    // if not NULL, points to an array of size
                          // ((width + 15) / 16) * ((height + 15) / 16) that
                          // will be filled with a macroblock map, depending
                          // on extra_info_type.

  //   STATS AND REPORTS
  ///////////////////////////
  // Pointer to side statistics (updated only if not NULL)
  WebPAuxStats* stats;

  // Error code for the latest error encountered during encoding
  WebPEncodingError error_code;

  // If not NULL, report progress during encoding.
  WebPProgressHook progress_hook;

  void* user_data;        // this field is free to be set to any value and
                          // used during callbacks (like progress-report e.g.).

  uint32_t pad3[3];       // padding for later use

  // Unused for now
  uint8_t *pad4, *pad5;
  uint32_t pad6[8];       // padding for later use

  // PRIVATE FIELDS
  ////////////////////
  void* memory_;          // row chunk of memory for yuva planes
  void* memory_argb_;     // and for argb too.
  void* pad7[2];          // padding for later use
};

// Animation parameters.
struct WebPMuxAnimParams {
  uint32_t bgcolor;  // Background color of the canvas stored (in MSB order) as:
                     // Bits 00 to 07: Alpha.
                     // Bits 08 to 15: Red.
                     // Bits 16 to 23: Green.
                     // Bits 24 to 31: Blue.
  int loop_count;    // Number of times to repeat the animation [0 = infinite].
};

// Global options.
struct WebPAnimEncoderOptions {
  WebPMuxAnimParams anim_params;  // Animation parameters.
  int minimize_size;    // If true, minimize the output size (slow). Implicitly
                        // disables key-frame insertion.
  int kmin;
  int kmax;             // Minimum and maximum distance between consecutive key
                        // frames in the output. The library may insert some key
                        // frames as needed to satisfy this criteria.
                        // Note that these conditions should hold: kmax > kmin
                        // and kmin >= kmax / 2 + 1. Also, if kmax <= 0, then
                        // key-frame insertion is disabled; and if kmax == 1,
                        // then all frames will be key-frames (kmin value does
                        // not matter for these special cases).
  int allow_mixed;      // If true, use mixed compression mode; may choose
                        // either lossy and lossless for each frame.
  int verbose;          // If true, print info and warning messages to stderr.

  uint32_t padding[4];  // Padding for later use.
};

struct WebPData {
  const uint8_t* bytes;
  size_t size;
};

// IDs for different types of chunks.
typedef enum WebPChunkId {
  WEBP_CHUNK_VP8X,        // VP8X
  WEBP_CHUNK_ICCP,        // ICCP
  WEBP_CHUNK_ANIM,        // ANIM
  WEBP_CHUNK_ANMF,        // ANMF
  WEBP_CHUNK_DEPRECATED,  // (deprecated from FRGM)
  WEBP_CHUNK_ALPHA,       // ALPH
  WEBP_CHUNK_IMAGE,       // VP8/VP8L
  WEBP_CHUNK_EXIF,        // EXIF
  WEBP_CHUNK_XMP,         // XMP
  WEBP_CHUNK_UNKNOWN,     // Other chunks.
  WEBP_CHUNK_NIL
} WebPChunkId;

typedef enum WebPMuxAnimDispose {
  WEBP_MUX_DISPOSE_NONE,       // Do not dispose.
  WEBP_MUX_DISPOSE_BACKGROUND  // Dispose to background color.
} WebPMuxAnimDispose;

typedef enum WebPMuxAnimBlend {
  WEBP_MUX_BLEND,              // Blend.
  WEBP_MUX_NO_BLEND            // Do not blend.
} WebPMuxAnimBlend;

// Encapsulates data about a single frame.
struct WebPMuxFrameInfo {
  WebPData    bitstream;  // image data: can be a raw VP8/VP8L bitstream
                          // or a single-image WebP file.
  int         x_offset;   // x-offset of the frame.
  int         y_offset;   // y-offset of the frame.
  int         duration;   // duration of the frame (in milliseconds).

  WebPChunkId id;         // frame type: should be one of WEBP_CHUNK_ANMF
                          // or WEBP_CHUNK_IMAGE
  WebPMuxAnimDispose dispose_method;  // Disposal method for the frame.
  WebPMuxAnimBlend   blend_method;    // Blend operation for the frame.
  uint32_t    pad[1];     // padding for later use
};

// Stores frame rectangle dimensions.
typedef struct {
  int x_offset_, y_offset_, width_, height_;
} FrameRectangle;

typedef struct {
  WebPMuxFrameInfo sub_frame_;  // Encoded frame rectangle.
  WebPMuxFrameInfo key_frame_;  // Encoded frame if it is a key-frame.
  int is_key_frame_;            // True if 'key_frame' has been chosen.
} EncodedFrame;

static const unsigned int ERROR_STR_MAX_LENGTH = 100;

struct WebPAnimEncoder {
  const int canvas_width_;                  // Canvas width.
  const int canvas_height_;                 // Canvas height.
  const WebPAnimEncoderOptions options_;    // Global encoding options.

  FrameRectangle prev_rect_;          // Previous WebP frame rectangle.
  WebPConfig last_config_;            // Cached in case a re-encode is needed.
  WebPConfig last_config_reversed_;   // If 'last_config_' uses lossless, then
                                      // this config uses lossy and vice versa;
                                      // only valid if 'options_.allow_mixed'
                                      // is true.

  WebPPicture* curr_canvas_;          // Only pointer; we don't own memory.

  // Canvas buffers.
  WebPPicture curr_canvas_copy_;      // Possibly modified current canvas.
  int curr_canvas_copy_modified_;     // True if pixels in 'curr_canvas_copy_'
                                      // differ from those in 'curr_canvas_'.

  WebPPicture prev_canvas_;           // Previous canvas.
  WebPPicture prev_canvas_disposed_;  // Previous canvas disposed to background.

  // Encoded data.
  EncodedFrame* encoded_frames_;      // Array of encoded frames.
  size_t size_;             // Number of allocated frames.
  size_t start_;            // Frame start index.
  size_t count_;            // Number of valid frames.
  size_t flush_count_;      // If >0, 'flush_count' frames starting from
                            // 'start' are ready to be added to mux.

  // key-frame related.
  int64_t best_delta_;      // min(canvas size - frame size) over the frames.
                            // Can be negative in certain cases due to
                            // transparent pixels in a frame.
  int keyframe_;            // Index of selected key-frame relative to 'start_'.
  int count_since_key_frame_;     // Frames seen since the last key-frame.

  int first_timestamp_;           // Timestamp of the first frame.
  int prev_timestamp_;            // Timestamp of the last added frame.
  int prev_candidate_undecided_;  // True if it's not yet decided if previous
                                  // frame would be a sub-frame or a key-frame.

  // Misc.
  int is_first_frame_;  // True if first frame is yet to be added/being added.
  int got_null_frame_;  // True if WebPAnimEncoderAdd() has already been called
                        // with a NULL frame.

  size_t in_frame_count_;   // Number of input frames processed so far.
  size_t out_frame_count_;  // Number of frames added to mux so far. This may be
                            // different from 'in_frame_count_' due to merging.

  WebPMux* mux_;        // Muxer to assemble the WebP bitstream.
  char error_str_[ERROR_STR_MAX_LENGTH];  // Error string. Empty if no error.
};

  void GIFGetBackgroundColor(const struct ColorMapObject* const color_map,
                           int bgcolor_index, int transparent_index,
                           uint32_t* const bgcolor);

  int GIFReadGraphicsExtension(const GifByteType* const buf, int* const duration,
                             GIFDisposeMethod* const dispose,
                             int* const transparent_index);

  int GIFReadFrame(struct GifFileType* const gif, int transparent_index,
                 GIFFrameRect* const gif_rect,
                 struct WebPPicture* const picture);

  int GIFReadLoopCount(struct GifFileType* const gif, GifByteType** const buf,
                     int* const loop_count);

  int GIFReadMetadata(struct GifFileType* const gif, GifByteType** const buf,
                    struct WebPData* const metadata);

  void GIFDisposeFrame(GIFDisposeMethod dispose, const GIFFrameRect* const rect,
                     const struct WebPPicture* const prev_canvas,
                     struct WebPPicture* const curr_canvas);

  void GIFBlendFrames(const struct WebPPicture* const src,
                    const GIFFrameRect* const rect,
                    struct WebPPicture* const dst);

  void GIFDisplayError(const struct GifFileType* const gif, int gif_error);

  void GIFClearPic(struct WebPPicture* const pic, const GIFFrameRect* const rect);

  void GIFCopyPixels(const struct WebPPicture* const src,
                   struct WebPPicture* const dst);

  static const unsigned int WEBP_ENCODER_ABI_VERSION = 0x020e;    // MAJOR(8b) + MINOR(8b)
  static const unsigned int WEBP_MUX_ABI_VERSION = 0x0108;        // MAJOR(8b) inline

  int WebPConfigInitInternal(WebPConfig*, WebPPreset, float, int);
  int WebPValidateConfig(const WebPConfig* config);

  int WebPPictureInitInternal(WebPPicture*, int);
  int WebPPictureAlloc(WebPPicture* picture);
  void WebPPictureFree(WebPPicture* picture);
  int WebPPictureCopy(const WebPPicture* src, WebPPicture* dst);

  int WebPAnimEncoderOptionsInitInternal(
    WebPAnimEncoderOptions*, int);

  WebPAnimEncoder* WebPAnimEncoderNewInternal(
    int, int, const WebPAnimEncoderOptions*, int);
  int WebPAnimEncoderAdd(
    WebPAnimEncoder* enc, struct WebPPicture* frame, int timestamp_ms,
    const struct WebPConfig* config);
  int WebPAnimEncoderAssemble(WebPAnimEncoder* enc,
                                        WebPData* webp_data);
  void WebPAnimEncoderDelete(WebPAnimEncoder* enc);
  const char* WebPAnimEncoderGetError(WebPAnimEncoder* enc);

  WebPMux* WebPMuxCreateInternal(const WebPData*, int, int);
  void WebPMuxDelete(WebPMux* mux);

  WebPMuxError WebPMuxGetAnimationParams(
    const WebPMux* mux, WebPMuxAnimParams* params);
  WebPMuxError WebPMuxSetAnimationParams(
    WebPMux* mux, const WebPMuxAnimParams* params);
  WebPMuxError WebPMuxSetChunk(
    WebPMux* mux, const char fourcc[4], const WebPData* chunk_data,
    int copy_data);
  WebPMuxError WebPMuxAssemble(WebPMux* mux,
                                         WebPData* assembled_data);
]])
return ffi.load("libwebp")