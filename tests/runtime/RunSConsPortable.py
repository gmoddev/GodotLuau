"""Run an approved portable SCons tree without modifying a Python installation."""
import sys

Modules = sys.argv.pop(1)
sys.path.insert(0, Modules)
import SCons.Script

SCons.Script.main()
