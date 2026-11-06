"""Run the actual Player.Character Luau controller in the existing isolated harness."""
from RunInputController import Main
from FixtureProcesses import StopAll

if __name__=='__main__':
    try:
        Main('PlayerController.gd','[Character:Controller] server PASS',('--character-mode','Local'),True)
    finally:
        StopAll()
