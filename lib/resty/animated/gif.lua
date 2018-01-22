-- Copyright (C) by Kwanhur Huang


local modulename = "animatedGif"
local _M = {}
_M._NAME = modulename
local mt = { __index = _M }

local ffi = require("ffi")
local lib = require("resty.animated.libgif")
local base = require('resty.animated.base')

local GIF_ERROR = 0

local ffi_new = ffi.new
local ffi_str = ffi.string
local ffi_gc = ffi.gc
local tonumber = tonumber
local tostring = tostring
local setmetatable = setmetatable

local get_int_ptr = base.get_int_ptr
local get_int_ptr_0 = base.get_int_ptr_0

local EXTENSION_CODE = ffi_new("struct ExtensionFunctionCode")

local get_error = function(status)
    if status == 0 then
        return "There was an error"
    else
        return ffi_str(lib.GifErrorString(status))
    end
end

local load_gif = function(fname)
    local err = get_int_ptr_0()
    local gif = lib.DGifOpenFileName(fname, err)
    if gif == nil then
        return nil, get_error(err[0])
    end
    return gif
end

local close_gif = function(gif)
    local err = get_int_ptr_0()
    if lib.DGifCloseFile(gif, err) == GIF_ERROR then
        return false, get_error(err[0])
    else
        return true
    end
end

local record_type = function(gif)
    local rt = base.get_gif_record_type_ptr()
    if GIF_ERROR == lib.DGifGetRecordType(gif, rt) then
        return nil, "failed to get record type, err:" .. tostring(get_error(gif.Error))
    end
    return rt[0]
end

_M.new = function(self, fname)
    local gif, err = load_gif(fname)
    if gif then
        self.gif = ffi_gc(gif, close_gif)
    else
        return nil, err
    end
    return setmetatable(self, mt)
end

_M.slurp = function(self)
    return GIF_ERROR ~= lib.DGifSlurp(self.gif)
end

_M.close = function(self)
    if not self.gif then
        return false, 'no gif instance'
    end
    ffi_gc(self.gif, nil)
    return close_gif(self.gif)
end

-- Number of current image
_M.image_index = function(self)
    return self.gif.ImageCount
end

_M.width = function(self)
    return self.gif.SWidth
end

_M.set_width = function(self, width)
    self.gif.SWidth = width
end

_M.height = function(self)
    return self.gif.SHeight
end

_M.set_height = function(self, height)
    self.gif.SHeight = height
end

_M.resolution = function(self)
    return self.gif.SColorResolution
end

_M.record_type = function(self)
    local ret, err = record_type(self.gif)
    if not ret then
        return nil, err
    end
    return tonumber(ret)
end

_M.color_map = function(self)
    return self.gif.SColorMap
end

_M.background_color = function(self)
    return self.gif.SBackGroundColor
end

_M.get_extension = function(self, ext_data)
    local ext_code = get_int_ptr()
    local ext_data = ext_data or ffi_new("GifByteType*[1]")
    if GIF_ERROR == lib.DGifGetExtension(self.gif, ext_code, ext_data) then
        return nil, "failed to get extension,err:" .. tostring(get_error(self.gif.Error)), nil
    end
    return tonumber(ext_code[0]), ffi_str(ext_data[0]), ext_data
end

_M.get_extension_next = function(self, ext_data)
    if GIF_ERROR == lib.DGifGetExtensionNext(self.gif, ext_data) then
        return nil, "failed to get extension next,err:" .. tostring(get_error(self.gif.Error))
    end
    return ffi_str(ext_data[0])
end

_M.EXTENSION_CODE = EXTENSION_CODE

_M.IMAGE_DESC_RECORD_TYPE = lib.IMAGE_DESC_RECORD_TYPE

_M.EXTENSION_RECORD_TYPE = lib.EXTENSION_RECORD_TYPE

_M.TERMINATE_RECORD_TYPE = lib.TERMINATE_RECORD_TYPE

_M.NULL = nil

_M.image = function(self)
    return self.gif.Image
end

_M.get_image_desc = function(self)
    if GIF_ERROR == lib.DGifGetImageDesc(self.gif) then
        return nil, "failed to get image desc"
    end
    return true
end

_M.error_str = function(self)
    return get_error(self.gif.Error)
end

return _M