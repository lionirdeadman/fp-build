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

if ! [ -f "$1" ]
then
    echo "$1 doesn't exist" >&2
    exit
fi

XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

git submodule update --init

if ! flatpak-builder \
    --download-only --no-shallow-clone \
    --force-clean --allow-missing-runtimes \
    --ccache \
    --state-dir="$XDG_CACHE_HOME/flatpak-builder" \
    "$XDG_CACHE_HOME/flatpak-builder-builddir/${1%.*}" "$1"
then
    echo "Download failed" >&2
    exit 1
fi

if ! flatpak-builder \
    --verbose --sandbox --user --install \
    --bundle-sources --force-clean --ccache \
    --repo="$XDG_CACHE_HOME/flatpak-builder-repo/${1%.*}" \
    --install-deps-from=flathub \
    --default-branch=localtest \
    --state-dir="$XDG_CACHE_HOME/flatpak-builder" \
    --extra-sources="$XDG_CACHE_HOME/flatpak-builder/downloads" \
    "$XDG_CACHE_HOME/flatpak-builder-builddir/${1%.*}" "$1"
then
    echo "Build failed" >&2
    exit 1
fi

flathub_json=$(dirname "$1")/flathub.json

echo "---"
echo "Appid check"
echo "---"
if zgrep -q "<id>${1%.*}\(\.\w\+\)*\(.desktop\)\?</id>" "$XDG_CACHE_HOME/flatpak-builder-builddir/${1%.*}/files/share/app-info/xmls/${1%.*}.xml.gz"
then
    echo "Pass!"
else
    echo "Fail!" >&2
fi

if [ -e "$flathub_json" ] && python3 -c 'import sys, json; sys.exit(not json.load(sys.stdin).get("skip-icons-check", False))' < "$flathub_json"
then
    echo "---"
    echo "Skipping icon check"
    echo "---"
else
    echo "---"
    echo "128x128 icon check"
    echo "---"
    if zgrep "<icon type=\\'remote\\'>" "$XDG_CACHE_HOME/flatpak-builder-builddir/${1%.*}/files/share/app-info/xmls/${1%.*}.xml.gz" || test -f "$XDG_CACHE_HOME/flatpak-builder-builddir/${1%.*}/files/share/app-info/icons/flatpak/128x128/${1%.*}.png"
    then
        echo "Pass!"
    else
        echo "Fail!" >&2
    fi
fi

if [ -e "$flathub_json" ] && python3 -c 'import sys, json; sys.exit(not json.load(sys.stdin).get("skip-appstream-check", False))' < "$flathub_json"
then
    echo "---"
    echo "Skipping Appstream check"
    echo "---"
else
    echo "---"
    echo "Appstream check"
    echo "---"
    flatpak run org.freedesktop.appstream-glib validate "$XDG_CACHE_HOME/flatpak-builder-builddir/${1%.*}/files/share/appdata/${1%.*}.appdata.xml"
fi

