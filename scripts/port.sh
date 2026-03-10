#!/usr/bin/env bash
set -euo pipefail
WORKDIR="$1"
DENSITY="$2"

STOCK="$WORKDIR/stock"
DONOR="$WORKDIR/donor"
TMP="$WORKDIR/tmp"

mkdir -p "$TMP/mounts" "$TMP/unpacked_stock" "$TMP/unpacked_donor"

# Helper: convert sparse -> raw if needed
convert_img() {
  local src="$1" dst="$2"
  if file "$src" | grep -q 'Android sparse'; then
    simg2img "$src" "$dst"
  else
    cp -v "$src" "$dst"
  fi
}

# 3. Распаковать .img файлы (product, system, system_ext, mi_ext)
# Convert and mount each image into unpacked dirs
for part in product system system_ext mi_ext vendor odm; do
  src_stock="$STOCK/${part}.img"
  src_donor="$DONOR/${part}.img"
  if [ -f "$src_stock" ]; then
    dst="$TMP/unpacked_stock/${part}.img.raw"
    convert_img "$src_stock" "$dst"
    mkdir -p "$TMP/mounts/stock_${part}"
    sudo mount -o loop,ro "$dst" "$TMP/mounts/stock_${part}" || true
  fi
  if [ -f "$src_donor" ]; then
    dst="$TMP/unpacked_donor/${part}.img.raw"
    convert_img "$src_donor" "$dst"
    mkdir -p "$TMP/mounts/donor_${part}"
    sudo mount -o loop,ro "$dst" "$TMP/mounts/donor_${part}" || true
  fi
done

# 5. product/etc/device_feature/ — копируем все файлы со стока в донор
if [ -d "$TMP/mounts/stock_product/product/etc/device_feature" ]; then
  mkdir -p "$TMP/mounts/donor_product/product/etc/device_feature"
  sudo cp -aT "$TMP/mounts/stock_product/product/etc/device_feature" "$TMP/mounts/donor_product/product/etc/device_feature" || true
fi

# 6. product/etc/display_config/ — копируем файлы display_id_*.xml
if [ -d "$TMP/mounts/stock_product/product/etc/display_config" ]; then
  mkdir -p "$TMP/mounts/donor_product/product/etc/display_config"
  sudo find "$TMP/mounts/stock_product/product/etc/display_config" -maxdepth 1 -type f -name 'display_id_*.xml' -exec cp -v {} "$TMP/mounts/donor_product/product/etc/display_config/" \; || true
fi

# 7. Добавляем строки в product/etc/build.prop донорской прошивки
DONOR_BUILDPROP="$TMP/mounts/donor_product/product/etc/build.prop"
if [ -f "$DONOR_BUILDPROP" ]; then
  sudo cp "$DONOR_BUILDPROP" "$DONOR_BUILDPROP.bak"
  echo "persist.miui.density_v2=$DENSITY" | sudo tee -a "$DONOR_BUILDPROP" >/dev/null
  echo "ro.sf.lcd_density=$DENSITY" | sudo tee -a "$DONOR_BUILDPROP" >/dev/null
fi

# 8. Удаление приложений — список удаляемых путей (product/app, product/data-app, product/priv-app, system/system/app)
REMOVE_LIST=(
"product/app/AnalyticsCore"
"product/app/CarWith"
"product/app/CatchLog"
"product/app/MIUIGuardProvider"
"product/app/MIUIsecurityinputmethod"
"product/app/MIUIsupermarket"
"product/app/Music"
"product/app/SogouIME"
"product/app/System"
"product/app/Updater"
"product/app/UPTsmservice"
"product/app/VoiceAssistAndroidT"
"product/data-app/BaiduIME"
"product/data-app/IFlytekIME"
"product/data-app/MiGalleryLockScreen"
"product/data-app/MIUICompass"
"product/data-app/MIservice"
"product/data-app/MiuiEmail"
"product/data-app/MiuiHuanji"
"product/data-app/MiuiMidrive"
"product/data-app/MiuiVirtualSim"
"product/data-app/MiuiXiaoAiSpeechEngine"
"product/data-app/OS2VipAccount"
"product/data-app/SmartHome"
"product/data-app/ThirdAppAssistant"
"product/data-app/XMRemoteController"
"product/priv-app/LinkToWindows"
"product/priv-app/MIUIbrowser"
"system/system/app/BasicDreams"
)

for p in "${REMOVE_LIST[@]}"; do
  target="$TMP/mounts/donor_product/$p"
  if [ -e "$target" ]; then
    sudo rm -rf "$target" || true
  fi
done

# 9. product/pangu: переносим нужные файлы
if [ -d "$TMP/mounts/stock_product/product/pangu/system/app" ]; then
  sudo cp -aT "$TMP/mounts/stock_product/product/pangu/system/app" "$TMP/mounts/donor_product/product/app" || true
fi
if [ -d "$TMP/mounts/stock_product/product/pangu/etc/permissions" ]; then
  mkdir -p "$TMP/mounts/donor_product/product/etc/permissions"
  sudo find "$TMP/mounts/stock_product/product/pangu/etc/permissions" -maxdepth 1 -type f -name '*.xml' -exec cp -v {} "$TMP/mounts/donor_product/product/etc/permissions/" \; || true
fi
if [ -d "$TMP/mounts/stock_product/product/pangu/priv-app" ]; then
  mkdir -p "$TMP/mounts/donor_product/product/priv-app"
  sudo find "$TMP/mounts/stock_product/product/pangu/priv-app" -maxdepth 1 -type d -not -name '*facebook*' -exec cp -a {} "$TMP/mounts/donor_product/product/priv-app/" \; || true
fi

# 10. product/overlay — копируем перечисленные apk
OVERLAYS=(AospFrameworkResOverlay.apk DevicesAndroidOverlay.apk DevicesOverlay.apk MiuiFrameworkResOverlay.apk)
for o in "${OVERLAYS[@]}"; do
  if [ -f "$TMP/mounts/stock_product/product/overlay/$o" ]; then
    mkdir -p "$TMP/mounts/donor_product/product/overlay"
    sudo cp -v "$TMP/mounts/stock_product/product/overlay/$o" "$TMP/mounts/donor_product/product/overlay/"
  fi
done

# 11. system_ext/apex — копируем com.android.vndk.v30.apex*
if [ -d "$TMP/mounts/stock_system_ext/system_ext/apex" ]; then
  mkdir -p "$TMP/mounts/donor_system_ext/system_ext/apex"
  sudo find "$TMP/mounts/stock_system_ext/system_ext/apex" -type f -name 'com.android.vndk.v30*.apex' -exec cp -v {} "$TMP/mounts/donor_system_ext/system_ext/apex/" \; || true
fi

# 12. Копируем build.prop из mi_ext/etc/ в product/etc/build.prop (вставляем содержимое)
if [ -f "$TMP/mounts/stock_mi_ext/mi_ext/etc/build.prop" ]; then
  sudo mkdir -p "$TMP/mounts/donor_product/product/etc"
  sudo bash -c "cat $TMP/mounts/stock_mi_ext/mi_ext/etc/build.prop >> $TMP/mounts/donor_product/product/etc/build.prop" || true
fi

# 13. Перемещаем содержимое mi_ext/product -> product, mi_ext/system -> system/system, mi_ext/system_ext -> system_ext
if [ -d "$TMP/mounts/stock_mi_ext/mi_ext/product" ]; then
  sudo cp -aT "$TMP/mounts/stock_mi_ext/mi_ext/product" "$TMP/mounts/donor_product/product" || true
fi
if [ -d "$TMP/mounts/stock_mi_ext/mi_ext/system" ]; then
  sudo cp -aT "$TMP/mounts/stock_mi_ext/mi_ext/system" "$TMP/mounts/donor_system/system" || true
fi
if [ -d "$TMP/mounts/stock_mi_ext/mi_ext/system_ext" ]; then
  sudo cp -aT "$TMP/mounts/stock_mi_ext/mi_ext/system_ext" "$TMP/mounts/donor_system_ext/system_ext" || true
fi

# 14. CorePatch - Disable Signature Verification
if [ -d "$(pwd)/corepatch" ]; then
  if [ -x "$(pwd)/corepatch/disable_sig_ver.sh" ]; then
    sudo "$(pwd)/corepatch/disable_sig_ver.sh" "$TMP/mounts/donor_product" || true
  fi
fi

# Unmount all mounts
sudo umount $(ls "$TMP/mounts" | sed -e "s#^#$TMP/mounts/#") || true || true
