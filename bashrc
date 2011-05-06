#!/bin/bash
# Copyright (c) 2010-2011, Piotr Karbowski <piotr.karbowski@gmail.com>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification, are
# permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright notice, this
#   list of conditions and the following disclaimer in the documentation and/or other
#   materials provided with the distribution.
# * Neither the name of the Piotr Karbowski nor the names of its contributors may be
#   used to endorse or promote products derived from this software without specific
#   prior written permission.
#
# QuickStart:
# mkdir /root/src
# cd /root/src
# git clone https://github.com/slashbeast/foobashrc.git
# ln -s /root/src/foobashrc/bashrc /etc/portage/bashrc

localpatch() {
	local patches_overlay_dir patches patch locksufix

	locksufix="${RANDOM}"

	LOCALPATCH_OVERLAY="${LOCALPATCH_OVERLAY:-/etc/portage/localpatches}"

	if [ -d "${LOCALPATCH_OVERLAY}" ]; then
		if [ -d "${LOCALPATCH_OVERLAY}/${CATEGORY}/${PN}-${PV}-${PR}" ]; then
			patches_overlay_dir="${LOCALPATCH_OVERLAY}/${CATEGORY}/${PN}-${PV}-${PR}"
		elif [ -d "${LOCALPATCH_OVERLAY}/${CATEGORY}/${PN}-${PV}" ]; then
			patches_overlay_dir="${LOCALPATCH_OVERLAY}/${CATEGORY}/${PN}-${PV}"
		elif [ -d "${LOCALPATCH_OVERLAY}/${CATEGORY}/${PN}" ]; then
			patches_overlay_dir="${LOCALPATCH_OVERLAY}/${CATEGORY}/${PN}"
		fi

		if [ -n "${patches_overlay_dir}" ]; then
			patches="$(find "${patches_overlay_dir}"/ -type f -regex '.*\.\(diff\|\patch\)$' | sort -n)";
		fi
	else
		ewarn "LOCALPATCH_OVERLAY is set to '${LOCALPATCH_OVERLAY}' but there is no such directory."
	fi

	if [ -n "${patches}" ]; then
		echo '>>> Applying local patches ...'
		if [ ! -d "${S}" ]; then
			eerror "The \$S variable pointing to non existing dir. Propably ebuild is messing with it."
			eerror "Localpatch cannot work in such case."
			die "localpatch failed."
		fi
		for patch in ${patches}; do
			if [ -r "${patch}" ] && [ ! -f "${S}/.patch-${patch##*/}.${locksufix}" ]; then
				for patchprefix in {0..4}; do
					if patch -d "${S}" --dry-run -p${patchprefix} -i "${patch}" --silent > /dev/null; then
						einfo "Applying ${patch##*/} [localpatch] ..."
						patch -d "${S}" -p${patchprefix} -i "${patch}" --silent; eend $?
						touch "${S}/.patch-${patch##*/}.${locksufix}"
						EPATCH_EXCLUDE+=" ${patch##*/} "
						break
					elif [ "${patchprefix}" -ge 4 ]; then
						eerror "\e[1;31mLocal patch ${patch##*/} does not fit.\e[0m"; eend 1; die "localpatch failed."
					fi
				done
			fi
		done

		rm "${S}"/.patch-*."${locksufix}" -f
	fi
}

striplafiles() {
	local i installlacrap donotstriplafilesfor
	# Some packages need .la crappy files, we will preserve them here.
	donotstriplafilesfor=( imagemagick libtool gst-plugins-base libsidplay gnome-bluetooth kdelibs )
	for i in "${donotstriplafilesfor[@]}"; do
		if [ "${PN}" = "${i}" ]; then
			installlacrap='true'
		fi
	done
	if ! [ "${installlacrap}" = 'true' ]; then
		local line
		find "$D" -type f -name '*.la' | while read line; do
			einfo "Removing \${D}/${line/${D}} [striplafiles] ..."
			rm "${line}"; eend $?
		done
	fi
}

post_src_unpack() {
	if hasq localpatch ${foobashrc_modules}; then 
		localpatch
	fi
}

post_pkg_preinst() {
	if hasq striplafiles ${foobashrc_modules}; then striplafiles; fi
	if hasq pathparanoid ${foobashrc_modules}; then /root/bin/pathparanoid --prefix "$D" --check --adjust; fi
}

post_pkg_postinst() {
	if hasq pathparanoid ${foobashrc_modules}; then /root/bin/pathparanoid --check --adjust; fi
}
