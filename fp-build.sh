#!/usr/bin/env sh
#
# Copyright © 2021 Lionir
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation;
# version 2.1 of the License.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library. If not, see <https://www.gnu.org/licenses/>.
#

# Our only argument is a flatpak manifest.
if ! [ "$1" ]
then
    echo "Specify a flatpak manifest"
    exit
fi

# Ensure the manifest extension is valid.
# sh exits when quotes are used here for some reason.
if [ $1 != *.yml ] && [ $1 != *.yaml ] && [ $1 != *.json ]
then
    echo "Specify a valid flatpak manifest extension"
    exit
fi

# Make sure the manifest exists
if ! [ -f "$1" ]
then
    echo "$1 doesn't exist"
    exit
fi

# We want to make sure we have all the needed binaries available.
REQUIREMENTS=('flatpak' 'zgrep' 'python3')
for binary in ${REQUIREMENTS[@]}; do
    command -v ${binary} > /dev/null 2>&1 || {
      echo "Install ${binary}}"
      exit
    }
done

XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
# Why type the whole command when we can just use a variable?
# Also helps for if someone needs to temporarily set a custom binary.
FLATPAK_BUILDER="flatpak run org.flatpak.Builder"

if ! ${FLATPAK_BUILDER} \
    --download-only --no-shallow-clone \
    --force-clean --allow-missing-runtimes \
    --ccache \
    --state-dir="$XDG_CACHE_HOME/flatpak-builder" \
    "$XDG_CACHE_HOME/flatpak-builder-builddir/${1%.*}" "$1"
then
    echo "Download failed!" >&2
    exit 1
fi

if ! ${FLATPAK_BUILDER} \
    --verbose --sandbox --user \
    --bundle-sources --force-clean --ccache \
    --install-deps-from=flathub \
    --default-branch=localtest \
    --state-dir="$XDG_CACHE_HOME/flatpak-builder" \
    --extra-sources="$XDG_CACHE_HOME/flatpak-builder/downloads" \
    "$XDG_CACHE_HOME/flatpak-builder-builddir/${1%.*}" "$1"
then
    echo "Build failed!" >&2
    exit 1
fi

if ! ${FLATPAK_BUILDER} \
    --user --install --force-clean \
    --repo="$XDG_CACHE_HOME/flatpak-builder-repo/" \
    --default-branch=localtest \
    --state-dir="$XDG_CACHE_HOME/flatpak-builder" \
    "$XDG_CACHE_HOME/flatpak-builder-builddir/${1%.*}" "$1"
then
    echo "Committing or install failed" >&2
    exit 1
fi

flathub_json=$(dirname "$1")/flathub.json

if zgrep -q "<id>${1%.*}\(\.\w\+\)*\(.desktop\)\?</id>" "$XDG_CACHE_HOME/flatpak-builder-builddir/${1%.*}/files/share/app-info/xmls/${1%.*}.xml.gz"
then
    echo "---"
    echo "AppID check.. passed!"
else
    echo "---"
    echo "AppID check.. failed!" >&2
fi

if [ -e "$flathub_json" ] && python3 -c 'import sys, json; sys.exit(not json.load(sys.stdin).get("skip-icons-check", False))' < "$flathub_json"
then
    echo "Skipping icon check.."
else
    if zgrep "<icon type=\\'remote\\'>" "$XDG_CACHE_HOME/flatpak-builder-builddir/${1%.*}/files/share/app-info/xmls/${1%.*}.xml.gz" || test -f "$XDG_CACHE_HOME/flatpak-builder-builddir/${1%.*}/files/share/app-info/icons/flatpak/128x128/${1%.*}.png"
    then
        echo "128x128 icon check.. passed!"
    else
        echo "128x128 icon check.. failed!" >&2
    fi
fi

if [ -e "$flathub_json" ] && python3 -c 'import sys, json; sys.exit(not json.load(sys.stdin).get("skip-appstream-check", False))' < "$flathub_json"
then
    echo "Skipping Appstream check"
    echo "---"
else
    echo "Appstream check"
    flatpak run org.freedesktop.appstream-glib validate "$XDG_CACHE_HOME/flatpak-builder-builddir/${1%.*}/files/share/appdata/${1%.*}.appdata.xml"
    echo "---"
fi

