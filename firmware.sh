#!/bin/bash
#


#############################
# Install coreboot Firmware #
#############################
function flash_coreboot()
{

fwTypeStr="UEFI"

echo_green "\nInstall/Update ${fwTypeStr} Full ROM Firmware"
echo_yellow "Standard disclaimer: flashing the firmware has the potential to
brick your device, requiring relatively inexpensive hardware and some
technical knowledge to recover.  You have been warned."

[[ "$isChromeOS" = true ]] && echo_yellow "Also, flashing Full ROM firmware will remove your ability to run ChromeOS."

read -ep "Do you wish to continue? [y/N] "
[[ "$REPLY" = "y" || "$REPLY" = "Y" ]] || return

#spacing
echo -e ""

# ensure hardware write protect disabled
[[ "$wpEnabled" = true ]] && { exit_red "\nHardware write-protect enabled, cannot flash Full ROM firmware."; return 1; }

#special warning for EVE
if [ "$device" = "eve" ]; then
echo_yellow "VERY IMPORTANT: flashing your Pixelbook is serious business. 
There is currently no way easy to unbrick if something goes wrong.
Only do this if you understand and accept the risk, because it's a
paperweight if something goes wrong.
(there have been no bricks so far, but the possibility exists)"

echo_yellow "If you wish to continue, type: 'I ACCEPT' and press enter."
read -e
[[ "$REPLY" = "I ACCEPT" ]] || return
fi

#UEFI or legacy firmware
useUEFI=true

#UEFI notice if flashing from ChromeOS or Legacy
if [[ "$useUEFI" = true && ! -d /sys/firmware/efi ]]; then
    [[ "$isChromeOS" = true ]] && currOS="ChromeOS" || currOS="Your Legacy-installed OS"
    echo_yellow "
NOTE: After flashing UEFI firmware, you will need to install a UEFI-compatible
OS; ${currOS} will no longer be bootable. UEFI firmware supports
Windows and Linux on all devices. Debian/Ubuntu-based distros require a small
fix to boot after install -- see https://mrchromebox.tech/#faq for more info."
    REPLY=""
    read -ep "Press Y to continue or any other key to abort. "
    [[ "$REPLY" = "y" || "$REPLY" = "Y" ]] || return
fi

#determine correct file / URL
firmware_source=${fullrom_source}
if [[ "$hasUEFIoption" = true ]]; then
    eval coreboot_file=$`echo "coreboot_uefi_${device}"`
else
    exit_red "Unknown or unsupported device (${device^^}); cannot continue."; return 1
fi

#peppy special case
if [ "$device" = "peppy" ]; then
    hasElan=$(cat /proc/bus/input/devices | grep "Elan")
    hasCypress=$(cat /proc/bus/input/devices | grep "Cypress")
    if [[ $hasElan = "" && $hasCypress = "" ]]; then
        echo -e ""
        read -ep "Unable to automatically determine trackpad type. Does your Peppy have an Elan pad? [y/N] "
        if [[ "$REPLY" = "y" || "$REPLY" = "Y" ]]; then
            if [ "$useUEFI" = true ]; then
                coreboot_file=${coreboot_uefi_peppy_elan}
            else
                coreboot_file=${coreboot_peppy_elan}
            fi
        fi
    elif [[ $hasElan != "" ]]; then
        if [ "$useUEFI" = true ]; then
            coreboot_file=${coreboot_uefi_peppy_elan}
        else
            coreboot_file=${coreboot_peppy_elan}
        fi
    fi
fi

#auron special case (upgrade from coolstar legacy rom)
if [ "$device" = "auron" ]; then
    echo -e ""
    echo_yellow "Unable to determine Chromebook model"
    echo -e "Because of your current firmware, I'm unable to
determine the exact mode of your Chromebook.  Are you using
an Acer C740 (Auron_Paine) or Acer C910/CB5-571 (Auron_Yuna)?
"
    REPLY=""
    while [[ "$REPLY" != "P" && "$REPLY" != "p" && "$REPLY" != "Y" && "$REPLY" != "y"  ]]
    do
        read -ep "Enter 'P' for Auron_Paine, 'Y' for Auron_Yuna: "
        if [[ "$REPLY" = "Y" || "$REPLY" = "y" ]]; then
            if [ "$useUEFI" = true ]; then
                coreboot_file=${coreboot_uefi_auron_yuna}
            else
                coreboot_file=${coreboot_auron_yuna}
            fi
        else
            if [ "$useUEFI" = true ]; then
                coreboot_file=${coreboot_uefi_auron_paine}
            else
                coreboot_file=${coreboot_auron_paine}
            fi
        fi
    done
fi

#extract MAC address if needed
if [[ "$hasLAN" = true ]]; then
    #check if contains MAC address, extract
    extract_vpd /tmp/bios.bin
    if [ $? -ne 0 ]; then
        #TODO - user enter MAC manually?
        echo_red "\nWarning: firmware doesn't contain VPD info - unable to persist MAC address."
        read -ep "Do you wish to continue? [y/N] "
        [[ "$REPLY" = "y" || "$REPLY" = "Y" ]] || return
    fi
fi

#check if existing firmware is stock
grep -obUa "vboot" /tmp/bios.bin >/dev/null
if [[ "$isStock" == "true" && $? -eq 0 ]]; then
    echo_yellow "\nCreate a backup copy of your stock firmware?"
    read -ep "This is highly recommended in case you wish to return your device to stock
configuration/run ChromeOS, or in the (unlikely) event that things go south
and you need to recover using an external EEPROM programmer. [Y/n] "
    [ "$REPLY" = "n" ] || backup_firmware
fi
#check that backup succeeded
[ $? -ne 0 ] && return 1

#headless?
useHeadless=false

#USB boot priority
preferUSB=false

#add PXE?
addPXE=false

#download firmware file
cd /tmp
echo_yellow "\nDownloading Full ROM firmware\n(${coreboot_file})"
curl -s -L -O "${firmware_source}${coreboot_file}"
curl -s -L -O "${firmware_source}${coreboot_file}.sha1"

#verify checksum on downloaded file
sha1sum -c ${coreboot_file}.sha1 --quiet > /dev/null 2>&1
[[ $? -ne 0 ]] && { exit_red "Firmware download checksum fail; download corrupted, cannot flash."; return 1; }

#check if we have a VPD to restore
if [ -f /tmp/vpd.bin ]; then
    ${cbfstoolcmd} ${coreboot_file} add -n vpd.bin -f /tmp/vpd.bin -t raw > /dev/null 2>&1
fi

#Persist RW_MRC_CACHE for BSW Full ROM firmware
${cbfstoolcmd} /tmp/bios.bin read -r RW_MRC_CACHE -f /tmp/mrc.cache > /dev/null 2>&1
if [[ $isBraswell = "true" &&  $isFullRom = "true" && $? -eq 0 ]]; then
    ${cbfstoolcmd} ${coreboot_file} write -r RW_MRC_CACHE -f /tmp/mrc.cache > /dev/null 2>&1
fi

#Persist SMMSTORE if exists
${cbfstoolcmd} /tmp/bios.bin read -r SMMSTORE -f /tmp/smmstore > /dev/null 2>&1
if [[ $useUEFI = "true" &&  $? -eq 0 ]]; then
    ${cbfstoolcmd} ${coreboot_file} write -r SMMSTORE -f /tmp/smmstore > /dev/null 2>&1
fi

#disable software write-protect
echo_yellow "Disabling software write-protect and clearing the WP range"
${flashromcmd} --wp-disable > /dev/null 2>&1
if [ $? -ne 0 ]; then
    exit_red "Error disabling software write-protect; unable to flash firmware."; return 1
fi

#clear SW WP range
${flashromcmd} --wp-range 0 0 > /dev/null 2>&1
if [ $? -ne 0 ]; then
    exit_red "Error clearing software write-protect range; unable to flash firmware."; return 1
fi

#flash Full ROM firmware

#flash only BIOS region, to avoid IFD mismatch upon verification 
echo_yellow "Installing Full ROM firmware (may take up to 90s)"
${flashromcmd} -i BIOS -w "${coreboot_file}" -o /tmp/flashrom.log > /dev/null 2>&1
if [ $? -ne 0 ]; then
    #try without specifying region
    ${flashromcmd} -w "${coreboot_file}" -o /tmp/flashrom.log > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        cat /tmp/flashrom.log
        exit_red "An error occurred flashing the Full ROM firmware. DO NOT REBOOT!"; return 1
    fi
fi

if [ $? -eq 0 ]; then
    echo_green "Full ROM firmware successfully installed/updated."

    #Prevent from trying to boot stock ChromeOS install
    if [[ "$isStock" = true && "$isChromeOS" = true ]]; then
       rm -rf /tmp/boot/efi > /dev/null 2>&1
       rm -rf /tmp/boot/syslinux > /dev/null 2>&1
    fi

    #Warn about long RAM training time, keyboard on Braswell
    if [[ "$isBraswell" = true ]]; then
        echo_yellow "IMPORTANT:\nThe first boot after flashing may take substantially
longer than subsequent boots -- up to 30s or more.
Be patient and eventually your device will boot :)"
    fi
    #set vars to indicate new firmware type
    isStock=false
    isFullRom=true
    firmwareType="Full ROM / UEFI (pending reboot)"
else
    echo_red "An error occurred flashing the Full ROM firmware. DO NOT REBOOT!"
fi

read -ep "Press [Enter] to return to the main menu."
}


##########################
# Restore Stock Firmware #
##########################
function restore_stock_firmware()
{
echo_green "\nRestore Stock Firmware"
echo_yellow "Standard disclaimer: flashing the firmware has the potential to
brick your device, requiring relatively inexpensive hardware and some
technical knowledge to recover.  You have been warned."

read -ep "Do you wish to continue? [y/N] "
[[ "$REPLY" = "Y" || "$REPLY" = "y" ]] || return

#spacing
echo -e ""

# ensure hardware write protect disabled
[[ "$wpEnabled" = true ]] && { exit_red "\nHardware write-protect enabled, cannot restore stock firmware."; return 1; }

firmware_file=""

read -ep "Do you have a firmware backup file on USB? [y/N] "
if [[ "$REPLY" = "y" || "$REPLY" = "Y" ]]; then
    read -ep "
Connect the USB/SD device which contains the backed-up stock firmware and press [Enter] to continue. "
    list_usb_devices
    [ $? -eq 0 ] || { exit_red "No USB devices available to read firmware backup."; return 1; }
    read -ep "Enter the number for the device which contains the stock firmware backup: " usb_dev_index
    [ $usb_dev_index -gt 0 ] && [ $usb_dev_index  -le $num_usb_devs ] || { exit_red "Error: Invalid option selected."; return 1; }
    usb_device="/dev/sd${usb_devs[${usb_dev_index}-1]}"
    mkdir /tmp/usb > /dev/null 2>&1
    mount "${usb_device}" /tmp/usb > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        mount "${usb_device}1" /tmp/usb
    fi
    if [ $? -ne 0 ]; then
        echo_red "USB device failed to mount; cannot proceed."
        read -ep "Press [Enter] to return to the main menu."
        umount /tmp/usb > /dev/null 2>&1
        return
    fi
    #select file from USB device
    echo_yellow "\n(Potential) Firmware Files on USB:"
    ls  /tmp/usb/*.{rom,ROM,bin,BIN} 2>/dev/null | xargs -n 1 basename 2>/dev/null
    if [ $? -ne 0 ]; then
        echo_red "No firmware files found on USB device."
        read -ep "Press [Enter] to return to the main menu."
        umount /tmp/usb > /dev/null 2>&1
        return
    fi
    echo -e ""
    read -ep "Enter the firmware filename:  " firmware_file
    firmware_file=/tmp/usb/${firmware_file}
    if [ ! -f ${firmware_file} ]; then
        echo_red "Invalid filename entered; unable to restore stock firmware."
        read -ep "Press [Enter] to return to the main menu."
        umount /tmp/usb > /dev/null 2>&1
        return
    fi
    #text spacing
    echo -e ""

else
    if [[ "$hasShellball" = false ]]; then
        exit_red "\nUnfortunately I don't have a stock firmware available to download for '${device^^}' at this time."
        return 1
    fi

    #download firmware extracted from recovery image
    echo_yellow "\nThat's ok, I'll download a shellball firmware for you."

    if [ "${device^^}" = "PANTHER" ]; then
        echo -e "Which device do you have?\n"
        echo "1) Asus CN60 [PANTHER]"
        echo "2) HP CB1 [ZAKO]"
        echo "3) Dell 3010 [TRICKY]"
        echo "4) Acer CXI [MCCLOUD]"
        echo "5) LG Chromebase [MONROE]"
        echo ""
        read -ep "? " fw_num
        if [[ $fw_num -lt 1 ||  $fw_num -gt 5 ]]; then
            exit_red "Invalid input - cancelling"
            return 1
        fi
        #confirm menu selection
        echo -e ""
        read -ep "Confirm selection number ${fw_num} [y/N] "
        [[ "$REPLY" = "y" || "$REPLY" = "Y" ]] || { exit_red "User cancelled restoring stock firmware"; return; }

        #download firmware file
        echo -e ""
        echo_yellow "Downloading recovery image firmware file"
        case "$fw_num" in
            1) _device="panther";
                ;;
            2) _device="zako";
                ;;
            3) _device="tricky";
                ;;
            4) _device="mccloud";
                ;;
            5) _device="monroe";
                ;;
        esac


    else
        #confirm device detection
        echo_yellow "Confirm system details:"
        echo -e "Device: ${deviceDesc}"
        echo -e "Board Name: ${device^^}"
        echo -e ""
        read -ep "? [y/N] "
        if [[ "$REPLY" != "y" && "$REPLY" != "Y" ]]; then
            exit_red "Device detection failed; unable to restoring stock firmware"
            return 1
        fi
        echo -e ""
        _device=${device}
    fi

    #download shellball ROM
    curl -s -L -o /tmp/stock-firmware.rom ${shellball_source}shellball.${_device}.bin;
    [[ $? -ne 0 ]] && { exit_red "Error downloading; unable to restore stock firmware."; return 1; }

    #extract VPD if present
    if [[ "$hasLAN" = true ]]; then
        #extract VPD from current firmware
        extract_vpd /tmp/bios.bin
        #merge with recovery image firmware
        if [ -f /tmp/vpd.bin ]; then
            echo_yellow "Merging VPD into recovery image firmware"
            ${cbfstoolcmd} /tmp/stock-firmware.rom write -r RO_VPD -f /tmp/vpd.bin > /dev/null 2>&1
        fi
    fi
    firmware_file=/tmp/stock-firmware.rom
fi

#disable software write-protect
${flashromcmd} --wp-disable > /dev/null 2>&1
if [ $? -ne 0 ]; then
#if [[ $? -ne 0 && ( "$isBraswell" = false || "$isFullRom" = false ) ]]; then
    exit_red "Error disabling software write-protect; unable to restore stock firmware."; return 1
fi

#clear SW WP range
${flashromcmd} --wp-range 0 0 > /dev/null 2>&1
if [ $? -ne 0 ]; then
    exit_red "Error clearing software write-protect range; unable to restore stock firmware."; return 1
fi

#flash stock firmware
echo_yellow "Restoring stock firmware"
${flashromcmd} -w ${firmware_file} > /dev/null 2>&1
[[ $? -ne 0 ]] && { exit_red "An error occurred restoring the stock firmware. DO NOT REBOOT!"; return 1; }
#all good
echo_green "Stock firmware successfully restored."
echo_green "After rebooting, you will need to restore ChromeOS using the ChromeOS recovery media,
then re-run this script to reset the Firmware Boot Flags (GBB Flags) to factory default."
read -ep "Press [Enter] to return to the main menu."
#set vars to indicate new firmware type
isStock=true
isFullRom=false
firmwareType="Stock ChromeOS (pending reboot)"
}


########################
# Extract firmware VPD #
########################
function extract_vpd()
{
#check params
[[ -z "$1" ]] && { exit_red "Error: extract_vpd(): missing function parameter"; return 1; }

firmware_file="$1"
#check if file contains MAC address
grep -obUa "ethernet_mac" ${firmware_file} >/dev/null
if [ $? -eq 0 ]; then
    #try FMAP extraction
    ${cbfstoolcmd} ${firmware_file} read -r RO_VPD -f /tmp/vpd.bin >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        #try CBFS extraction
        ${cbfstoolcmd} ${firmware_file} extract -n vpd.bin -f /tmp/vpd.bin >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo_red "Failure extracting MAC address from current firmware."
            return 1
        fi
    fi
else
    #file doesn't contain VPD
    return 1
fi
return 0
}


#########################
# Backup stock firmware #
#########################
function backup_firmware()
{
echo -e ""
read -ep "Connect the USB/SD device to store the firmware backup and press [Enter]
to continue.  This is non-destructive, but it is best to ensure no other
USB/SD devices are connected. "
list_usb_devices
if [ $? -ne 0 ]; then
    backup_fail "No USB devices available to store firmware backup."
    return 1
fi

read -ep "Enter the number for the device to be used for firmware backup: " usb_dev_index
if [ $usb_dev_index -le 0 ] || [ $usb_dev_index  -gt $num_usb_devs ]; then
    backup_fail "Error: Invalid option selected."
    return 1
fi

usb_device="/dev/sd${usb_devs[${usb_dev_index}-1]}"
mkdir /tmp/usb > /dev/null 2>&1
mount "${usb_device}" /tmp/usb > /dev/null 2>&1
if [ $? != 0 ]; then
    mount "${usb_device}1" /tmp/usb
fi
if [ $? -ne 0 ]; then
    backup_fail "USB backup device failed to mount; cannot proceed."
    return 1
fi
backupname="stock-firmware-${boardName}-$(date +%Y%m%d).rom"
echo_yellow "\nSaving firmware backup as ${backupname}"
cp /tmp/bios.bin /tmp/usb/${backupname}
if [ $? -ne 0 ]; then
    backup_fail "Failure reading stock firmware for backup; cannot proceed."
    return 1
fi
sync
umount /tmp/usb > /dev/null 2>&1
rmdir /tmp/usb
echo_green "Firmware backup complete. Remove the USB stick and press [Enter] to continue."
read -ep ""
}

function backup_fail()
{
umount /tmp/usb > /dev/null 2>&1
rmdir /tmp/usb > /dev/null 2>&1
exit_red "\n$@"
}


####################
# Set Boot Options #
####################
function set_boot_options()
{
# set boot options via firmware boot flags

# ensure hardware write protect disabled
[[ "$wpEnabled" = true ]] && { exit_red  "\nHardware write-protect enabled, cannot set Boot Options / GBB Flags."; return 1; }


[[ -z "$1" ]] && legacy_text="Legacy Boot" || legacy_text="$1"


echo_green "\nSet Firmware Boot Options (GBB Flags)"
echo_yellow "Select your preferred boot delay and default boot option.
You can always override the default using [CTRL+D] or
[CTRL+L] on the Developer Mode boot screen"

echo -e "1) Short boot delay (1s) + ${legacy_text} default
2) Long boot delay (30s) + ${legacy_text} default
3) Short boot delay (1s) + ChromeOS default
4) Long boot delay (30s) + ChromeOS default
5) Reset to factory default
6) Cancel/exit
"
local _flags=0x0
while :
do
    read -ep "? " n
    case $n in
        1) _flags=0x4A9; break;;
        2) _flags=0x4A8; break;;
        3) _flags=0xA9; break;;
        4) _flags=0xA8; break;;
        5) _flags=0x0; break;;
        6) read -ep "Press [Enter] to return to the main menu."; break;;
        *) echo -e "invalid option";;
    esac
done
[[ $n -eq 6 ]] && return
echo_yellow "\nSetting boot options..."
#disable software write-protect
${flashromcmd} --wp-disable > /dev/null 2>&1
if [ $? -ne 0 ]; then
    exit_red "Error disabling software write-protect; unable to set GBB flags."; return 1
fi
${flashromcmd} -r -i GBB:/tmp/gbb.temp > /dev/null 2>&1
[[ $? -ne 0 ]] && { exit_red "\nError reading firmware (non-stock?); unable to set boot options."; return 1; }
${gbbutilitycmd} --set --flags="${_flags}" /tmp/gbb.temp > /dev/null
[[ $? -ne 0 ]] && { exit_red "\nError setting boot options."; return 1; }
${flashromcmd} -w -i GBB:/tmp/gbb.temp > /dev/null 2>&1
[[ $? -ne 0 ]] && { exit_red "\nError writing back firmware; unable to set boot options."; return 1; }
echo_green "\nFirmware Boot options successfully set."
read -ep "Press [Enter] to return to the main menu."
}


###################
# Set Hardware ID #
###################
function set_hwid()
{
# set HWID using gbb_utility

# ensure hardware write protect disabled
[[ "$wpEnabled" = true ]] && { exit_red  "\nHardware write-protect enabled, cannot set HWID."; return 1; }

echo_green "Set Hardware ID (HWID) using gbb_utility"

#get current HWID
_hwid="$(crossystem hwid)" >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo_yellow "Current HWID is $_hwid"
fi
read -ep "Enter a new HWID (use all caps): " hwid
echo -e ""
read -ep "Confirm changing HWID to $hwid [y/N] " confirm
if [[ "$confirm" = "Y" || "$confirm" = "y" ]]; then
    echo_yellow "\nSetting hardware ID..."
    #disable software write-protect
    ${flashromcmd} --wp-disable > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        exit_red "Error disabling software write-protect; unable to set HWID."; return 1
    fi
    ${flashromcmd} -r -i GBB:/tmp/gbb.temp > /dev/null 2>&1
    [[ $? -ne 0 ]] && { exit_red "\nError reading firmware (non-stock?); unable to set HWID."; return 1; }
    ${gbbutilitycmd} --set --hwid="${hwid}" /tmp/gbb.temp > /dev/null
    [[ $? -ne 0 ]] && { exit_red "\nError setting HWID."; return 1; }
    ${flashromcmd} -w -i GBB:/tmp/gbb.temp > /dev/null 2>&1
    [[ $? -ne 0 ]] && { exit_red "\nError writing back firmware; unable to set HWID."; return 1; }
    echo_green "Hardware ID successfully set."
fi
read -ep "Press [Enter] to return to the main menu."
}


##################
# Remove Bitmaps #
##################
function remove_bitmaps()
{
# remove bitmaps from GBB using gbb_utility

# ensure hardware write protect disabled
[[ "$wpEnabled" = true ]] && { exit_red  "\nHardware write-protect enabled, cannot remove bitmaps."; return 1; }

echo_green "\nRemove ChromeOS Boot Screen Bitmaps"

read -ep "Confirm removing ChromeOS bitmaps? [y/N] " confirm
if [[ "$confirm" = "Y" || "$confirm" = "y" ]]; then
    echo_yellow "\nRemoving bitmaps..."
    #disable software write-protect
    ${flashromcmd} --wp-disable > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        exit_red "Error disabling software write-protect; unable to remove bitmaps."; return 1
    fi
    ${flashromcmd} -r -i GBB:/tmp/gbb.temp > /dev/null 2>&1
    [[ $? -ne 0 ]] && { exit_red "\nError reading firmware (non-stock?); unable to remove bitmaps."; return 1; }
    touch /tmp/null-images > /dev/null 2>&1
    ${gbbutilitycmd} --set --bmpfv=/tmp/null-images /tmp/gbb.temp > /dev/null
    [[ $? -ne 0 ]] && { exit_red "\nError removing bitmaps."; return 1; }
    ${flashromcmd} -w -i GBB:/tmp/gbb.temp > /dev/null 2>&1
    [[ $? -ne 0 ]] && { exit_red "\nError writing back firmware; unable to remove bitmaps."; return 1; }
    echo_green "ChromeOS bitmaps successfully removed."
fi
read -ep "Press [Enter] to return to the main menu."
}


##################
# Restore Bitmaps #
##################
function restore_bitmaps()
{
# restore bitmaps from GBB using gbb_utility

# ensure hardware write protect disabled
[[ "$wpEnabled" = true ]] && { exit_red  "\nHardware write-protect enabled, cannot restore bitmaps."; return 1; }

echo_green "\nRestore ChromeOS Boot Screen Bitmaps"

read -ep "Confirm restoring ChromeOS bitmaps? [y/N] " confirm
if [[ "$confirm" = "Y" || "$confirm" = "y" ]]; then
    echo_yellow "\nRestoring bitmaps..."
    #disable software write-protect
    ${flashromcmd} --wp-disable > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        exit_red "Error disabling software write-protect; unable to restore bitmaps."; return 1
    fi
    #download shellball
    curl -s -L -o /tmp/shellball.rom ${shellball_source}shellball.${device}.bin;
    [[ $? -ne 0 ]] && { exit_red "Error downloading shellball; unable to restore bitmaps."; return 1; }
    #extract GBB region, bitmaps
    ${cbfstoolcmd} /tmp/shellball.rom read -r GBB -f gbb.new >/dev/null 2>&1
    [[ $? -ne 0 ]] && { exit_red "Error extracting GBB region from shellball; unable to restore bitmaps."; return 1; }
    ${flashromcmd} -r -i GBB:/tmp/gbb.temp > /dev/null 2>&1
    [[ $? -ne 0 ]] && { exit_red "\nError reading firmware (non-stock?); unable to restore bitmaps."; return 1; }
    ${gbbutilitycmd} --get --bmpfv=/tmp/bmpfv /tmp/gbb.new > /dev/null
    ${gbbutilitycmd} --set --bmpfv=/tmp/bmpfv /tmp/gbb.temp > /dev/null
    [[ $? -ne 0 ]] && { exit_red "\nError restoring bitmaps."; return 1; }
    ${flashromcmd} -w -i GBB:/tmp/gbb.temp > /dev/null 2>&1
    [[ $? -ne 0 ]] && { exit_red "\nError writing back firmware; unable to restore bitmaps."; return 1; }
    echo_green "ChromeOS bitmaps successfully restored."
fi
read -ep "Press [Enter] to return to the main menu."
}


function clear_nvram() {
echo_green "\nClear UEFI NVRAM"
echo_yellow "Clearing the NVRAM will remove all EFI variables\nand reset the boot order to the default."
read -ep "Would you like to continue? [y/N] "
[[ "$REPLY" = "y" || "$REPLY" = "Y" ]] || return

echo_yellow "\nClearing NVRAM..."
smmstore=$(mktemp)
dd if=/dev/zero bs=256K count=1 2> /dev/null | tr '\000' '\377' > ${smmstore} 
${flashromcmd} -w -i SMMSTORE:${smmstore} > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo_red "\nFailed to write SMMSTORE firmware region; NVRAM not cleared."
    return 1;
fi
#all done
echo_green "NVRAM has been cleared."
read -ep "Press Enter to continue"
}

########################
# Firmware Update Menu #
########################
function menu_fwupdate() {
    printf "\ec"
    echo -e "${NORMAL}\n ChromeOS Firmware Utility Script ${script_date} ${NORMAL}"
    echo -e "${NORMAL} (c) Mr Chromebox <mrchromebox@gmail.com> ${NORMAL}"
    echo -e "${NORMAL} (c) CoolStar <coolstarorganization@gmail.com> ${NORMAL}"
    echo -e "${MENU}*********************************************************${NORMAL}"
    echo -e "${MENU}**${NUMBER}   Device: ${NORMAL}${deviceDesc} (${boardName^^})"
    echo -e "${MENU}**${NUMBER} CPU Type: ${NORMAL}$deviceCpuType"
    echo -e "${MENU}**${NUMBER}  Fw Type: ${NORMAL}$firmwareType"
    if [ "$wpEnabled" = true ]; then
        echo -e "${MENU}**${NUMBER}    Fw WP: ${RED_TEXT}Enabled${NORMAL}"
    WP_TEXT=${RED_TEXT}
    else
        echo -e "${MENU}**${NUMBER}    Fw WP: ${NORMAL}Disabled"
    WP_TEXT=${GREEN_TEXT}
    fi
    echo -e "${MENU}*********************************************************${NORMAL}"
    if [[ "$unlockMenu" = true || "$hasUEFIoption" = true || "$hasLegacyOption" = true ]]; then
        echo -e "${MENU}**${WP_TEXT} [WP]${NUMBER} 1)${MENU} Install/Update Full ROM Firmware ${NORMAL}"
    else
        echo -e "${GRAY_TEXT}**     ${GRAY_TEXT} 1)${GRAY_TEXT} Install/Update Full ROM Firmware${NORMAL}"
    fi
    if [[ "$unlockMenu" = true || ( "$isFullRom" = false && "$isBootStub" = false ) ]]; then
        echo -e "${MENU}**${WP_TEXT} [WP]${NUMBER} 2)${MENU} Set Boot Options (GBB flags) ${NORMAL}"
        echo -e "${MENU}**${WP_TEXT} [WP]${NUMBER} 3)${MENU} Set Hardware ID (HWID) ${NORMAL}"
    else
        echo -e "${GRAY_TEXT}**     ${GRAY_TEXT} 2)${GRAY_TEXT} Set Boot Options (GBB flags)${NORMAL}"
        echo -e "${GRAY_TEXT}**     ${GRAY_TEXT} 3)${GRAY_TEXT} Set Hardware ID (HWID) ${NORMAL}"
    fi
    if [[ "$unlockMenu" = true || ( "$isFullRom" = false && "$isBootStub" = false && \
        "$isSkylake" = false && "$isKbl" = false && "$isApl" = false) ]]; then
        echo -e "${MENU}**${WP_TEXT} [WP]${NUMBER} 4)${MENU} Remove ChromeOS Bitmaps ${NORMAL}"
        echo -e "${MENU}**${WP_TEXT} [WP]${NUMBER} 5)${MENU} Restore ChromeOS Bitmaps ${NORMAL}"
    else
        echo -e "${GRAY_TEXT}**     ${GRAY_TEXT} 4)${GRAY_TEXT} Remove ChromeOS Bitmaps ${NORMAL}"
        echo -e "${GRAY_TEXT}**     ${GRAY_TEXT} 5)${GRAY_TEXT} Restore ChromeOS Bitmaps ${NORMAL}"
    fi
    if [[ "$unlockMenu" = true || ( "$isChromeOS" = false  && "$isFullRom" = true ) ]]; then
        echo -e "${MENU}**${WP_TEXT} [WP]${NUMBER} 6)${MENU} Restore Stock Firmware (full) ${NORMAL}"
    else
        echo -e "${GRAY_TEXT}**     ${GRAY_TEXT} 6)${GRAY_TEXT} Restore Stock Firmware (full) ${NORMAL}"
    fi
    echo -e "${MENU}*********************************************************${NORMAL}"
    echo -e "${ENTER_LINE}Select a menu option or${NORMAL}"
    [[ "$unlockMenu" = true || "$isUEFI" = true ]] && nvram="${RED_TEXT}C${NORMAL} to clear NVRAM  " || nvram=""
    echo -e "${nvram}${RED_TEXT}R${NORMAL} to reboot ${NORMAL} ${RED_TEXT}P${NORMAL} to poweroff ${NORMAL} ${RED_TEXT}Q${NORMAL} to quit ${NORMAL}"
    
    read -e opt
    case $opt in

        1)  if [[  "$unlockMenu" = true || "$hasUEFIoption" = true || "$hasLegacyOption" = true ]]; then
                flash_coreboot
            fi
            menu_fwupdate
            ;;

        2)  if [[ "$unlockMenu" = true || "$isChromeOS" = true || "$isUnsupported" = false \
                    && "$isFullRom" = false && "$isBootStub" = false ]]; then
                set_boot_options
            fi
            menu_fwupdate
            ;;

        3)  if [[ "$unlockMenu" = true || "$isChromeOS" = true || "$isUnsupported" = false \
                    && "$isFullRom" = false && "$isBootStub" = false ]]; then
                set_hwid
            fi
            menu_fwupdate
            ;;

        4)  if [[ "$unlockMenu" = true || ( "$isFullRom" = false && "$isBootStub" = false && \
                    "$isSkylake" = false && "$isKbl" = false && "$isApl" = false)  ]]; then
                remove_bitmaps
            fi
            menu_fwupdate
            ;;

        5)  if [[ "$unlockMenu" = true || ( "$isFullRom" = false && "$isBootStub" = false && \
                    "$isSkylake" = false && "$isKbl" = false && "$isApl" = false)  ]]; then
                restore_bitmaps
            fi
            menu_fwupdate
            ;;

        6)  if [[ "$unlockMenu" = true || "$isChromeOS" = false && "$isUnsupported" = false \
                    && "$isFullRom" = true ]]; then
                restore_stock_firmware
            fi
            menu_fwupdate
            ;;

        [rR])  echo -e "\nRebooting...\n";
            cleanup
            reboot
            exit
            ;;

        [pP])  echo -e "\nPowering off...\n";
            cleanup
            poweroff
            exit
            ;;

        [qQ])  cleanup;
            exit;
            ;;

        [U])  if [ "$unlockMenu" = false ]; then
                echo_yellow "\nAre you sure you wish to unlock all menu functions?"
                read -ep "Only do this if you really know what you are doing... [y/N]? "
                [[ "$REPLY" = "y" || "$REPLY" = "Y" ]] && unlockMenu=true
            fi
            menu_fwupdate
            ;;

        [cC]) if [[ "$unlockMenu" = true || "$isUEFI" = true ]]; then
                clear_nvram
            fi
            menu_fwupdate
            ;;

        *)  clear
            menu_fwupdate;
            ;;
    esac
}

