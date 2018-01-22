-- Copyright (C) by Kwanhur Huang


local modulename = "animatedUtil"
local _M = {}
_M._NAME = modulename

_M.trim = function(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end
return _M