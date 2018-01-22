-- Copyright (C) by Kwanhur Huang


local modulename = "animatedInit"
local _M = {}
_M._NAME = modulename
local mt = { __index = _M }

local gif = require('resty.animated.gif')
local webp = require('resty.animated.gif2webp')

local lower = string.lower
local tonumber = tonumber
local setmetatable = setmetatable


_M.new = function(self, fname)
    self.fname = fname
    self.image = nil
    self.anim = nil
    self.config = {
        lossless = 1,
        loop_compatibility = false,
        quality = 75,
        method = 0,
        filter_strength = 0,
        stored_icc = false,
        stored_xmp = true,
        allow_mixed = 0,
        minimize_size = 0,
        kmin = 3,
        kmax = 5
    }
    self.default_kmin = true
    self.default_kmax = true
    return setmetatable(self, mt)
end

_M.load = function(self)
    local image, err = gif:new(self.fname)
    if not image then
        return nil, err
    end
    self.image = image
    return true
end

_M.set_config = function(self, config, value)
    if not config then
        return false, "no specified config"
    end
    config = lower(config)
    if config == 'lossy' and value then
        self.config.lossless = 0
    elseif config == 'mixed' and value then
        self.encode_option.allow_mixed = 1
    elseif config == 'loop_compatibility' and value then
        self.config.loop_compatibility = true
    elseif config == 'quality' then
        value = tonumber(value)
        if not value then
            return false, "value not a number"
        elseif value < 0 or value > 100 then
            return false, "value must be in range [0..100]"
        end
        self.config.quality = value
    elseif config == 'method' then
        value = tonumber(value)
        if not value then
            return false, "value not a number"
        elseif value < 0 or value > 6 then
            return false, "value must be in range [0..6]"
        end
        self.config.method = value
    elseif config == 'kmax' then
        value = tonumber(value)
        if not value then
            return false, "value not a number"
        end
        self.encode_option.kmax = value
        self.default_kmax = false
    elseif config == 'kmin' then
        value = tonumber(value)
        if not value then
            return false, "value not a number"
        end
        self.encode_option.kmin = value
        self.default_kmin = false
    elseif config == "filter_strength" then
        value = tonumber(value)
        if not value then
            return false, "value not a number"
        elseif value < 0 or value > 100 then
            return false, "value must be in range [0..100]"
        end
        self.config.filter_strength = value
    elseif config == 'metadata' then
        if value == 'all' then
            self.config.stored_icc = true
            self.config.sotred_xmp = true
        elseif value == 'none' then
            self.config.stored_icc = false
            self.config.stored_xmp = false
        elseif value == 'icc' then
            self.config.stored_icc = true
            self.config.stored_xmp = false
        elseif value == 'xmp' then
            self.config.stored_icc = false
            self.config.stored_xmp = true
        else
            return false, "value must be in range [all,none,icc,xmp]"
        end
    else
        return false, "could not recognize config item:" .. config
    end

    if self.default_kmax then
        if self.config.lossless == 1 then
            self.config.kmax = 17
        else
            self.config.kmax = 5
        end
    end
    if self.default_kmin then
        if self.config.lossless == 1 then
            self.config.kmin = 9
        else
            self.config.kmin = 3
        end
    end

    return true
end

_M.set_format = function(self, format)
    format = lower(format)
    if format == 'webp' then
        self.anim = webp:new(self.image)
        local ok, err = self.anim:convert(self.config)
        if not ok then
            ngx.log(ngx.ERR, err)
        end
        return true
    end
    return false, "format only support webp"
end

_M.get_blob = function(self)
    return self.anim:blob()
end

return _M