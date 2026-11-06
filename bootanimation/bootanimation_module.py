# my-avbroot-setup module that replaces the boot animation.
# GrapheneOS ships /product/media/bootanimation.zip (bootanimation-dark.zip is a symlink to it).

import argparse
from collections.abc import Iterable
import logging
from pathlib import Path
import shutil
from typing import override

from lib import modules
from lib.filesystem import CpioFs, ExtFs
from lib.modules import Module, ModuleRequirements


logger = logging.getLogger(__name__)

# (partition image, path inside image)
CANDIDATES = [
    ('product', 'media/bootanimation.zip'),
    ('system', 'system/product/media/bootanimation.zip'),
    ('system', 'system/media/bootanimation.zip'),
]


class BootAnimationModule(Module):
    @classmethod
    @override
    def add_args(cls, parser: argparse.ArgumentParser):
        parser.add_argument(
            '--bootanimation',
            type=Path,
            help='bootanimation.zip to replace the existing boot animation with',
        )

    def __init__(self, args: argparse.Namespace) -> None:
        if args.bootanimation is None:
            raise modules.MissingArgs()
        self.zip: Path = args.bootanimation

    @override
    def requirements(self) -> ModuleRequirements:
        return ModuleRequirements(
            boot_images=set(),
            ext_images={'system', 'product'},
            selinux_patching=False,
        )

    @override
    def inject(
        self,
        boot_fs: dict[str, CpioFs],
        ext_fs: dict[str, ExtFs],
        sepolicies: Iterable[Path],
    ) -> None:
        replaced = False

        for image, path in CANDIDATES:
            fs = ext_fs[image]
            entry = fs._find(fs._get_paths(path)[0])
            if entry is None or entry.file_type != 'RegularFile':
                continue

            logger.info(f'Replacing boot animation {image}:/{path} with {self.zip}')
            # Existing entry keeps its mode, owner and SELinux label
            with fs.open(path, 'wb') as f_out, open(self.zip, 'rb') as f_in:
                shutil.copyfileobj(f_in, f_out)
            replaced = True

        if not replaced:
            path = 'system/media/bootanimation.zip'
            logger.info(f'No existing boot animation found, adding system:/{path}')
            fs = ext_fs['system']
            fs.mkdir('system/media', parents=True, exist_ok=True)
            with fs.open(path, 'wb') as f_out, open(self.zip, 'rb') as f_in:
                shutil.copyfileobj(f_in, f_out)
