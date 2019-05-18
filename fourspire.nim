import core

const speed = 20.0
var x = 0.0
var y = 0.0

#pack atlas when compiling
when not defined(release):
    const result = staticExec("java -jar tools/texturepacker.jar sprites/ assets/ sprites.atlas")
    echo "Packed sprites: \n" & result

proc init(core: Core) = 
    core.createAtlas()
    core.clearColor = %"d1dadd"

proc update(core: Core) =
    if core.tapped(KEYCODE_ESCAPE):
        core.quit()
    
    if core.down(KEYCODE_W): y += speed
    if core.down(KEYCODE_A): x -= speed
    if core.down(KEYCODE_S): y -= speed
    if core.down(KEYCODE_D): x += speed
    
    core.draw(core$"test", x, y)

initCore(init, update, windowTitle = "Fourspire")