#!/usr/bin/env python3
# Runs chenxiaolong/my-avbroot-setup's patch.py with an additional module that
# replaces the boot animation. my-avbroot-setup itself stays unmodified.
#
# Usage: patch_wrapper.py <my-avbroot-setup dir> <patch.py args...>

import sys
from pathlib import Path

setup_dir = Path(sys.argv.pop(1)).resolve()
sys.path.insert(0, str(setup_dir))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from lib import modules  # noqa: E402
from bootanimation_module import BootAnimationModule  # noqa: E402

_orig_all_modules = modules.all_modules
# patch.py looks up modules.all_modules() at call time, so this takes effect
modules.all_modules = lambda: _orig_all_modules() + [BootAnimationModule]

import patch  # noqa: E402

if __name__ == '__main__':
    patch.main()
