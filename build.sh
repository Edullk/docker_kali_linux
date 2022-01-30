#!/bin/bash

set -e
set -u

IMAGES="${1:-kali-rolling}"
ARCHS="${2:-amd64}"

USAGE="Usage: $(basename $0) [IMAGES] [ARCHITECTURES]

IMAGES and ARCHITECTURES must be space-separated and surrounded by quotes.
Use 'all' as a special keyword to build all images. Same for architectures.
"

if [ $# -ge 3 ]; then
    echo "$USAGE" >&2
    exit 1
fi

BASE_IMAGES="kali-rolling kali-dev kali-last-release"
EXTRA_IMAGES="kali-experimental kali-bleeding-edge kali"

[ "$IMAGES" == all ] && IMAGES="$BASE_IMAGES $EXTRA_IMAGES"
[ "$ARCHS" == all ] && ARCHS="amd64 arm64 armhf"

# ensure base images get built first, as extra images depend on it
for image in $(printf "%s\n" $BASE_IMAGES | tac); do
    if echo "$IMAGES" | grep -qw $image; then
        IMAGES="$image ${IMAGES//$image/}"
    fi
done

echo "Images ..... : $IMAGES"
echo "Architectures: $ARCHS"

RUN=$(test $(id -u) -eq 0 || echo sudo)

for image in $IMAGES; do
    # we can't just use 'grep -w' due to an image being named 'kali'
    # cf. https://stackoverflow.com/a/46073005/776208 for the regex magic
    if echo "$BASE_IMAGES" | grep -q -P '(?<![\w-])'"$image"'(?![\w-])'; then
        base_image=1
    elif echo "$EXTRA_IMAGES" | grep -q -P '(?<![\w-])'"$image"'(?![\w-])'; then
        base_image=0
    else
        echo "Invalid image name '$image'" >&2
        continue
    fi
    for arch in $ARCHS; do
        echo "========================================"
        echo "Building image $image/$arch"
        echo "========================================"
        if [ $base_image -eq 1 ]; then
            $RUN ./build-rootfs.sh "$image" "$arch"
            $RUN ./docker-build.sh "$image" "$arch"
        else
            $RUN ./docker-build-extra.sh "$image" "$arch"
        fi
        $RUN ./docker-test.sh  "$image" "$arch"
        $RUN ./docker-push.sh  "$image" "$arch"
    done
    $RUN ./docker-push-manifest.sh "$image" "$ARCHS"
done
