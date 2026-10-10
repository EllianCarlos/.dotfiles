local c = { root="#0A0A09", panel="#121211", raised="#1A1A18", border="#33332F", muted="#8C8C84", text="#E8E8E3", void="#000000", yellow="#FFD400", green="#5AF78E", cyan="#5EDFFF", magenta="#FF6AC1", red="#FF5C57" }
local function mode(bg) return { a = { fg = c.void, bg = bg, gui = "bold" }, b = { fg = c.text, bg = c.raised }, c = { fg = c.muted, bg = c.root } } end
return {
  normal = mode(c.yellow),
  insert = mode(c.green),
  visual = mode(c.magenta),
  replace = mode(c.red),
  command = mode(c.cyan),
  inactive = { a = { fg = c.muted, bg = c.root }, b = { fg = c.muted, bg = c.root }, c = { fg = c.muted, bg = c.root } },
}
