#!/bin/bash
#


#define these here for easy updating
script_date="[2019-01-04]"

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
coreboot_uefi_butterfly="coreboot_tiano-butterfly-mrchromebox_20190104.rom"
coreboot_uefi_lumpy="coreboot_tiano-lumpy-mrchromebox_20190104.rom"
coreboot_uefi_link="coreboot_tiano-link-mrchromebox_20190104.rom"
coreboot_uefi_parrot="coreboot_tiano-parrot-mrchromebox_20190104.rom"
coreboot_uefi_stout="coreboot_tiano-stout-mrchromebox_20190104.rom"
coreboot_uefi_stumpy="coreboot_tiano-stumpy-mrchromebox_20190104.rom"
#Haswell
coreboot_uefi_falco="coreboot_tiano-falco-mrchromebox_20190104.rom"
coreboot_uefi_leon="coreboot_tiano-leon-mrchromebox_20190104.rom"
coreboot_uefi_mccloud="coreboot_tiano-mccloud-mrchromebox_20190104.rom"
coreboot_uefi_monroe="coreboot_tiano-monroe-mrchromebox_20190104.rom"
coreboot_uefi_panther="coreboot_tiano-panther-mrchromebox_20190104.rom"
coreboot_uefi_peppy="coreboot_tiano-peppy-mrchromebox_20190104.rom"
coreboot_uefi_peppy_elan="coreboot_tiano-peppy_elan-mrchromebox_20190104.rom"
coreboot_uefi_tricky="coreboot_tiano-tricky-mrchromebox_20190104.rom"
coreboot_uefi_wolf="coreboot_tiano-wolf-mrchromebox_20190104.rom"
coreboot_uefi_zako="coreboot_tiano-zako-mrchromebox_20190104.rom"
#Broadwell
coreboot_uefi_auron_paine="coreboot_tiano-auron_paine-mrchromebox_20190104.rom"
coreboot_uefi_auron_yuna="coreboot_tiano-auron_yuna-mrchromebox_20190104.rom"
coreboot_uefi_buddy="coreboot_tiano-buddy-mrchromebox_20190104.rom"
coreboot_uefi_gandof="coreboot_tiano-gandof-mrchromebox_20190104.rom"
coreboot_uefi_guado="coreboot_tiano-guado-mrchromebox_20190104.rom"
coreboot_uefi_lulu="coreboot_tiano-lulu-mrchromebox_20190104.rom"
coreboot_uefi_rikku="coreboot_tiano-rikku-mrchromebox_20190104.rom"
coreboot_uefi_samus="coreboot_tiano-samus-mrchromebox_20190104.rom"
coreboot_uefi_tidus="coreboot_tiano-tidus-mrchromebox_20190104.rom"
#Baytrail
coreboot_uefi_banjo="coreboot_tiano-banjo-mrchromebox_20190104.rom"
coreboot_uefi_candy="coreboot_tiano-candy-mrchromebox_20190104.rom"
coreboot_uefi_clapper="coreboot_tiano-clapper-mrchromebox_20190104.rom"
coreboot_uefi_enguarde="coreboot_tiano-enguarde-mrchromebox_20190104.rom"
coreboot_uefi_glimmer="coreboot_tiano-glimmer-mrchromebox_20190104.rom"
coreboot_uefi_gnawty="coreboot_tiano-gnawty-mrchromebox_20190104.rom"
coreboot_uefi_heli="coreboot_tiano-heli-mrchromebox_20190104.rom"
coreboot_uefi_kip="coreboot_tiano-kip-mrchromebox_20190104.rom"
coreboot_uefi_ninja="coreboot_tiano-ninja-mrchromebox_20190104.rom"
coreboot_uefi_orco="coreboot_tiano-orco-mrchromebox_20190104.rom"
coreboot_uefi_quawks="coreboot_tiano-quawks-mrchromebox_20190104.rom"
coreboot_uefi_squawks="coreboot_tiano-squawks-mrchromebox_20190104.rom"
coreboot_uefi_sumo="coreboot_tiano-sumo-mrchromebox_20190104.rom"
coreboot_uefi_swanky="coreboot_tiano-swanky-mrchromebox_20190104.rom"
coreboot_uefi_winky="coreboot_tiano-winky-mrchromebox_20190104.rom"
#Braswell
coreboot_uefi_banon="coreboot_tiano-banon-mrchromebox_20190104.rom"
coreboot_uefi_celes="coreboot_tiano-celes-mrchromebox_20190104.rom"
coreboot_uefi_cyan="coreboot_tiano-cyan-mrchromebox_20190104.rom"
coreboot_uefi_edgar="coreboot_tiano-edgar-mrchromebox_20190104.rom"
coreboot_uefi_kefka="coreboot_tiano-kefka-mrchromebox_20190104.rom"
coreboot_uefi_reks="coreboot_tiano-reks-mrchromebox_20190104.rom"
coreboot_uefi_relm="coreboot_tiano-relm-mrchromebox_20190104.rom"
coreboot_uefi_setzer="coreboot_tiano-setzer-mrchromebox_20190104.rom"
coreboot_uefi_terra="coreboot_tiano-terra-mrchromebox_20190104.rom"
coreboot_uefi_ultima="coreboot_tiano-ultima-mrchromebox_20190104.rom"
coreboot_uefi_wizpig="coreboot_tiano-wizpig-mrchromebox_20190104.rom"
#Skylake
coreboot_uefi_asuka="coreboot_tiano-asuka-mrchromebox_20190104.rom"
coreboot_uefi_caroline="coreboot_tiano-caroline-mrchromebox_20190104.rom"
coreboot_uefi_cave="coreboot_tiano-cave-mrchromebox_20190104.rom"
coreboot_uefi_chell="coreboot_tiano-chell-mrchromebox_20190104.rom"
coreboot_uefi_lars="coreboot_tiano-lars-mrchromebox_20190104.rom"
coreboot_uefi_sentry="coreboot_tiano-sentry-mrchromebox_20190104.rom"
#KabyLake
coreboot_uefi_eve="coreboot_tiano-eve-mrchromebox_20190104.rom"
coreboot_uefi_fizz="coreboot_tiano-fizz-mrchromebox_20190104.rom"
