
from strformat import fmt

#from opengl import GL_TRUE, GL_COMPILE_STATUS, GL_VERTEX_SHADER, GL_FRAGMENT_SHADER, glCreateShader, glShaderSource, glCompileShader, glGetShaderiv, glGetShaderInfoLog, GLsizei

import nimgl/opengl

type Shaders* = tuple[vert, frag: uint32]

proc statusShader*(shader: uint32) =
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


proc createShader*(shadersName:string; typ:string; shads: var Shaders) =
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
    glShaderSource(shadId, 1, cText.addr, nil) # for nimgl-1.1.4
    glCompileShader(shadId)
    statusShader(shadId)

#---------------------------------------------------
proc createShadersName*(shadersName:string): Shaders =
    var shads: Shaders

    createShader(shadersName, "vertex", shads)
    createShader(shadersName, "fragmt", shads)

    return shads


