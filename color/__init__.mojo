# color — the public surface: exactly the seven names below, re-exports
# only (ARCHITECTURE.md, Public Surface). Import from `color` directly
# (`from color import Painter, Style, Color`); the internal layout may move.

from color.attribute import Attribute
from color.color import Color
from color.color_level import ColorLevel
from color.painter import Painter
from color.style import Style
from color.visible import strip_escapes, visible_width
