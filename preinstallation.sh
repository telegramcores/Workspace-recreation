#!/usr/bin/env bash

print_if_verbatim(){
    if ! [ -z "$VERBOSE" ]; then
        eval "$@"
    fi
}


DISK="$1"

print_if_verbatim set -x

print_if_verbatim echo "date before ntpd launch: $(date)"

ntpd -q -g

print_if_verbatim echo "date after ntpd launch: $(date)"

pushd /mnt/gentoo

    # downloading distfiles list

    MIRROR="https://mirror.yandex.ru"
    PROCESSOR="amd64"
    PATH_TO_AUTOBUILDS="gentoo-distfiles/releases/${PROCESSOR}/autobuilds"

    SORTED_OUT=$(mktemp)
    print_if_verbatim echo "sorted autobuilds are in : ${SORTED_OUT}"

    download_list(){
        URL="$1"

        wget "${URL}" -O - 2>/dev/null | 
            sed -n -e '/^<a[[:space:]]\+href/p' | 
            sed 's/<[^>]*>//g' |
            sort -k 2,2r 
    }

    download_list "${MIRROR}/${PATH_TO_AUTOBUILDS}" | sed '/\//!d' > "${SORTED_OUT}"

    FOLDER_COOSER='[0-9]\{8\}T[0-9]\{6\}Z'
    FOLDER=$(cat "${SORTED_OUT}" | grep "${FOLDER_COOSER}" | awk '{print $1}' | sed 1q)

    URL_TO_CHOOSED_STAGE="${MIRROR}/${PATH_TO_AUTOBUILDS}/${FOLDER}"
    URL_TO_STAGE_FILES="${URL_TO_CHOOSED_STAGE}/$(download_list "${URL_TO_CHOOSED_STAGE}" | 
                                                    grep "${FOLDER_COOSER}" |
                                                    grep "stage3-amd64-${FOLDER_COOSER}" |
                                                    sed -e '/CONTENTS/Id'\
                                                        -e '/DIGESTS/Id' \
                                                        -e '/nomultilib/Id' |
                                                    sed 1q |
                                                    awk '{print $1}')"

    wget "${URL_TO_STAGE_FILES}"

    tar xpf stage3-*.tar.* --xattrs-include='*.*' --numeric-owner

    # adding -march=native flag
    sed -i '/COMMON_FLAGS=/ s/\("[^"]*\)"/\1 -march=native"/' etc/portage/make.conf


    # selecting mirror interactively
    mirrorselect -i -o >> etc/portage/make.conf

    mkdir --parents etc/portage/repos.conf
    cp usr/share/portage/config/repos.conf etc/portage/repos.conf/gentoo.conf

    cp --dereference /etc/resolv.conf etc/

    # mounting livecd folders
    mount --types proc  /proc proc
    mount --rbind       /sys  sys
    mount --make-rslave       sys
    mount --rbind       /dev  dev
    mount --make-rslave       dev

popd

cp ./installation.sh /mnt/gentoo
cp ./compiling.sh /mnt/gentoo
chroot /mnt/gentoo bash ./installation.sh "${DISK}"$(parted --script "${DISK}" | grep 'boot' | awk '{print $1}')
