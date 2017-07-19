#!/bin/bash
#


#define these here for easy updating
script_date="[2017-04-11]"

#where the stuff is
util_source="https://www.coolstar.org/chromebook/downloads/firmwareutils/"
fullrom_source="https://www.mrchromebox.tech/files/firmware/full_rom/"
fullrom_source_coolstar="https://www.coolstar.org/chromebook/downloads/ROM/"
shellball_source="https://www.mrchromebox.tech/files/firmware/shellball/"

#LE sources
LE_url_official="http://releases.libreelec.tv/"
LE_url=${LE_url_official}
chrx_url="https://chrx.org/go"

#LE version
LE_version_base="LibreELEC-Generic.x86_64"
LE_version_stable="8.0.1"
LE_version_latest="8.0.1"

#syslinux version
syslinux_version="syslinux-6.04-pre1"

#UEFI Full ROMs

#SNB/IVB
coreboot_uefi_butterfly="coreboot_tiano-butterfly-mrchromebox_20170714.rom"
coreboot_uefi_lumpy="coreboot_tiano-lumpy-mrchromebox_20170714.rom"
coreboot_uefi_link="coreboot_tiano-link-mrchromebox_20170714.rom"
coreboot_uefi_parrot="coreboot_tiano-parrot_snb-mrchromebox_20170714.rom"
coreboot_uefi_parrot_ivb="coreboot_tiano-parrot_ivb-mrchromebox_20170714.rom"
coreboot_uefi_stumpy="coreboot_tiano-stumpy-mrchromebox_20170714.rom"

#Haswell
coreboot_uefi_falco="coreboot_tiano-falco-mrchromebox_20170714.rom"
coreboot_uefi_leon="coreboot_tiano-leon-mrchromebox_20170714.rom"
coreboot_uefi_mccloud="coreboot_tiano-mccloud-mrchromebox_20170714.rom"
coreboot_uefi_monroe="coreboot_tiano-monroe-mrchromebox_20170714.rom"
coreboot_uefi_panther="coreboot_tiano-panther-mrchromebox_20170714.rom"
coreboot_uefi_peppy="coreboot_tiano-peppy-mrchromebox_20170714.rom"
coreboot_uefi_peppy_elan="coreboot_tiano-peppy_elan-mrchromebox_20170714.rom"
coreboot_uefi_tricky="coreboot_tiano-tricky-mrchromebox_20170714.rom"
coreboot_uefi_wolf="coreboot_tiano-wolf-mrchromebox_20170714.rom"
coreboot_uefi_zako="coreboot_tiano-zako-mrchromebox_20170714.rom"

#Broadwell
coreboot_uefi_auron_paine="coreboot_tiano-auron_paine-mrchromebox_20170714.rom"
coreboot_uefi_auron_yuna="coreboot_tiano-auron_yuna-mrchromebox_20170714.rom"
coreboot_uefi_gandof="coreboot_tiano-gandof-mrchromebox_20170714.rom"
coreboot_uefi_guado="coreboot_tiano-guado-mrchromebox_20170714.rom"
coreboot_uefi_lulu="coreboot_tiano-lulu-mrchromebox_20170714.rom"
coreboot_uefi_rikku="coreboot_tiano-rikku-mrchromebox_20170714.rom"
coreboot_uefi_samus="coreboot_tiano-samus-mrchromebox_20170714.rom"
coreboot_uefi_tidus="coreboot_tiano-tidus-mrchromebox_20170714.rom"

#Baytrail
coreboot_uefi_banjo="coreboot_tiano-banjo-mrchromebox_20170714.rom"
coreboot_uefi_candy="coreboot_tiano-candy-mrchromebox_20170714.rom"
coreboot_uefi_clapper="coreboot_tiano-clapper-mrchromebox_20170714.rom"
coreboot_uefi_enguarde="coreboot_tiano-enguarde-mrchromebox_20170714.rom"
coreboot_uefi_glimmer="coreboot_tiano-glimmer-mrchromebox_20170714.rom"
coreboot_uefi_gnawty="coreboot_tiano-gnawty-mrchromebox_20170714.rom"
coreboot_uefi_heli="coreboot_tiano-heli-mrchromebox_20170714.rom"
coreboot_uefi_kip="coreboot_tiano-kip-mrchromebox_20170714.rom"
coreboot_uefi_ninja="coreboot_tiano-ninja-mrchromebox_20170714.rom"
coreboot_uefi_orco="coreboot_tiano-orco-mrchromebox_20170714.rom"
coreboot_uefi_quawks="coreboot_tiano-quawks-mrchromebox_20170714.rom"
coreboot_uefi_squawks="coreboot_tiano-squawks-mrchromebox_20170714.rom"
coreboot_uefi_sumo="coreboot_tiano-sumo-mrchromebox_20170714.rom"
coreboot_uefi_swanky="coreboot_tiano-swanky-mrchromebox_20170714.rom"
coreboot_uefi_winky="coreboot_tiano-winky-mrchromebox_20170714.rom"
