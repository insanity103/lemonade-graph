"""Syntax-check the deliberately Lua-compatible handoff subset without running it.

This uses the system Lua 5.4 parser, not a Roblox runtime or a Luau type checker.
"""
import ctypes
import ctypes.util
from pathlib import Path

root=Path(__file__).resolve().parents[1]/'assets'/'map_redesign'
lua=ctypes.CDLL(ctypes.util.find_library('lua5.4'))
lua.luaL_newstate.restype=ctypes.c_void_p
lua.luaL_loadfilex.argtypes=[ctypes.c_void_p,ctypes.c_char_p,ctypes.c_char_p]
lua.luaL_loadfilex.restype=ctypes.c_int
lua.lua_tolstring.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_void_p]
lua.lua_tolstring.restype=ctypes.c_char_p
lua.lua_close.argtypes=[ctypes.c_void_p]
files=list((root/'integration').glob('*.luau'))+[root/'MapAnchors.luau',root/'CollisionLayout.luau']
errors=[]
for path in files:
    state=lua.luaL_newstate()
    try:
        result=lua.luaL_loadfilex(state,str(path).encode(),None)
        if result:errors.append((path.name,lua.lua_tolstring(state,-1,None).decode()))
    finally:lua.lua_close(state)
assert not errors,errors
print(f'{len(files)} Lua-compatible handoff files parsed successfully; Roblox runtime not tested.')
