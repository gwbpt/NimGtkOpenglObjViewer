
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
        no      : int     # start at one
        id      : string
        name    : string
        parent  : Obj3D
        children: seq[Obj3D]
        hidden  : bool
        mtlName : string

        pos0, pos : Vec3f # ie glm.Vec3[float32]
        speed  : Vec3f
        xyzRot0, xyzRot : Vec3f
        dxyzRot : Vec3f

        accLin, accRot : Vec3f

        idx0*, idx1*: OBJL.Idx
        mtl     : OBJL.MaterialTmpl
        mapKaId, mapKdId, mapKsId : GLuint # texure_id

#[
func `$`(self: Obj3D): string =
    result = fmt"{self.name:16}: speed:{self.speed}, pos:{self.pos}, dxyzRot:{self.dxyzRot}, xyzRot:{self.xyzRot}"

func toStr(self: Obj3D): string =
    result = fmt"Obj3D {self}:"
    result &= NL & fmt"    mtl: {self.mtl}"
    for child in self.children:
        result &= NL & fmt"    child: {SQ & child.name & SQ:21}: hidden:{child.hidden}, mtlName:'{child.mtlName}', mapKaId:{child.mapKaId}, mapKdId:{child.mapKdId}, mapKsId:{child.mapKsId}"
]#

const Obj3dNil: Obj3D = nil

proc newObj3D(parent=Obj3dNil; name="root", hidden=false, pos0=zeroVec3f): Obj3D =
    result = new Obj3D
    result.name   = name
    result.hidden = hidden
    result.pos0   = pos0
    result.pos    = pos0
    result.accLin = glm.vec3f(0.005f, 0.005f, 0.005f)
    result.accRot = glm.vec3f(0.002f, 0.002f, 0.002f)
    if parent == nil:
      result.id = "0"
    else:
      result.parent = parent
      result.id = parent.id & '_' & $ parent.children.len
      parent.children.add(result)

proc `$`(self: Obj3D): string =
    if self == nil: result = "Obj3dNil"
    else:
      result = fmt"id:{self.id:9}: name:{self.name:16}, hidden:{self.hidden}" #: speed:{self.speed}, pos:{self.pos}, dxyzRot:{self.dxyzRot}, xyzRot:{self.xyzRot}"
      for child in self.children:
          result &= NL & "    child: " & $child

proc toStr(self: Obj3D): string =
    result = fmt"Obj3D {self}:"
    #result &= NL & fmt"    mtl: {self.mtl}"
    for child in self.children:
        result &= NL & fmt"    child: {SQ & child.name & SQ:21}: "
        #, mtlName:'{child.mtlName}', mapKaId:{child.mapKaId}, mapKdId:{child.mapKdId}, mapKsId:{child.mapKsId}"

echo "Obj3dNil: ", Obj3dNil.type, ": ", Obj3dNil

#-----------------------------------------------------

type
    Axe = enum
        noAxe = -1
        X     =  0
        Y     =  1
        Z     =  2
        XYZ   =  3

    Cmd = enum
        LESS = -1
        STOP =  0
        MORE =  1
        RST  =  2

var axe = Y
echo fmt"axe: {axe}, ", $axe

proc accLinCmd(self: Obj3D; axe: Axe; cmd: Cmd) =
    echo self.name & ".accLinCmd(" & $axe & ", " & $cmd & ")"
    let idx = axe.int
    if cmd == RST: # reset position
        self.pos[idx] = self.pos0[idx]
    elif cmd == STOP: # stop move
        self.speed[idx] = 0.0f
    else:
        echo fmt"0: speed[{idx}]: {self.speed[idx]:8.3f}"
        self.speed[idx] += self.accLin[idx] * cmd.float32
        echo fmt"1: speed[{idx}]: {self.speed[idx]:8.3f}"

proc accRotCmd(self: Obj3D; axe: Axe; cmd: Cmd) =
    echo self.name & ".accRotCmd(" & $axe & ", " & $cmd & ")"
    let idx = axe.int
    if cmd == RST: # reset position
        self.xyzRot[idx] = 0.0f
    elif cmd == STOP: # stop rotation
        self.dxyzRot[idx] = 0.0f
    else:
        echo fmt"0: dxyzRot[{idx}]: {self.dxyzRot[idx]:8.3f}"
        self.dxyzRot[idx] += self.accRot[idx] * cmd.float32
        echo fmt"1: dxyzRot[idx]: {self.dxyzRot[idx]:8.3f}"

proc move(self: Obj3D; dt: float32) =
    for i in 0 ..< 3:
        self.pos[i] += self.speed[i] * dt

    for i in 0 ..< 3:
        self.xyzRot[i] += self.dxyzRot[i] * dt

proc stopMove(self: Obj3D; axe=XYZ; dummy=STOP) =
    #echo "stopMove"
    self.speed.reset
    self.dxyzRot.reset

proc resetPos(self: Obj3D; axe=XYZ; dummy=RST) =
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
var exTable = { 1234 : ("Dummy", accRotCmd, "dummyObj", X, STOP)}.toTable
type KeyCode2NameActionTable* = type(exTable)

#got tuple (int, tuple of (string, proc (self: Obj3D, idx: int, i: int){.gcsafe, locks: 0.}, Obj3D, int, float32))>
#but tuple (int, tuple of (string, proc (self: Obj3D, idx: int, dv: float32){.gcsafe, locks: 0.}, Obj3D, int, float32))'

const nObj3dCtrls = 2

type
    ParamsObj* = object of RootObj
        allObj3Ds*      : seq[Obj3D] # flat list
        obj3Ds*         : seq[Obj3D]
        tStore          : TreeStore
        tView           : TreeView
        buttons         : seq[Button]
        valLabels       : seq[Label]
        modelFileName   : string
        debugTextureFile: string
        useTextures     : bool
        cullFace        : int
        time, dt        : float
        delta           : float32
        frames*         : int
        polygDisp*      : PolygonDisplay
        rgbaMask        : Vec4f
        lightPos*       : Vec3f
        lightPower*     : float32
        camer*          : Obj3D
        objToControl    : array[nObj3dCtrls, Obj3D]
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
        progId           : NGL.GLuint
        matTplLib        : OBJL.MatTmplLib
        rangMtlNames     : OBJL.RangMtls
        textureNameToIds : OrderedTable[string, GLuint]
        bufs             : OBJL.IndexedBufs
        nVert, nNorm, nUvts, nTriangles : int
        uMVP, uV, uM     : NGL.GLint
        uColor           : NGL.GLint
        lightPos_id, lightPower_id, rgbaMask_id, useTextures_id : NGL.GLint
        textureLoc0      : NGL.GLint
        mesh             : Mesh
        transpose        : GLboolean
        #frames          : int
        bg_color         : Vec3f
        bufferAttrIdList : seq[BufferParams]
        #grps_range      : seq[OBJL.GrpRange]

func `$`*(self: Params): string =
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


type # for pack parameters for callbacks of connect
  LabTxt = tuple
    l : Label
    t : string

  SbIdTxt = tuple
    sb : Statusbar
    id : int
    t  : string
  #[
  TreeStoreColumn = tuple
    st  : TreeStore
    col : int

  TreeViewColumn = tuple
    tv  : TreeView
    col : int
  ]#
  ParmsColumn = tuple
    parms : Params
    col   : int

  Obj3RotAxeCmd = tuple
    obj3d : Obj3D
    rot   : bool
    axe   : Axe
    cmd   : Cmd

func getObj3d(parms: Params; no: int): Obj3d =
    if no >= 1 and parms.allObj3Ds.len >= no:
        result = parms.allObj3Ds[no-1]

type
    AxeControl = ref object of RootObj
        # logic
        parent        : Obj3dControl
        axe           : Axe
        rot           : bool
        # GUI
        hbox          : Box
        buttons       : array[4, Button]
        nameLabel     : Label
        speedValLab   : Label
        posValEntry   : Entry
        posUnitLab    : Label

    Obj3dControl = ref object of RootObj
        id            : int
        name          : string # actual display
        pos, xyzRot   : Vec3f # actual display
        vBox          : Box
        linAxeCtrl    : seq[AxeControl]
        rotAxeCtrl    : seq[AxeControl]

#-------------------------------------------------------------------------

type
    GuiDatas =  ref object of RootObj
        parms       : Params
        glArea      : MyGLArea
        obj3dCtrls  : array[nObj3dCtrls, Obj3dControl]

#-------------------------------------------------------------------------
#let params  = new Params # Global var !!!!!!!!!!!! TO REMOVE

#let guiDat = new GuiDatas # Global var !!!!!!!!!!!!
#guiDat.parms = params



#-------------------------------------------------------------------------

#[ extract from gintro/gobject.nim
proc g_type_invalid_get_type*(): GType = g_type_from_name("(null)")
proc g_type_none_get_type*(): GType = g_type_from_name("void")
proc g_interface_get_type*(): GType = g_type_from_name("GInterface")
proc g_char_get_type*(): GType = g_type_from_name("gchar")
proc g_uchar_get_type*(): GType = g_type_from_name("guchar")
proc g_boolean_get_type*(): GType = g_type_from_name("gboolean")
proc g_int_get_type*(): GType = g_type_from_name("gint")
proc g_uint_get_type*(): GType = g_type_from_name("guint")
proc g_long_get_type*(): GType = g_type_from_name("glong")
proc g_ulong_get_type*(): GType = g_type_from_name("gulong")
proc g_int64_get_type*(): GType = g_type_from_name("gint64")
proc g_uint64_get_type*(): GType = g_type_from_name("guint64")
proc g_enum_get_type*(): GType = g_type_from_name("GEnum")
proc g_flags_get_type*(): GType = g_type_from_name("GFlags")
proc g_float_get_type*(): GType = g_type_from_name("gfloat")
proc g_double_get_type*(): GType = g_type_from_name("gdouble")
proc g_string_get_type*(): GType = g_type_from_name("gchararray")
proc g_pointer_get_type*(): GType = g_type_from_name("gpointer")
proc g_boxed_get_type*(): GType = g_type_from_name("GBoxed")
proc g_param_get_type*(): GType = g_type_from_name("GParam")
proc g_variant_get_type*(): GType = g_type_from_name("GVariant")

atk.nim:proc setCurrentValue*(self: Value | NoOpObject; value: gobject.Value): bool =
atk.nim:proc setValue*       (self: Value | NoOpObject; newValue: cdouble) =
proc setBoolean*             (self: Value; vBoolean: bool = true) =
proc setBoxed*               (self: Value; vBoxed: pointer) =
proc setBoxedTakeOwnership*  (self: Value; vBoxed: pointer) =
proc setChar*                (self: Value; vChar: int8) =
proc setDouble*              (self: Value; vDouble: cdouble) =
proc setEnum*                (self: Value; vEnum: int) =
proc setFlags*               (self: Value; vFlags: int) =
proc setFloat*               (self: Value; vFloat: cfloat) =
proc setGtype*               (self: Value; vGtype: GType) =
proc setInstance*            (self: Value; instance: pointer) =
proc setInt*                 (self: Value; vInt: int) =
proc setInt64*               (self: Value; vInt64: int64) =
proc setLong*                (self: Value; vLong: int64) =
proc setObject*              (self: Value; vObject: Object = nil) =
proc setParam*               (self: Value; param: ParamSpec = nil) =
proc setPointer*             (self: Value; vPointer: pointer) =
proc setSchar*               (self: Value; vChar: int8) =
proc setStaticBoxed*         (self: Value; vBoxed: pointer) =
proc setStaticString*        (self: Value; vString: cstring = "") =
proc setString*              (self: Value; vString: cstring = "") =
proc setStringTakeOwnership* (self: Value; vString: cstring = "") =
proc setUchar*               (self: Value; vUchar: uint8) =
proc setUint*                (self: Value; vUint: int) =
proc setUint64*              (self: Value; vUint64: uint64) =
proc setUlong*               (self: Value; vUlong: uint64) =
proc setVariant*             (self: Value; variant: glib.Variant = nil) =

proc getBoolean*(self: Value): bool =
proc getBoxed*  (self: Value): pointer =
proc getChar*   (self: Value): int8 =
proc getDouble* (self: Value): cdouble =
proc getEnum*   (self: Value): int =
proc getFlags*  (self: Value): int =
proc getFloat*  (self: Value): cfloat =
proc getGtype*  (self: Value): GType =
proc getInt*    (self: Value): int =
proc getInt64*  (self: Value): int64 =
proc getLong*   (self: Value): int64 =
proc getObject* (self: Value): Object =
proc getParam*  (self: Value): ParamSpec =
proc getPointer*(self: Value): pointer =
proc getSchar*  (self: Value): int8 =
proc getString* (self: Value): string =
proc getUchar*  (self: Value): uint8 =
proc getUint*   (self: Value): int =
proc getUint64* (self: Value): uint64 =
proc getUlong*  (self: Value): uint64 =
proc getVariant*(self: Value): glib.Variant =
]#

let
  gType_invalid  : GType = typeFromName("(null)")
  gType_none     : GType = typeFromName("void")
  gType_interface: GType = typeFromName("GInterface")
  gType_char     : GType = typeFromName("gchar")
  gType_uchar    : GType = typeFromName("guchar")
  gType_boolean  : GType = typeFromName("gboolean")
  gType_int      : GType = typeFromName("gint")
  gType_uint     : GType = typeFromName("guint")
  gType_long     : GType = typeFromName("glong")
  gType_ulong    : GType = typeFromName("gulong")
  gType_int64    : GType = typeFromName("gint64")
  gType_uint64   : GType = typeFromName("guint64")
  gType_enum     : GType = typeFromName("GEnum")
  gType_flags    : GType = typeFromName("GFlags")
  gType_float    : GType = typeFromName("gfloat")
  gType_double   : GType = typeFromName("gdouble")
  gType_string   : GType = typeFromName("gchararray")
  gType_pointer  : GType = typeFromName("gpointer")
  gType_boxed    : GType = typeFromName("GBoxed")
  gType_param    : GType = typeFromName("GParam")
  gType_variant  : GType = typeFromName("GVariant")

let str_gtype  = gType_string  # : GType = gStringGetType()
let bool_gtype = gType_boolean # : GType = gBooleanGetType()

proc toStringVal(s: string): Value =
  #let gtype = typeFromName("gchararray")
  discard init(result, gType_string) # gtype)
  setString(result, s)

#[
proc toUIntVal(i: int): Value =
  let gtype = typeFromName("guint")
  discard init(result, gtype)
  setUint(result, i)
]#
proc toBoolVal(b: bool): Value =
  #let gtype = typeFromName("gboolean")
  discard init(result, gType_boolean) # gtype)
  setBoolean(result, b)

proc toIntVal(i: int): Value =
  #let gtype = typeFromName("gboolean")
  discard init(result, gType_int) # gtype)
  setInt(result, i)

proc toPointerVal(p: pointer): Value =
  discard init(result, gType_pointer)
  setPointer(result, p)


type
  Columns = enum
    ID_COLUMN
    NAME_COLUMN
    HIDDEN_COLUMN
    MTL_COLUMN
    N_COLUMNS # give the nb of column

var columnTypes  : seq[GType]  = @[gType_int, str_gtype, bool_gtype, str_gtype]
var columnTitles : seq[string] = @[   "Id"  ,   "Name" ,  "Hidden" , "mtlName"]

#[
let str_gtype : GType = gStringGetType()
let int_gtype : GType = gIntGetType()
let bool_gtype: GType = gBooleanGetType()

proc toStringVal(s: string): Value =
  let gtype = typeFromName("gchararray")
  discard init(result, gtype)
  setString(result, s)

proc toUIntVal(i: int): Value =
  let gtype = typeFromName("guint")
  discard init(result, gtype)
  setUint(result, i)

proc toBoolVal(b: bool): Value =
  let gtype = typeFromName("gboolean")
  discard init(result, gtype)
  setBoolean(result, b)
]#

# we need the following two procs for now -- later we will not use that ugly cast...
proc typeTest(o: gobject.Object; s: string): bool =
  let gt = g_type_from_name(s)
  return g_type_check_instance_is_a(cast[ptr TypeInstance00](o.impl), gt).toBool


proc treeStore(o: gobject.Object): gtk.TreeStore =
  assert(typeTest(o, "GtkTreeStore"))
  cast[gtk.TreeStore](o)

#let iterNil = cast[ptr TreeIter](nil)[]

proc loadObj3dInIter(self: TreeStore; obj3d: Obj3D, parent=cast[ptr TreeIter](nil)[]): TreeIter =
  self.append(result, parent)

  self.setValue(result, ID_COLUMN.int    , obj3d.no.toIntVal) # store Obj3d.no
  self.setValue(result, NAME_COLUMN.int  , obj3d.name.toStringVal)
  self.setValue(result, HIDDEN_COLUMN.int, obj3d.hidden.toBoolVal)
  self.setValue(result, MTL_COLUMN.int   , obj3d.mtlName.toStringVal)

#[
func treeIterToStr(self: TreeStore; iter: TreeIter): string =
  var valStr1, valstr2, valBool: Value

  self.getValue(iter, ID_COLUMN.int , valStr1)
  let id  : string = valStr1.getString()

  self.getValue(iter, NAME_COLUMN.int , valStr2)
  let name: string = valStr2.getString()

  self.getValue(iter, HIDDEN_COLUMN.int, valBool)
  let hidden: bool = valBool.getBoolean()

  var value: Value
  self.getValue(iter, USER_DATA.int, value)
  let refObj = value.getPointer()
  #debugEcho "1: p: ", p.repr

  let obj3d: Obj3D = cast[Obj3D](refObj)
  #debugEcho "1: obj3d.mtlName: ", obj3d.mtlName
  result =fmt"id: {id}, name: {name}, hidden: {hidden:5}, obj3d.mtlName:{obj3d.mtlName}, obj3d.addr:{refObj.repr}" # refObj.int.toHex(16)

  #debugEcho result

#proc loadObj3dInIter(self: TreeStore; obj3d: Obj3D, parent=cast[ptr TreeIter](nil)[]): TreeIter =
proc loadObj3dInIter(self: TreeStore; obj3d: Obj3D, parent=cast[ptr TreeIter](nil)[]): TreeIter =
  self.append(result, parent)
  self.setValue(result, ID_COLUMN.int   , obj3d.id.toIntVal)
  self.setValue(result, NAME_COLUMN.int , obj3d.name.toStringVal)
  #self.setValue(result, HIDDEN_COLUMN.int, obj3d.hidden.toBoolVal)

  let refObj = cast[pointer](obj3d)
  echo "0: refObj: ", refObj.repr
  var value = refObj.toPointerVal
  self.setValue(result, USER_DATA.int, value)

  echo "loadObj3dInIter: ", self.treeIterToStr(result)
]#

func getObj3d_no(self: TreeStore; iter: TreeIter): int =
  var value: Value
  self.getValue(iter, ID_COLUMN.int , value)
  result = value.getInt()

func getObj3d_name(self: TreeStore; iter: TreeIter): string =
  var value: Value
  self.getValue(iter, NAME_COLUMN.int , value)
  result = value.getString()

func getObj3d_hidden(self: TreeStore; iter: TreeIter): bool =
  var value: Value
  self.getValue(iter, HIDDEN_COLUMN.int , value)
  result = value.getBoolean()

func getObj3d_mtl(self: TreeStore; iter: TreeIter): string =
  var value: Value
  self.getValue(iter, MTL_COLUMN.int , value)
  result = value.getString()

func treeIterToStr(self: TreeStore; iter: TreeIter): string =
  let no     : int    = self.getObj3d_no(iter)
  let name   : string = self.getObj3d_name(iter)
  let hidden : bool   = self.getObj3d_hidden(iter)
  let mtlName: string = self.getObj3d_mtl(iter)

  result =fmt"no: {no}, name: {name}, hidden: {hidden:5}, mtlName: {mtlName}"
  #debugEcho result

proc fillTreeStore(store: TreeStore; root: Obj3D) =
  var rootIter = store.loadObj3dInIter(root)
  for child in root.children:
    var childIter = store.loadObj3dInIter(child, rootIter)
    for gchild in child.children:
      var gchildIter = store.loadObj3dInIter(gchild, childIter)

func getObj3d(parms: Params; iter: TreeIter): Obj3d =
    let ts : TreeStore = parms.tStore
    let no = ts.getObj3d_no(iter)
    return parms.getObj3d(no)

#------------------------------------------------------

proc storedObj3dInScene(parms: Params; obj3d: Obj3d): int =
    parms.allObj3Ds.add(obj3d)
    obj3d.no = parms.allObj3Ds.len
    return obj3d.no

proc prepareBufs(objGL: ObjsOpengl; modelFile: string,
                  check=false, normalize=true, swapVertYZ=false, swapNormYZ=false, flipU=false, flipV=false,
                  ignoreTexture=false, debugTextureFile="";
                  grpsToInclude: seq[string]= @[], grpsToExclude: seq[string]= @[];
                  debug=1, dbgDecountReload=0
                ): Obj3D =

    #if debug >= 1: echo fmt"prepareBufs: {modelFile.extractFilename}, swapVertYZ:{swapVertYZ}, swapNormYZ:{swapNormYZ}, flipU:{flipU}, flipV:{flipV}"

    let objLoader = OBJL.newObjLoader()

    let parseOk = OBJL.parseObjFile(objLoader, modelFile, debug=debug, dbgDecountReload=dbgDecountReload)
    if not parseOk : return


    result =  newObj3D(name=objLoader.objFile) # newObj3dStoredInScene(parms)
    objGL.matTplLib = objLoader.matTplLib
    #[
    type
        IndexedBufs* = object
            rgMtls* : RangMtls
            ver*, nor*, uvt* : seq[float32]
            idx* : seq[uint32]
    ]#
    var vertSwapYZ, normSwapYZ : bool
    if   objLoader.vertical == OBJL.Axis.Z:
        vertSwapYZ = true
        normSwapYZ = true
    elif objLoader.vertical == OBJL.Axis.Y:
        vertSwapYZ = false
        normSwapYZ = false
    else:
        vertSwapYZ = swapVertYZ
        normSwapYZ = swapVertYZ

    OBJL.normalizeModel( objLoader, check=check,
                        normalize=normalize,
                        unit = objLoader.unit,
                        swapVertYZ=vertSwapYZ, swapNormYZ=swapNormYZ,
                        flipU=flipU, flipV=flipV,
                        debug=3)

    objGL.bufs = OBJL.loadOglBufs(objLoader, debug=1)

    echo fmt"Loaded model: {result.name}, include:{grpsToInclude}, exclude:{grpsToExclude}"


proc on_createContext(self: MyGLArea): uInt64 =
    echo "MyGLArea.on_createContext"

proc bufSiz[T](buf: seq[T]): int     {.inline.} = result = buf.len * T.sizeof
proc bufAdr[T](buf: seq[T]): pointer {.inline.} = result = buf[0].unsafeaddr

proc textureIdOfFile(objGL: ObjsOpengl; texFile: string): GLuint =
    if objGL.textureNameToIds.contains(texFile): result = objGL.textureNameToIds[texFile]
    else:
        result = load_image(texFile, debug=2)
        #if result >= 1: objGL.useTextures = true # at least one texture loaded
        objGL.textureNameToIds[texFile] = result

proc addModel(objGL: ObjsOpengl; parms: Params) = # model: OBJM.Model) =
    let modelFile = parms.modelFileName
    echo "addModel: ", modelFile.extractFilename # model.name

    const vectorDim: GLint = 3 # 2D or 3D

    #let objGL = self.objGL

    let normalize  = true  # model.normalize
    let swapVertYZ = false # model.swapYZ
    let swapNormYZ = false # model.swapYZ
    let obj3d = objGL.prepareBufs(modelFile, flipV=true, normalize=normalize, swapVertYZ=swapVertYZ, swapNormYZ=swapNormYZ, debug=1)
    if obj3d == nil:
        echo "!!!!!!!!!!!!!!!!!!!!!! Cannot load model: ", modelFile
        return

    discard parms.storedObj3dInScene(obj3d)

    echo fmt"***************** loading textures if not yet for {obj3d.name}: ", $objGL.bufs.rgMtls
    for rgMtl in objGL.bufs.rgMtls:
        let child = newObj3D(name=rgMtl.name, hidden=false, parent=obj3d)
        discard parms.storedObj3dInScene(child)
        child.name    = rgMtl.name
        child.idx0    = rgMtl.idx0
        child.idx1    = rgMtl.idx1
        child.mtlName = rgMtl.mtl

        #parms.obj3dSel = obj3d # select the last created
        parms.objToControl[1]  = obj3d # select the last created

        if objGL.matTplLib != nil and objGL.matTplLib.mtls.contains(child.mtlName) :
            child.mtl = objGL.matTplLib.mtls[child.mtlName]
            echo "child.mtl: ", $child.mtl
            if child.mtl.mapKa.len > 0: child.mapKaId = objGL.textureIdOfFile(child.mtl.mapKa)
            if child.mtl.mapKd.len > 0: child.mapKdId = objGL.textureIdOfFile(child.mtl.mapKd)
            if child.mtl.mapKs.len > 0: child.mapKsId = objGL.textureIdOfFile(child.mtl.mapKs)

    for name, gluint in objGL.textureNameToIds.pairs:
        if gluint >= 1:
            parms.useTextures = true # at least one texture loaded
            break

    parms.obj3Ds.add(obj3d)

    echo "---------- obj3Ds: ---------"
    for o in parms.obj3Ds:
        echo o.toStr
    echo "----------------------------"

    echo ">>>>>>>>>>> put obj3d in tree store"
    #parms.tStore.loadObj3dInIter(obj3d) # root
    parms.tStore.fillTreeStore(obj3d) # TODO: add scene as root object

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


proc on_realize(self: MyGLArea, guiDat: GuiDatas) =
    echo "MyGLArea.on_realize"

    let objGL = self.objGL
    let parms = guiDat.parms

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

    parms.lightPower = 20000.0'f32 # proportional to square of dist
    parms.lightPos   = vec3(30.0'f32, 100.0'f32, 50.0'f32) # sun at 100 meters
    parms.rgbaMask   = vec4(1.0'f32 ,1.0'f32 ,1.0'f32, 1.0'f32)

    glUseProgram(objGL.progId)

    objGL.uMVP = glGetUniformLocation(objGL.progId, "MVP")
    objGL.uV   = glGetUniformLocation(objGL.progId, "V")
    objGL.uM   = glGetUniformLocation(objGL.progId, "M")
    #echo fmt"Got handle for uniforms: MVP: {objGL.uMVP}, V: {objGL.uV}, M: {objGL.uM}"

    objGL.lightPos_id = glGetUniformLocation(objGL.progId, "LightPosition_worldspace");
    #echo "Got handle for uniform LightPosition : ", objGL.lightPos_id

    objGL.lightPower_id = glGetUniformLocation(objGL.progId, "LightPower");
    #echo "Got handle for uniform LightPosition : ", objGL.lightPower_id

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


proc on_unrealize(self: MyGLArea, guiDat: GuiDatas) =
    echo "MyGLArea.on_unrealize"


proc on_resize(self: MyGLArea; width: int, height: int, guiDat: GuiDatas) = # ; user_data: pointer ?????
    #echo "on_resize : (w, h): ", (width, height)
    self.width  = width
    self.height = height


proc addObj(self: GuiDatas; fileName:string) =
    echo fmt"--------------------- MyGLArea.addObj: {fileName} ----------------------"
    #let pwd = joinPath(os.getCurrentDir(), "Obj3D")
    self.parms.modelFileName = fileName # .relativePath(pwd) # make a request


proc on_render(self: MyGLArea; context: gdk.GLContext, guiDat: GuiDatas): bool = # ; user_data: pointer ?????
    let parms = guiDat.parms
    if parms.modelFileName.len > 0: # addModelReq:
        self.objGL.addModel(parms) # parms.model)
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

    glUniform3f(objGL.lightPos_id, parms.lightPos.x, parms.lightPos.y, parms.lightPos.z)
    glUniform1f(objGL.lightPower_id, parms.lightPower)

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

const allAxes: array[3, Axe] = [X, Y, Z]

proc updateDisplay(objCtrl: Obj3dControl; linAxes: openArray[Axe], rotAxes: openArray[Axe], parms:Params) =
    let id = objCtrl.id
    if parms.objToControl[id] == nil:
        # echo "updateDisplay: obj3d is nil !"
        return

    let name = parms.objToControl[id].name
    #echo "updateDisplay: obj3d: ", name

    var i : int

    if name != objCtrl.name:
        echo fmt"updateDisplay: {name}"
        for axe in linAxes:
            i = axe.int
            objCtrl.linAxeCtrl[i].nameLabel.setLabel(name)
            objCtrl.rotAxeCtrl[i].nameLabel.setLabel(name)
        objCtrl.name = name

    var txt: string
    for axe in linAxes:
        i = axe.int
        let val = parms.objToControl[id].pos[i]
        if val != objCtrl.pos[i]:
            txt = fmt"{val:8.3f}"
            #echo fmt"updateDisplay: {name}: linAxe:{axe}: ", txt
            objCtrl.linAxeCtrl[i].posValEntry.setText(txt)
            objCtrl.pos[i] =  val

    for axe in rotAxes:
        i = axe.int
        let val = parms.objToControl[id].xyzRot[i]
        if val != objCtrl.xyzRot[i]:
            txt = fmt"{val:8.3f}"
            #echo fmt"updateDisplay: {name}: rotAxe:{axe}: ", txt
            objCtrl.rotAxeCtrl[i].posValEntry.setText(txt)
            objCtrl.xyzRot[i] = val

proc animationStep(guiDat: GuiDatas) {.cdecl.} = #x: var float, y: var float, z: var float) =
    let parms = guiDat.parms

    parms.time += parms.dt

    parms.camer.move(1.0)

    for obj3d in parms.obj3Ds:
        obj3d.move(1.0)

    for objCtrl in guiDat.obj3dCtrls:
        objCtrl.updateDisplay(linAxes=allAxes, rotAxes=allAxes, parms)

proc invalidateCb(guiDat: GuiDatas): bool =
    animationStep(guiDat)
    guiDat.glArea.queueRender() # queueDraw
    return SOURCE_CONTINUE

func `$`(event: gdk.EventKey): string =
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
        parms.objToControl[1].stopMove()
        parms.polygDisp.faceIdx = 0 # GL_FRONT_AND_BACK
        parms.polygDisp.modeIdx = if not release: 1 else: 0 # GL_LINE else: GL_FILL
        return

    if release: return # "drop key release"

    if  10.uint16 <= keyCode and keyCode <= 19: # select subObj
        let i = keyCode.int - 10
        if parms.objToControl[1] != nil and i < parms.objToControl[1].children.len:
            let child = parms.objToControl[1].children[i]
            child.hidden = not child.hidden
            echo fmt"child: {child.name}:" & (if child.hidden: "hidden" else: "shown")
        else: echo fmt"keyCode:{keyCode:3}: i:{i} >= {parms.obj3Ds.len} => no selection !"


    elif keyCode.int in parms.KeyCod2NamActionObj:
        let (name, fct, objStr, axe, d) = parms.KeyCod2NamActionObj[keyCode.int]
        if axe == noAxe : echo "nothing to do"
        else:
            #echo fmt"found : {keyCode:3}: '{name}', axe:{axe}, d:{d:.3f}, objStr:{objStr}" #, fct:{fct} " # , type(obj) #, {obj}, fct.repr
            var obj: Obj3D
            if   objStr == "camer": obj = parms.camer
            elif objStr == "obj3d": obj = parms.objToControl[1]
            if obj != nil: fct(obj, axe, d)
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
    if parms.objToControl[1] != nil : s &= fmt"; obj3dSel: {parms.objToControl[1].name}, xyzRot:{parms.objToControl[1].xyzRot}"
    echo s

var keyCodePressed : uint16
proc onKeyPress(self: gtk.Window; event: gdk.EventKey, parms: Params): bool =
    #echo "press  : ", $event
    var keyCode : uint16
    assert event.keycode(keyCode) # get the code and check return is ok
    if keyCode != keyCodePressed: # to supress repeatition
        keyCodePressed = keyCode
        actionKey(event, parms, release=false)
    result = true

#proc onKeyRelease(self: ApplicationWindow; event: gdk.EventKey): bool =
proc onKeyRelease(self: gtk.Window; event: gdk.EventKey, parms: Params): bool =
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
  discard chooser.setCurrentFolder(joinPath(os.getCurrentDir(), "Obj3D"))
  let ff = newFileFilter()
  ff.setName("file.obj only")
  ff.addPattern("*.obj")
  chooser.addFilter(ff)

  let res = chooser.run()
  if res == ResponseType.accept.ord:
      result = chooser.getFilename()
      #echo "accept open: ", result # fileName
  chooser.destroy

proc onClick(b: Button, p:LabTxt) =
  let (l, txt) = p
  echo "click " & txt
  l.label = txt & " has been clicked"


proc onClick(b: Button, p:SbIdTxt) =
  let (sb, id, txt) = p
  echo "click " & txt
  discard sb.push(id, txt & " has been clicked")

type MyButton = ref object of Button
  objCtrl : Obj3dControl # parent
  axeCtrl : AxeControl # parent
  cmd     : Cmd

proc onClick(b: MyButton, parms: Params) =
  var speedTxt : string
  let obj3d = parms.objToControl[b.objCtrl.id]
  if obj3d != nil:
      let axe = b.axeCtrl.axe
      let i   = axe.int
      let rot = b.axeCtrl.rot
      if rot:
          echo fmt"rot around axe: {axe}, cmd: {b.cmd}"
          obj3d.accRotCmd(b.axeCtrl.axe, b.cmd)
          speedTxt = fmt"{obj3d.dxyzRot[i]:8.3f} rd/s"
      else:
          echo fmt"translate  axe: {axe}, cmd: {b.cmd}"
          obj3d.accLinCmd(b.axeCtrl.axe, b.cmd)
          speedTxt = fmt"{obj3d.speed[i]:8.3f} m/s"

      b.axeCtrl.speedValLab.setLabel(speedTxt)

  else: echo "onClick: obj3d is nil !"

  #discard sb.push(id, txt & " has been clicked")

proc onActivate(self: Entry; ac:AxeControl) =
  echo "onActivate: ", self.getText


proc onAddObj(mi: MenuItem, guiDat: GuiDatas) = # glArea: MyGLArea) =
  let fileName = chooseFileObj()
  # echo "onAddObj: fileName: ", fileName
  if fileName.len > 0: guiDat.addObj(fileName)


proc onWindowDestroy(w: gtk.Window, txt= "") =
  echo "onWindowDestroy " & txt
  mainQuit()


proc onQuitMenuActivate(mi: MenuItem, txt= "") =
  echo "onQuitMenuActivate " & txt
  mainQuit()


proc onRemItem(widget: Button; tv: TreeView) =
  let selection = tv.selection
  var store = tv.getModel.treeStore #getListStore(treeView)
  var iter: TreeIter
  if not store.getIterFirst(iter):
      echo "Nothing to remove !"
      return
  if selection.getSelected(store, iter):
    discard store.remove(iter)

proc onRemoveAll(widget: Button; tv: TreeView) =
  var iter: TreeIter
  let store = tv.getModel.treeStore
  if store.getIterFirst(iter):
    clear(store)
  else: echo "Nothing to remove !"

proc toggleBool(parms: Params; iter: TreeIter; column: int) =
    var value: Value
    parms.tStore.getValue(iter, column, value)
    var b : bool = not value.getBoolean
    value.setBoolean( b )
    parms.tStore.setValue(iter, column, value)

    var obj3d = parms.getObj3d(iter)
    obj3d.hidden =  b

proc onToggle(crToggle: CellRendererToggle; path: string, p: ParmsColumn) =
  let (parms, column) = p
  #var store = tv.getModel.treeStore
  let treePath: TreePath = newTreePathFromString(path)
  var iter: TreeIter
  if parms.tStore.getIter(iter, treePath):
    echo NL & fmt"before toggle:{path}, iter: " & parms.tStore.treeIterToStr(iter)
    parms.toggleBool(iter, column)
    echo fmt"after  toggle:{path}, iter: " & parms.tStore.treeIterToStr(iter)

proc onEdited(crText: CellRendererText; path: string; newText: string; tv: TreeView) =
  let selection = tv.selection
  var store = tv.getModel.treeStore
  var iter: TreeIter
  if selection.getSelected(store, iter):
    echo "onEdited: ", path, ", ", newText
    store.setValue(iter, NAME_COLUMN.int, newText.toStringVal)


proc initTreeStoreAndView(parms : Params) =
  parms.tView  = newTreeView()
  parms.tView.setHeadersVisible(true)

  parms.tStore = newTreeStore(nColumns=N_COLUMNS.int, types=columnTypes[0].addr)
  parms.tView.setModel(parms.tStore) # connect view to store

  for i, title in columnTitles.pairs:
    let column = newTreeViewColumn()
    column.title = title
    if i == HIDDEN_COLUMN.int:
      let crToggle = newCellRendererToggle()
      let p: ParmsColumn = (parms, i)
      crToggle.connect("toggled", onToggle, p)
      column.packStart(crToggle, true)
      column.addAttribute(crToggle, "active", i) # "radio"
    else:
      let crText   = newCellRendererText()
      column.packStart(crText, true)
      column.addAttribute(crText, "text", i) # "text"
      if i == NAME_COLUMN.int:
        crText.setProperty("editable", true.toBoolVal)
        if false: # read back
          var valBool: Value
          discard valBool.init(bool_gtype)
          crText.getProperty("editable", valBool)
          echo "editable: ", valBool.getBoolean
        crText.connect("edited", onEdited, parms.tView)
        #column.addAttribute(crText, "active", i) # "editable-set"
    discard parms.tView.appendColumn(column)

#[
proc initButtonGrid(parms: Params): Grid = # Box = #
    #result = newbox(Orientation.vertical  , spacing=0)
    #result = newbox(Orientation.horizontal, spacing=0)
    result = newGrid()
    for p in [("Up", 1, 0), ("Left", 0, 1), ("Stop", 1, 1), ("Right", 2, 1), ("Down", 1, 2)]:
        echo "p : ", p
        let (label, left, top) = p
        let but = newButton(label)
        but.setSizeRequest(width= 48, height=32)
        parms.buttons.add(but)
        #result.add(but)
        result.attach(but, left=left, top=top, width=1, height=1)
]#

proc newAxeControl(parent:Obj3dControl; parms: Params, axe: Axe, rot=false, butLabels: openArray[string]): AxeControl =
    result = new AxeControl
    result.parent = parent
    #let name = if parent.obj3d == nil: "noObj3d" else: parent.obj3d.name
    let linRotStr = if rot: " rotAxe " else: " linAxe "
    let unitStr = if rot: "rd" else: "m"
    result.axe = axe
    result.rot = rot
    result.hBox = newBox(Orientation.horizontal, spacing=0)
    for cmdi, label in butLabels.pairs:
        let but: MyButton = newButton(MyButton, label)
        but.axeCtrl = result
        but.objCtrl = parent
        but.cmd = (cmdi-1).Cmd
        but.setSizeRequest(width= 56, height=32)
        echo fmt"cmdi:{cmdi}, but.cmd:{but.cmd:4}, label:{label}"
        but.connect("clicked", onClick, parms)
        result.hbox.add(but)

    result.nameLabel = newLabel("noObj " & linRotStr & $axe)
    result.nameLabel.setSizeRequest(width= 140, height=32)
    result.hbox.add(result.nameLabel)

    result.speedValLab = newLabel("   0.0 " & unitStr & "/s")
    result.speedValLab.setXalign(0.99)
    result.speedValLab.setSizeRequest(width= 80, height=32)
    result.hBox.add(result.speedValLab)

    result.posValEntry = newEntry()
    result.posValEntry.setText("0.0")
    result.posValEntry.setAlignment(0.99)
    result.posValEntry.setSizeRequest(width= 80, height= -1)
    result.hBox.add(result.posValEntry)
    result.posValEntry.connect("activate", onActivate, result)

    result.posUnitLab  = newLabel(unitStr)
    result.posUnitLab.setSizeRequest(width= 15, height=32)
    result.hBox.add(result.posUnitLab)

    parent.vBox.add(result.hBox)

proc newObj3dControl(id: int, parms: Params): Obj3dControl =
    result = new Obj3dControl
    result.id = id

    result.vBox = newBox(Orientation.vertical, spacing=0)

    var ac: AxeControl
    ac = newAxeControl(parent=result, parms, axe=X, rot=false, butLabels= ["Left", "StopX", "Right", "Reset"])
    result.linAxeCtrl.add(ac)
    #result.vBox.add(ac.hBox)

    ac = newAxeControl(parent=result, parms, axe=Y, rot=false, butLabels= ["Down", "stopY", "Up"   , "Reset"])
    result.linAxeCtrl.add(ac)
    #result.vBox.add(ac.hBox)

    ac = newAxeControl(parent=result, parms, axe=Z, rot=false, butLabels=["Back" , "StopZ", "Frwd" , "Reset"])
    result.linAxeCtrl.add(ac)
    #result.vBox.add(ac.hBox)

    ac = newAxeControl(parent=result, parms, axe=X, rot=true , butLabels=["RotX-", "stopX", "RotX+", "Reset"])
    result.rotAxeCtrl.add(ac)
    #result.vBox.add(ac.hBox)

    ac = newAxeControl(parent=result, parms, axe=Y, rot=true , butLabels=["RotY-", "stopY", "RotY+", "Reset"])
    result.rotAxeCtrl.add(ac)
    result.vBox.add(ac.hBox)

    ac = newAxeControl(parent=result, parms, axe=Z, rot=true , butLabels=["RotZ-", "stopZ", "Rot+" , "Reset"])
    result.rotAxeCtrl.add(ac)
    #result.vBox.add(ac.hBox)

#[
proc initButtons(guiDat: GuiDatas): Box =
    result = newBox(Orientation.vertical, spacing=0)

    let parms = guiDat.parms

    guiDat.camControl = newObj3dControl(parms)
    result.add(guiDat.camControl.vBox)

    guiDat.objSelControl = newObj3dControl(parms)
    result.add(guiDat.objSelControl.vBox)
]#

proc main(debugTextureFile="") =
    #let parms = guiDat.parms
    let guiDat = new GuiDatas
    let parms  = new Params
    guiDat.parms = parms

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

    let hbox = newbox(Orientation.horizontal, spacing=0)
    vBox.packStart(hbox, expand=true, fill=true, padding=0)

    let rightBox = newBox(Orientation.vertical, 0)
    hBox.add(rightBox)

    parms.camer = newObj3D(name="camera", pos0=vec3f(0.0, 1.0, 4.0))

    let objCtrlBox = newBox(Orientation.vertical, spacing=0)
    var objCtrl: Obj3dControl
    for i in 0 ..< nObj3dCtrls:
        guiDat.obj3dCtrls[i]  = newObj3dControl(i, parms)
        parms.objToControl[i] = Obj3dNil
        objCtrlBox.add(guiDat.obj3dCtrls[i].vBox)
    rightBox.add(objCtrlBox)

    parms.objToControl[0] = parms.camer

    parms.initTreeStoreAndView()

    rightBox.packStart(parms.tView, true, true, 0)

    guiDat.glArea = newMyGLArea(parms) # newGLArea()
    #vBox.add(glArea)
    #echo "type(glArea): ", type(glArea)
    #glArea.setAutoRender()
    guiDat.glArea.setSizeRequest(256, 256)

    #glArea.connect("create-context", on_createContext)
    guiDat.glArea.connect("realize"  , on_realize, guiDat)
    guiDat.glArea.connect("unrealize", on_unrealize, guiDat)
    guiDat.glArea.connect("resize"   , on_resize, guiDat)
    guiDat.glArea.connect("render"   , on_render, guiDat)

    addObjMi.connect("activate", onAddObj, guiDat)

    if false:
        vBox.packStart(guiDat.glArea, expand=true, fill=true, padding=0) # hBox
    else:
        let openglWin = newWindow(gtk.WindowType.toplevel)
        openglWin. title = "OpenGL Window"
        openglWin.add(guiDat.glArea)
        openglWin.showAll

    #parms.obj3ds = Obj3D(); parms.sujet.name = "subject"
    #parms.sujet.resetPos()

    let obj3dSel = parms.objToControl[1]
    let camer    = parms.camer
    #let dv      = parms.delta
    parms.KeyCod2NamActionObj = {
        #[
        0 : ("KbdNul"   , nil, nil, -1, 0),

        9 : ("KeyEscape", , 1),
       65 : ("KeySpace" , 0, 1),
       ]#
       79 : ("NumPad7"  , accRotCmd, "obj3d", Z, LESS),
       80 : ("NumPad8"  , accRotCmd, "obj3d", Z, STOP),
       81 : ("NumPad9"  , accRotCmd, "obj3d", Z, MORE),

       83 : ("NumPad4"  , accRotCmd, "obj3d", Y, LESS),
       84 : ("NumPad5"  , accRotCmd, "obj3d", Y, STOP),
       85 : ("NumPad6"  , accRotCmd, "obj3d", Y, MORE),

       87 : ("NumPad1"  , accRotCmd, "obj3d", X, LESS),
       88 : ("NumPad2"  , accRotCmd, "obj3d", X, STOP),
       89 : ("NumPad3"  , accRotCmd, "obj3d", X, MORE),

       90 : ("NumPad0"  , stopMove , "obj3d", XYZ, STOP),
       91 : ("NumPadSup", resetPos , "obj3d", XYZ, STOP),

      113 : ("KeyLeft"  , accLinCmd, "camer", X, LESS),
      114 : ("KeyRigth" , accLinCmd, "camer", X, MORE),
      116 : ("KeyDown"  , accLinCmd, "camer", Y, LESS),
      111 : ("KeyUp"    , accLinCmd, "camer", Y, MORE),
      112 : ("PageUp"   , accLinCmd, "camer", Z, LESS),
      117 : ("PageDown" , accLinCmd, "camer", Z, MORE),
      118 : ("insert"   , resetPos , "camer", XYZ, STOP),
      119 : ("Supress"  , stopMove , "camer", XYZ, STOP),
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

    window.connect("key_press_event"  , onKeyPress  , parms)
    window.connect("key_release_event", onKeyRelease, parms)

    window.showAll

    # proc timeoutAdd*(priority: int; interval: int; function: SourceFunc; data: pointer; notify: DestroyNotify): int =
    #discard timeoutAdd(interval=(parms.dt*1000.0).uint32, function=invalidateCb, data=guiDat)
    discard timeoutAdd((parms.dt*1000.0).uint32, invalidateCb, guiDat)

    gtk.main()

#===========================================================================

when isMainModule:
    from os import getAppFilename, extractFilename, commandLineParams
    let appName = extractFilename(getAppFilename())
    echo fmt"Begin {appName}"

    main()

    echo fmt"End {appName}"

