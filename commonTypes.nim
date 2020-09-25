
iterator items1in1out*[T](ins0: openArray[T]; outs0: var openArray[T]): (T, ptr T) {.inline.} =
    let n = len(ins0)
    assert len(outs0) == n
    var i = 0
    while i < n:
        yield (ins0[i], outs0[i].addr)
        inc(i)

iterator items2in1out*[T](ins0, ins1: openArray[T]; outs0: var openArray[T]): (T, T, ptr T) {.inline.} =
    let n = len(ins0)
    assert len(ins1)  == n
    assert len(outs0) == n
    var i = 0
    while i < n:
        yield (ins0[i], ins1[i], outs0[i].addr)
        inc(i)

iterator items1in2out*[T](ins0: openArray[T]; outs0, outs1: var openArray[T]): (T, ptr T, ptr T) {.inline.} =
    let n = len(ins0)
    assert len(outs0) == n
    assert len(outs1) == n
    var i = 0
    while i < n:
        yield (ins0[i], outs0[i].addr, outs1[i].addr)
        inc(i)

iterator items2in2out*[T](ins0, ins1: openArray[T]; outs0, outs1: var openArray[T]): (T, T, ptr T, ptr T) {.inline.} =
    let n = len(ins0)
    assert len(ins1)  == n
    assert len(outs0) == n
    assert len(outs1) == n
    var i = 0
    while i < n:
        yield (ins0[i], ins1[i], outs0[i].addr, outs1[i].addr)
        inc(i)

iterator items3in2out*[T](ins0, ins1, ins2: openArray[T]; outs0, outs1: var openArray[T]): (T, T, T, ptr T, ptr T) {.inline.} =
    let n = len(ins0)
    assert len(ins1)  == n
    assert len(ins2)  == n
    assert len(outs0) == n
    assert len(outs1) == n
    var i = 0
    while i < n:
        yield (ins0[i], ins1[i], ins2[i], outs0[i].addr, outs1[i].addr)
        inc(i)

iterator itemsInsOuts*[T](ins: seq[openArray[T]]; outs: var seq[openArray[T]]): (seq[T], seq[ptr T]) {.inline.} =
    let n = len(ins[0])
    for inx  in ins[1 .. ^1] : assert len(inx)  == n
    for outx in outs[1 .. ^1]: assert len(outx) == n
    var i = 0
    while i < n:
        var inSeq: seq[T]
        for inx in ins: inSeq.add(inx[i])
        var outSeq: seq[ptr T]
        for outx in outs: inSeq.add(outx[i].addr)
        yield (inSeq, outSeq)
        inc(i)

# usage example:
proc addArrays(ins0, ins1:openArray[float]; outs0: var openArray[float]) =
    for in0, in1, out0 in items2in1out(ins0, ins1, outs0):
        out0[] = in0 + in1

const NL* = "\p"
const TAB* = '\t'

const Obj3D_path*  = "Obj3D/" # "../../../"
const debugTexturePath* = Obj3D_path & "DebugTextures/"

from fenv import maximumPositiveValue
import glm

proc setTo*[N,T](vec: var Vec[N,T], val: T) =
    for i in 0 ..< N:
        vec[i] = val

proc reset*[N,T](vec: var Vec[N,T]) =
    let zero: T = 0.T
    vec.setTo(zero)

proc setToOne*[N,T](vec: var Vec[N,T]) =
    let one: T = 1.T
    vec.setTo(one)

# unary operators
proc min*[N,T](v: Vec[N,T]): T =
    result = T.maximumPositiveValue
    for i in 0 ..< N:
        result = min(result, v.arr[i])

proc max*[N,T](v: Vec[N,T]): T =
    result = -T.maximumPositiveValue
    for i in 0 ..< N:
        result = max(result, v.arr[i])


#from math import sqrt

import strformat
import strutils, parseutils

from sequtils import repeat
from sugar    import collect

const
    maxF32 = float32.maximumPositiveValue
    minF32 = - maxF32
    MaxFloat3 = vec3f(maxF32, maxF32, maxF32)
    MinFloat3 = vec3f(minF32, minF32, minF32)
#echo "MaxFloat3 :", MaxFloat3
#echo "MinFloat3 :", MinFloat3

proc `$`*(f3:Vec3f): string =
    result = fmt"({f3[0]:6.3f}, {f3[1]:6.3f}, {f3[2]:6.3f})"

func vdiv*(v3: Vec3f, d: float32): Vec3f = result = glm.vec3f(v3[0]/d, v3[1]/d, v3[2]/d)

proc xyzsMinMax*(xyzs: seq[Vec3f]) : (Vec3f, Vec3f) =
    result[0] = MaxFloat3 # init to max possible to store the min of all xyzs
    result[1] = MinFloat3 # init to min possible to store the max of all xyzs

    for f3 in xyzs:
        result[0] = min(result[0], f3)
        result[1] = max(result[1], f3)
        #[for f, fMin, fMax in items1in2out(f3, result[0], result[1]):
            fMin[] = min(fMin[], f)
            fMax[] = max(fMax[], f)
        ]#

proc centerScalePos_inpl*(xyzs: var seq[Vec3f]; center:Vec3f; scale=1.0'f32, pos:Vec3f) = # InPlace
    var pos_center : Vec3f
    for i in 0 ..< 3:
        pos_center[i] = pos[i] - center[i] * scale

    for f3 in xyzs.mitems :    # or mitems(verts):
        for i in 0 ..< 3:
          f3[i] *= scale
          f3[i] += pos_center[i]

#-----------------------------------------------------------------

type
    TypVec* = enum
        vert, norm, uvtx

#[
type VerNor*   =  array[6, float32] # 3 + 3
proc `$`*(vnu:VerNor): string =
    result  = NL & fmt"({vnu[0]:6.3f}, {vnu[1]:6.3f}, {vnu[2]:6.3f})"
    result &=    fmt", ({vnu[3]:6.3f}, {vnu[4]:6.3f}, {vnu[5]:6.3f})"

type VerNorUV* =  array[8, float32] # 3 + 3 + 2
proc `$`*(vnu:VerNorUV): string =
    result  = NL & fmt"({vnu[0]:6.3f}, {vnu[1]:6.3f}, {vnu[2]:6.3f})"
    result &=    fmt", ({vnu[3]:6.3f}, {vnu[4]:6.3f}, {vnu[5]:6.3f})"
    result &=    fmt", ({vnu[6]:6.3f}, {vnu[7]:6.3f})"
]#
#==============================================================================

when isMainModule:
    var v3 = vec3f(1.0, -4.0, 2.0 ) # ie glm.vec3(1.0'f32, -4.0'f32, 2.0'f32 )
    echo "min_max of ", v3, (v3.min, v3.max)

