import tables, parseutils

proc loadAtlas*(filename: string): Table[string, tuple[x: int, y: int, w: int, h: int]] =
    let file = open(filename)
    var line: string

    #header is 5 lines and irrelevant, skip it
    for i in 0..4:
        discard file.readLine(line)

    while file.readLine(line):
        #name of region
        let key = line
        #rotation (ignored)
        discard file.readLine(line)
        #xy
        discard file.readLine(line)
        var x, y : int
        var xyoffset = "  xy: ".len
        xyoffset += line.parseInt(x, xyoffset)
        discard line.parseInt(y, xyoffset + 1)

        #size
        discard file.readLine(line)
        var width, height : int
        var sizeoffset = "  size: ".len
        sizeoffset += line.parseInt(width, sizeoffset)
        discard line.parseInt(height, sizeoffset + 1)

        #origin (ignored)
        discard file.readLine(line)
        #offset (ignored)
        discard file.readLine(line)
        #index (ignored)
        discard file.readLine(line)

        result[key] = (x, y, width, height)
    