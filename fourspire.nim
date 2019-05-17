import core

proc init(core: Core) = 
    core.createAtlas("atlas")
    echo "init done!"

proc update(core: Core) =
    if core.tapped(KEYCODE_ESCAPE):
        core.quit()
    
    echo "updating"

initCore(init, update, windowTitle = "Fourspire")