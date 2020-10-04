
from strformat import fmt
from strutils import toLowerAscii, toHex
from os import splitFile, joinPath, addFileExt, fileExists
from osproc import execCmd

import nimgl/opengl

import nimPNG
# let png = loadPNG32("Kangaroo_texture.png")
# is equivalent to:
# let png = loadPNG("image.png", LCT_RGBA, 8)
# will produce rgba pixels:
# echo fmt"widthxheight: {png.width}x{png.height}"
# let nPix = png.width * png.height
#echo fmt"nPix * 4 : {nPix*4}, len: {png.data.len}"

proc bind_texture(texture_id: GLuint; mode="DEFAULT"; debug=1) =
    #[ Bind texture_id using several different modes
        Notes:
            Without mipmapping the texture is incomplete
            and requires additional constraints on OpenGL
            to properly render said texture.

            Use 'MIN_FILTER" or 'MAX_LEVEL' to render
            a generic texture with a single resolution
        Ref:
            [] - http://www.opengl.org/wiki/Common_Mistakes#Creating_a_complete_texture
            [] - http://gregs-blog.com/2008/01/17/opengl-texture-filter-parameters-explained/
        TODO:
            - Rename modes to something useful
    ]#
    if debug >= 1: echo fmt"bind_texture id:{texture_id}: mode: {mode}"
    if mode == "DEFAULT":
        glBindTexture(GL_TEXTURE_2D, texture_id)
        glPixelStorei(GL_UNPACK_ALIGNMENT,1)
    elif mode == "MIN_FILTER":
        glBindTexture(GL_TEXTURE_2D, texture_id)
        glPixelStorei(GL_UNPACK_ALIGNMENT,1)
        #glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S    , 1.0) # GL_CLAMP)
        #glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T    , 1.0) # GL_CLAMP)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST.GLint) #G L_LINEAR)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST.GLint) # GL_LINEAR)
    elif mode == "MAX_LEVEL":
        glBindTexture(GL_TEXTURE_2D, texture_id)
        glPixelStorei(GL_UNPACK_ALIGNMENT,1)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_BASE_LEVEL, 0)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, 0)
    else:
        glBindTexture(GL_TEXTURE_2D, texture_id)
        glPixelStorei(GL_UNPACK_ALIGNMENT,1)

    glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE.GLint) # to improve transparency
    glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE.GLint) # to improve transparency

    # Generate mipmaps?  Doesn't seem to work
    #if 0: glGenerateMipmap(GL_TEXTURE_2D)

const jpgExt = ["jpg", "jpeg"]
# os.changeFileExt(filename, ext: string)

proc load_image*(fileName, mode="MIN_FILTER", debug=1): GLuint = # return texture_id "MIN_FILTER"
    #let nameExt = fileName.rsplit('.', 1)
    #var (name, ext) = (nameExt[0], nameExt[1])
    var (dir, name, ext) = splitFile(fileName)
    name = joinPath(dir, name)
    if ext.toLowerAscii in jpgExt : ext = "png"
    let file_png = name.addFileExt(ext) # name & '.' & ext
    if not fileExists(file_png):
        echo file_png & " not exists !!!!!!"
        var file_jpg : string
        var goodExt = ""
        for ext in jpgExt:
            file_jpg = name.addFileExt(ext) # name & '.' & ext
            if fileExists(file_jpg):
                goodExt = ext
                break
            else:
                if debug >= 2: echo fmt"{file_jpg} not exist"
        if goodExt.len == 0:
            echo fmt"{name} not exists with extension {jpgExt}, !!!!!!!!!!!!!!"
        else:
            let cmd = fmt"convert {file_jpg} {file_png}"
            echo fmt"executing {cmd} ..."
            let errC = execCmd(cmd)
            echo fmt"execCmd({cmd}) -> {errC}"
    if debug >= 2: echo fmt"load texture: {file_png}"
    let im = loadPNG32(file_png)
    echo "im.width: ", im.width
    #[
    try:
        width, height, image = im.size[0], im.size[1], im.tobytes("raw", "RGBA", 0, -1)
    except : # gwb: remove SystemError
        width, height, image = im.size[0], im.size[1], im.tobytes("raw", "RGBX", 0, -1)
    ]#

    if debug >= 1: echo fmt"loaded texture: {im.width:4}, {im.height:4}, len(image):{im.data.len:7}"

    var texture_id: GLuint
    glGenTextures(1, texture_id.addr) # proc glGenTextures(n: GLsizei, textures: ptr GLuint)
    #echo "glGenTextures: texture_id: ", texture_id

    # To use OpenGL 4.2 ARB_texture_storage to automatically generate a single mipmap layer
    # uncomment the 3 lines below.  Note that this should replaced glTexImage2D below.
    #bind_texture(texture_id,'DEFAULT')
    #glTexStorage2D(GL_TEXTURE_2D, 1, GL_RGBA8, width, height);
    #glTexSubImage2D(GL_TEXTURE_2D,0,0,0,width,height,GL_RGBA,GL_UNSIGNED_BYTE,image)

    # "Bind" the newly created texture : all future texture functions will modify this texture
    bind_texture(texture_id, mode=mode, debug=debug-1)
    # glTexImage2D(target: GLenum, level: GLint, internalformat: GLint, width: GLsizei, height: GLsizei, border: GLint, format: GLenum, `type`: GLenum, pixels: pointer)

    let width  = im.width
    let height = im.height
    let size   = im.data.len
    let nPixs  = width * height
    #echo fmt"Image: width:{width}, height:{height}, nPixs:{nPixs}, im.data.len:{size}"
    #echo fmt"im.data[0]: {im.data[0].int},  {im.data[1].int},  {im.data[2].int},  {im.data[3].int}"

    if false: # make a square hole in the midle of texture using transparency
        let
            x0 = width.div(2)
            y0 = height.div(2)
            d = 50
        var i0, i1 : int
        for y in y0-d ..< y0+d:
            i0 = y * (width * 4)
            for x in x0-d ..< x0+d:
                i1 = i0 + x*4
                im.data[i1+0] = 255.char
                im.data[i1+1] = 255.char
                im.data[i1+2] = 0.char
                im.data[i1+3] = 0.char
    if false: # check texture
        let
          dx = 50
          dy = 25
        let xM = width.div(dx)
        let yM = height.div(dy)
        var s : string
        var i0, i1 : int
        #for c in 0 ..< 4:
            #echo "rgba: ", c
        for y in 0 ..< yM:
            i0 = (y*dy) * (width * 4) # + c
            s = fmt"{y*dy:6}: "
            for x in 0 ..< xM:
                i1 = i0 + x* (dx * 4)
                s &= $im.data[i1].ord.toHex(2) & " " & $im.data[i1+1].ord.toHex(2) & " " & $im.data[i1+2].ord.toHex(2) & " " & $im.data[i1+3].ord.toHex(2) & ", "
            echo s

    if false:
        let yC = height.div(2)
        let xC = width.div(2)
        var r2 = 256
        var dx, dy, dx2, dy2: int
        var i = 0
        for y in 0 ..< height:
            dy = y - yC
            dy2 = dy * dy
            for x in 0 ..< width:
                dx = x - xC
                dx2 = dx * dx
                if dy2 + dx2 < r2 :
                    im.data[i]   = 0.char
                    im.data[i+1] = 0.char
                    im.data[i+2] = 0.char
                i += 4

    var ptrPix: pointer = im.data[0].addr
    #(target: GLenum, level: GLint, internalformat: GLint, width: GLsizei, height: GLsizei, border: GLint, format: GLenum, type: GLenum, pixels: pointer)
    glTexImage2D(
           GL_TEXTURE_2D,   # target: GLenum
           0,               # level: GLint
           GL_RGBA.GLint,   # internalformat: GLint 3
           width.GLsizei,   # width : GLsizei
           height.GLsizei,  # height: GLsizei
           0,               # border: GLint
           GL_RGBA,         # format: GLenum # GL_RGBA !!!!!GL_RGB8UI?
           GL_UNSIGNED_BYTE,# `type`: GLenum
           ptrPix           # pixels: pointer ?
       )
    return texture_id


