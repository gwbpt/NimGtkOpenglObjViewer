
# load from file

import strformat
import strutils

from os import DirSep, joinPath, splitPath, splitFile, fileExists

import ../../FLOAT16/float16

const logLevel = 2

proc plog(level: int; msg: string) =
  if logLevel >= level: stdout.writeLine("LOG" & $level & ": " & msg)

template tlog(level: int; msg: string) =
  if logLevel >= level: stdout.writeLine("LOG" & $level & ": " & msg)

#var x = 4
#log("x has the value: " & $x)

import glm
import commonTypes

type VerNor*   =  array[6, Float16] # 3 + 3
proc `$`*(vnu:VerNor): string =
    result  = NL & fmt"({vnu[0]:6.3f}, {vnu[1]:6.3f}, {vnu[2]:6.3f})"
    result &=    fmt", ({vnu[3]:6.3f}, {vnu[4]:6.3f}, {vnu[5]:6.3f})"

type VerNorUV* =  array[8, Float16] # 3 + 3 + 2
proc `$`*(vnu:VerNorUV): string =
    result  = NL & fmt"({vnu[0]:6.3f}, {vnu[1]:6.3f}, {vnu[2]:6.3f})"
    result &=    fmt", ({vnu[3]:6.3f}, {vnu[4]:6.3f}, {vnu[5]:6.3f})"
    result &=    fmt", ({vnu[6]:6.3f}, {vnu[7]:6.3f})"


const NLT = NL & TAB

type
    Idx*  = uint32
    Idx3* = array[3, Idx]  # indexes 3 per triangles

const IdxNone*: Idx = Idx.high # 0xffffffff = None

proc `$`*(idx:Idx): string =
    result = if idx == IdxNone: "IdxNone" else: fmt"{idx:4}"

func parseIdx*(s:string):Idx     = parseInt(s).Idx

proc `$`*(i3:Idx3): string =
    result = fmt"({i3[0]}, {i3[1]}, {i3[2]})"

proc `$`*(f2:Vec2f): string =
    result = NL & fmt"({f2[0]:6.3f}, {f2[1]:6.3f})"

type Color3 = glm.Vec3f
const
    WHITE  = vec3f(1.0, 1.0, 1.0)
    RED    = vec3f(1.0, 0.0, 0.0)
    GREEN  = vec3f(0.0, 1.0, 0.0)
    BLUE   = vec3f(0.0, 0.0, 1.0)
    YELLOW = vec3f(1.0, 1.0, 0.0)
    BLACK  = vec3f(0, 0, 0)


import objModels

import Tables
type Idx3ToIdx = OrderedTable[Idx3, Idx]

proc addIfNotYetAndReturnIndex(tbl: var Idx3ToIdx, elem:Idx3): Idx =
    echo fmt"addIfNotYetAndReturnIndex: start find in {tbl.len} elems"
    #let resp = tbl.find(elem)
    echo "addIfNotYetAndReturnIndex: end find"
    if tbl.hasKey(elem) :
        result = tbl[elem]
        #echo fmt"addIfNotYetAndReturnIndex: {elem} in {tbl} at ", $result
    else: # not in tbl
        result = tbl.len.Idx
        tbl[elem] = result #tbl.add(elem)
        #echo fmt"addIfNotYetAndReturnIndex: {elem} added to {tbl} at ", $result

type
    SeqIdx3FastFind = ref object
        lst : seq[Idx3]
        dic : Table[Idx3, Idx]

proc addIfNotYetAndReturnIndex(self:SeqIdx3FastFind, elem: Idx3): Idx =
    if elem in self.dic: return self.dic[elem]

    let idx = self.lst.len.Idx
    self.lst.add(elem)
    self.dic[elem] = idx
    return idx

proc index(self:SeqIdx3FastFind, elem: Idx3): Idx =
    result = self.dic.getOrDefault(elem, IdxNone)

proc `[]`(self:SeqIdx3FastFind, idx:Idx): Idx3 =
    assert idx < self.lst.len.Idx
    result = self.lst[idx]
#------------------------------------------------------------------------------
#import fenv
#from sequtils import repeat
#from sugar import collect

func normalTriangle(vert3: array[3, Vec3f]; debug=0): Vec3f =
    #if debug >= 2: echo fmt"normalTriangle: vert3: {vert3}"
    let v2 = vert3[2] - vert3[0]
    let v1 = vert3[1] - vert3[0]
    #if debug >= 3: echo fmt"normalTriangle: v1:{v1}, v2:{v2}"
    let vProd = cross(v1, v2)
    let length = length(vProd)
    result = vdiv(vProd, length)
    #if debug >= 1: echo fmt"normalTriangle: {result}"

proc print2d(datas2d:seq[Idx3], title="", debug=1) =
    if debug <= 0: return
    echo fmt"{datas2d.len:6} {title}"
    if debug >= 2:
        let firstChar = title[0]
        #[
        let n = datas2d.len
        if debug >= 3 or n <= 20:
            r = range(n)
        else:
            r = list(range(10)) + list(range(n-10, n))
        if debug >= 4: echo "debug: %d, range: n: %d"%(debug, n), r); quit()
        for i in r :
            echo "    {}%06d: {}"%(firstChar, i, datas2d[i]))
        ]#

proc print2d(datas2d:seq[Vec2f], title="", debug=1) =
    if debug <= 0: return
    echo fmt"{datas2d.len:6} {title}"
    if debug >= 2:
        let firstChar = title[0]
        let n = datas2d.len
        #[
        if debug >= 3 or n <= 20:
            r = range(n)
        else:
            r = list(range(10)) + list(range(n-10, n))
        if debug >= 4: echo "debug: %d, range: n: %d"%(debug, n), r); quit()
        for i in r :
            echo "    {}%06d: {}"%(firstChar, i, datas2d[i]))
        ]#

proc print2d(datas2d:seq[Vec3f], title="", debug=1) =
    if debug <= 0: return
    echo fmt"{datas2d.len:6} {title}"
    if debug >= 2:
        let firstChar = title[0]
        let n = datas2d.len
        #[
        if debug >= 3 or n <= 20:
            r = range(n)
        else:
            r = list(range(10)) + list(range(n-10, n))
        if debug >= 4: echo "debug: %d, range: n: %d"%(debug, n), r); quit()
        for i in r :
            echo "    {}%06d: {}"%(firstChar, i, datas2d[i]))
        ]#

#------------------------------------------------------------------------------
#[ Examples
    newmtl name (ex:12255_Mute_Swan)

    * Material color and illumination
    Ka 0.0435 0.0435 0.0435
    Kd 0.1086 0.1086 0.1086
    Ks 0.0000 0.0000 0.0000
    Tf 0.9885 0.9885 0.9885
    illum 6
    d -halo 0.6600
    Ns 10.0000
    sharpness 60
    Ni 1.19713
    * Texture map:
    map_Ka -s 1 1 1 -o 0 0 0 -mm 0 1 chrome.mpc
    map_Kd -s 1 1 1 -o 0 0 0 -mm 0 1 chrome.mpc
    map_Ks -s 1 1 1 -o 0 0 0 -mm 0 1 chrome.mpc
    map_Ns -s 1 1 1 -o 0 0 0 -mm 0 1 wisp.mps
    map_d -s 1 1 1 -o 0 0 0 -mm 0 1 wisp.mps
    disp -s 1 1 .5 wisp.mps
    decal -s 1 1 1 -o 0 0 0 -mm 0 1 sand.mps
    bump -s 1 1 1 -o 0 0 0 -bm 1 sand.mpb
]#
#[
   Ka 1.000 1.000 1.000
   Kd 1.000 1.000 1.000
   Ks 0.000 0.000 0.000
   d 1.0
   illum 2
   map_Ka lemur.tga           # the ambient texture map
   map_Kd lemur.tga           # the diffuse texture map (most of the time, it will be the same as the ambient texture map)
   map_Ks lemur.tga           # specular color texture map
   map_Ns lemur_spec.tga      # specular highlight component
   map_d lemur_alpha.tga      # the alpha texture map
   map_bump lemur_bump.tga    # some implementations use 'map_bump' instead of 'bump' below
   bump lemur_bump.tga        # bump map (which by default uses luminance channel of the image)
   disp lemur_disp.tga        # displacement map
   decal lemur_stencil.tga    # stencil decal texture (defaults to 'matte' channel of the image)
]#

type
    MaterialTmpl* = ref object of RootObj # Material Template
        name* : string
        Ka*, Kd*, Ks*, Tf* : Color3
        d*     : float
        illum* : int
        mapKa*, mapKd*, mapKs* : string

    MatTmplLib* = ref object of RootObj # Material Template Library
        mtlPathFile* : string
        mtls* : OrderedTable[string, MaterialTmpl]


proc `$`*(o:MaterialTmpl): string =
    if o == nil :
        result = "MaterialTmpl nil"
    else:
        # return "{}{NLT}Ka:{}{NLT}Kd:{}{NLT}Ks:{}{NLT}mapKa: {}{NLT}mapKd: {}{NLT}mapKs: {}"%(self.name, self.Ka, self.Kd, self.Ks, self.mapKa, self.mapKd, self.mapKs)
        #result = fmt"{o.name}{NLT}Ka:{o.Ka}{NLT}Kd:{o.Kd}{NLT}Ks:{o.Ks}{NLT}mapKa:{o.mapKa}{NLT}mapKd:{o.mapKd}{NLT}mapKs:{o.mapKs}"
        result  = fmt"MLT:'{o.name}':"
        if o.Ka != BLACK  : result &= NLT & fmt"Ka:{o.Ka}"
        if o.Kd != BLACK  : result &= NLT & fmt"Kd:{o.Kd}"
        if o.Ks != BLACK  : result &= NLT & fmt"Ks:{o.Ks}"
        if o.mapKa.len > 0: result &= NLT & fmt"mapKa:'{o.mapKa}'"
        if o.mapKd.len > 0: result &= NLT & fmt"mapKd:'{o.mapKd}'"
        if o.mapKs.len > 0: result &= NLT & fmt"mapKs:'{o.mapKs}'"

proc `$`*(o:MatTmplLib): string =
    result = fmt"MaterialTmplLib: from file:'{o.mtlPathFile}':"
    for name, mtl in pairs(o.mtls):
        result &= NLT & $mtl

proc newMaterialTmpl(name:string): MaterialTmpl =
    result = new MaterialTmpl
    result.name = name
    result.Ka = WHITE
    result.Kd = WHITE
    result.Ks = BLACK

proc parseMaterialTmplFile(mtlPath, mtlFileName :string): MatTmplLib =
    let mtlPathFile = joinPath(mtlPath, mtlFileName)

    #echo fmt"reading mtlPathFile:'{mtlPathFile}'"
    let txt: string = readFile(mtlPathFile).string

    result = new MatTmplLib
    #result.mtls = initTable[string, MaterialTmpl]() # () is important = dict()

    result.mtlPathFile = mtlPathFile
    # echo fmt"parseMaterialTmplFile from {result.mtlPathFile}"

    let mtlLines = txt.splitLines()
    var name: string
    for i, rawLine in pairs(mtlLines):
        let line = rawLine.strip()
        #echo fmt"line{i:03d}: {line}"
        if line.len == 0 or line[0] == '#': continue

        let toks = line.split()
        let (cmd, tokens) = (toks[0], toks[1 ..< toks.len])
        if cmd == "newmtl":
            name = tokens[0]
            result.mtls[name] = newMaterialTmpl(name)
        elif len(line) >= 6:
            let line0_4 = line[0 ..< 5]
            #echo "line0_4:", line0_4)
            if line0_4 == "map_K":
                #let mapK = line[6 ..< line.len].strip()
                let car = line[5]
                let fullFileName = joinPath(mtlPath, tokens[0])
                # echo fmt"mtlPath:'{mtlPath}', tokens[0]:'{tokens[0]}' -> fullFileName:'{fullFileName}'"
                # echo "car:", car)
                if   car == 'a': result.mtls[name].mapKa = fullFileName
                elif car == 'd': result.mtls[name].mapKd = fullFileName
                elif car == 's': result.mtls[name].mapKs = fullFileName
                else:
                    echo fmt"mapK{car} not take in account !!!!"
        #[
        if newmtl is not None:
            newmtl.analyse()
            echo "ooooooooooooooo %d textureGenerated"%textureutils.nbTextureGenerated)
            echo "resultat analyse newmtl:", newmtl)
        ]#
    echo fmt"read {mtlPathFile} -> :\p", result

#-------------------------------------------------------------------------------

const
    quad_uvIdxs    : array[4, int] = [0, 1, 2 ,3]
    triangle_uvIdxs: array[4, int] = [0, 1, 2 ,3]

type
    GrpTyp = enum oGROUP, gGROUP

    States = enum NoChg, IGNORE, INIT, MTLIB, IN_O, IN_V, IN_VT, IN_VN, IN_F, IN_L, IN_G, USEMTL, IN_S, END

    Group = ref object of RootObj
        objMgr  : ObjsManager # forward declaration in same type
        prevGrp : Group # Option[Group] # set: some(grp) or none(Group); test: x.isNone x.isSome; get x.get()
        name    : string
        typ     : GrpTyp
        debug   : int
        paramS  : string # or int ????
        faces_vunIdxs_index : seq[seq[Idx]] # 3 (triangles) or 4 (square) !!!!!!!!!!!!!!!!!
        nTris, nQuads : int
        ignoreTexture, check : bool
        debugTextureFile: string
        vMin, vMax, nMin, nMax, uMin, uMax, cMin, cMax : uint32
        verts   : seq[Vec3f]
        norms   : seq[Vec3f]
        uvtxs   : seq[Vec2f]
        couls   : seq[Vec3f]
        usemtl  : string

    ObjsManager* = ref object of RootObj
        objLdr : ObjLoader
        groups : OrderedTable[string, Group]
        debugTextureFile: string
        ignoreTexture : bool
        debugUvtxs : seq[Vec2f]
        vunIdxsFastList: SeqIdx3FastFind
        allFaceGroupNames: seq[string]
        selGrp: Group
        selMtl: string

    ObjLoader* = ref object of RootObj
        matTplLib* : MatTmplLib
        objMgr     : ObjsManager
        #obj3D_path : string  # to replace global Obj3D_path
        #objPath, objPathFile, texPathFile : string
        debugTextureFile  : string # abs path
        absPath, objFile* : string
        debug      : int
        normalize, check, o_eq_g : bool
        ignoreObjs : seq[string]
        allVerts   : seq[Vec3f]
        allNorms   : seq[Vec3f]
        allUvtxs   : seq[Vec2f]
        allCouls   : seq[Vec3f]
        lineIdx    : int
        errorsCount: int
        key        : string
        tokens     : seq[string]
        dbgDecount, dbgDecountReload : int
        state      : States
        lineRead   : string
        swapVertYZ, swapNormYZ, flipU, flipV : bool

proc `$`*(self: Group): string =
    #let prevName = if self.prevGrp == nil: "None" else: self.prevGrp.name
    result = fmt"Group:{self.name:21}: {self.typ}, debug:{self.debug}, check:{self.check:5}, ignoreTexture:{self.ignoreTexture:5}, debugTextureFile:'{self.debugTextureFile}'"
    result &= fmt", usemtl:{self.usemtl:19}"
    let min_max_str = fmt"vidx:{self.vMin:06d}..{self.vMax:06d}, nidx:{self.nMin:06d}..{self.nMax:06d}, uidx:{self.uMin:06d}..{self.uMax:06d}, cidx:{self.cMin:06d}..{self.cMax:06d}"
    result &= fmt", prmS:'{self.paramS:1}', {min_max_str}, :{self.faces_vunIdxs_index.len:6} faces_vunIdxs_index"

    let (n_v, n_n, n_u) = (self.verts.len, self.norms.len, self.uvtxs.len)
    if n_v==0 and n_n==0 and n_u==0 :
        result &= ", NoVNU" # verts norms uvtxs"
    else:
        result &= fmt", {n_v:6} verts, {n_n:6} norms, {n_u:6} uvtxs"

proc printFull(self: Group, debug=0): string =
    #echo self
    echo "printFull not implemented !"
    #print2d(self.faces_vunIdxs_index , "faces_vunIdxs_index" , debug=debug)


proc newGroup(objMgr: ObjsManager, prevGrp:Group, grpTyp=oGROUP, name="noName", debugTextureFile="", ignoreTexture=false, check=false, debug=0): Group =
    result = new Group
    result.objMgr  = objMgr
    result.prevGrp = prevGrp
    result.name    = name
    result.debug   = debug
    result.check   = check
    result.debugTextureFile = debugTextureFile
    result.ignoreTexture    = ignoreTexture

    # max indices for vert, norm, uvtx, coul at creation time
    if prevGrp != nil :
        #echo fmt"prevGrp: {prevGrp}"
        result.vMin = prevGrp.vMax
        result.nMin = prevGrp.nMax
        result.uMin = prevGrp.uMax
        result.cMin = prevGrp.cMax

    if result.objMgr.objLdr.dbgDecount > 0: echo fmt">>> new  {result}"

proc initAtFirstFace(self:Group) =
    if self.faces_vunIdxs_index.len > 0:
        #echo "initAtFirstFace: not first"
        return

    let objLd = self.objMgr.objLdr

    self.vMax = objLd.allVerts.len.Idx
    self.nMax = objLd.allNorms.len.Idx
    self.uMax = objLd.allUvtxs.len.Idx
    self.cMax = objLd.allCouls.len.Idx

    if len(objLd.allUvtxs) == 0:
        if self.debugTextureFile == "":
            self.ignoreTexture = true
        echo fmt"Group {self.name} no texture => ignoreTexture:{self.ignoreTexture}, debugTextureFile:{self.debugTextureFile}"

    if self.debugTextureFile != "":
        self.uMin = 0
        self.uMax = self.objMgr.debugUvtxs.len.uint32

    #echo fmt"initAtFirstFace: vertMaxIdx:{self.vMax}, normMaxIdx:{self.nMax}, uvMaxIdx:{self.uMax}"

proc check_v_u_n_idxs(self: Group; vunIdxs: array[3, uint32]): string =
    let vidx = vunIdxs[0]
    let uidx = vunIdxs[1]
    let nidx = vunIdxs[2]
    if                     not (self.vMin <= vidx and vidx < self.vMax): result &= NL & fmt"Group {self.name} check fail: {self.vMin}<= vidx:{vidx} <{self.vMax} !"
    if uidx != IdxNone and not (self.uMin <= uidx and uidx < self.uMax): result &= NL & fmt"Group {self.name} check fail: {self.uMin}<= uidx:{uidx} <{self.uMax} !"
    if nidx != IdxNone and not (self.nMin <= nidx and nidx < self.nMax): result &= NL & fmt"Group {self.name} check fail: {self.nMin}<= nidx:{nidx} <{self.nMax} !"

var sqIdx3: seq[Idx3]
let idx3: Idx3 = [1'u32, 2'u32, 3'u32]
sqIdx3.add(idx3)

proc addFaceTriOrQuad(self: Group; face_idxs: seq[Idx]) =
    let n = face_idxs.len
    if   n == 3: inc(self.nTris)
    elif n == 4: inc(self.nQuads)
    else:
        quit(fmt"ERROR: face_idxs: {n} : not Triangle(3) nor Quad(4) => quit !")

    self.faces_vunIdxs_index.add(face_idxs)

proc add_vunIdxs(self: Group; vunIdxs: Idx3): (Idx, string) =
    var idx: Idx
    var errorMsg: string
    if self.check :
        errorMsg = self.check_v_u_n_idxs(vunIdxs)
    if errorMsg.len == 0: # no error
        idx = self.objMgr.vunIdxsFastList.addIfNotYetAndReturnIndex(vunIdxs)
    result = (idx, errorMsg)
    #echo "add_vunIdxs -> ", result

proc addVert(self: Group; idx: Idx) =
    #echo "addVer(idx:{})"%idx)
    if self.check: assert self.vMin <= idx and idx < self.vMax, fmt"FacesGroup '{self.name}' addVert: {self.vMin} <= idx:{idx} < {self.vMax}"
    self.verts.add(self.objMgr.objLdr.allVerts[idx])

proc addNorm(self: Group; idx: Idx) =
    if self.check: assert self.nMin <= idx and idx < self.nMax, fmt"FacesGroup '{self.name}' addNorm: {self.nMin} <= idx:{idx} < {self.nMax}"
    self.norms.add(self.objMgr.objLdr.allNorms[idx])

proc addUvtxParams(self: Group; idx: Idx; uvtxs:seq[Vec2f], check: bool) =
    if check: assert self.uMin <= idx and idx < self.uMax, fmt"Group '{self.name}' addUvtx: {self.uMin} <= idx:{idx} < {self.uMax}"
    self.uvtxs.add(uvtxs[idx])

proc addUvtx(self: Group; idx: Idx) =
    if self.debugTextureFile != "":
        self.addUvtxParams(idx, self.objMgr.debugUvtxs     , true)
    else:
        self.addUvtxParams(idx, self.objMgr.objLdr.allUvtxs, self.check)

proc addCoul(self: Group; idx: Idx) =
    if self.check : assert self.cMin <= idx and idx < self.cMax #, "FacesGroup '{}' addCoul: {} <= idx:{} < {}"%(self.name, self.cMin, idx, self.cMax)
    self.couls.add(self.objMgr.objLdr.allCouls[idx])

proc closeGroup(self: Group) =
    if self.objMgr.objLdr.dbgDecount > 0: echo fmt"<<< close{self}"

#-----------------------------------
import times
import terminal # for colored

proc addTriangleWithoutIdx(self: Group; triangl_vunIdxs: seq[Idx3], debug=0) =
    if debug >= 2: echo fmt"addTriangleWithoutIdx: {triangl_vunIdxs}"

    var vertexIdxs: seq[Idx] # for calculation normal if not defined
    for idx3 in triangl_vunIdxs:
        let (vertIdx, uvtxIdx, normIdx) = (idx3[0], idx3[1], idx3[2])
        if debug >= 2: echo fmt"vertIdx:{vertIdx}, uvtxIdx:{uvtxIdx}, normIdx:{normIdx}"
        try:
            self.addVert(vertIdx)
        except:
            styledEcho(fgRed, fmt"addTriangleWithoutIdx: vertIdx:{vertIdx}")
            raise

        if not self.ignoreTexture and uvtxIdx != IdxNone:
            #self.uvtxs.append(self.allUvtxs[uvtxIdx])
            try:
                self.addUvtx(uvtxIdx)
            except:
                styledEcho(fgRed, fmt"addTriangleWithoutIdx: uvtxIdx:{uvtxIdx}")
                raise

        if normIdx == IdxNone:
            # store vertex of triangle for generate a Normal
            vertexIdxs.add(vertIdx)
        else:
            #self.norms.append(self.getNorm(normIdx)) # self.allNorms[normIdx])
            self.addNorm(normIdx)

    if vertexIdxs.len == 3:
        if debug >= 0: echo "generate normal from triangles"
        var vert3: array[3, Vec3f]
        for i, idx in pairs(vertexIdxs):
            vert3[i] = self.objMgr.objLdr.allVerts[idx]
        let normal = normalTriangle(vert3)
        for i in 0 ..< 3: # add 3 time the calculated normal
            self.norms.add(normal) # calculated norm


proc fillVUNnonIndexedOfFaceGrp(self: Group, debug=0) =
    if debug >= 3: echo fmt"fillVUNnonIndexedOfFaceGrp '{self.name}'"

    var time0, dt : float

    time0 = cpuTime()

    if debug >= 1 : echo fmt"Group {self.name}.fillVUNnonIndexedOfFaceGrp: debug:{debug}"
    if debug >= 2 : echo fmt"{self.faces_vunIdxs_index.len} self.faces_vunIdxs_index"

    for iface, faceIdxs in pairs(self.faces_vunIdxs_index):
        if debug > 0 :
            let m = if debug == 1: 1000 elif debug == 2: 100 elif debug == 3: 10 else: 1
            if iface.mod(m) == 0 : echo fmt"    face{iface:05d}: {faceIdxs}"

        var vunIdxs: seq[Idx3]
        for faceIdx in faceIdxs:
            if faceIdx == IdxNone:
                continue
            #echo "faceIdx: ", faceIdx
            let vunIdx = self.objMgr.vunIdxsFastList[faceIdx]
            #echo "vunIdx: ", vunIdx
            vunIdxs.add(vunIdx)

        if   len(vunIdxs) == 3:
            if debug >= 3: echo "Triangle"
            self.addTriangleWithoutIdx(vunIdxs, debug=debug)
        elif len(vunIdxs) == 4:
            #triangl_idxs = [face_idxs[i] for i in (2, 3, 0)] ; echo "face_idxs:{}, triangl_idxs:{}"%(face_idxs, triangl_idxs)); quit()
            if debug >= 3: echo "Quad divided in 2 triangles"
            self.addTriangleWithoutIdx(@[vunIdxs[0], vunIdxs[1], vunIdxs[2]], debug=debug)
            self.addTriangleWithoutIdx(@[vunIdxs[2], vunIdxs[3], vunIdxs[0]], debug=debug)
        else:
            let msg =fmt"fill_verts_uvtxs_norms_noIndexed: vunIdxs.len: {vunIdxs.len} not in (3:TRI, 4:QUAD) !!! => quit()"
            quit(msg, 1)
    if debug >= 2:
        echo "Group {self.name}.fillVUNnonIndexedOfFaceGrp:"
        print2d(self.verts, "verts_out", debug=debug)
        print2d(self.uvtxs, "uvtxs_out", debug=debug)
        print2d(self.norms, "norms_out", debug=debug)

    dt = cpuTime() - time0
    if debug >= 1: echo fmt"Group {self.name}.fillVUNnonIndexedOfFaceGrp: in {dt:7.3f} s"
    #self.faces_vunIdxs_index = @[] #del(self.faces_vunIdxs_index)

#------------------------------------------------------------------------------

proc addGroup(self: ObjsManager; grpTyp:GrpTyp; grpName:string, check:bool) =
    var grp = newGroup(self, self.selGrp, grpTyp, name=grpName, debugTextureFile=self.debugTextureFile, ignoreTexture=self.ignoreTexture, check=check, debug=1)
    grp.usemtl = self.selMtl
    self.groups[grpName] = grp
    self.selGrp = grp

proc addObjGroup(self: ObjsManager; grpName="noName", check:bool) =
    self.addGroup(grpTyp=oGROUP, grpName=grpName, check=check)

proc init_uvs_of_default_texture(self: ObjsManager) =
    # uvs for default texture square + triangle bitmap
    self.debugUvtxs = @[]

    # for QUAD left part of bitmap
    self.debugUvtxs.add(vec2f(0.0, 0.0))
    self.debugUvtxs.add(vec2f(0.5, 0.0))
    self.debugUvtxs.add(vec2f(0.5, 1.0))
    self.debugUvtxs.add(vec2f(0.0, 1.0))

    # for TRIANGLE right part if bitmap
    self.debugUvtxs.add(vec2f(0.5, 0.0))
    self.debugUvtxs.add(vec2f(1.0, 0.0))
    self.debugUvtxs.add(vec2f(1.0, 1.0))

proc newObjsManager(parent:ObjLoader; debugTextureFile="", ignoreTexture=false, check=false): ObjsManager =
    result = new ObjsManager
    result.objLdr = parent
    result.debugTextureFile = debugTextureFile
    result.ignoreTexture    = ignoreTexture

    result.groups = initOrderedTable[string, Group]()
    result.allFaceGroupNames = @[]

    result.vunIdxsFastList = new SeqIdx3FastFind

    result.selGrp = nil  # do not remove used by addObjGroup
    result.addObjGroup(grpName="default", check=check)

    result.init_uvs_of_default_texture()

proc `$`*(self: ObjsManager): string =
    result = "ObjsManager.groups:"
    for name, grp in pairs(self.groups):
        assert grp.name == name
        result &= fmt"{NL}{name:24}:{grp}"

proc addFaceGroup(self: ObjsManager; grpName="noName", check:bool) =
    self.addGroup(grpTyp=gGROUP, grpName=grpName, check=check)

proc selectGroups(self: ObjsManager; grpsToInclude: seq[string]= @[], grpsToExclude: seq[string]= @[]): seq[string] =
    assert self.allFaceGroupNames.len >= 1

    for name in self.allFaceGroupNames :
        if grpsToExclude.contains(name): continue
        if grpsToInclude.len == 0 or name in grpsToInclude:
            result.add(name)

    #echo fmt"selectedGrps: {result}"

#-----------------------------------------------------------------------

type
    GrpRange* = object
        name* : string
        mtl*  : string
        idx0*, idx1*: Idx

type
    RangMtls* = seq[GrpRange]

    VnuMerged* = tuple
        verts:seq[Vec3f]
        norms:seq[Vec3f]
        uvtxs:seq[Vec2f]

    GroupMerged* = tuple
        rgMtls: RangMtls
        vnuMrgd: VnuMerged

proc `$`*(o:GrpRange): string =
    result = fmt"GrpRange: '{o.name}', mtl:'{o.mtl}', idx0:{o.idx0:6}, idx1:{o.idx0:6}"

proc `$`*(o:RangMtls): string =
    result = fmt"RangMtls: {o.len} elems:"
    for e in o : result &= NL & $e

proc `$`*(o:VnuMerged): string =
    result = fmt"{o.verts.len} verts, {o.norms.len} norms, {o.uvtxs.len} uvtxs"

proc `$`*(o:GroupMerged): string =
    result = fmt"{o.rgMtls}, {o.vnuMrgd}"

#---------------------------------------------

const jpgExt = ["png", "jpg", "jpeg"]
# os.changeFileExt(filename, ext: string)

proc textureFileExist(fileName: string): bool =
    if fileExists(fileName):
        result = true
    else:
        echo fileName & " not exists"
        let nameExt = fileName.rsplit('.', 1)
        var (name, ext) = (nameExt[0], nameExt[1])
        let fileWithOtherExt = name & ".*"
        if fileExists(fileWithOtherExt):
            echo fileName & " not exists but " & fileWithOtherExt & " exists*"
            result = true
        else: echo fileWithOtherExt & " not exists !!!!!!"

proc mergesGroups(self: ObjsManager; groups: seq[string]; debug=0): GroupMerged =
    echo "----------------- merging groups ..."
    assert len(groups) > 0
    #var firstIdx = 0
    for i, name in pairs(groups):
        #echo "   merge group '{}'"%name)
        if i >= 10: break
        let grp = self.groups[name]
        if grp.norms.len == 0:
            echo fmt"**************** mergesGroups: no norms for {grp}"
            continue
        if grp.uvtxs.len == 0:
            echo fmt"**************** mergesGroups: no uvtxs for {grp}"
            continue
        var grpRng: GrpRange
        grpRng.name = name
        grpRng.mtl  = grp.usemtl

        grpRng.idx0 = result.vnuMrgd.verts.len.Idx
        result.vnuMrgd.verts &= grp.verts
        grpRng.idx1 = result.vnuMrgd.verts.len.Idx

        result.vnuMrgd.norms &= grp.norms
        result.vnuMrgd.uvtxs &= grp.uvtxs

        echo "mergesGroups: add: ", grpRng
        result.rgMtls.add(grpRng)

    #return grps_verts, grps_norms, grps_uvtxs, grps_range, texFilesToLoad


proc fill_verts_uvtxs_norms_noIndexed(self: ObjsManager; debug=0) =
    if debug >= 1: echo "fill_verts_uvtxs_norms_noIndexed"
    for name, grp in pairs(self.groups):
        # grp.verts_uvtxs_norms ??? = grp.fillVUNnonIndexedOfFaceGrp(debug=debug) # bug python ????????????
        grp.fillVUNnonIndexedOfFaceGrp(debug=debug-1)
    # to free memory before ctypes generation
    # del(self.objLdr.allVerts, self.objLdr.allCouls, self.objLdr.allNorms, self.objLdr.allUvtxs) # !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    if false:
        self.objLdr.allVerts = @[]
        self.objLdr.allCouls = @[]
        self.objLdr.allNorms = @[]
        self.objLdr.allUvtxs = @[]


proc checkGrps(self:ObjsManager, debug=1) =
    if debug >= 1: echo fmt"ObjsManager.checkGrps: {self.groups.len:2} groups :"
    self.allFaceGroupNames = @[]
    for name, grp in pairs(self.groups):
        if name == "default" and grp.faces_vunIdxs_index.len == 0 :
            if debug >= 2: echo "Group 'default' is empty"
            continue
        if debug >= 2: echo fmt"checkGrps: allFaceGroupNames.add({name})"
        self.allFaceGroupNames.add(name)

    if len(self.allFaceGroupNames) == 0: echo "***************** allFaceGroupNames empty => raise   !!!!!!"; raise

    for name in self.allFaceGroupNames:
        #grp.printFull(debug=2)
        echo fmt"{self.groups[name]}"

#------------------------------- class ObjLoader ---------------------------------

proc `$`*(self:ObjLoader): string =
    return fmt"absPath: {self.absPath}, objFile: {self.objFile}, normalize:{self.normalize}, mtl:{self.matTplLib}, objMgr:{NL}   {self.objMgr}"

proc getVert(self:ObjLoader, idx: int): Vec3f =
    if idx < len(self.allVerts):
        return self.allVerts[idx]
    echo "!!!!!!!! getVert: idx:{idx} >= len(verts):{self.allVerts.len} !!!!!"
    quit()
    #return None

proc getNorm(self:ObjLoader, idx: int): Vec3f =
    if idx < len(self.allNorms): return self.allNorms[idx]

    self.errorsCount += 1
    echo "errorsCount:{self.errorsCount:3}: getNorm: idx:{idx} >= len(norms):{self.allNorms.len} !!!!!"
    if self.errorsCount > 10:
        assert false #quit()
    #return None

#---------------- line parsers -------------------

proc parseNotImplemented(self:ObjLoader) =
    echo "parser for state {self.state} not implemented !"

proc parse_mtlib_line(self:ObjLoader) =
    echo fmt"lin{self.lineIdx:6}: parse_mtlib_line: '{self.lineRead}'"
    #let grpo = self.objMgr.selGrp
    if self.objMgr.selGrp != nil:
        #let grp = grpo.get
        if self.objMgr.selGrp.ignoreTexture or self.objMgr.selGrp.debugTextureFile != "":
            echo "ignoreTexture or debugTextureFile specified"
            return

    let mtlFile = self.tokens[0]
    self.matTplLib = parseMaterialTmplFile(self.absPath, mtlFile)

proc parse_objName_line(self:ObjLoader) =
    if self.objMgr.selGrp != nil:
        self.objMgr.selGrp.closeGroup()
    let name = self.tokens[0]
    #echo "parse_objName_line: '{}'"%name)
    self.objMgr.addObjGroup(name, check=self.check)

proc parse_gGrp_line(self:ObjLoader) =
    let name = self.tokens[0]
    echo fmt"lin{self.lineIdx:6}: parse_gGrp_line: '{name}'"
    self.objMgr.addFaceGroup(name, check=self.check)

proc parse_sGrp_line(self:ObjLoader) =
    let name = self.tokens[0]
    echo fmt"lin{self.lineIdx:6}: parse_sGrp_line '{name}'"
    self.objMgr.selGrp.paramS = name
    #self.objMgr.selGrp = FacesGroup() # new group

#--------------------------

proc parse_usemtl_line(self:ObjLoader) = # Material Template Library
    let mtlName = self.tokens[0]
    echo fmt"lin{self.lineIdx:6}: parse_usemtl_line:'{mtlName}'"
    self.objMgr.selMtl = mtlName
    #[
    #let grpo = self.objMgr.selGrp
    #let grp = grpo.get
    if self.objMgr.selGrp.ignoreTexture or self.objMgr.selGrp.debugTextureFile.len > 0: return

    #if self.objMgr.selGrp is None: self.addFaceGroup("default")

    if self.matTplLib != nil:
        if self.matTplLib.mtls.contains(mtlName):
             = self.matTplLib.mtls[mtlName]
            #self.objMgr.selGrp.usemtl = self.matTplLib.mtls[mtlName]
            #echo fmt"self.objMgr.selGrp.usemtl:'{self.objMgr.selGrp.usemtl:19}'{NL}found in mtl.mtls:{self.matTplLib.mtls}"
        else:
            echo fmt"!!!! usemtl: {mtlName:19} not found in mtl.mtls:{self.matTplLib.mtls} !!!!"
            raise
    else: echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! matTplLib is None !"
    ]#
#--------------------------

proc parse_f3(s3: seq[string], off=0, swapYZ=false): Vec3f =
    for i in 0 ..< 3:
        result[i] = parseFloat(s3[i+off]).float32
    if swapYZ:
        let y = result[1]
        result[1] = result[2]
        result[2] = -y

proc parse_vert_line(self:ObjLoader) =
    #if not self.parseOn: return

    let xyz_rgb_Str = self.tokens
    # valid vertex strings are either v x y z or v x y z r g b (Meshlab dumps color to vertices)
    #assert xyz_rgb_Str.len in (3, 6)
    assert xyz_rgb_Str.len == 3 or xyz_rgb_Str.len == 6, fmt"lin{self.lineIdx:6}:'{self.lineRead}': tokens:{self.tokens}: xyz_rgb_Str.len:{xyz_rgb_Str.len} != 3 or 6"
    self.allVerts.add(parse_f3(xyz_rgb_Str, swapYZ=self.swapVertYZ))
    if len(xyz_rgb_Str) == 6:
        self.allCouls.add(parse_f3(xyz_rgb_Str, off=3))
    if self.dbgDecount > 0: echo fmt"parse_uvtx_line: allVerts.len: {self.allVerts.len}"

proc parse_norm_line(self:ObjLoader) =
    #if not self.parseOn: return

    let normalStr = self.tokens
    assert len(normalStr) == 3 # , "parse_norm_line: '{}', normalStr: {}"%(self.lineRead, normalStr)
    self.allNorms.add(parse_f3(normalStr, swapYZ=self.swapNormYZ))
    if self.dbgDecount > 0: echo fmt"parse_uvtx_line: allNorms.len: {self.allNorms.len}"

proc parse_uvtx_line(self:ObjLoader) =
    #grp = self.objMgr.selGrp; if grp.ignoreTexture or grp.debugTextureFile is not None: return # do not change index of others groups

    let uvStr = self.tokens
    #echo fmt"parse_uvtx_line: {uvStr}"
    assert uvStr.len >= 2 , fmt"uvStr.len:{uvStr.len} is not >= 2"
    var u = parseFloat(uvStr[0])
    var v = parseFloat(uvStr[1])
    if not ( 0.0 <= u and u <= 1.0 and 0.0 <= v and v <= 1.0 ) :
        echo fmt"lin{self.lineIdx:6}:'{self.lineRead}': u or v not in 0.0 .. 1.0 -> corrected"
        u = max(0.0, min(1.0, u))
        v = max(0.0, min(1.0, v))
    if self.flipU: u = 1.0 - u
    if self.flipV: v = 1.0 - v
    let f2: Vec2f = vec2f(u, v)
    self.allUvtxs.add(f2)
    if self.dbgDecount > 0: echo fmt"parse_uvtx_line: allUvtxs.len: {self.allUvtxs.len}"

proc parse_line_line(self:ObjLoader) =
    echo fmt"lin{self.lineIdx:6}:'{self.lineRead}': line geometry not supported !"

proc parse_face_line(self:ObjLoader) =
    #if not self.parseOn: return

    #let grpo = self.objMgr.selGrp
    #let grp = grpo.get
    self.objMgr.selGrp.initAtFirstFace()

    var faceIdxsStr = self.tokens
    var nVertsInFace = faceIdxsStr.len
    if nVertsInFace < 3:
        echo fmt"lin{self.lineIdx:6}:'{self.lineRead}': face with less than 3 vertexs skiped !"
        return
    if nVertsInFace > 4:
        echo fmt"lin{self.lineIdx:6}:'{self.lineRead}': face with more than 4 vertexs non supported : obj need triangulation -> face truncated !"
        faceIdxsStr = faceIdxsStr[0 ..< 4]
        nVertsInFace = 4
    #let nFaces = self.objMgr.selGrp.faces_vunIdxs_index.len
    var uvIdxs: array[4, int]
    if self.objMgr.selGrp.debugTextureFile.len > 0:
        #uvIdxs = if faceIdxsStr.len == 4: self.objMgr.quad_uvIdxs else: self.objMgr.triangle_uvIdxs
        uvIdxs = if faceIdxsStr.len == 4: quad_uvIdxs else: triangle_uvIdxs
    #else: echo "*********** debugTextureFile: {} *********"{}elf.objMgr.selGrp.debugTextureFile) ; quit()

    var face_idxs: seq[Idx]
    const UV_IDX = 1
    for i, xyz_uv_n_idxsStr in pairs(faceIdxsStr):
        #vunIdxs = [None if strIdx == "" else int(strIdx)-1 for strIdx in xyz_uv_n_idxsStr.split('/')]
        var vunIdxs: seq[Idx]
        for strIdx in xyz_uv_n_idxsStr.split('/'):
            if strIdx == "": vunIdxs.add(IdxNone)
            else: vunIdxs.add((parseInt(strIdx) - 1).Idx)
        #echo fmt"{i:3}: xyz_uv_n_idxsStr: {xyz_uv_n_idxsStr:12} -> {vunIdxs}"
        if vunIdxs.len == 1 :# No texture and no normal
            # 2 Nones in indexes list
            vunIdxs.add(IdxNone) # None
            vunIdxs.add(IdxNone) # None
        assert vunIdxs.len == 3, fmt"lin{self.lineIdx:6}:'{self.lineRead}', vunIdxs: {vunIdxs}: len != 3"
        if self.objMgr.selGrp.debugTextureFile != "":
            #echo "use debug texture"
            vunIdxs[UV_IDX] = uvIdxs[i].Idx # force index 4 5 6 for TRIANG 0 1 2 3 for QUAD
        #else
        #vunIdxsIdx = grp.addVunIdxsInFastList(vunIdxs)
        var idx3:Idx3
        for k in 0 ..< 3: idx3[k] = vunIdxs[k].Idx
        #echo "idx3: ", idx3
        let (vunIdxsIdx, errMsg) = self.objMgr.selGrp.add_vunIdxs(idx3)
        if errMsg.len == 0:
            face_idxs.add(vunIdxsIdx)
        else:
            quit(fmt"lin{self.lineIdx:6}:'{self.lineRead}': Error: {errMsg} => quit", 1)
    #echo "face_idxs: ", face_idxs
    self.objMgr.selGrp.addFaceTriOrQuad(face_idxs)

proc parse_end_file(self:ObjLoader) =
    if self.objMgr.selGrp != nil:
        self.objMgr.selGrp.closeGroup()
    #echo "End of parsing ----------------------------------------------------"

#--------------------------------------------------------

type
    Cmd2States       = Table[string  , States  ]
    State2Cmd2States = Table[States, Cmd2States]

const stateChanges: State2Cmd2States =
  {
    States.INIT  : {"mtllib": States.MTLIB , "v" : States.IN_V   , "g" : States.IN_G , "o" : States.IN_O , "vn": States.IN_VN, "end": States.END}.toTable,
    States.MTLIB : {"v"     : States.IN_V  , "g" : States.IN_G   , "o" : States.IN_O   , "end": States.END}.toTable,
    States.IN_V  : {"v"     : States.NoChg , "vt": States.IN_VT  , "vn": States.IN_VN, "f" : States.IN_F , "o" : States.IN_O, "end": States.END}.toTable,
    States.IN_VT : {"vt"    : States.NoChg , "vn": States.IN_VN  , "f" : States.IN_F , "g" : States.IN_G                    , "usemtl": States.USEMTL, "end": States.END}.toTable,
    States.IN_VN : {"vn"    : States.NoChg , "vt": States.IN_VT  , "v" : States.IN_V , "f" : States.IN_F , "g" : States.IN_G, "usemtl": States.USEMTL,"s" : States.IGNORE, "end": States.END}.toTable,
    States.IN_O  : {"usemtl": States.USEMTL, "v" : States.IN_V, "end": States.END}.toTable,
    States.IN_G  : {"usemtl": States.USEMTL, "g" : States.IGNORE , "v" : States.IN_V , "f" : States.IN_F , "end": States.END}.toTable,
    States.IN_S  : {"usemtl": States.USEMTL, "s" : States.IGNORE , "f" : States.IN_F , "end": States.END}.toTable,
    States.USEMTL: {"s"     : States.IN_S  , "g" : States.IN_G   , "f" : States.IN_F , "end": States.END}.toTable,
    States.IN_F  : {"f"     : States.NoChg , "usemtl": States.USEMTL, "g" : States.IN_G   , "o" : States.IN_O   , "v" : States.IN_V , "l" : States.IN_L , "end": States.END}.toTable,
    States.IN_L  : {"l"     : States.NoChg , "usemtl": States.USEMTL, "f" : States.IN_F   , "g" : States.IN_G   , "o" : States.IN_O , "v" : States.IN_V , "end": States.END}.toTable,
  }.toTable

#echo "stateChanges: " & NL, stateChanges

let parsers = { States.MTLIB : parse_mtlib_line,
                States.IN_O  : parse_objName_line,
                States.IN_V  : parse_vert_line,
                States.IN_VT : parse_uvtx_line,
                States.IN_VN : parse_norm_line,
                States.IN_F  : parse_face_line,
                States.IN_L  : parse_line_line,
                States.USEMTL: parse_usemtl_line,
                States.IN_G  : parse_gGrp_line,
                States.IN_S  : parse_sGrp_line,
                States.END   : parse_end_file,
            }.toTable


proc printStatus(self:ObjLoader, abort=false) =
    let s = if abort: " => abort" else: ""
    echo fmt"line{self.lineIdx:06d}: {self.state}: key:'{self.key}' : ignored in line:'{self.lineRead.strip()}'{s}"
    if abort : quit()

proc ignoreKey(self:ObjLoader) = echo fmt"ignore key '{self.key}"

proc changeState(self:ObjLoader, newState:States) =
    self.dbgDecount = self.dbgDecountReload
    if self.debug >= 2: echo fmt"line{self.lineIdx:06d}: {self.state} => {newState}"
    self.state = newState

#------------------------------------------------------

proc load(self:ObjLoader; objFileAbsPath:string; debug=1) =
    if debug >= 1: echo fmt"loading: check:{self.check}, swapVertYZ:{self.swapVertYZ}, swapNormYZ:{self.swapNormYZ}, flipU:{self.flipU}, flipV:{self.flipV}"

    self.debug = debug
    self.errorsCount = 0

    var time0, dt : float

    time0 = cpuTime()

    if debug >= 2: echo fmt"------------- loading: rescale at +-1.0:{self.normalize}, debug:{self.debug}, file: {self.objFile} :" #ignoreTexture:{self.ignoreTexture}
    #with open(Obj3D_path & self.objPathFile,'r') as f:
    let text: string = readFile(objFileAbsPath).string
    let lines = splitLines(text)
    if debug >= 2: echo fmt"{lines.len} lines read"
    #let parsers = { States.MTLIB : toto }.toTable

    self.state = States.INIT
    var line, comment: string
    for i in 0 .. lines.len:
        self.lineRead = if i < lines.len: lines[i] else: "end # added"
        self.lineIdx += 1

        line    = "???"
        comment = ""
        #echo fmt"0: {self.lineIdx:6}:'{self.lineRead}'"
        #if '#'.in(self.lineRead):
        if self.lineRead.contains('#'):
            #echo fmt"# in :'{self.lineRead}'"
            #if debug >= 2 : echo fmt"line{self.lineIdx:06d}: {self.lineRead.strip()}"
            let res = self.lineRead.split("#", 1)
            #echo fmt"res: {res}"
            line    = res[0].strip()
            comment = res[1].strip()
            if debug >= 4 and comment != "" : echo "Comment:", comment
        else:
            #echo fmt"1: {self.lineIdx:6}: '{self.lineRead}'->'{line}'"
            line = self.lineRead.strip()
        if line == "" : continue

        if debug >= 9 :
            var txt = fmt"{self.lineIdx:6}:{line}"
            if comment != "": txt &= fmt" # {comment}|"
            echo txt
        let lineStrip = line.strip()
        #echo fmt"lineStrip:'{lineStrip}'"
        if self.dbgDecount > 0 :
            dec(self.dbgDecount)
            #echo "dbgDecount: ", self.dbgDecount
        if debug >= 3 or (debug >= 2 and (self.dbgDecount > 0 or self.lineIdx.mod(1000) == 0)): echo fmt"line{self.lineIdx:06d}:{lineStrip} {comment}"
        # tokenize each line (ie. Split lines up in to lists of elements)
        # e.g. f 1//1 2//2 3//3 => [f,1//1,2//2,3//3]
        let tokens = lineStrip.splitWhitespace() #split() # (' ') = each blank give a string
        #echo "tokens:", tokens
        if tokens[0].len == 0: continue

        self.key    = tokens[0].toLower
        self.tokens = tokens[1 ..^ 1]

        let keyActions = stateChanges[self.state]
        if not self.key.in(keyActions): self.printStatus(abort=true)
        let nextState = keyActions[self.key]
        if nextState == IGNORE: continue
        if nextState != NoChg: self.changeState(nextState)

        if self.state.notIn(parsers):
            self.parseNotImplemented()
        else:
            let parseProc = parsers[self.state]
            self.parseProc()

    dt = cpuTime() - time0

    var nAllTris, nAllQuads : int
    for name, grp in pairs(self.objMgr.groups):
        nAllTris  += grp.nTris
        nAllQuads += grp.nQuads

    let nAllTriFaces = nAllTris + 2 * nAllQuads
    if false:
        echo fmt"ObjLoader(debug={self.debug}) loaded:"
        print2d(self.allVerts , "allVerts" , debug=self.debug)
        print2d(self.allNorms , "allNorms" , debug=self.debug)
        print2d(self.allUvtxs , "allUvtxs" , debug=self.debug)
        print2d(self.allCouls , "allCouls" , debug=self.debug)
    echo fmt"-> {nAllTris} Triangles and {nAllTris} Quads -> {nAllTriFaces} triangularFaces in {self.objMgr.groups.len} groups in {dt:7.3f} s"

    time0 = cpuTime() # -------------------------------------

    let (xyzsMin, xyzsMax) = xyzsMinMax(self.allVerts)
    let dims   =  xyzsMax - xyzsMin
    let center = (xyzsMax + xyzsMin) / 2

    if debug >= 3: echo fmt"xyzsMin :{xyzsMin}, xyzsMax :{xyzsMax}, center :{center}, dims :{dims}"

    if self.normalize:
        let boxDims = vec3f(2.0, 2.0, 2.0)
        let boxPos  = vec3f(0.0, 1.0, 0.0)
        #echo fmt"Put in box of dims:{boxDims} at position:{boxPos})"

        #[
        var xyzScale: Vec3f
        for d1, d2, s in items2in1out(dims, boxDims, xyzScale):
            s[] = d2 / d1
        ]#
        let xyzScale = boxDims / dims
        let scale = xyzScale.min

        centerScalePos_inpl(self.allVerts, center, scale, boxPos)

        let (xyzsMin2, xyzsMax2) = xyzsMinMax(self.allVerts)

        #[
        var dims2, center2 : Vec3f
        for vmax, vmin, d, c in items2in2out(xyzsMax2, xyzsMin2, dims2, center2):
            d[] =  vmax - vmin
            c[] = (vmax + vmin) / 2
        ]#
        let dims2   =  xyzsMax2 - xyzsMin2
        let center2 = (xyzsMax2 + xyzsMin2) / 2

        if debug >= 3: echo fmt"xyzsMin2:{xyzsMin2}, xyzsMax2:{xyzsMax2}, center2:{center2}, dims2:{dims2}"
        if debug >= 3: echo fmt"recentred and scaled by {scale:.3f} to fit in box scale"

    dt = cpuTime() - time0  # -------------------------------------
    if debug >= 2: echo "rescale {self.allVerts.len:6d} vertex in -1.0 .. +1.0 in {dt:7.3f} s"

    self.objMgr.checkGrps(debug=0)

    if self.debug >= 1: echo fmt"------------- loaded: debug: {self.debug}, file: {self.objFile} :"
    #quit() # **********************************************************

proc newObjLoader*(): ObjLoader =
    # init if any
    result = new ObjLoader

# model    : objPath, objFile, objPathFile, texFile, texPathFile
# ObjLoader: objPath,          objPathFile, texPathFile + obj3D_path


#proc loadModel*(self: ObjLoader; model: Model;
#ignoreTexture=false, debugTextureFile=""; swapVertYZ=false, swapNormYZ=false; flipU=false, flipV=false, check=false, debug=1, dbgDecountReload=0): bool =

proc loadModel*(self: ObjLoader;
                objFileAbsPath: string;
                ignoreTexture=false,
                debugTextureFile="",
                swapVertYZ=false, swapNormYZ=false,
                flipU=false, flipV=false, check=false,
                debug=1, dbgDecountReload=0
               ): bool =
    # Load Wavefront OBJ
    #[
    if true:
        self.objPath       = model.objPath
        self.objPathFile   = Obj3D_path & model.objPathFile
        if not fileExists(self.objPathFile):
            echo fmt"ERROR '{self.objPathFile}' not found"
            return false
    ]#
    # simulate new loadModel
    #let objPathFile = Obj3D_path & model.objPathFile # proviendra du nouveau loadModel
    #---------------------------------------------------------------------------------
    #[
    let ignoreTexture    = false
    let debugTextureFile = ""
    let swapVertYZ = false
    let swapNormYZ = false
    let flipU = false
    let flipV = false
    let check = false
    let debug = 1
    let dbgDecountReload = 0
    ]#
    #[
    let pathSplitted = objPathFile.split(DirSep)
    echo "pathSplitted: ", pathSplitted

    self.obj3D_path  = pathSplitted[0] & DirSep # nouveau Obj3D_path
    self.objPath     = pathSplitted[1 ..^ 2].joinPath
    self.objPathFile = pathSplitted[1 ..^ 1].joinPath
    ]#

    #[
    let objPath0     = model.objPath
    let objPathFile0 = self.obj3D_path & model.objPathFile # new
    echo fmt"self.obj3D_path: '{self.obj3D_path}' & model.objPathFile: '{model.objPathFile}' -> objPathFile0: '{objPathFile0}'"


    echo fmt"zzzzzzzzzzzzzzzzzz self.obj3D_path:'{self.obj3D_path}' ?= obj3D_path0:'{obj3D_path0}'"
    assert self.obj3D_path == obj3D_path0

    self.objPath = pathSplitted[1 ..^ 1].joinPath
    self.objPathFile = self.obj3D_path & self.objPath
    echo fmt"zzzzzzzzzzzzzzzzzz self.objPathFile:'{self.objPathFile}' ?= objPathFile0:'{objPathFile0}'"
    assert self.objPathFile == objPathFile0

    self.obj3D_path  = ?
    self.objPathFile = ?
    ]#

    self.debugTextureFile = debugTextureFile

    if not fileExists(objFileAbsPath):
        echo fmt"ERROR '{objFileAbsPath}' not found"
        assert false
        return false

    let (path, name, ext) = splitFile(objFileAbsPath)
    self.absPath = path
    self.objFile = name & ext
    #[
    if debugTextureFile.len > 0 and false:
        let fullDebugTextureFilePath = Obj3D_path & debugTextureFile
        if fileExists(fullDebugTextureFilePath):
            self.debugTextureFile = fullDebugTextureFilePath
            echo fmt"INFO: '{fullDebugTextureFilePath}' found"
        else:
            self.debugTextureFile = debugTextureFile
            echo fmt"WARN: '{fullDebugTextureFilePath}' not found"
    ]#
    self.o_eq_g      = true # treat 'o' as 'g'
    #self.texPathFile = Obj3D_path & model.texPathFile
    #self.normalize   = model.normalize
    #self.ignoreObjs  = model.ignoreObjs
    self.check       = check
    self.swapVertYZ  = swapVertYZ
    self.swapNormYZ  = swapNormYZ
    self.flipU       = flipU
    self.flipV       = flipV
    self.dbgDecountReload = dbgDecountReload

    #[
    self.allVerts = list()
    self.allNorms = list()
    self.allUvtxs = list()
    self.allCouls = list()
    ]#
    #self.matTplLib = nil

    self.objMgr = newObjsManager(parent=self, ignoreTexture=ignoreTexture, debugTextureFile=debugTextureFile, check=check)

    #echo fmt"ObjLoader: {result}"

    self.load(objFileAbsPath, debug)

    return true

proc selectGroups*(self: ObjLoader; grpsToInclude: seq[string]= @[], grpsToExclude: seq[string]= @[]): seq[string] =
     return self.objMgr.selectGroups(grpsToInclude, grpsToExclude)

proc fill_verts_uvtxs_norms_noIndexed*(self: ObjLoader; debug=0) =
     self.objMgr.fill_verts_uvtxs_norms_noIndexed(debug)

proc mergesGroups*(self: ObjLoader; groups: seq[string]; debug=0): GroupMerged =
    return self.objMgr.mergesGroups(groups, debug)

#from vnugt_reader21b3 as VNUG import nil


type
    IndexedBufs* = object
        rgMtls* : RangMtls
        ver*, nor*, uvt* : seq[float32]
        idx* : seq[uint32]

import tables

proc indexVBOs*(gMrgd: GroupMerged; debug=1): IndexedBufs =
    #result = new IndexedBufs
    result.rgMtls = gMrgd.rgMtls

    # make vnus

    let n = gMrgd.vnuMrgd.verts.len
    if debug >= 3: echo "gMrgd.vnuMrgd.verts.len: ", n
    assert  gMrgd.vnuMrgd.norms.len == n
    assert  gMrgd.vnuMrgd.uvtxs.len == n

    var vnus: seq[VerNorUV]
    var vnu : VerNorUV
    for i in 0 ..< n:
        for k in 0 ..< 3: vnu[k]   = gMrgd.vnuMrgd.verts[i][k].float16
        for k in 0 ..< 3: vnu[k+3] = gMrgd.vnuMrgd.norms[i][k].float16
        for k in 0 ..< 2: vnu[k+6] = gMrgd.vnuMrgd.uvtxs[i][k].float16

        vnus.add(vnu)

    # supress vnus in double
    var
        nduplicate = 0
        index: uint32

    let nVnus = vnus.len
    if debug >= 3: echo "nVnus: ", nVnus

    result.idx = newSeqUninitialized[uint32](nVnus) # preallocate seq is faster

    var vnuTable = initOrderedTable[VerNorUV, uint32]() # () is important
    for i in 0 ..< nVnus:
        let vnu = vnus[i]
        if vnuTable.hasKey(vnu):
            inc(nduplicate)
            index = vnuTable[vnu]
        else:
            if debug >= 3: echo "vnu:{vnu} not in vnuTable:{vnuTable}"
            index = vnuTable.len.uint32
            vnuTable[vnu] = index
        result.idx[i] = index

    let nTable = vnuTable.len
    if debug >= 3: echo "idx.len     : ", result.idx.len
    if debug >= 3: echo "vnuTable.len: ", vnuTable.len

    assert nTable + nduplicate == nVnus

    result.ver = newSeqUninitialized[float32](nTable*3) # preallocate seq is faster
    result.nor = newSeqUninitialized[float32](nTable*3)
    result.uvt = newSeqUninitialized[float32](nTable*2)

    var i = 0
    for vnu in vnuTable.keys:
        for j in 0 ..< 3: result.ver[i*3+j] = vnu[j].toF32
        for j in 0 ..< 3: result.nor[i*3+j] = vnu[j+3].toF32
        for j in 0 ..< 2: result.uvt[i*2+j] = vnu[j+6].toF32
        #echo fmt"{i:3}: vun: ", vnu
        inc(i)

    let nVerBuf = result.ver.len
    let nNorBuf = result.nor.len
    let nUvtBuf = result.uvt.len

    assert nVerBuf.mod(3) == 0 # 3D
    assert nNorBuf.mod(3) == 0 # 3D
    assert nUvtBuf.mod(2) == 0 # 2D

    let nVert = nVerBuf.div(3)
    let nNorm = nNorBuf.div(3)
    let nUvts = nUvtBuf.div(2)

    assert nVert == nTable
    assert nNorm == nTable
    assert nUvts == nTable

    if debug >= 1: echo fmt"Found {nduplicate} duplicates over {nVnus} => ie new size = {(nVert/nVnus)*100.0:.1f} % of initial size"


proc loadOglBufs*(self:ObjLoader; grpsToInclude: seq[string]= @[], grpsToExclude: seq[string]= @[]; debug=1): IndexedBufs =

    let selectedGrps = self.selectGroups(grpsToInclude, grpsToExclude)
    echo "selectedGrps after inclusion and exclusion:", selectedGrps

    if debug >= 1: echo "Analyse OBJ file with FacesGroup"
    self.fill_verts_uvtxs_norms_noIndexed(debug=1)


    if debug >= 2: echo "start merge groups"
    let grpMerged = self.mergesGroups(selectedGrps, debug=3)
    if debug >= 1: echo "grpMerged: ", grpMerged

    result = indexVBOs(grpMerged)

#==============================================================================

when isMainModule:
    from os import getAppFilename, extractFilename, commandLineParams, sleep
    let appName = extractFilename(getAppFilename())
    echo fmt"Begin test {appName}"

    let params = commandLineParams()
    let nParams = params.len

    let nargs = nParams + 1
    var sys_argv: seq[string] = @[appName]
    for param in params: sys_argv.add(param)
    #tlog(1, "sys_argv: " & $sys_argv) # emulation sys.argv

    from objModels import models, printAllModels

    proc printHelpAndQuit() =
        echo "Help:"
        echo fmt"usage: nim c -r {appName}.nim Suzanne"
        echo "args: -dbtx: debug texture to see mesh"
        echo "args: -igtx: ignore texture"
        echo "args: -ig name: include only groups"
        echo "args: -eg name: exclude only groups"
        echo fmt"example: nim c -r {appName}.nim 4 -o 2-model-1 WhipperNude_Head" # "python3.7 tutorial09gwb7b.py 4 -o WhipperNude_Head WhipperNude_Hair WhipperNude_Body WhipperNude_Hands WhipperNude_Feet")
        printAllModels()
        quit()

    let defaultDebugTextureFile = debugTexturePath & "whiteSquareWithColoredEdges.jpg"
    var noTexture        : bool
    var grpsToInclude    : seq[string]
    var grpsToExclude    : seq[string]
    var debugTextureFile = defaultDebugTextureFile
    var debug            = 1
    var ignoreTexture    = false
    var modelName        = "cylindre4" # default model

    if nargs >= 2:
        modelName = sys_argv[1]
        if not modelName.in(models):
            printHelpAndQuit()

        var arg: string
        if nargs >= 3:
            var i = 2
            while i < nargs:
                arg = sys_argv[i]
                echo "arg{i}: '{arg}'"
                if   arg == "-dbtx":
                    debugTextureFile = defaultDebugTextureFile
                elif arg == "-notx": noTexture = true
                elif arg.in(["-ig", "-eg"]):
                    var grps: seq[string]
                    inc(i)
                    while i < nargs and sys_argv[i][0] != '-':
                        grps.add(sys_argv[i])
                        inc(i)
                    if len(grps) == 0: echo "-ig or -og options need one or several name(s) !"; printHelpAndQuit()
                    if   arg == "-ig": grpsToInclude = grps
                    elif arg == "-eg": grpsToExclude = grps
                else: echo "unknown arg: '{arg}'"; printHelpAndQuit()
                inc(i)

    echo fmt"modelName: {modelName}, noTexture: {noTexture}, debugTextureFile: {debugTextureFile}, include:{grpsToInclude}, exclude:{grpsToExclude}"

    let model = getModel(modelName)
    if model == nil:
        echo fmt"{modelName} not in {models}"
        printAllModelNames()
    else:
      echo model

      echo fmt"objPathFile: {model.objPathFile}"

      let objLoader = newObjLoader()
      if not objLoader.loadModel(model,ignoreTexture=ignoreTexture, debugTextureFile=debugTextureFile, check=false, debug=debug, dbgDecountReload=4):
          quit()
      let idxedBufs: IndexedBufs = objLoader.loadOglBufs(grpsToInclude= @[], grpsToExclude= @[], debug=1)
      echo "rangTxFils: ", idxedBufs.rgMtls

    echo fmt"End test {appName}"

    let milsecs = 1000
    sleep(milsecs)
    echo "Bye bye"

