-- Copyright (C) by Kwanhur Huang


local modulename = "animatedBase"
local _M = {}
_M._NAME = modulename
_M._VERSION = '0.0.1'

local ffi = require('ffi')
local ffi_new = ffi.new
local ffi_cast = ffi.cast
local ffi_istype = ffi.istype
local ffi_str = ffi.string

local str_buf_size = 4096

local int_0
local int_ptr_0
local int_ptr
local gif_record_type_ptr

ffi.cdef([[
    char *strerror(int errnum);
]])

_M.get_int_ptr_0 = function()
    if not int_ptr_0 then
        int_ptr_0 = ffi_new("int[1]", 0)
    end

    return int_ptr_0
end

_M.get_int_0 = function()
    if not int_0 then
        int_0 = ffi_new("int", 0)
    end

    return int_0
end

_M.get_int_ptr = function()
    if not int_ptr then
        int_ptr = ffi_new("int[1]")
    end

    return int_ptr
end

_M.get_string_buf_size = function()
    return str_buf_size
end

_M.get_uint32_const_ptr = function(num)
    return ffi_cast('uint32_t* const', ffi_new('uint32_t', num))
end

_M.get_gif_record_type_ptr = function()
    if not gif_record_type_ptr then
        gif_record_type_ptr = ffi_new("GifRecordType[1]")
    end
    return gif_record_type_ptr
end

_M.isctype = function(ct, obj)
    return ffi_istype(ct, obj)
end

_M.cast = function(ct, init)
    return ffi_cast(ct, init)
end

_M.error = function()
    local errno = ffi.errno()
    if not errno then
        return ''
    end

    return ffi_str(ffi.C.strerror(errno))
end

return _M