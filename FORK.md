# rooted-graphene-9a-stocklogo

Fork of [schnatterer/rooted-graphene](https://github.com/schnatterer/rooted-graphene) for the **Pixel 9a (tegu)**.
It is the same as upstream, except that the GrapheneOS boot animation is replaced by the **stock Google Pixel boot animation**.

## Custota OTA server URLs

* magisk: https://kquote03.github.io/rooted-graphene-9a-stocklogo/magisk
* pixincreate: https://kquote03.github.io/rooted-graphene-9a-stocklogo/pixincreate
* rootless: https://kquote03.github.io/rooted-graphene-9a-stocklogo/rootless

The AVB public key for `fastboot flash avb_custom_key` is `avb_pkmd.bin` on the `gh-pages` branch:
`curl -sLO https://raw.githubusercontent.com/kquote03/rooted-graphene-9a-stocklogo/gh-pages/avb_pkmd.bin`

## Initial installation (Pixel 9a, tested)

The README's sideload-based install doesn't work on the Pixel 9a: recovery fails with `kPostinstallMountError (63)`
(upstream [#313](https://github.com/schnatterer/rooted-graphene/issues/313), [#346](https://github.com/schnatterer/rooted-graphene/issues/346)).
This sequence, based on the workaround in [#338](https://github.com/schnatterer/rooted-graphene/issues/338), works.
Keep the bootloader **unlocked** until the last step, and **never switch slots by hand**: slot b is unbootable until the first OTA.

1. Unlock the bootloader and install the GrapheneOS factory image **with the same version** as the OTA, using the security-preview build
   (`https://releases.grapheneos.org/tegu-install-<version>01.zip`) and `./flash-all.sh`.
   Run `adb kill-server` first, and plug the phone in directly, not through a hub: either can make fastboot hang.
2. Extract **all** partitions and flash them. `--all` is required, because this fork also modifies `product`.
   Without it, `product` doesn't match `vbmeta` and the device shows "Your device is corrupt".
   ```bash
   avbroot ota extract --input <ota>.zip --directory extracted --fastboot --all
   export ANDROID_PRODUCT_OUT=extracted
   fastboot flashall --skip-reboot
   ```
3. Set your AVB key:
   ```bash
   fastboot reboot-bootloader
   fastboot erase avb_custom_key
   fastboot flash avb_custom_key avb_pkmd.bin
   ```
4. Boot once with verification disabled. If you see the "corrupt" warning, press power to continue.
   ```bash
   fastboot --disable-verity --disable-verification flash vbmeta extracted/vbmeta.img
   fastboot reboot
   ```
5. Go back to the bootloader (hold power and volume down), then reflash the dynamic partitions from fastbootd and restore the real vbmeta:
   ```bash
   fastboot reboot fastboot
   for p in product system system_ext system_dlkm vendor vendor_dlkm; do fastboot flash $p extracted/$p.img; done
   fastboot reboot bootloader
   fastboot flash vbmeta extracted/vbmeta.img
   fastboot reboot
   ```
   Press power at the "corrupt" warning again.
6. In GrapheneOS, set the Custota URL (see above). Long-press **Version**, choose **Allow reinstall**, then install and reboot.
   This OTA install clears the bootloader's sticky `avb-hastree-error-mode:eio` flag, which causes the "corrupt" warning,
   and moves the phone to slot b the proper way.
7. Run `fastboot flashing lock`. **Never turn off OEM unlocking** afterwards.

Troubleshooting:
* If a boot fails, check `fastboot getvar slot-retry-count:a`. `fastboot --set-active=a` resets the counter without switching slots.
* The bootloader stays reachable throughout, so GrapheneOS's `flash-all.sh` always gets you back to a working phone.
* Disable the System Updater app, or block its network access.

## What differs from upstream

* `bootanimation/bootanimation.zip`: the stock boot animation, extracted from Google's official tegu OTA (see `bootanimation/SOURCE`).
* `bootanimation/bootanimation_module.py`: a [my-avbroot-setup](https://github.com/chenxiaolong/my-avbroot-setup) module that overwrites GrapheneOS's `bootanimation.zip`.
* `bootanimation/patch_wrapper.py`: runs my-avbroot-setup's `patch.py` with that module registered (my-avbroot-setup itself is left unmodified).
* `rooted-ota.sh`: passes `--bootanimation` and calls the wrapper. Set `BOOTANIMATION_ZIP=` (empty) to keep the GrapheneOS animation.
* `.github/workflows/release-single.yaml`: `skip-pixincreate` can also be set via `workflow_call`.
* `.github/workflows/release-tegu.yaml`: checks for new GrapheneOS releases every 6 hours and builds the magisk, pixincreate and rootless flavors.
* `.github/workflows/sync-upstream.yaml`: merges upstream `main` every night, then triggers a release.
  If the merge conflicts, the workflow fails and you resolve it by hand:
  `git remote add upstream https://github.com/schnatterer/rooted-graphene.git; git fetch upstream; git merge upstream/main`.
* Renovate is disabled in this repo. Dependency updates arrive through the upstream sync.

## Refreshing the stock boot animation

```bash
DEVICE_ID=tegu bootanimation/extract-stock-bootanimation.sh
git add bootanimation && git commit -m "Update stock boot animation"
```

## Secrets

`KEY_AVB_BASE64`, `KEY_OTA_BASE64`, `CERT_OTA_BASE64`, `PASSPHRASE_AVB`, `PASSPHRASE_OTA` (see the README)
and `SYNC_TOKEN`, a fine-grained PAT for this repo with Contents, Workflows and Actions set to read/write.
