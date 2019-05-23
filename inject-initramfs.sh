#!/bin/bash

unsquash() {
    echo "Unsquashing $kernel..."
    unsquashfs -d "$rootdir" "$kernel"
}

extract() {
    echo "Extracting initramfs..."
    unmkinitramfs "$rootdir/initrd.img" "$fsdir"
}

inject() {
    echo "Injecting $initramfs..."
    cp -rap "$initramfs"/conf/* "$confdir"
    cp -rap "$initramfs"/scripts/* "$scriptdir"
}

repack() {
    echo "Repacking initramfs..."
    (cd "$fsdir/early"; find . | cpio -H newc -o) > "$rootdir/initrd.img"
    (cd "$fsdir/main"; find . | cpio -H newc -o | gzip -c) >> "$rootdir/initrd.img"
}

resquash() {
    if [ -z "$output" ]; then
        num=1
        while [ -f "$kernel.$num" ]; do
            num=$((num + 1))
        done
        output="$kernel.$num"
    fi
    mksquashfs "$rootdir" "$output" -noappend -comp xz -no-xattrs -no-fragments
    echo "Created $output"
}

usage() {
    echo "Usage: $0 [-o output] <kernel snap> <initramfs>"
    exit
}

while getopts "ho:" opt; do
    case "${opt}" in
        o)
            output="$OPTARG"
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

if [ $# -lt 2 ]; then
    usage
fi


kernel="$1"
initramfs="$2"
tmpdir=$(mktemp -d -t inject-XXXXXXXXXX)
rootdir="$tmpdir/root"
fsdir="$tmpdir/fs"
confdir="$fsdir"/main/conf/conf.d
scriptdir="$fsdir"/main/scripts

mkdir -p "$confdir" "$scriptdir"

function finish {
    echo "Cleaning up"
    rm -Rf "$tmpdir"
}
trap finish EXIT

unsquash
extract
inject
repack
resquash
