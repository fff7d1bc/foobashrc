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
	# Return (skip localpatch) if there is no 'localpatch' in foobashrc_modules variable
	# or if 2nd item from FUNCNAME array is not specified phase (or default one, if not specified).
	if ! has localpatch ${foobashrc_modules} || [ "${FUNCNAME[1]}" != "${localpatch_into_phase:-post_src_unpack}" ]; then
		# Localpatch is not enabled.
		return
	else
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
		fi
}

striplafiles() {
	# Do nothing if USE contain static-libs.
	if has 'static-libs' ${USE}; then return; fi

	local i install_lafiles lafiles_whitelist

	# Some packages need .la files, we will whitelist them here.
	lafiles_whitelist=( imagemagick libtool gst-plugins-base libsidplay gnome-bluetooth kdelibs )
	for i in "${lafiles_whitelist[@]}"; do
		if [ "${PN}" = "${i}" ]; then
			install_lafiles='true'
			break
		fi
	done
	if ! [ "${install_lafiles}" = 'true' ]; then
		local line
		find "${D}" -type f -name '*.la' -print0 | while read -d $'\0' line; do
			einfo "Removing \${D}/${line/${D}} [striplafiles] ..."
			rm "${line}"; eend $?
		done
	fi
}

# All the ebuild pre and post functions.
# If function foo is not enabled, then it will 'return' after executing foo.

pre_src_unpack() { 
	localpatch
}

post_src_unpack() {
	localpatch
}

pre_src_prepare() {
	localpatch
}

post_src_prepare() {
	localpatch
}

pre_src_configure() {
	localpatch
}

post_src_configure() {
	localpatch
}

pre_src_compile() {
	localpatch
}

post_src_compile() {
	localpatch
}

pre_src_install() {
	localpatch
}

post_src_install() {
	# Srsly what you may want patch *after* installing sources?
	localpatch
}

post_pkg_preinst() {
	if has striplafiles ${foobashrc_modules}; then striplafiles; fi
	if has pathparanoid ${foobashrc_modules}; then /root/bin/pathparanoid --prefix "$D" --check --adjust; fi
}

post_pkg_postinst() {
	if has pathparanoid ${foobashrc_modules}; then /root/bin/pathparanoid --check --adjust; fi
}
