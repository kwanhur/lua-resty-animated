# lua-resty-animated
Lua implement animated image converter with FFI, support gif2webp.

This library inspires from [gif2webp](https://github.com/webmproject/libwebp/blob/master/examples/gif2webp.c) and
[giflib](https://github.com/leafo/giflib).

Table of Contents
=================

* [Name](#name)
* [Status](#status)
* [Synopsis](#synopsis)
* [Methods](#methods)
    * [new](#new)
    * [load](#load)
    * [set_config](#set-config)
    * [set_format](#set-format)
    * [get_blob](#get-blob)
* [Installation](#installation)
* [Dependency](#dependency)
* [Authors](#authors)
* [Copyright and License](#copyright-and-license)

Status
======

This library is under early development.

Synopsis
========
```lua
    lua_package_path "/path/to/lua-resty-animated/lib/?.lua;;";

    server {
        location /t {
            content_by_lua '
              local ani = require('resty.animated.init')
              local animator = ani:new('/path/to/test.gif')
              local ok, err = animator:load()
              if not ok then
                  ngx.log(ngx.ERR, err)
                  return
              end
              ok, err = animator:set_format('webp')
              if not ok then
                  ngx.log(ngx.ERR, err)
                  return
              end
              local blob = animator:get_blob()
              ngx.print(blob)
            ';
        }
    }
```

Methods
=======

[Back to TOC](#table-of-contents)

new
---
`syntax: animator = ani:new('/path/to/test.gif')`

Create a new animated object.

[Back to TOC](#table-of-contents)

load
----
`syntax: ok, err = animator:load()`

Load the specified origin animated image

[Back to TOC](#table-of-contents)

set_config
----------
`syntax: ok, err = aniamtor:set_config(item, value)`

Set converter related configuration,like quality, metadata etc.

[Back to TOC](#table-of-contents)

set_format
----------
`syntax: ok, err = animator:set_format('webp')`

Set converter target animated image format

[Back to TOC](#table-of-contents)

get_blob
------
`syntax: blob = animator:get_blob()`

Fetch the animated image blob content

[Back to TOC](#table-of-contents)

Installation
============

You can install it with [opm](https://github.com/openresty/opm#readme).
Just like that: opm install kwanhur/lua-resty-animated

[Back to TOC](#table-of-contents)

Dependency
============

* [giflib](https://sourceforge.net/projects/giflib)
* [libwebp](https://github.com/webmproject/libwebp)

[Back to TOC](#table-of-contents)

Authors
=======

kwanhur <huang_hua2012@163.com>, VIPS Inc.

[Back to TOC](#table-of-contents)

Copyright and License
=====================

This module is licensed under the BSD 2-Clause License .

Copyright (C) 2018, by kwanhur <huang_hua2012@163.com>, VIPS Inc.

All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

[Back to TOC](#table-of-contents)