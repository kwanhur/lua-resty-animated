-- Copyright (C) by Kwanhur Huang


local modulename = "animatedWebp"
local _M = {}
_M._NAME = modulename
local mt = { __index = _M }

local ffi = require("ffi")
local lib = require("resty.animated.libwebp")
local base = require("resty.animated.base")

local WEBP_OK = 1
local WEBP_QUALITY_DEFAULT = 75
local GIF_INDEX_INVALID = -1 -- Opaque by default.
local WEBP_MUX_ERROR = {}
WEBP_MUX_ERROR['1'] = 'WEBP_MUX_OK'
WEBP_MUX_ERROR['0'] = 'WEBP_MUX_NOT_FOUND'
WEBP_MUX_ERROR['-1'] = 'WEBP_MUX_INVALID_ARGUMENT'
WEBP_MUX_ERROR['-2'] = 'WEBP_MUX_BAD_DATA'
WEBP_MUX_ERROR['-3'] = 'WEBP_MUX_MEMORY_ERROR'
WEBP_MUX_ERROR['-4'] = 'WEBP_MUX_NOT_ENOUGH_DATA'

local setmetatable = setmetatable
local tostring = tostring
local ffi_new = ffi.new
local ffi_str = ffi.string
local ffi_gc = ffi.gc

local libgifdec = ffi.load('libgifdec')
local libmux = ffi.load('libwebpmux')

_M.new = function(self)
    return setmetatable(self, mt)
end

_M.gif_rect = function(self)
    return ffi_new("struct GIFFrameRect")
end

_M.picture = function(self)
    return ffi_new("struct WebPPicture")
end

_M.picture_init = function(self, pic)
    local ret = lib.WebPPictureInitInternal(pic, lib.WEBP_ENCODER_ABI_VERSION) == WEBP_OK
    if ret then
        ffi_gc(pic, lib.WebPPictureFree)
    end
    return ret
end

_M.picture_alloc = function(self, pic)
    return lib.WebPPictureAlloc(pic) == WEBP_OK
end

_M.picture_copy = function(self, pic, canvas)
    return lib.WebPPictureCopy(pic, canvas) == WEBP_OK
end

_M.gif_clear_pic = function(self, pic)
    libgifdec.GIFClearPic(pic, nil)
end

_M.gif_get_background_color = function(self, color_map, background_color, bgcolor)
    libgifdec.GIFGetBackgroundColor(color_map, background_color, GIF_INDEX_INVALID, base.get_uint32_const_ptr(bgcolor))
end

_M.gif_read_frame = function(self, gif, gif_rect, frame)
    return libgifdec.GIFReadFrame(gif, GIF_INDEX_INVALID, gif_rect, frame) == WEBP_OK
end

_M.gif_blend_frames = function(self, frame, gif_rect, curr_canvas)
    libgifdec.GIFBlendFrames(frame, gif_rect, curr_canvas)
end

_M.gif_dispose_frame = function(self, orig_dispose, gif_rect, prev_canvas, curr_canvas)
    libgifdec.GIFDisposeFrame(orig_dispose, gif_rect, prev_canvas, curr_canvas)
end

_M.gif_copy_pixels = function(self, curr_canvas, prev_canvas)
    libgifdec.GIFCopyPixels(curr_canvas, prev_canvas)
end

_M.gif_read_graphics_extension = function(self, data, frame_duration, orig_dispose)
    return libgifdec.GIFReadGraphicsExtension(data, frame_duration, orig_dispose, GIF_INDEX_INVALID) == WEBP_OK
end

_M.gif_read_loop_count = function(self, gif, data, loop_count)
    return libgifdec.GIFReadLoopCount(gif, data, loop_count) == WEBP_OK
end

_M.gif_read_metadata = function(self, gif, data, metadata)
    return libgifdec.GIFReadMetadata(gif, data, metadata) == WEBP_OK
end

_M.GIF_DISPOSE_NONE = lib.GIF_DISPOSE_NONE

_M.encoder_options = function(self)
    return ffi_new("struct WebPAnimEncoderOptions")
end

_M.encoder_options_init = function(self, enc_options)
    return libmux.WebPAnimEncoderOptionsInitInternal(enc_options, lib.WEBP_MUX_ABI_VERSION) == WEBP_OK
end

_M.encoder = function(self)
    return ffi_new("struct WebPAnimEncoder")
end

_M.encoder_new = function(self, width, height, enc_options)
    local ret = libmux.WebPAnimEncoderNewInternal(width, height, enc_options, lib.WEBP_MUX_ABI_VERSION)
    if ret then
        ffi_gc(enc_options, libmux.WebPAnimEncoderDelete)
    end
    return ret
end

_M.encoder_add = function(self, enc, curr_canvas, frame_timestamp, config)
    return libmux.WebPAnimEncoderAdd(enc, curr_canvas, frame_timestamp, config) == WEBP_OK
end

_M.encoder_error = function(self, enc)
    return ffi_str(libmux.WebPAnimEncoderGetError(enc))
end

_M.config = function(self)
    return ffi_new("struct WebPConfig")
end

_M.config_init = function(self, config)
    return lib.WebPConfigInitInternal(config, lib.WEBP_PRESET_DEFAULT, WEBP_QUALITY_DEFAULT, lib.WEBP_ENCODER_ABI_VERSION) == WEBP_OK
end

_M.config_validate = function(self, config)
    return lib.WebPValidateConfig(config) == WEBP_OK
end

_M.webp_data = function(self)
    return ffi_new("struct WebPData")
end

_M.webp_anim_params = function(self)
    return ffi_new("struct WebPMuxAnimParams")
end

_M.webp_anim_encoder_add = function(self, enc, frame_timestamp)
    return self:encoder_add(enc, nil, frame_timestamp, nil)
end

_M.webp_anim_encoder_assemble = function(self, enc, webp_data)
    return libmux.WebPAnimEncoderAssemble(enc, webp_data) == WEBP_OK
end

_M.webp_anim_encoder_error = function(self, enc)
    return tostring(libmux.WebPAnimEncoderGetError(enc))
end

_M.mux_create = function(self, webp_data)
    local ret = libmux.WebPMuxCreate(webp_data, 1)
    if ret then
        ffi_gc(ret, libmux.WebPMuxDelete)
    end
    return ret
end

_M.mux_assemble = function(self, mux, webp_data)
    local code = libmux.WebPMuxAssemble(mux, webp_data)
    local ret = code == libmux.WEBP_MUX_OK
    if ret then
        return true
    else
        return false, WEBP_MUX_ERROR[tostring(code)]
    end
end

_M.mux_set_chunk = function(self, mux, fourcc, chunk_data)
    local code = libmux.WebPMuxSetChunk(mux, fourcc, chunk_data, 1)
    local ret = code == libmux.WEBP_MUX_OK
    if ret then
        return true
    else
        return false, WEBP_MUX_ERROR[tostring(code)]
    end
end

_M.mux_get_animation_params = function(self, mux, new_params)
    local code = libmux.WebPMuxGetAnimationParams(mux, new_params)
    local ret = code == libmux.WEBP_MUX_OK
    if ret then
        return true
    else
        return false, WEBP_MUX_ERROR[tostring(code)]
    end
end

_M.mux_set_animation_params = function(self, mux, new_params)
    local code = libmux.WebPMuxSetAnimationParams(mux, new_params)
    local ret = code == libmux.WEBP_MUX_OK
    if ret then
        return true
    else
        return false, WEBP_MUX_ERROR[tostring(code)]
    end
end

return _M