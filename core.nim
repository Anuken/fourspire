import sdl2, sdl2/image, atlas, tables

# INTERNALS

#math

#TODO should this be kept...?
type vec2* = object
    x, y: float32

#graphics

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

    #clear screen with the default color
    core.renderer.clear()
    

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
    
    renderer.setDrawColor(0, 0, 0)
    initProc(core)

    while core.running:
        core.beginUpdate()
        loopProc(core)
        core.endUpdate()

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

proc `$`*(core: Core, name: string): Tex = 
    return core.atlas.getOrDefault(name, core.atlas["error"])

proc createAtlas*(core: Core, name: string) =
    let atlasTex = core.renderer.loadTexture(name & ".png")
    let map = loadAtlas(name & ".atlas")
    for key, val in map.pairs:
        core.atlas[key] = Tex(texture: atlasTex, region: rect(val.x.cint, val.y.cint, val.w.cint, val.h.cint))
    
proc draw*(core: Core, tex: Tex, x: float32, y: float32, w: float32 = tex.w.toFloat, h: float32 = tex.h.toFloat, rotation: float32 = 0) = 
    #[
    if rotation == 0.0 and not flipx and not flipy:
        #simple copy, no rotation or flip
        var r1 = tex.region
        var r2 = rect((x - w/2.0).cint, (y - h/2.0).cint, w.cint, h.cint)
        core.renderer.copy(tex.texture, r1.addr, r2.addr)
    else:]#
    #advanced copyEx stuff
    var r1 = tex.region
    var r2 =  rect((x - w/2.0 + core.cam.x + core.screen.w/2).cint, (-y - h/2.0 + core.cam.y + core.screen.h/2).cint, w.cint, h.cint)
    var p = point(w/2.0, h/2.0)
    core.renderer.copyEx(tex.texture, r1, r2, angle = rotation, center = p.addr, flip = SDL_FLIP_NONE)