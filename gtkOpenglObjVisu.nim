
# without gio
# with Load Obj from menu

from os import getAppFilename
echo "*********************** appFileName: ", getAppFilename(), " **************************"

import commonTypes
from objLoaderMtl as OBJL import nil
from objLoaderMtl import `$`

const fileNameExecuted = "gtkOpenglObjVisu01"

import times
import strformat
import strutils
from os import getEnv, joinPath, fileExists, getCurrentDir, relativePath, extractFilename
from osproc import execCmd

import glm
#import nimgl/glfw
from opengl as GL import nil
#const EGL_FLOAT = 0x1406.GLenum # cGL_FLOAT
import nimgl/opengl # import nil # glInit

import gintro/[gtk, glib, gobject, gdk] #, gio
#import gintro/[gtk, gobject, gio]
#echo "FileChooserAction.open :", FileChooserAction.open

#import nimgl/opengl
from nimgl/opengl as NGL import nil
echo "GL_FRONT          :", GL_FRONT.int32.tohex
echo "GL_FRONT_AND_BACK :", GL_FRONT_AND_BACK.int32.tohex
echo "GL_BACK           :", GL_BACK.int32.tohex

if os.getEnv("CI") != "":
  quit()

proc toRGB(vec: Vec3f): Vec3f =
  return vec3f(vec.x / 255, vec.y / 255, vec.z / 255)

#-------------------------------------------------------
# glPolygonMode(face, mode)
let PolygFaces = [GL_FRONT_AND_BACK, GL_FRONT, GL_BACK]
let CullFaces  = [GL_BACK, GL_FRONT, GL_FRONT_AND_BACK]
let PolyModes  = [GL_FILL, GL_LINE, GL_POINT]

type
    PolygonDisplay = object
        faceIdx : int
        modeIdx : int

proc setOgl(pd: PolygonDisplay) =
    let glFace: GL_ENUM = PolygFaces[pd.faceIdx]
    let glMode: GL_ENUM = PolyModes[pd.modeIdx]
    #echo "glPolygonMode: ", (glFace.uint32.toHex, glMode.uint32.toHex)
    glPolygonMode(glFace, glMode)

proc nextFace(pd: var PolygonDisplay) =
    pd.faceIdx = (pd.faceIdx + 1).mod(PolygFaces.len)
    pd.setOgl()

proc nextMode(pd: var PolygonDisplay) =
    pd.modeIdx = (pd.modeIdx + 1).mod(PolyModes.len)
    pd.setOgl()

proc reset(pd: var PolygonDisplay) =
    pd.faceIdx = 0
    pd.modeIdx = 0
    pd.setOgl()

#-------------------------------------------------------

type
    Obj3D = ref object of RootObj
        name    : string
        parent  : Obj3D
        children: seq[Obj3D]

        pos0, pos : Vec3f # ie glm.Vec3[float32]
        speed  : Vec3f
        xyzRot0, xyzRot : Vec3f
        dxyzRot : Vec3f

        hidden  : bool
        idx0*, idx1*: OBJL.Idx
        mtlName : string
        mtl     : OBJL.MaterialTmpl
        mapKaId, mapKdId, mapKsId : GLuint # texure_id

proc `$`(self: Obj3D): string =
    result = fmt"{self.name:16}: speed:{self.speed}, pos:{self.pos}, dxyzRot:{self.dxyzRot}, xyzRot:{self.xyzRot}"

proc toStr(self: Obj3D): string =
    result = fmt"Obj3D {self}:"
    result &= NL & fmt"    mtl: {self.mtl}"
    for child in self.children:
        result &= NL & fmt"    child: {SQ & child.name & SQ:21}: hidden:{child.hidden}, mtlName:'{child.mtlName}', mapKaId:{child.mapKaId}, mapKdId:{child.mapKdId}, mapKsId:{child.mapKsId}"

proc accLin(self: Obj3D; idx: int; dv: float32) =
    if dv == 0.0f: # stop vitess
        self.speed[idx] = 0.0f
    else:
        self.speed[idx] += dv.float32

proc accRot(self: Obj3D; idx: int; dv: float32) =
    #echo self.name & ".accRot"
    if dv == 0.0f: # stop vitess
        self.dxyzRot[idx] = 0.0f
    else:
        self.dxyzRot[idx] += dv.float32

proc move(self: Obj3D; dt: float32) =
    for i in 0 ..< 3:
        self.pos[i] += self.speed[i] * dt

    for i in 0 ..< 3:
        self.xyzRot[i] += self.dxyzRot[i] * dt

proc stopMove(self: Obj3D; idx=0; dv=0.0f) =
    #echo "stopMove"
    self.speed.reset
    self.dxyzRot.reset

proc resetPos(self: Obj3D; idx=0; dv=0.0f) =
    self.stopMove()
    #echo "resetPos"
    self.pos    = self.pos0
    self.xyzRot = self.xyzRot0

# -------------------------------------------------------------------------------------------

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

proc load_image(fileName, mode="MIN_FILTER", debug=1): GLuint = # return texture_id "MIN_FILTER"
    let nameExt = fileName.rsplit('.', 1)
    var (name, ext) = (nameExt[0], nameExt[1])
    if ext.toLowerAscii in jpgExt : ext = "png"
    let file_png = name & '.' & ext
    if not fileExists(file_png):
        echo file_png & " not exists !!!!!!"
        var file_jpg : string
        var goodExt = ""
        for ext in jpgExt:
            file_jpg = name & '.' & ext
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
    #[
    try:
        width, height, image = im.size[0], im.size[1], im.tobytes("raw", "RGBA", 0, -1)
    except : # gwb: remove SystemError
        width, height, image = im.size[0], im.size[1], im.tobytes("raw", "RGBX", 0, -1)
    ]#

    if debug >= 1: echo fmt"loaded texture: {im.width:d}, {im.height:4}, len(image):{im.data.len:7}"

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

# ----------------------------------------------------------------------------------------------------

proc statusShader(shader: uint32) =
    var status: int32
    glGetShaderiv(shader, GL_COMPILE_STATUS, status.addr);
    if status != GL_TRUE.ord:
        echo "statusShader ERROR !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        if true:
            var
                log_length: int32
                message = newSeq[char](1024)
            glGetShaderInfoLog(shader, 1024, log_length.addr, message[0].addr);
            var msg : string
            for c in message:
                if c.ord == 0: break
                msg.add(c)
            #let msg: string = cast[string](message)
            echo msg
        assert false

type Shaders = tuple[vert, frag: uint32]

var isNormalBuf, is_uv_buf: bool

# --------------------------------------------------------------------
proc createShader(shadersName:string; typ:string; shads: var Shaders) =
    #echo fmt"createShader('{shadersName}', {typ})"
    var shadId: uint32
    if   typ == "vertex":
        shads.vert = glCreateShader(GL_VERTEX_SHADER)
        shadId = shads.vert
    elif typ == "fragmt":
        shads.frag = glCreateShader(GL_FRAGMENT_SHADER)
        shadId = shads.frag
    else:
        echo fmt"ERROR: unknown shader typ: '{typ}'"
        assert false

    let fileName: string = fmt"{shadersName}.{typ}"
    # echo fmt"createShader from '{fileName}':"
    let text:string = readFile(fileName)
    #echo "source: " & NL, text

    var cText: cstring = text.cstring

    #glShaderSource(shader: GLuint; count: GLsizei; string: cstringArray; length: ptr GLint) # /opengl-1.2.6
    #glShaderSource(shadId, 1.GLsizei, cast[cstringArray](cText.addr), nil) # /opengl-1.2.6
    glShaderSource(shadId, 1, cText.addr, nil)# glShaderSource(shadId, 1, cText.addr, nil) for nimgl-1.1.4
    glCompileShader(shadId)
    statusShader(shadId)

#---------------------------------------------------
proc createShadersName(shadersName:string): Shaders =
    var shads: Shaders

    createShader(shadersName, "vertex", shads)
    createShader(shadersName, "fragmt", shads)

    return shads

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

from objModels as OBJM import nil
from objModels import `$`

let t0 : float = epochTime()

import tables # also exist gtk.Table: Table !

# this declaration dont fit !:
# type KeyCode2NameActionTable = tables.Table[system.int, tuple[name: string, fct: proc (self: Obj3D, idx: int, i: int){.gcsafe, locks: 0.}, obj: Obj3D, idx: int, d:int]]

# use an example to define define the correct type of the table
var dummyObj: Obj3D
var exTable = { 1234 : ("Dummy", accRot, "dummyObj", 3, -0.5f)}.toTable
type KeyCode2NameActionTable* = type(exTable)

#got tuple (int, tuple of (string, proc (self: Obj3D, idx: int, i: int){.gcsafe, locks: 0.}, Obj3D, int, float32))>
#but tuple (int, tuple of (string, proc (self: Obj3D, idx: int, dv: float32){.gcsafe, locks: 0.}, Obj3D, int, float32))'
type
    ParamsObj* = object of RootObj
        modelFileName   : string
        debugTextureFile: string
        useTextures     : bool
        cullFace        : int
        time, dt        : float
        delta           : float32
        frames*         : int
        polygDisp*      : PolygonDisplay
        rgbaMask        : Vec4f
        camer*          : Obj3D
        obj3Ds*         : seq[Obj3D]
        obj3dSel        : Obj3D
        textureNameToIds: OrderedTable[string, GLuint]
        KeyCod2NamActionObj* : KeyCode2NameActionTable

    Params = ref ParamsObj

type
    Mesh = tuple[vbo, vao, ebo, norm, uvt: uint32]

type
    BufferParams = ref object of RootObj
        name    : string
        bufId   : uint32 # or GLuint
        nFloats : GLint  # ak int32
        dtyp    : GLenum # ex EGL_FLOAT, GL_HALF_FLOAT
        attrLoc : GLuint # uint32 #

type
    ObjsOpengl* = ref object of RootObj
        progId: NGL.GLuint
        matTplLib    : OBJL.MatTmplLib
        rangMtlNames : OBJL.RangMtls
        bufs         : OBJL.IndexedBufs
        nVert, nNorm, nUvts, nTriangles : int
        uMVP, uV, uM : NGL.GLint
        uColor : NGL.GLint
        light_id, rgbaMask_id, useTextures_id : NGL.GLint
        textureLoc0 : NGL.GLint
        mesh        : Mesh
        transpose   : GLboolean
        #frames      : int
        bg_color    : Vec3f
        lightPos    : Vec3f
        bufferAttrIdList: seq[BufferParams]
        #grps_range     : seq[OBJL.GrpRange]

proc `$`*(self: Params): string =
    result = fmt"Params: frames: {self.frames}"
    result &= ", model: "
    result &= self.modelFileName

type
    MyGLArea* = ref object of GLArea
        width, height : int
        #parms: Params
        objGL: ObjsOpengl

proc newMyGLArea*(parms: Params): MyGLArea =
    result = newGLArea(MyGLArea)
    #result.parms = parms
    result.objGL = new ObjsOpengl

let parms = new Params # Global var !!!!!!!!!!!!

#------------------------------------------------------

proc prepareBufs( self: MyGLArea; modelFile: string,
                  check=false, normalize=true, swapVertYZ=false, swapNormYZ=false, flipU=false, flipV=false,
                  ignoreTexture=false, debugTextureFile="";
                  grpsToInclude: seq[string]= @[], grpsToExclude: seq[string]= @[];
                  debug=1, dbgDecountReload=0
                ): Obj3D =

    let objGL = self.objGL
    #if debug >= 1: echo fmt"prepareBufs: {modelFile.extractFilename}, swapVertYZ:{swapVertYZ}, swapNormYZ:{swapNormYZ}, flipU:{flipU}, flipV:{flipV}"

    let objLoader = OBJL.newObjLoader()
    let parseOk = OBJL.parseObjFile(objLoader, modelFile, debug=debug, dbgDecountReload=dbgDecountReload)
    #[
                    loadModel(objLoader, modelFile,
                            ignoreTexture=ignoreTexture,
                            debugTextureFile=debugTextureFile,
                            normalize=normalize, swapVertYZ=swapVertYZ, swapNormYZ=swapNormYZ,
                            flipU=flipU, flipV=flipV, check=check,
                            debug=debug, dbgDecountReload=dbgDecountReload
                            )
    ]#
    if not parseOk : return

    result = new Obj3D
    result.name = objLoader.objFile
    objGL.matTplLib = objLoader.matTplLib
    #[
    type
        IndexedBufs* = object
            rgMtls* : RangMtls
            ver*, nor*, uvt* : seq[float32]
            idx* : seq[uint32]
    ]#
    let normOk = OBJL.normalizeModel( objLoader,
                                      #debugTextureFile="",
                                      normalize=normalize,
                                      #swapVertYZ=swapVertYZ, swapNormYZ=swapNormYZ,
                                      swapVertYZ=true, swapNormYZ=true,
                                      flipU=flipU, flipV=flipV, check=check,
                                      debug=1)
    if not normOk : return

    objGL.bufs = OBJL.loadOglBufs(objLoader, debug=1)

    echo fmt"Loaded model: {result.name}, include:{grpsToInclude}, exclude:{grpsToExclude}"


proc on_createContext(self: MyGLArea): uInt64 =
    echo "MyGLArea.on_createContext"

proc on_unrealize(self: MyGLArea) =
    echo "MyGLArea.on_unrealize"

proc bufSiz[T](buf: seq[T]): int     {.inline.} = result = buf.len * T.sizeof
proc bufAdr[T](buf: seq[T]): pointer {.inline.} = result = buf[0].unsafeaddr

proc textureIdOfFile(texFile: string): GLuint =
    if parms.textureNameToIds.contains(texFile): result = parms.textureNameToIds[texFile]
    else:
        result = load_image(texFile, debug=2)
        if result >= 1: parms.useTextures = true # at least one texture loaded
        parms.textureNameToIds[texFile] = result

proc addModel(self: MyGLArea; modelFile:string) = # model: OBJM.Model) =
    echo "addModel: ", modelFile.extractFilename # model.name

    const vectorDim: GLint = 3 # 2D or 3D

    let objGL = self.objGL

    let normalize  = true  # model.normalize
    let swapVertYZ = false # model.swapYZ
    let swapNormYZ = false # model.swapYZ
    let obj3d = self.prepareBufs(modelFile, flipV=true, normalize=normalize, swapVertYZ=swapVertYZ, swapNormYZ=swapNormYZ, debugTextureFile=parms.debugTextureFile, debug=2)
    if obj3d == nil:
        echo "!!!!!!!!!!!!!!!!!!!!!! Cannot load model: ", modelFile
        return

    echo fmt"***************** loading textures if not yet for {obj3d.name}: ", $objGL.bufs.rgMtls
    for rgMtl in objGL.bufs.rgMtls:
        let child = new Obj3d
        child.name    = rgMtl.name
        child.idx0    = rgMtl.idx0
        child.idx1    = rgMtl.idx1
        child.mtlName = rgMtl.mtl
        obj3d.children.add(child)

        parms.obj3dSel = obj3d # select the last created

        if objGL.matTplLib != nil and objGL.matTplLib.mtls.contains(child.mtlName) :
            child.mtl = objGL.matTplLib.mtls[child.mtlName]
            echo "child.mtl: ", $child.mtl
            if child.mtl.mapKa.len > 0: child.mapKaId = textureIdOfFile(child.mtl.mapKa)
            if child.mtl.mapKd.len > 0: child.mapKdId = textureIdOfFile(child.mtl.mapKd)
            if child.mtl.mapKs.len > 0: child.mapKsId = textureIdOfFile(child.mtl.mapKs)

    parms.obj3Ds.add(obj3d)

    echo ">>>>>>>>>>> obj3Ds: "
    for o in parms.obj3Ds:
        echo o.toStr

    if false:
        echo fmt"objGL.bufs.idx: len:{objGL.bufs.idx.len:6}, sizeof:{objGL.bufs.idx.sizeof}"
        echo fmt"objGL.bufs.ver: len:{objGL.bufs.ver.len:6}, sizeof:{objGL.bufs.ver.sizeof}"
        echo fmt"objGL.bufs.nor: len:{objGL.bufs.nor.len:6}, sizeof:{objGL.bufs.nor.sizeof}"
        echo fmt"objGL.bufs.uvt: len:{objGL.bufs.uvt.len:6}, sizeof:{objGL.bufs.uvt.sizeof}"

    #objGL.grps_range = rangMtlNames.rangs

    assert objGL.bufs.ver.len.mod(3) == 0 # 3D
    assert objGL.bufs.nor.len.mod(3) == 0 # 3D
    assert objGL.bufs.uvt.len.mod(2) == 0 # 2D

    objGL.nVert = objGL.bufs.ver.len.div(3)
    objGL.nNorm = objGL.bufs.nor.len.div(3)
    objGL.nUvts = objGL.bufs.uvt.len.div(2)

    assert objGL.bufs.idx.len.mod(3) == 0 # Triangles

    objGL.nTriangles = objGL.bufs.idx.len.div(3)

    if true:
        echo "nVert   : ", objGL.nVert
        echo "nNorm   : ", objGL.nNorm
        echo "nUvts   : ", objGL.nUvts
        echo "nTriangl: ", objGL.nTriangles

    isNormalBuf = objGL.nNorm == objGL.nVert
    is_uv_buf   = objGL.nUvts == objGL.nVert
    echo "normals exists: ", isNormalBuf
    echo "uvts    exists: ", is_uv_buf

    objGL.textureLoc0 = glGetUniformLocation(objGL.progId, "texture0")
    echo "Got handle for uniform texture0: ", objGL.textureLoc0

    glBindVertexArray(objGL.mesh.vao)
    glBindBuffer(GL_ARRAY_BUFFER, 0)

    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, objGL.mesh.ebo)
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, objGL.bufs.idx.bufSiz, objGL.bufs.idx.bufAdr, GL_STATIC_DRAW)

    glBindBuffer(GL_ARRAY_BUFFER, objGL.mesh.vbo)
    glBufferData(GL_ARRAY_BUFFER, objGL.bufs.ver.bufSiz, objGL.bufs.ver.bufAdr, GL_STATIC_DRAW)

    if isNormalBuf:
        glBindBuffer(GL_ARRAY_BUFFER, objGL.mesh.norm)
        glBufferData(GL_ARRAY_BUFFER, objGL.bufs.nor.bufSiz, objGL.bufs.nor.bufAdr, GL_STATIC_DRAW)

    if is_uv_buf:
        glBindBuffer(GL_ARRAY_BUFFER, objGL.mesh.uvt)
        glBufferData(GL_ARRAY_BUFFER, objGL.bufs.uvt.bufSiz, objGL.bufs.uvt.bufAdr, GL_STATIC_DRAW)

    # 1rst attribute buffer : vertices
    glEnableVertexAttribArray(0)
    glVertexAttribPointer(0'u32, vectorDim, EGL_FLOAT, false, float32.sizeof * vectorDim, nil)
    glBindBuffer(GL_ARRAY_BUFFER, 0)


proc on_realize(self: MyGLArea) =
    echo "MyGLArea.on_realize"

    let objGL = self.objGL
    #let parms = parms

    self.makeCurrent()
    let err : ptr glib.Error = self.error
    if err != nil: echo "error after makeCurrent: ", err.repr

    var context = self.getContext()
    echo "0: context: ", context.repr

    var major, minor: int
    context.getVersion(major, minor)
    echo "context.getVersion: ", major, "; ", minor

    if true:
        assert NGL.glInit() # GWB: glInit(): glVersion.isNil -> false
        context = self.getContext()
        echo "1: context: ", context.repr

    if true:
        #echo "hasDepthBuffer: ", self.hasDepthBuffer
        self.hasDepthBuffer = true
        #echo "hasDepthBuffer: ", self.hasDepthBuffer

    objGL.progId = NGL.glCreateProgram()
    #echo "objGL.progId: ", objGL.progId

    NGL.glEnable(NGL.GL_DEPTH_TEST) # Enable depth test
    NGL.glDepthFunc(NGL.GL_LESS)    # Accept fragment if it closer to the camera than the former one
    #NGL.glEnable(NGL.GL_CULL_FACE)  # Cull triangles which normal is not towards the camera

    var shadName: string = "shader"

    let shaders: Shaders = createShadersName(shadName)

    NGL.glAttachShader(objGL.progId, shaders.vert)
    NGL.glAttachShader(objGL.progId, shaders.frag)

    NGL.glLinkProgram(objGL.progId)

    # proc glGenBuffers(n: GLsizei, buffers: ptr GLuint)
    glGenVertexArrays(1, objGL.mesh.vao.addr)

    # create OpenGl buffer and fill it with objGL.bufs.idx (index of vertices)
    glGenBuffers(1, objGL.mesh.ebo.addr)

    # create OpenGl buffer and fill it with objGL.bufs.ver
    glGenBuffers(1, objGL.mesh.vbo.addr)

    # create OpenGl buffer and fill it with objGL.bufs.nor
    glGenBuffers(1, objGL.mesh.norm.addr)

    # create OpenGl buffer and fill it with objGL.bufs.uvt
    glGenBuffers(1, objGL.mesh.uvt.addr)

    objGL.lightPos = vec3(1.0'f32, 4.0'f32, 3.0'f32)
    parms.rgbaMask = vec4(1.0'f32 ,1.0'f32 ,1.0'f32, 1.0'f32)

    glUseProgram(objGL.progId)

    objGL.uMVP = glGetUniformLocation(objGL.progId, "MVP")
    objGL.uV   = glGetUniformLocation(objGL.progId, "V")
    objGL.uM   = glGetUniformLocation(objGL.progId, "M")
    #echo fmt"Got handle for uniforms: MVP: {objGL.uMVP}, V: {objGL.uV}, M: {objGL.uM}"

    objGL.light_id = glGetUniformLocation(objGL.progId, "LightPosition_worldspace");
    #echo "Got handle for uniform LightPosition : ", objGL.light_id

    objGL.rgbaMask_id = glGetUniformLocation(objGL.progId, "rgbaMask")
    #echo "Got handle for uniform 'rgbaMask'  : ", objGL.rgbaMask_id

    objGL.useTextures_id = glGetUniformLocation(objGL.progId, "useTextures")
    #echo "Got handle for uniform 'useTextures': ", useTextures_id

    #let toto3_id = glGetUniformLocation(objGL.progId, "toto3")
    #echo "Got handle for uniform 'toto3' :", toto3_id

    var
        log_length: int32
        message = newSeq[char](1024)
        pLinked: int32
    glGetProgramiv(objGL.progId, GL_LINK_STATUS, pLinked.addr);
    if pLinked != GL_TRUE.ord:
        glGetProgramInfoLog(objGL.progId, 1024, log_length.addr, message[0].addr);
        echo message

    # declaration usefull for UniformColorMode
    objGL.uColor = glGetUniformLocation(objGL.progId, "uColor")
    var uniformColor = vec3f(0.2f, 0.9f, 0.2f) # .toRgb()

    #for i, f in parms.model.bgRGB.pairs: objGL.bg_color[i] = f.float32 # a remplacer
    objGL.bg_color = vec3f(0.2f, 0.2f, 0.5f)

    #var p, v, m, vp, mvp : Mat4f # ie glm.Mat4[float32]

    objGL.bufferAttrIdList = @[]

    objGL.bufferAttrIdList.add(BufferParams(name: "vsPosModSpace" , bufId: objGL.mesh.vbo , nFloats: 3, dtyp: EGL_FLOAT, attrLoc: 0))
    #if isNormalBuf:
    objGL.bufferAttrIdList.add(BufferParams(name: "vsNormModSpace", bufId: objGL.mesh.norm, nFloats: 3, dtyp: EGL_FLOAT, attrLoc: 0))
    #if is_uv_buf:
    objGL.bufferAttrIdList.add(BufferParams(name: "vsTextureUV"   , bufId: objGL.mesh.uvt , nFloats: 2, dtyp: EGL_FLOAT, attrLoc: 0))

    for bufParams in objGL.bufferAttrIdList: # find location number from shaders
        let resp:GLint = glGetAttribLocation(objGL.progId, bufParams.name)
        if resp < 0:
            echo fmt"problem, attrib: '{bufParams.name}' do not exist !"
            assert false
        else:
            bufParams.attrLoc = resp.GLuint
            #echo fmt"location {bufParams.attrLoc.int}: '{bufParams.name}'"


proc on_resize(self: MyGLArea; width: int, height: int) = # ; user_data: pointer ?????
    echo "on_resize : (w, h): ", (width, height)
    self.width  = width
    self.height = height


proc addObj(self: MyGLArea; fileName:string) =
    echo fmt"--------------------- MyGLArea.addObj: {fileName} ----------------------"
    #let pwd = joinPath(os.getCurrentDir(), "Obj3D")
    parms.modelFileName = fileName # .relativePath(pwd) # make a request


proc on_render(self: MyGLArea; context: gdk.GLContext): bool = # ; user_data: pointer ?????

    if parms.modelFileName.len > 0: # addModelReq:
        self.addModel(parms.modelFileName) # parms.model)
        parms.modelFileName = "" # reset the request
        parms.frames = 0 # to display the first rendering

    let debugMat4 = false
    let dbgFirstFrame = parms.frames == 0
    if dbgFirstFrame: echo "----------- render first frame ---------------"

    result = true # TRUE to stop other handlers from being invoked for the event. FALSE to propagate the event further

    let objGL = self.objGL
    let camer = parms.camer

    if false:
        echo "on_render: ", type(self)
        var major, minor: int
        context.getVersion(major, minor)
        echo "context.getVersion: ", major, "; ", minor

    context.makeCurrent()

    glCullFace(CullFaces[parms.cullFace])  # Cull triangles which normal is not towards the camera

    parms.polygDisp.setOgl() # met a jour glPolygonMode qui est ecrase par Gtk

    let viewport_x     :NGL.GLint = 0
    let viewport_y     :NGL.GLint = 0
    let viewport_width :NGL.GLint = NGL.GLint(self.width)  # getAllocatedWidth( self))
    let viewport_height:NGL.GLint = NGL.GLint(self.height) # getAllocatedHeight(self)) #.float

    let
        w_h_ratio = viewport_width.float / viewport_height.float
        fov       = radians(45.0f) / sqrt(w_h_ratio).float32
        zNear     =    0.1f
        zFar      =    20.0f
        #w_h_ratio = winWidth.float / winHeigh.float

    var p = perspective(
        fov,       # vertical Field Of View: the amount of "zoom". Think "camera lens". Usually between 90° (extra wide) and 30° (zoom)
        w_h_ratio, # Aspect Ratio. Depends on the size of your window. Notice that 4/3 == 800/600 == 1280/960, sounds familiar ?
        zNear,     # Near clipping plane. Keep as big as possible, or you'll get precision issues.
        zFar       # Far clipping plane. Keep as little as possible.
        )
    if debugMat4: echo "Proj :\n", p

    # recule la camera et tourne la camera autour du sujet
    var v = mat4(1.0f) # identity
    v.translateInpl(vec3(-camer.pos[0], -camer.pos[1], -camer.pos[2]));
    #v.rotateInpl(yRotCam, vec3(-1.0f, 0.0f, 0.0f)) # axe horizontal suivant x
    #v.rotateInpl(xRotCam, vec3( 0.0f, 1.0f, 0.0f)) # axe vertical y
    if debugMat4: echo "View :\n", v

    var vp  = p * v

    if dbgFirstFrame and debugMat4:
        echo "p:\n" , p
        echo "v:\n" , v
        echo "vp:\n", vp

    glClearColor(objGL.bg_color.r, objGL.bg_color.g, objGL.bg_color.b, 1.0f)
    glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)

    glUseProgram(objGL.progId)
    let count1 = GLsizei(1)
    # Send transformation matrix MVP, M, V to the currently bound shader as uniform
    #glUniformMatrix4fv(location: GLint, count: GLsizei, transpose: GLboolean, value: ptr GLfloat): void
    glUniformMatrix4fv(objGL.uV, count1, objGL.transpose, v.caddr) # View

    glUniform3f(objGL.light_id, objGL.lightPos.x, objGL.lightPos.y, objGL.lightPos.z)

    glUniform4f(objGL.rgbaMask_id, parms.rgbaMask[0], parms.rgbaMask[1], parms.rgbaMask[2], parms.rgbaMask[3])

    # Binding of 3 GL_ARRAY_BUFFER : indexs vertexs normals, uvTextures
    for bp in objGL.bufferAttrIdList:
        #if parms.frames < 2: print("type(buf):", type(buf))
        glEnableVertexAttribArray(bp.attrLoc)
        glBindBuffer(GL_ARRAY_BUFFER, bp.bufId)
        glVertexAttribPointer(
            bp.attrLoc,          # layout(location = id) in the shader.
            bp.nFloats,          # len(vertex_data)
            bp.dtyp,             # type
            false,               # normalized?
            0,                   # stride
            nil                  # array buffer offset (c_type == void*)
            )
        if dbgFirstFrame : echo fmt"binded {bp.name:16}, loc:{bp.attrLoc}, nFloats:{bp.nFloats}"

    # echo "glDrawElements"
    # draw each object with its own texture
    type cTypeIdx = GLuint # ou GLushort pour diminuer la taille des indexs
    var m, mvp : Mat4f
    var msg: string
    if dbgFirstFrame: echo fmt"render: {parms.obj3Ds.len} obj3d"
    for obj3d in parms.obj3Ds:
        if dbgFirstFrame: echo "obj3d: ", obj3d.name
        m = mat4(1.0f) # identity
        m.translateInpl(obj3d.pos) # vec3(sujet.pos[0], sujet.pos[1], sujet.pos[2]));
        m.rotateInpl(obj3d.xyzRot[0], vec3( 1.0f, 0.0f, 0.0f)) # axe  vers la camera
        m.rotateInpl(obj3d.xyzRot[1], vec3( 0.0f, 1.0f, 0.0f)) # axe  vers la camera
        m.rotateInpl(obj3d.xyzRot[2], vec3( 0.0f, 0.0f, 1.0f)) # axe horizontal vers la camera
        glUniformMatrix4fv(objGL.uM, count1, objGL.transpose, m.caddr) # Model

        mvp = vp * m
        glUniformMatrix4fv(objGL.uMVP, count1, objGL.transpose, mvp.caddr) # MVP

        if dbgFirstFrame and debugMat4:
            echo "Modele:\n", m
            echo "MVP:\n", mvp

        for child in obj3d.children:
            if child.hidden : continue
            let count : GLsizei = child.idx1.GLsizei - child.idx0.GLsizei
            let offsetInt : uint32 = child.idx0.uint32 * cTypeIdx.sizeof.uint32 #.(OBJL.Idx) # in bytes
            let offset : ptr uint8 = cast[ptr uint8](offsetInt)
            if dbgFirstFrame: msg = fmt"    child:{SQ & child.name & SQ:24}; offset: 0x{offsetInt.toHex}, count:{count:7}, "

            let useTex = parms.useTextures and objGL.bufs.uvt.len != 0 and child.mapKdId > 0
            glUniform1i(objGL.useTextures_id, useTex.GLint) # bool to GLint
            if useTex:
                glActiveTexture((GL_TEXTURE0.int + child.mapKdId.int-1).GLenum)
                glUniform1i(objGL.textureLoc0, (child.mapKdId-1).GLint)
                glBindTexture(GL_TEXTURE_2D, child.mapKdId.GLuint) # textureIds[idxTex])
                if dbgFirstFrame: msg &= fmt"glBindTexture: {child.mapKdId:2}"
            else:
                # active couleur diffuse
                if dbgFirstFrame: msg &= fmt"parms.useTextures: {parms.useTextures}, uvt.len: {objGL.bufs.uvt.len} and mapKdId: {child.mapKdId} => no useTexture"
            if dbgFirstFrame: echo msg

            glBindVertexArray(objGL.mesh.vao)
            # glDrawElements(mode: GLenum, count: GLsizei, `type`: GLenum, indices: pointer)
            glDrawElements(
                GL_TRIANGLES,    # mode: GLenum
                count.GLsizei,   # bufs.idx.len.cint, # count: GLsizei
                GL_UNSIGNED_INT, # type GL_UNSIGNED_SHORT or GL_UNSIGNED_INT
                offset           # bufs.idx[gr.idx0].addr # indices: pointer element array buffer offset # nil
                )

    parms.frames += 1

proc animationStep(parms: Params) {.cdecl.} = #x: var float, y: var float, z: var float) =
    parms.camer.move(1.0)
    for obj3d in parms.obj3Ds:
        obj3d.move(1.0)

proc invalidateCb(self: MyGLArea): bool =
    animationStep(parms)

    parms.time += parms.dt
    self.queueRender() # queueDraw
    return SOURCE_CONTINUE

proc `$`(event: gdk.EventKey): string =
    var keyCode : uint16
    assert event.keycode(keyCode) # get the code and check return is ok
    result = fmt"keycode: {keyCode:3}, 0x" & keyCode.int32.tohex(4)

    result &= "; "

    var keyVal : int
    assert event.keyval(keyVal) # get the code and check return is ok
    var c = '?'
    if 0 < keyVal and keyVal < 127:
        c = chr(keyVal)
        result &= fmt"keyval: 0x{keyVal.tohex(2)}, {keyVal:3}, char:'{c}'"
    elif keyVal < 0x10000:
        result &= "keyval <  0x10000 : 0x" & keyVal.tohex(4)
    else:
        result &= "keyval >= 0x10000 : 0x" & keyVal.tohex(16)


proc actionKey(event: gdk.EventKey, parms: Params, release=false) =
    var keyCode : uint16
    assert event.keycode(keyCode) # get the code and check return is ok

    var keyVal : int
    assert event.keyval(keyVal) # get the code and check return is ok

    var keyChar = chr(0)
    if 0 < keyVal and keyVal < 127:
        if 'A'.ord < keyVal and keyVal < 'Z'.ord:
            keyVal += ('a'.ord - 'A'.ord).int
        keyChar = chr(keyVal)

    if keyCode == 65 :  # "KeySpace" -> Show mesh
        parms.camer.stopMove()
        parms.obj3dSel.stopMove()
        parms.polygDisp.faceIdx = 0 # GL_FRONT_AND_BACK
        parms.polygDisp.modeIdx = if not release: 1 else: 0 # GL_LINE else: GL_FILL
        return

    if release: return # "drop key release"

    if  10.uint16 <= keyCode and keyCode <= 19: # select subObj
        let i = keyCode.int - 10
        if parms.obj3dSel != nil and i < parms.obj3dSel.children.len:
            let child = parms.obj3dSel.children[i]
            child.hidden = not child.hidden
            echo fmt"child: {child.name}:" & (if child.hidden: "hidden" else: "shown")
        else: echo fmt"keyCode:{keyCode:3}: i:{i} >= {parms.obj3Ds.len} => no selection !"


    elif keyCode.int in parms.KeyCod2NamActionObj:
        let (name, fct, objStr, idx, d) = parms.KeyCod2NamActionObj[keyCode.int]
        if idx < 0 : echo "nothing to do"
        else:
            #echo fmt"found : {keyCode:3}: '{name}', idx:{idx}, d:{d:.3f}, objStr:{objStr}" #, fct:{fct} " # , type(obj) #, {obj}, fct.repr
            var obj: Obj3D
            if   objStr == "camer": obj = parms.camer
            elif objStr == "obj3d": obj = parms.obj3dSel
            if obj != nil: fct(obj, idx, d)
            #echo fmt"frame {parms.frames}: {obj}"
    elif keyChar == chr(0) :
        #echo "no action for keyCode: ", keyCode
        return
    elif keyChar == 'c' : parms.cullFace = (parms.cullFace + 1).mod(3)
    elif keyChar == 't' : parms.useTextures = not parms.useTextures
    elif keyChar == 'm' : parms.polygDisp.nextMode()
    elif keyChar == 'f' : parms.polygDisp.nextFace()
    elif keyChar == 'r' :
        echo "resetAll"
        parms.camer.resetPos()
        parms.polygDisp.reset()
        for obj3d in parms.obj3Ds:
            obj3d.resetPos()
    else:
        echo fmt"no action for keyCode: {keyCode} ie keyChar: '{keyChar}'"
        return
    var s = fmt"frame{parms.frames:5}: useTextures: {parms.useTextures}, cullFace: {parms.cullFace}, posCamera:{parms.camer.pos}"
    if parms.obj3dSel != nil : s &= fmt"; obj3dSel: {parms.obj3dSel.name}, xyzRot:{parms.obj3dSel.xyzRot}"
    echo s

var keyCodePressed : uint16
proc onKeyPress(self: gtk.Window; event: gdk.EventKey): bool =
    #echo "press  : ", $event
    var keyCode : uint16
    assert event.keycode(keyCode) # get the code and check return is ok
    if keyCode != keyCodePressed: # to supress repeatition
        keyCodePressed = keyCode
        actionKey(event, parms, release=false)
    result = true

#proc onKeyRelease(self: ApplicationWindow; event: gdk.EventKey): bool =
proc onKeyRelease(self: gtk.Window; event: gdk.EventKey): bool =
    #echo "release: ", $event
    keyCodePressed = 0
    actionKey(event, parms, release=true)
    result = true

#-------------------------------------------
#proc newFileChooserDialog*(title: string = ""; parent: Window = nil; action: FileChooserAction): FileChooserDialog =
#[
type ResponseType* = enum
    help = -11
    apply = -10
    no = -9
    yes = -8
    close = -7
    cancel = -6
    ok = -5
    deleteEvent = -4
    accept = -3
    reject = -2
    none = -1
]#
proc chooseFileObj(): string =
  let chooser = newFileChooserDialog("select an obj file", action=FileChooserAction.open)
  discard chooser.addButton("_Open"   , ResponseType.accept.ord)
  discard chooser.addButton("_Cancel" , ResponseType.cancel.ord)
  let ff = newFileFilter()
  ff.setName("file.obj only")
  ff.addPattern("*.obj")
  chooser.addFilter(ff)

  let res = chooser.run()
  if res == ResponseType.accept.ord:
      result = chooser.getFilename()
      #echo "accept open: ", result # fileName
  chooser.destroy


type
  LabTxt = tuple
    l : Label
    t : string

  SbIdTxt = tuple
    sb : Statusbar
    id : int
    t  : string

proc onClick(b: Button, p:LabTxt) =
  let (l, txt) = p
  echo "click " & txt
  l.label = txt & " has been clicked"


proc onClick(b: Button, p:SbIdTxt) =
  let (sb, id, txt) = p
  echo "click " & txt
  discard sb.push(id, txt & " has been clicked")


proc onAddObj(mi: MenuItem, glArea: MyGLArea) =
  let fileName = chooseFileObj()
  # echo "onAddObj: fileName: ", fileName
  if fileName.len > 0: glArea.addObj(fileName)


proc onWindowDestroy(w: gtk.Window, txt= "") =
  echo "onWindowDestroy " & txt
  mainQuit()


proc onQuitMenuActivate(mi: MenuItem, txt= "") =
  echo "onQuitMenuActivate " & txt
  mainQuit()


proc main(debugTextureFile="") =
    #var parms = new Params
    parms.dt    = 0.050
    parms.delta = 0.004f
    parms.debugTextureFile = debugTextureFile

    gtk.init()
    let window = newWindow()
    window.title = "GTK3 OpenGL Nim"
    window.defaultSize = (400, 300)

    window.position = WindowPosition.center

    let vbox = newbox(Orientation.vertical, spacing=0)
    window.add(vbox)

    let menubar = newMenubar()
    vBox.add(menubar)

    let addObjMi = newMenuItemWithLabel("Add obj")

    block: # items of menubar
      let fileMi   = newMenuItemWithLabel("File")
      menubar.append(fileMi)

      let fileMenu = gtk.newMenu()
      fileMi.setSubmenu(fileMenu)
      block: # item of fileMenu
        fileMenu.append(addObjMi)

        let imprMi    = newMenuItemWithLabel("Import")
        fileMenu.append(imprMi)

        let imprMenu  = gtk.newMenu()
        imprMi.setSubmenu(imprMenu) # imprMenu.submenu = imprMi #
        block: # # item of imprMenu
          let feedMi    = newMenuItemWithLabel("Import news feed...")
          imprMenu.append(feedMi)
          let bookMi    = newMenuItemWithLabel("Import bookmarks...")
          imprMenu.append(bookMi)
          let mailMi    = newMenuItemWithLabel("Import mail...")
          imprMenu.append(mailMi)


        let sep    = newSeparatorMenuItem()
        fileMenu.append(sep)

        let quitMi = newMenuItemWithLabel("Quit")
        quitMi.connect("activate", onQuitMenuActivate, "aurevoir")
        fileMenu.append(quitMi)

      let RenderMi = newMenuItemWithLabel("Render")
      menubar.append(RenderMi)

      let WindowMi = newMenuItemWithLabel("Window")
      menubar.append(WindowMi)

      let HelpMi   = newMenuItemWithLabel("Help")
      menubar.append(HelpMi)

    let glArea = newMyGLArea(parms) # newGLArea()
    #vBox.add(glArea)
    vBox.packStart(glArea, expand=true, fill=true, padding=0)

    addObjMi.connect("activate", onAddObj, glArea)

    #echo "type(glArea): ", type(glArea)
    #glArea.setAutoRender()
    glArea.setSizeRequest(256, 256)

    #glArea.connect("create-context", on_createContext)
    glArea.connect("realize"  , on_realize)
    glArea.connect("unrealize", on_unrealize)
    glArea.connect("resize"   , on_resize)
    glArea.connect("render"   , on_render)

    #parms.obj3ds = Obj3D(); parms.sujet.name = "subject"
    #parms.sujet.resetPos()

    parms.camer = Obj3D(); parms.camer.name = "camera"
    parms.camer.pos0 = glm.vec3f(0.0, 1.0, 4.0)
    parms.camer.resetPos()

    let obj3dSel = parms.obj3dSel
    let camer = parms.camer
    let dv    = parms.delta
    parms.KeyCod2NamActionObj = {
        #[
        0 : ("KbdNul"   , nil, nil, -1, 0),

        9 : ("KeyEscape", , 1),
       65 : ("KeySpace" , 0, 1),
       ]#
       79 : ("NumPad7"  , accRot  , "obj3d", 2, -dv),
       80 : ("NumPad8"  , accRot  , "obj3d", 2,  0f),
       81 : ("NumPad9"  , accRot  , "obj3d", 2,  dv),

       83 : ("NumPad4"  , accRot  , "obj3d", 1, -dv),
       84 : ("NumPad5"  , accRot  , "obj3d", 1, -0f),
       85 : ("NumPad6"  , accRot  , "obj3d", 1,  dv),

       87 : ("NumPad1"  , accRot  , "obj3d", 0, -dv),
       88 : ("NumPad2"  , accRot  , "obj3d", 0,  0f),
       89 : ("NumPad3"  , accRot  , "obj3d", 0,  dv),

       90 : ("NumPad0"  , stopMove, "obj3d", 0,  0f),
       91 : ("NumPadSup", resetPos, "obj3d", 0,  0f),

      113 : ("KeyLeft"  , accLin  , "camer", 0, -dv),
      114 : ("KeyRigth" , accLin  , "camer", 0,  dv),
      116 : ("KeyDown"  , accLin  , "camer", 1, -dv),
      111 : ("KeyUp"    , accLin  , "camer", 1,  dv),
      112 : ("PageUp"   , accLin  , "camer", 2, -dv),
      117 : ("PageDown" , accLin  , "camer", 2,  dv),
      118 : ("insert"   , resetPos, "camer", 0,  0f),
      119 : ("Supress"  , stopMove, "camer", 0,  0f),
      }.toTable

    echo "use arrow and pageup/down for camera move and keypad keys for model rotation"
    echo "use 'r' for reset positions, 't' for texture on-off 'm' for display mode, space-bar for stop movments"
    echo "use keys 1 to 9, 0 to show/hide parts of object"

    let statusBar = newStatusbar()
    vBox.add(statusBar)

    let mainStatusBarId = statusBar.getContextId("main")
    echo "mainStatusBarId: ", mainStatusBarId
    let firstStatusbarMsgId = statusBar.push(mainStatusBarId, "First message of main")
    echo "firstStatusbarMsgId: ", firstStatusbarMsgId

    window.connect("destroy" , onWindowDestroy, "goodbye")

    window.connect("key_press_event"  , onKeyPress  )
    window.connect("key_release_event", onKeyRelease)

    window.showAll

    discard timeoutAdd((parms.dt*1000.0).uint32, invalidateCb, glArea)

    gtk.main()

#===========================================================================

when isMainModule:
    from os import getAppFilename, extractFilename, commandLineParams
    let appName = extractFilename(getAppFilename())
    echo fmt"Begin {appName}"

    main()

    echo fmt"End {appName}"

