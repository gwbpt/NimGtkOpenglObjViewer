
import strformat
from sequtils import repeat
from strutils import toLower

const NL = "\p"
const SQ = "'"[0]

import Tables

import os

type
    Model* = ref object of RootObj
        name*: string
        objPath*, objFile*, objPathFile*, texFile*, texPathFile* : string
        swapYZ*, normalize*, fast*: bool
        bgRGB*: array[3, float]
        info* : string
        ignoreObjs*: seq[string]

proc addIndexToFileName(fName: string; index:int): string =
    echo fmt"addIndexToFileName({result}, index:{index}"
    assert index > 0
    var (dir, name, ext) = splitFile(fName)
    #echo fmt"dir:{dir}, name:{name}, ext:{ext}"
    name &= $index
    #echo fmt"dir:{dir}, name:{name}, ext:{ext}"
    result = joinPath([dir, name]) & ext
    echo fmt"addIndexToFileName ->: {result}"

proc newModel(name:string; objPathFile:seq[string]; texPathFile:seq[string]= @[]; fileIndex=0; bgRGB: array[3, float]=[0.4, 0.4, 0.9]; normalize=false; swapYZ=false, info="", ignoreObjs: seq[string]= @[]): Model =
    result = new Model
    result.name = name
    var
        objPathFil = objPathFile
        texPathFil = texPathFile

    if fileIndex > 0:
        objPathFil[^1] = addIndexToFileName(objPathFil[^1], fileIndex)
        if texPathFil.len > 0:
            texPathFil[^1] = addIndexToFileName(texPathFil[^1], fileIndex)

    result.objPath     = joinPath(objPathFil[0 ..< ^1])
    result.objFile     = objPathFil[^1]
    result.objPathFile = joinPath(objPathFil)
    #echo fmt"result.objPathFile: {result.objPathFile}"

    result.texFile     = if texPathFil.len == 0: "" else: texPathFil[^1]
    result.texPathFile = if texPathFil.len == 0: "" else: joinPath(texPathFil)

    result.swapYZ     = swapYZ
    result.bgRGB      = bgRGB
    result.info       = info
    result.ignoreObjs = ignoreObjs
    result.normalize  = normalize
    result.fast       = true

proc `$`*(self: Model): string =
    result  = fmt"Model {SQ & self.name & SQ:20}:"
    result &= fmt"{NL}objPath:'{self.objPath:24}', objFile:'{self.objFile:24}', objPathFile:'{self.objPathFile}'"
    if self.texFile.len > 0:result &= fmt"{NL}{self.texFile:24} in {self.texPathFile}"
    #result &= "{NL}Initial rotation X,Y,Z:%6.3f,%6.3f,%6.3f"%(self.radX*RAD2DEG, self.radY*RAD2DEG, self.radZ*RAD2DEG)
    #result &= "{NL}Initial rotSpeed X,Y,Z:%6.3f,%6.3f,%6.3f"%(self.dRadX*RAD2DEG, self.dRadY*RAD2DEG, self.dRadZ*RAD2DEG)
    #result &= "{NL}normalize:%s, fast:%s"%(self.normalize, self.fast)
    result &= fmt"{NL}swapYZ:{self.swapYZ}, bgRGB:{self.bgRGB}"
    if self.info != "" : result &= NL & self.info
    result &= NL

#----------------------- fill datas ------------------------------

type Models* = OrderedTable[string, Model]

var models*: Models
models = initOrderedTable[string, Model]() # () is important = dict()

proc getModel*(modelName:string): Model =
    let nameLower = modelName.toLower
    if nameLower.in(models):
        result = models[nameLower]

var mdl: Model

mdl = newModel(name     = "Cylindre3",
            objPathFile = @["TestObjs", "cylindre3.obj"],
      )
models[mdl.name.toLower] = mdl

mdl = newModel(name     = "Cylindre4",
            objPathFile = @["TestObjs", "cylindre4.obj"],
      )
models[mdl.name.toLower] = mdl

mdl = newModel(name     = "Cylindre6",
            objPathFile = @["TestObjs", "cylindre6.obj"],
      )
models[mdl.name.toLower] = mdl

mdl = newModel(name     = "Cylindre8",
            objPathFile = @["TestObjs", "cylindre8.obj"],
      )
models[mdl.name.toLower] = mdl

mdl = newModel(name     = "House",
            objPathFile = @["Buildings", "ordinary-house", "house.obj"],
            normalize   = true,
            info        = "  xxxx faces,   xxx vertexs"
      )
models[mdl.name.toLower] = mdl

mdl = newModel(name     = "Head",
            objPathFile = @["Humans", "realistic-lowpoly-head", "head.obj"],
            normalize   = true,
            info        = "    xxx faces,     xxx vertexs"
      )
models[mdl.name.toLower] = mdl

mdl = newModel(name     = "Man",
            objPathFile = @["Humans", "man", "man.obj"],
            bgRGB       = [0.1, 0.1, 0.4],  # dark blue
            info        = "  x faces,    x vertexs"
      )
models[mdl.name.toLower] = mdl

mdl = newModel(name     = "Earth1",
            objPathFile = @["Earth1", "earth.obj"],
            bgRGB       = [0.1, 0.1, 0.4],  # dark blue
            info        = "  x faces,    x vertexs"
      )
models[mdl.name.toLower] = mdl


proc printAllModels*(models=models) =
    let sepLin = "--------------------------------------------------------------" # '-'.repeat(15) not working
    echo sepLin
    for name, mdl in models.pairs:
        echo $mdl
    echo sepLin

proc printAllModelNames*(models=models) =
    echo "names no sensitive to case"
    for name, mdl in models.pairs:
        echo mdl.name

#==============================================================================

when isMainModule:
    from os import getAppFilename, extractFilename, commandLineParams, sleep
    let appName = extractFilename(getAppFilename())
    echo fmt"Begin test {appName}"

    let params = commandLineParams()
    let nParams = params.len

    let modelName = if nParams >= 1: params[0] else: "head"
    #if modelName.in(models): # OK
    let model = getModel(modelName)
    if model == nil:
        echo fmt"{modelName} not in {models}"
        printAllModelNames()
    else:
      echo model
    echo fmt"End test {appName}"

