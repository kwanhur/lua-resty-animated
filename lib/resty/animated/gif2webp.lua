-- Copyright (C) by Kwanhur Huang


local modulename = "animatedGif2Webp"
local _M = {}
_M._NAME = modulename
local mt = { __index = _M }

local setmetatable = setmetatable
local tonumber = tonumber
local tostring = tostring

local webp = require('resty.animated.webp')
local util = require('resty.animated.util')
local base = require('resty.animated.base')

local NETSCAPE = 'NETSCAPE2.0'
local ANIMEXTS = 'ANIMEXTS1.0'
local XMPDATA = 'XMP DataXMP'
local ICCRGB = 'ICCRGBG1012'

_M.new = function(self, image)
    self.image = image
    self.anim = webp:new()
    self.enc = nil -- = self.anim:encoder()

    self.frame = self.anim:picture()
    self.curr_canvas = self.anim:picture()
    self.prev_canvas = self.anim:picture()
    self.webp_data = self.anim:webp_data()
    self.icc_data = self.anim:webp_data()
    self.xmp_data = self.anim:webp_data()
    self.webp_config = nil

    self.frame_number = 0
    self.frame_timestamp = 0
    self.frame_duration = 0

    self.loop_compatibility = false
    self.loop_count = 0
    self.stored_loop_count = false
    self.stored_xmp = false
    self.stored_icc = false

    self.mux = nil

    return setmetatable(self, mt)
end

_M.config = function(self, config)
    local webp_config = self.anim:config()
    if not self.anim:config_init(webp_config) then
        return nil, "init failed"
    end

    webp_config.lossless = config.lossless
    webp_config.quality = config.quality
    webp_config.method = config.method
    webp_config.filter_strength = config.filter_strength

    return webp_config
end

_M.enc_options = function(self, config)
    local enc_options = self.anim:encoder_options()
    if not self.anim:encoder_options_init(enc_options) then
        return nil, "encoder init failed"
    end

    enc_options.allow_mixed = config.allow_mixed
    enc_options.minimize_size = config.minimize_size
    enc_options.kmin = config.kmin
    enc_options.kmax = config.kmax

    return enc_options
end

_M.process_image_desc = function(self, enc_options)
    local ok, err = self.image:get_image_desc()
    if not ok then
        return false, err
    end

    local gif_rect = self.anim:gif_rect()
    local image_desc = self.image:image()
    if self.frame_number == 0 then
        ngx.log(ngx.NOTICE, "canvas screen:", self.image:width(), " x ", self.image:height())
        -- Fix some broken GIF global headers that report
        -- 0 x 0 screen dimension.
        if self.image:width() == 0 or self.image:height() == 0 then
            image_desc.Left = 0
            image_desc.Top = 0
            self.image:set_width(image_desc.Width)
            self.image:set_height(image_desc.Height)
            if self.image:width() <= 0 or self.image:height() <= 0 then
                return false, "width or height not greater than zero"
            end
            ngx.log(ngx.NOTIE, "fixed canvas screen dimension to ", self.image:width(), ' x ', self.image:height())
        end
        self.frame.width = self.image:width()
        self.frame.height = self.image:height()
        self.frame.use_argb = 1
        if not self.anim:picture_alloc(self.frame) then
            return false, "picture alloc fail"
        end

        self.anim:gif_clear_pic()
        self.anim:picture_copy(self.frame, self.curr_canvas)
        self.anim:picture_copy(self.frame, self.prev_canvas)

        -- background color
        self.anim:gif_get_background_color(self.image:color_map(), self.image:background_color(), enc_options.anim_params.bgcolor)
        self.enc = self.anim:encoder_new(self.curr_canvas.width, self.curr_canvas.height, enc_options)
        if not self.enc then
            return false, "could not create encoder object"
        end
    end

    --Some even more broken GIF can have sub-rect with zero width/height.
    if image_desc.Width == 0 or image_desc.Height == 0 then
        image_desc.Width = self.image:width()
        image_desc.Height = self.image:height()
    end

    if not self.anim:gif_read_frame(self.image.gif, gif_rect, self.frame) then
        return false, "gif read frame fail"
    end
    -- Blend frame rectangle with previous canvas to compose full canvas.
    -- Note that 'curr_canvas' is same as 'prev_canvas' at this point.
    self.anim:gif_blend_frames(self.frame, gif_rect, self.curr_canvas)

    if not self.anim:encoder_add(self.enc, self.curr_canvas, self.frame_timestamp, self.webp_config) then
        return false, "error while adding frame:" .. tostring(self.frame_number) .. " err:" .. self.anim:encoder_error(self.enc)
    else
        self.frame_number = self.frame_number + 1
    end

    -- Update canvases.
    self.anim:gif_dispose_frame(self.anim.GIF_DISPOSE_NONE, gif_rect, self.prev_canvas, self.curr_canvas)
    self.anim:gif_copy_pixels(self.curr_canvas, self.prev_canvas)

    -- Update timestamp (for next frame).
    self.frame_timestamp = self.frame_timestamp + self.frame_duration
    self.frame_duration = 0

    return true
end

_M.process_extension = function(self)
    local ext_code, extension, ext_data = self.image:get_extension()
    if ext_data == nil then
        return true
    end

    if not ext_code then
        return false, "gif get extension code was nil" -- ext_data continue to process next record type
    end

    extension = util.trim(extension)
    ngx.log(ngx.NOTICE, 'ext code:', ext_code, ' extension:', extension)

    -- 254
    if ext_code == self.image.EXTENSION_CODE.COMMENT_EXT_FUNC_CODE then
        -- do nothing for now

        -- 249
    elseif ext_code == self.image.EXTENSION_CODE.GRAPHICS_EXT_FUNC_CODE then
        if not self.anim:gif_read_graphics_extension(ext_data, self.frame_duration, self.anim.GIF_DISPOSE_NONE) then
            return false, "gif read graphics extension fail"
        end
        -- 1
    elseif ext_code == self.image.EXTENSION_CODE.PLAINTEXT_EXT_FUNC_CODE then
        -- do nothing

        -- 255
    elseif ext_code == self.image.EXTENSION_CODE.APPLICATION_EXT_FUNC_CODE then
        ngx.log(ngx.NOTICE, 'extension:', extension)
        if extension == NETSCAPE or extension == ANIMEXTS then
            local loop_count = base.get_int_ptr()
            if not self.anim:gif_read_loop_count(self.image.gif, ext_data, loop_count) then
                return false, "read loop count err:" .. self.image:error_str()
            end
            self.loop_count = loop_count
            ngx.log(ngx.NOTICE, "loop count:", self.loop_count)
            --
            --            local err
            --            extension, err = self.image:get_extension_next(ext_data)
            --            if not extension then
            --                return false, err
            --            else
            --                --[[ convert into loop count
            --                  if (*buf == NULL) {
            --                    return 0;  // Loop count sub-block missing.
            --                  }
            --                  if ((*buf)[0] < 3 || (*buf)[1] != 1) {
            --                    return 0;   // wrong size/marker
            --                  }
            --                  *loop_count = (*buf)[2] | ((*buf)[3] << 8);
            --                --]]
            --                ngx.log(ngx.NOTICE, 'next ext code:', ext_code, ' data:', extension)
            --                extension = util.trim(extension)
            --            end
            if self.loop_compatibility then
                self.stored_loop_count = self.loop_count ~= 0
            else
                self.stored_loop_count = true
            end
        else
            -- An extension containing metadata.
            -- We only store the first encountered chunk of each type, and
            -- only if requested by the user.
            local is_xmp = self.stored_xmp and extension == XMPDATA
            local is_icc = self.stored_icc and extension == ICCRGB
            if is_xmp or is_icc then
                local ret
                if is_xmp then
                    ret = self.anim:gif_read_metadata(self.image.gif, ext_data, self.xmp_data)
                else
                    ret = self.anim:gif_read_metadata(self.image.gif, ext_data, self.icc_data)
                end
                ngx.log(ngx.NOTICE, 'xmp:', is_xmp, ' icc:', is_icc, ' read metadata:', ret)
                if not ret then
                    return false, "gif read metadata nil"
                end
            end
        end
    end

    local err
    while ext_data ~= nil do
        extension, err = self.image:get_extension_next(ext_data)
        ngx.log(ngx.NOTICE, 'while ext data:', extension)
        extension = util.trim(extension)
        if extension ~= nil then
            return false, "while loop extension at the end err"
        else
            ngx.log(ngx.NOTICE, 'while ext code:', ext_code, ' data:', extension)
        end
    end

    return true
end

_M.process_mux = function(self)
    if not (self.stored_loop_count or self.stored_icc or self.stored_xmp) then
        return false, "stored loop count or xmp or icc was false"
    end

    self.mux = self.anim:mux_create(self.webp_data)
    if not self.mux then
        return false, "could not re-mux to add loop count/metadata"
    end

    self.webp_data = nil
    if not self.stored_loop_count then
        return false, "stored loop count was false"
    end

    local new_params = self.anim:webp_anim_params()
    local ok, err = self.anim:mux_get_animation_params(self.mux, new_params)
    if not ok then
        return false, "could not fetch loop count,err:" .. err
    end

    new_params.loop_count = self.loop_count
    local ok, err = self.anim:mux_set_animation_params(self.mux, new_params)
    if not ok then
        return false, "could not update loop count,err:" .. err
    end

    if self.stored_icc then
        local ok, err = self.anim:mux_set_chunk(self.mux, "ICCP", self.icc_data)
        if not ok then
            ngx.log(ngx.ERR, "could not set ICC chunk,err:", err)
        end
        ngx.log(ngx.NOTICE, "ICC size:", tonumber(self.icc_data.size))
    elseif self.stored_xmp then
        local ok, err = self.anim:mux_set_chunk(self.mux, "XMP ", self.xmp_data)
        if not ok then
            ngx.log(ngx.ERR, "could not set XMP chunk,err:", err)
        end
        ngx.log(ngx.NOTICE, "XMP size:", tonumber(self.xmp_data.size))
    else
        return false, "store icc or xmp fail"
    end

    local ok, err = self.anim:mux_assemble(self.mux, self.webp_data)
    if not ok then
        return false, "could not assemble when re-muxing to add loop count/metadata,err:" .. err
    else
        ngx.log(ngx.NOTICE, "blob size:", tonumber(self.webp_data.size))
        return true
    end
end

_M.convert = function(self, config)
    local webp_config, err = self:config(config)
    if not webp_config then
        ngx.log(ngx.ERR, err)
        return
    end
    if not self.anim:config_validate(webp_config) then
        ngx.log(ngx.ERR, "invalid configuration")
        return
    end


    local enc_options, err = self:enc_options(config)
    if not enc_options then
        ngx.log(ngx.ERR, err)
        return
    end

    if not self.anim:picture_init(self.frame) or not self.anim:picture_init(self.curr_canvas) or not self.anim:picture_init(self.prev_canvas) then
        ngx.log(ngx.ERR, "version mismatch")
        return
    end

    self.webp_config = webp_config
    self.stored_xmp, self.stored_icc = config.stored_xmp, config.stored_icc
    self.loop_compatibility = config.loop_compatibility

    local while_loop = 0

    local record_type
    while true do
        while_loop = while_loop + 1
        record_type, err = self.image:record_type()
        if not record_type then
            return false, err
        end
        ngx.log(ngx.NOTICE, 'record type:', record_type)

        if self.image.IMAGE_DESC_RECORD_TYPE == record_type then
            local ok, err = self:process_image_desc()
            if not ok then
                return false, err
            end
        elseif self.image.EXTENSION_RECORD_TYPE == record_type then
            local ok, err = self:process_extension()
            if not ok then
                return false, err
            end
        elseif self.image.TERMINATE_RECORD_TYPE == record_type then
            return false, "terminate record"
        else
            return false, "could not recoginze record type " .. tostring(record_type)
        end

        ngx.log(ngx.NOTICE, 'while loop:', while_loop)
    end

    if not self.enc then
        return false, "encoder object not initlize"
    end

    if not self.anim:webp_anim_encoder_add(self.enc, self.frame_timestamp) then
        ngx.log(ngx.ERR, "error flushing WebP muxer err:", self.anim:webp_anim_encoder_error(self.enc))
    end
    if not self.anim:webp_anim_encoder_assemble(self.enc, self.webp_data) then
        return false, "encoder assemble err:" .. webp:webp_anim_encoder_error(self.enc)
    end

    if not self.loop_compatibility then
        if self.stored_loop_count then
            if self.frame_number > 1 then
                self.stored_loop_count = true
                self.loop_count = 1
            end
        elseif self.loop_count > 0 then
            self.loop_count = self.loop_count + 1
        end
    end
    if self.loop_count == 0 then
        self.stored_loop_count = false
    end

    return self:process_mux()
end

_M.blob = function(self)
    return self.webp_data.blob
end

return _M