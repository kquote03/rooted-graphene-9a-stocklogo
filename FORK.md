# rooted-graphene-9a-stocklogo

Fork of [schnatterer/rooted-graphene](https://github.com/schnatterer/rooted-graphene) for the **Pixel 9a (tegu)**.
It is the same as upstream, except that the GrapheneOS boot animation is replaced by the **stock Google Pixel boot animation**.

## Custota OTA server URLs

* magisk: https://kquote03.github.io/rooted-graphene-9a-stocklogo/magisk
* pixincreate: https://kquote03.github.io/rooted-graphene-9a-stocklogo/pixincreate
* rootless: https://kquote03.github.io/rooted-graphene-9a-stocklogo/rootless

The AVB public key for `fastboot flash avb_custom_key` is `avb_pkmd.bin` on the `gh-pages` branch:
`curl -sLO https://raw.githubusercontent.com/kquote03/rooted-graphene-9a-stocklogo/gh-pages/avb_pkmd.bin`

Apart from that, follow the installation steps in the [README](README.md), with one change:

> ⚠️ This fork also modifies the `product` partition, so when extracting the OTA for the initial installation you **must** add `--all`:
> ```bash
> avbroot ota extract --input /path/to/ota.zip --directory extracted --fastboot --all
> ```
> Without it, `product` is not flashed, the stock GrapheneOS `product` doesn't match the patched `vbmeta`, and the device shows "Your device is corrupt".

> ⚠️ On the Pixel 9a, `adb sideload` in recovery fails with `kPostinstallMountError (63)` (upstream [#313](https://github.com/schnatterer/rooted-graphene/issues/313), [#346](https://github.com/schnatterer/rooted-graphene/issues/346)), so the sideload step can't clear "device is corrupt".
> Instead, use the workaround from [#338](https://github.com/schnatterer/rooted-graphene/issues/338) (bootloader still unlocked, never switch slots):
> 1. `fastboot flashall --skip-reboot` (with `ANDROID_PRODUCT_OUT=extracted`, extracted with `--all`)
> 2. `fastboot reboot-bootloader && fastboot --disable-verity --disable-verification flash vbmeta extracted/vbmeta.img && fastboot reboot`, and let it boot to setup
> 3. Back in the bootloader: `fastboot reboot fastboot`, then `fastboot flash <p> extracted/<p>.img` for product, system, system_ext, system_dlkm, vendor and vendor_dlkm
> 4. `fastboot reboot bootloader && fastboot flash vbmeta extracted/vbmeta.img && fastboot reboot`
> 5. Test an update through Custota (long-press Version, Allow reinstall) before you run `fastboot flashing lock`.

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
