#!/bin/bash
#
#############################
# Install coreboot Firmware #
#############################
function flash_coreboot()
{
echo_green "\nInstall/Update Full ROM Firmware"
echo_yellow "Standard disclaimer: flashing the firmware has the potential to 
brick your device, requiring relatively inexpensive hardware and some 
technical knowledge to recover.  You have been warned."

read -p "Do you wish to continue? [y/N] "
[[ "$REPLY" = "y" || "$REPLY" = "Y" ]] || return

#spacing
echo -e ""

# ensure hardware write protect disabled
[[ "$wpEnabled" = true ]] && { exit_red "\nHardware write-protect enabled, cannot flash Full ROM firmware."; return 1; }

#UEFI Only
useUEFI=true

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
        read -p "Unable to automatically determine trackpad type. Does your Peppy have an Elan pad? [y/N] "
        if [[ "$REPLY" = "y" || "$REPLY" = "Y" ]]; then
            coreboot_file=${coreboot_uefi_peppy_elan}
        fi
    elif [[ $hasElan != "" ]]; then 
        coreboot_file=${coreboot_uefi_peppy_elan}
    fi
fi

#parrot special case
if [ "$device" = "parrot" ]; then
    isSnb=$(cat /proc/cpuinfo | grep "847")
    isIvb=$(cat /proc/cpuinfo | grep "1007")
    if [[ $isSnb = "" && $isIvb = "" ]]; then
        echo -e ""
        read -p "Unable to automatically determine CPU type. Does your Parrot have a Celeron 1007U CPU? [y/N] "
        if [[ "$REPLY" = "y" || "$REPLY" = "Y" ]]; then
            coreboot_file=${coreboot_uefi_parrot_ivb}
        fi
    elif [[ $isIvb != "" ]]; then 
        coreboot_file=${coreboot_uefi_parrot_ivb}
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
        read -p "Enter 'P' for Auron_Paine, 'Y' for Auron_Yuna: "
        if [[ "$REPLY" = "Y" || "$REPLY" = "y" ]]; then
            coreboot_file=${coreboot_uefi_auron_yuna}
        else
            coreboot_file=${coreboot_uefi_auron_paine}
        fi
    done 
fi

#extract MAC address if needed
if [[ "$isHswBox" = true || "$isBdwBox" = true || "$device" = "ninja" ]]; then
    #check if contains MAC address, extract
    extract_vpd /tmp/bios.bin
    if [ $? -ne 0 ]; then
        #TODO - user enter MAC manually?
        echo_red "\nWarning: firmware doesn't contain VPD info - unable to persist MAC address."
        read -p "Do you wish to continue? [y/N] "
        [[ "$REPLY" = "y" || "$REPLY" = "Y" ]] || return
    fi
fi

#check if existing firmware is stock
grep -obUa "vboot" /tmp/bios.bin >/dev/null
if [[ "$isStock" == "true" && $? -eq 0 ]]; then
    echo_yellow "\nCreate a backup copy of your stock firmware?"
    read -p "This is highly recommended in case you wish to return your device to stock 
configuration/run ChromeOS, or in the (unlikely) event that things go south
and you need to recover using an external EEPROM programmer. [Y/n] "
    [ "$REPLY" = "n" ] || backup_firmware
fi
#check that backup succeeded
[ $? -ne 0 ] && return 1

#USB boot priority
preferUSB=false

#download firmware file
cd /tmp
echo_yellow "\nDownloading Full ROM firmware\n(${coreboot_file})"
curl -s -L -O "${firmware_source}${coreboot_file}"
curl -s -L -O "${firmware_source}${coreboot_file}.md5"

#verify checksum on downloaded file
md5sum -c ${coreboot_file}.md5 --quiet > /dev/null 2>&1
[[ $? -ne 0 ]] && { exit_red "Firmware download checksum fail; download corrupted, cannot flash."; return 1; }

#check if we have a VPD to restore
if [ -f /tmp/vpd.bin ]; then
    ${cbfstoolcmd} ${coreboot_file} add -n vpd.bin -f /tmp/vpd.bin -t raw > /dev/null 2>&1
fi

#disable software write-protect
${flashromcmd} --wp-disable > /dev/null 2>&1
if [ $? -ne 0 ]; then
    exit_red "Error disabling software write-protect; unable to flash firmware."; return 1
fi

#clear SW WP range (needed for BYT/BSW)
${flashromcmd} --wp-range 0 0 > /dev/null 2>&1
if [ $? -ne 0 ]; then
    exit_red "Error clearing software write-protect range; unable to flash firmware."; return 1
fi

#flash coreboot firmware
echo_yellow "Installing Full ROM firmware"
${flashromcmd} -w "${coreboot_file}" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo_green "Full ROM firmware successfully installed/updated."
    
    #Prevent from trying to boot stock ChromeOS install in UEFI mode
    if [[ "$isStock" = true && "$isChromeOS" = true &&  "$useUEFI" = true ]]; then
        mv /tmp/boot/EFI /tmp/boot/EFI_ > /dev/null 2>&1
    fi
else
    echo_red "An error occurred flashing the Full ROM firmware. DO NOT REBOOT!"
fi

read -p "Press [Enter] to return to the main menu."
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

read -p "Do you wish to continue? [y/N] "
[[ "$REPLY" = "Y" || "$REPLY" = "y" ]] || return

#spacing
echo -e ""

# ensure hardware write protect disabled
[[ "$wpEnabled" = true ]] && { exit_red "\nHardware write-protect enabled, cannot restore stock firmware."; return 1; }

firmware_file=""

read -p "Do you have a firmware backup file on USB? [y/N] "
if [[ "$REPLY" = "y" || "$REPLY" = "Y" ]]; then
    read -p "
Connect the USB/SD device which contains the backed-up stock firmware and press [Enter] to continue. "      
    list_usb_devices
    [ $? -eq 0 ] || { exit_red "No USB devices available to read firmware backup."; return 1; }
    read -p "Enter the number for the device which contains the stock firmware backup: " usb_dev_index
    [ $usb_dev_index -gt 0 ] && [ $usb_dev_index  -le $num_usb_devs ] || { exit_red "Error: Invalid option selected."; return 1; }
    usb_device="/dev/sd${usb_devs[${usb_dev_index}-1]}"
    mkdir /tmp/usb > /dev/null 2>&1
    mount "${usb_device}" /tmp/usb > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        mount "${usb_device}1" /tmp/usb
    fi
    if [ $? -ne 0 ]; then
        echo_red "USB device failed to mount; cannot proceed."
        read -p "Press [Enter] to return to the main menu."
        umount /tmp/usb > /dev/null 2>&1
        return
    fi
    #select file from USB device
    echo_yellow "\n(Potential) Firmware Files on USB:"
    ls  /tmp/usb/*.{rom,ROM,bin,BIN} 2>/dev/null | xargs -n 1 basename 2>/dev/null
    if [ $? -ne 0 ]; then
        echo_red "No firmware files found on USB device."
        read -p "Press [Enter] to return to the main menu."
        umount /tmp/usb > /dev/null 2>&1
        return
    fi
    echo -e ""
    read -p "Enter the firmware filename:  " firmware_file
    firmware_file=/tmp/usb/${firmware_file}
    if [ ! -f ${firmware_file} ]; then
        echo_red "Invalid filename entered; unable to restore stock firmware."
        read -p "Press [Enter] to return to the main menu."
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
        read -p "? " fw_num
        if [[ $fw_num -lt 1 ||  $fw_num -gt 5 ]]; then
            exit_red "Invalid input - cancelling"
            return 1
        fi
        #confirm menu selection
        echo -e ""
        read -p "Confirm selection number ${fw_num} [y/N] "
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
        read -p "? [y/N] "
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
    if [[ "$isHswBox" = true || "$isBdwBox" = true || "$device" = "ninja" || "$device" = "monroe" ]]; then
        #read current firmware to extract VPD
        echo_yellow "Reading current firmware"
        ${flashromcmd} -r /tmp/bios.bin > /dev/null 2>&1
        [[ $? -ne 0 ]] && { exit_red "Failure reading current firmware; cannot proceed."; return 1; }
        #extract VPD
        extract_vpd /tmp/bios.bin
        #merge with recovery image firmware
        if [ -f /tmp/vpd.bin ]; then
            echo_yellow "Merging VPD into recovery image firmware"
            dd if=/tmp/vpd.bin bs=1 seek=$((0x00600000)) count=$((0x00004000)) of=/tmp/stock-firmware.rom conv=notrunc > /dev/null 2>&1
        fi
    fi
    firmware_file=/tmp/stock-firmware.rom
fi

#flash stock firmware
echo_yellow "Restoring stock firmware"
${flashromcmd} -w ${firmware_file} > /dev/null 2>&1
[[ $? -ne 0 ]] && { exit_red "An error occurred restoring the stock firmware. DO NOT REBOOT!"; return 1; }
#all good
echo_green "Stock firmware successfully restored."
echo_green "After rebooting, you will need to restore ChromeOS using the ChromeOS recovery media,
then re-run this script to reset the Firmware Boot Flags (GBB Flags) to factory default."
read -p "Press [Enter] to return to the main menu."
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
    #we have a MAC; determine if stock firmware (FMAP) or coreboot (CBFS)
    grep -obUa "vboot" ${firmware_file} >/dev/null
    if [ $? -eq 0 ]; then
        #stock firmware, extract w/dd
        extract_cmd="dd if=${firmware_file} bs=1 skip=$((0x00600000)) count=$((0x00004000)) of=/tmp/vpd.bin"
    else
        #coreboot firmware, extract w/cbfstool
        extract_cmd="${cbfstoolcmd} ${firmware_file} extract -n vpd.bin -f /tmp/vpd.bin"
    fi
    #run extract command
    ${extract_cmd}  > /dev/null 2>&1
    if [ $? -ne 0 ]; then 
        echo_red "Failure extracting MAC address from current firmware."
        return 1
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
read -p "Connect the USB/SD device to store the firmware backup and press [Enter] 
to continue.  This is non-destructive, but it is best to ensure no other 
USB/SD devices are connected. "
list_usb_devices
if [ $? -ne 0 ]; then
    backup_fail "No USB devices available to store firmware backup."
    return 1
fi

read -p "Enter the number for the device to be used for firmware backup: " usb_dev_index
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
backupname="stock-firmware-${device}-$(date +%Y%m%d).rom"
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
read -p ""
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
    read -p "? " n  
    case $n in
        1) _flags=0x4A9; break;;
        2) _flags=0x4A8; break;;
        3) _flags=0xA9; break;;
        4) _flags=0xA8; break;;
        5) _flags=0x0; break;;
        6) read -p "Press [Enter] to return to the main menu."; break;;
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
read -p "Press [Enter] to return to the main menu."
}


###################
# Set Hardware ID #
###################
function set_hwid() 
{
# set HWID using gbb_utility

# ensure hardware write protect disabled
[[ "$wpEnabled" = true ]] && { exit_red  exit_red "\nHardware write-protect enabled, cannot set HWID."; return 1; }

echo_green "Set Hardware ID (HWID) using gbb_utility"

#get current HWID
_hwid="$(crossystem hwid)" >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo_yellow "Current HWID is $_hwid"
fi
read -p "Enter a new HWID (use all caps): " hwid
echo -e ""
read -p "Confirm changing HWID to $hwid [y/N] " confirm
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
read -p "Press [Enter] to return to the main menu."
}


##################
# Remove Bitmaps #
##################
function remove_bitmaps() 
{
# remove bitmaps from GBB using gbb_utility

# ensure hardware write protect disabled
[[ "$wpEnabled" = true ]] && { exit_red  exit_red "\nHardware write-protect enabled, cannot remove bitmaps."; return 1; }

echo_green "\nRemove ChromeOS Boot Screen Bitmaps"

read -p "Confirm removing ChromeOS bitmaps? [y/N] " confirm
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
read -p "Press [Enter] to return to the main menu."
}


##################
# Restore Bitmaps #
##################
function restore_bitmaps() 
{
# restore bitmaps from GBB using gbb_utility

# ensure hardware write protect disabled
[[ "$wpEnabled" = true ]] && { exit_red  exit_red "\nHardware write-protect enabled, cannot restore bitmaps."; return 1; }

echo_green "\nRestore ChromeOS Boot Screen Bitmaps"

read -p "Confirm restoring ChromeOS bitmaps? [y/N] " confirm
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
read -p "Press [Enter] to return to the main menu."
}


########################
# Firmware Update Menu #
########################
function menu_fwupdate() {
    printf "\ec"
    echo -e "${NORMAL}\n ChromeOS Firmware Utility Script ${script_date} ${NORMAL}"
    echo -e "${NORMAL} (c) Mr Chromebox <mrchromebox@gmail.com> ${NORMAL}"
    echo -e "${NORMAL} (c) CoolStar <coolstarorganization@gmail.com> ${NORMAL}"
    echo -e "${MENU}******************************************************${NORMAL}"
    echo -e "${MENU}**${NUMBER}   Device: ${NORMAL}${deviceDesc} (${device^^})"
    echo -e "${MENU}**${NUMBER} CPU Type: ${NORMAL}$deviceCpuType"
    echo -e "${MENU}**${NUMBER}  Fw Type: ${NORMAL}$firmwareType"
    if [ "$wpEnabled" = true ]; then
        echo -e "${MENU}**${NUMBER}    Fw WP: ${RED_TEXT}Enabled${NORMAL}"
    else
        echo -e "${MENU}**${NUMBER}    Fw WP: ${NORMAL}Disabled"
    fi
    echo -e "${MENU}******************************************************${NORMAL}"
    if [[ "$unlockMenu" = true || ( "$isUnsupported" = false && "$isBraswell" = false && "$isSkylake" = false ) ]]; then
        echo -e "${MENU}**${NUMBER} 1)${MENU} Install/Update Full ROM Firmware ${NORMAL}"
    else
        echo -e "${GRAY_TEXT}**${GRAY_TEXT} 1)${GRAY_TEXT} Install/Update Full ROM Firmware${NORMAL}"
    fi
    if [[ "$unlockMenu" = true || ( "$isFullRom" = false && "$isBootStub" = false ) ]]; then
        echo -e "${MENU}**${NUMBER} 2)${MENU} Set Boot Options (GBB flags) ${NORMAL}"
        echo -e "${MENU}**${NUMBER} 3)${MENU} Set Hardware ID (HWID) ${NORMAL}"
    else
        echo -e "${GRAY_TEXT}**${GRAY_TEXT} 2)${GRAY_TEXT} Set Boot Options (GBB flags)${NORMAL}"
        echo -e "${GRAY_TEXT}**${GRAY_TEXT} 3)${GRAY_TEXT} Set Hardware ID (HWID) ${NORMAL}"
    fi
    if [[ "$unlockMenu" = true || ( "$isFullRom" = false && "$isBootStub" = false && "$isSkylake" = false) ]]; then
        echo -e "${MENU}**${NUMBER} 4)${MENU} Remove ChromeOS Bitmaps ${NORMAL}"
        echo -e "${MENU}**${NUMBER} 5)${MENU} Restore ChromeOS Bitmaps ${NORMAL}"
    else
        echo -e "${GRAY_TEXT}**${GRAY_TEXT} 4)${GRAY_TEXT} Remove ChromeOS Bitmaps ${NORMAL}"
        echo -e "${GRAY_TEXT}**${GRAY_TEXT} 5)${GRAY_TEXT} Restore ChromeOS Bitmaps ${NORMAL}"
    fi
    if [[ "$unlockMenu" = true || ( "$isChromeOS" = false  && "$isFullRom" = true ) ]]; then
        echo -e "${MENU}**${NUMBER} 6)${MENU} Restore Stock Firmware (full) ${NORMAL}" 
    else
        echo -e "${GRAY_TEXT}**${GRAY_TEXT} 6)${GRAY_TEXT} Restore Stock Firmware (full) ${NORMAL}" 
    fi
    echo -e "${MENU}**${NORMAL}"
    echo -e "${MENU}**${NUMBER} U)${NORMAL} Unlock Disabled Functions ${NORMAL}"
    echo -e "${MENU}******************************************************${NORMAL}"
    echo -e "${ENTER_LINE}Select a menu option or${NORMAL}"
    echo -e "${RED_TEXT}R${NORMAL} to reboot ${NORMAL} ${RED_TEXT}P${NORMAL} to poweroff ${NORMAL} ${RED_TEXT}Q${NORMAL} to quit ${NORMAL}"
    read opt
            
    while [ opt != '' ]
        do
        if [[ $opt = "q" ]]; then 
                exit;
        else
            case $opt in
                1)  if [[ "$unlockMenu" = true || ( "$isUnsupported" = false \
                            && "$isBraswell" = false && "$isSkylake" = false ) ]]; then
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
                                                            
                4)  if [[ "$unlockMenu" = true || "$isChromeOS" = true || "$isUnsupported" = false \
                            && "$isFullRom" = false && "$isBootStub" = false && "$isSkylake" = false ]]; then
                        remove_bitmaps   
                    fi
                    menu_fwupdate
                    ;;
                    
                5)  if [[ "$unlockMenu" = true || "$isChromeOS" = true || "$isUnsupported" = false \
                            && "$isFullRom" = false && "$isBootStub" = false && "$isSkylake" = false ]]; then
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
                    cleanup;
                    reboot;
                    exit;
                    ;;
                    
                [pP])  echo -e "\nPowering off...\n";
                    cleanup;
                    poweroff;
                    exit;
                    ;;
                
                [qQ])  cleanup;
                    exit;
                    ;;
                
                [uU])  if [ "$unlockMenu" = false ]; then
                        echo_yellow "\nAre you sure you wish to unlock all menu functions?"
                        read -p "Only do this if you really know what you are doing... [y/N]? "
                        [[ "$REPLY" = "y" || "$REPLY" = "Y" ]] && unlockMenu=true
                    fi
                    menu_fwupdate
                    ;;
                \n) cleanup;
                    exit;
                    ;;
                    
                *)  clear;
                    menu_fwupdate;
                    ;;     
            esac
        fi
    done
}


