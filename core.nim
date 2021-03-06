import sdl2, sdl2/image, tables, parseutils, streams, strutils

const assetsFolder = "assets/"

# INTERNALS

#IO

template staticReadRW(filename: string): ptr RWops =
    const file = staticRead(filename)
    rwFromConstMem(file.cstring, file.len)
  
template staticReadStream(filename: string): string =
    const file = staticRead(filename)
    newStringStream(file)

template staticReadString(filename: string): string = 
    const str = staticRead(filename)
    str

#math

#TODO should this be kept...?
type Vec2* = object
    x, y: float32

#graphics

#defines a color
type Col* = object
    r*, g*, b*, a*: uint8

#converts a hex string to a color
export parseHexInt
template `%`*(str: string): Col =
    Col(r: str[0..1].parseHexInt().uint8, g: str[2..3].parseHexInt().uint8, b: str[4..5].parseHexInt().uint8, a: 255)

type Camera* = ref object
    x, y, w, h: float32

##defines a texture region type
type Tex* = object
    texture: TexturePtr
    region: Rect

proc x*(tex: Tex): int {.inline.} = tex.region.x.int
proc y*(tex: Tex): int {.inline.} = tex.region.y.int
proc w*(tex: Tex): int {.inline.} = tex.region.w.int
proc h*(tex: Tex): int {.inline.} = tex.region.h.int

type Align* = enum
    alignTop, alignBot, alignLeft, alignRight, alignCenter, 
    alignBotLeft, alignTopLeft, alignBotRight, alignTopRight

#core engine

template sdlFailIf(cond: typed, reason: string) =
    if cond: raise Exception.newException(reason & ", SDL error: " & $getError())

type KeyCode* = enum
    KEYCODE_A = 4, KEYCODE_B = 5, KEYCODE_C = 6, KEYCODE_D = 7, KEYCODE_E = 8, KEYCODE_F = 9,
    KEYCODE_G = 10, KEYCODE_H = 11, KEYCODE_I = 12, KEYCODE_J = 13, KEYCODE_K = 14, KEYCODE_L = 15, KEYCODE_M = 16, KEYCODE_N = 17, KEYCODE_O = 18,
    KEYCODE_P = 19, KEYCODE_Q = 20, KEYCODE_R = 21, KEYCODE_S = 22, KEYCODE_T = 23, KEYCODE_U = 24,
    KEYCODE_V = 25, KEYCODE_W = 26, KEYCODE_X = 27, KEYCODE_Y = 28, KEYCODE_Z = 29, KEYCODE_1 = 30,
    KEYCODE_2 = 31, KEYCODE_3 = 32, KEYCODE_4 = 33, KEYCODE_5 = 34, KEYCODE_6 = 35, KEYCODE_7 = 36,
    KEYCODE_8 = 37, KEYCODE_9 = 38, KEYCODE_0 = 39, KEYCODE_RETURN = 40, KEYCODE_ESCAPE = 41,
    KEYCODE_BACKSPACE = 42, KEYCODE_TAB = 43, KEYCODE_SPACE = 44, KEYCODE_MINUS = 45,
    KEYCODE_EQUALS = 46, KEYCODE_LEFTBRACKET = 47, KEYCODE_RIGHTBRACKET = 48, KEYCODE_BACKSLASH = 49,
    KEYCODE_SEMICOLON = 51, KEYCODE_APOSTROPHE = 52, KEYCODE_GRAVE = 53, KEYCODE_COMMA = 54, KEYCODE_PERIOD = 55,
    KEYCODE_SLASH = 56, KEYCODE_CAPSLOCK = 57, KEYCODE_F1 = 58, KEYCODE_F2 = 59, KEYCODE_F3 = 60, KEYCODE_F4 = 61,
    KEYCODE_F5 = 62, KEYCODE_F6 = 63, KEYCODE_F7 = 64, KEYCODE_F8 = 65, KEYCODE_F9 = 66, KEYCODE_F10 = 67,
    KEYCODE_F11 = 68, KEYCODE_F12 = 69, KEYCODE_PRINTSCREEN = 70, KEYCODE_SCROLLLOCK = 71,
    KEYCODE_PAUSE = 72, KEYCODE_INSERT = 73, KEYCODE_HOME = 74, KEYCODE_PAGEUP = 75,
    KEYCODE_DELETE = 76, KEYCODE_END = 77, KEYCODE_PAGEDOWN = 78, KEYCODE_RIGHT = 79,
    KEYCODE_LEFT = 80, KEYCODE_DOWN = 81, KEYCODE_UP = 82

type Core* = ref object
    #input
    pressed: array[SDL_NUM_SCANCODES.int, bool]
    justDown: array[SDL_NUM_SCANCODES.int, bool]
    justUp: array[SDL_NUM_SCANCODES.int, bool]

    #rendering
    window: WindowPtr
    renderer: RendererPtr
    cam*: Camera
    atlas: Table[string, Tex]
    clearColor*: Col

    #core loop stuff
    running: bool

proc beginUpdate(core: Core) =
    #poll input
    var event = defaultEvent
    while pollEvent(event):
        case event.kind
        of QuitEvent:
            core.running = false
        of KeyDown:
            core.pressed[event.key.keysym.scancode.int] = true
            core.justDown[event.key.keysym.scancode.int] = true
        of KeyUp:
            core.pressed[event.key.keysym.scancode.int] = false
            core.justUp[event.key.keysym.scancode.int] = true
        else:
            discard

    core.renderer.setDrawColor(core.clearColor.r, core.clearColor.g, core.clearColor.b, core.clearColor.a)
    #clear screen with the specified clear color
    core.renderer.clear()
    #reset to default color now
    core.renderer.setDrawColor(1, 1, 1, 1)
    

proc endUpdate(core: Core) = 
    #present everything rendered
    core.renderer.present()

    #clean up input after rendering
    for x in core.justDown.mitems: x = false
    for x in core.justUp.mitems: x = false

#external functions for use by outside classes

proc initCore*(initProc: proc(core: Core), loopProc: proc(core: Core), windowWidth = 800, windowHeight = 600, windowTitle = "Unknown") =

    sdlFailIf(not sdl2.init(INIT_VIDEO or INIT_TIMER or INIT_EVENTS)): "SDL2 initialization failed"
    defer: sdl2.quit()
    
    let window = createWindow(title = windowTitle, x = SDL_WINDOWPOS_CENTERED, y = SDL_WINDOWPOS_CENTERED, w = windowWidth.cint, h = windowHeight.cint, flags = SDL_WINDOW_SHOWN or SDL_WINDOW_RESIZABLE or SDL_WINDOW_MAXIMIZED)
    sdlFailIf window.isNil: "Window could not be created"
    defer: window.destroy()
    
    let renderer = window.createRenderer(index = -1, flags = Renderer_Accelerated or Renderer_PresentVsync)
    sdlFailIf renderer.isNil: "Renderer could not be created"
    defer: renderer.destroy()

    sdlFailIf(image.init(IMG_INIT_PNG) != IMG_INIT_PNG):  "SDL2 Image initialization failed"
    defer: image.quit()

    let core = Core(window: window, renderer: renderer, running: true)
    core.cam = Camera(x: 0, y: 0, w: 0, h: 0)
    core.clearColor = Col(r: 0, g: 0, b: 0, a: 255)
    
    initProc(core)

    while core.running:
        core.beginUpdate()
        loopProc(core)
        core.endUpdate()

#stops the game, does not quit immediately
proc quit*(core: Core) = core.running = false

#input

#returns window size
proc screen(core: Core): tuple[w: int, h: int] {.inline.} = 
    var w, h: cint
    core.window.getSize(w, h)
    return (w.int, h.int)

#returns mouse position in Y-up coordinates
proc mouse*(core: Core): (int, int) {.inline.} = 
    var mouseX, mouseY: cint
    getMouseState(mouseX, mouseY)
    (mouseX.int, core.screen.h - 1 - mouseY.int)

proc down*(core: Core, key: KeyCode): bool {.inline.} = core.pressed[ord(key)]
proc tapped*(core: Core, key: KeyCode): bool {.inline.} = core.justDown[ord(key)]
proc released*(core: Core, key: KeyCode): bool {.inline.} = core.justUp[ord(key)]

#graphics

proc `color=`*(core: Core, value: Col) {.inline.} =
    core.renderer.setDrawColor(value.r, value.g, value.b, value.a)

#returns a texture region by name
proc `$`*(core: Core, name: string): Tex = 
    return core.atlas.getOrDefault(name, core.atlas["error"])

#parse an atlas from a string
proc loadAtlas(atlas: string): Table[string, tuple[x: int, y: int, w: int, h: int]] =
    result = initTable[string, tuple[x: int, y: int, w: int, h: int]]()
    let lines = splitLines(atlas)
    var index = 6

    while index < lines.len - 1:
        #name of region
        var key = lines[index]
        index += 2
        #xy
        var numbers = lines[index]
        var x, y : int
        var xyoffset = "  xy: ".len
        xyoffset += numbers.parseInt(x, xyoffset)
        discard numbers.parseInt(y, xyoffset + 2)
        index += 1

        #size
        var sizes = lines[index]
        var width, height : int
        var sizeoffset = "  size: ".len
        sizeoffset += sizes.parseInt(width, sizeoffset)
        discard sizes.parseInt(height, sizeoffset + 2)
        index += 4

        result[key] = (x, y, width, height)

#loads 'sprites.atlas' into the core
#TODO: remove and load implicitly
proc createAtlas*(core: Core) =
    let atlasTex = core.renderer.loadTextureRW(staticReadRW(assetsFolder & "sprites.png"), freesrc = 1)
    let map = loadAtlas(staticReadString(assetsFolder & "sprites.atlas"))
    core.atlas = initTable[string, Tex]()
    for key, val in map.pairs:
        core.atlas[key] = Tex(texture: atlasTex, region: rect(val.x.cint, val.y.cint, val.w.cint, val.h.cint))
    
proc draw*(core: Core, tex: Tex, x: float32, y: float32, w: float32 = 0, h: float32 = 0, rotation: float32 = 0) = 
    #this sets up default values for w/h if not provided; 0 mean 'use tex size'
    var fw = if w == 0: tex.w.toFloat else: w
    var fh = if h == 0: tex.h.toFloat else: h
    var r1 = tex.region
    var r2 =  rect((x - fw/2.0 + core.cam.x + core.screen.w/2).cint, (-y - fh/2.0 + core.cam.y + core.screen.h/2).cint, fw.cint, fh.cint)
    var p = point(fw/2.0, fh/2.0)
    core.renderer.copyEx(tex.texture, r1, r2, angle = rotation, center = p.addr, flip = SDL_FLIP_NONE)