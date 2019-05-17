import core

proc init(core: Core) = 
    core.createAtlas("sprites")
    echo "init done!"

proc update(core: Core) =
    if core.tapped(KEYCODE_ESCAPE):
        core.quit()
    
    core.draw(core$"test", 0, 0, w = 10, h = 10)
    echo "updating"

initCore(init, update, windowTitle = "Fourspire")