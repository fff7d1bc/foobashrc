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

localpatch() {
	local patches_overlay_dir patches patch locksufix

	locksufix="${RANDOM}"

	LOCALPATCH_OVERLAY="${LOCALPATCH_OVERLAY:-/etc/portage/patches}"

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

preserveperms() {

	myelog(){
		ewarn "$@"
		if [ -n "${preserveperms_logfile}" ]; then
			echo "${CATEGORY}/${PN}-${PVR}: $@" >> ${preserveperms_logfile}
		fi
	}

	find ${D} | while read line; do
		newthing="${line}"
		oldthing="${ROOT}${line/${D}/}"
		if [ -e "${oldthing}" ]; then
			oldthing_owner="$(stat -c '%U' "${oldthing}")"
			oldthing_group="$(stat -c '%G' "${oldthing}")"
			oldthing_mode="$(stat -c '%a' "${oldthing}")"

			newthing_owner="$(stat -c '%U' "${newthing}")"
			newthing_group="$(stat -c '%G' "${newthing}")"
			newthing_mode="$(stat -c '%a' "${newthing}")"

			if [ "${newthing_owner}" != "${oldthing_owner}" ]; then
				myelog "Preserve perms on \${D}${oldthing}: Changing owner from '${newthing_owner}' to '${oldthing_owner}'"
				chown "${oldthing_owner}" "${newthing}" || die 'chown failed.'
			fi
			
			if [ "${newthing_group}" != "${oldthing_group}" ]; then
				myelog "Preserve perms on \${D}${oldthing}: Changing group from '${newthing_group}' to '${oldthing_group}'"
				chgrp "${oldthing_group}" "${newthing}" || die 'chgrp failed.'
			fi

			if [ "${newthing_mode}" != "${oldthing_mode}" ]; then
				myelog "Preserve perms on \${D}${oldthing}: Changing mode from '${newthing_mode}' to '${oldthing_mode}'" 
				chmod "${oldthing_mode}" "${newthing}" || die 'chmod failed.'
			fi
		fi
	done

	unset -f myelog
}

pre_src_prepare() {
	if hasq localpatch ${foobashrc_modules}; then 
		localpatch
	fi
}

post_pkg_preinst() {
	if hasq preserveperms ${foobashrc_modules}; then
		preserveperms
	fi
}
