#!/bin/bash
# Turns the stock `rustdesk` deb produced by build.py into an `intratecremote` deb.
#
# The client derives its systemd unit, desktop file and process names from the app
# name (lowercased), so the binary, unit and desktop files must all be called
# `intratecremote`. librustdesk.so keeps its name: the runner loads it by that name.
#
# Usage: rebrand_deb.sh <input rustdesk.deb> <output.deb> [bundle.tar.gz]
set -euo pipefail

IN=$(realpath "$1")
OUT=$(realpath -m "$2")
TARBALL=${3:+$(realpath -m "$3")}
NAME=intratecremote
DISPLAY_NAME=IntratecRemote

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
x="$work/pkg"
dpkg-deb -R "$IN" "$x"

mv "$x/usr/share/rustdesk" "$x/usr/share/$NAME"
mv "$x/usr/share/$NAME/rustdesk" "$x/usr/share/$NAME/$NAME"
mv "$x/usr/share/$NAME/files/systemd/rustdesk.service" "$x/usr/share/$NAME/files/systemd/$NAME.service"
mv "$x/usr/share/applications/rustdesk.desktop" "$x/usr/share/applications/$NAME.desktop"
mv "$x/usr/share/applications/rustdesk-link.desktop" "$x/usr/share/applications/$NAME-link.desktop"
mv "$x/usr/share/icons/hicolor/256x256/apps/rustdesk.png" "$x/usr/share/icons/hicolor/256x256/apps/$NAME.png"
mv "$x/usr/share/icons/hicolor/scalable/apps/rustdesk.svg" "$x/usr/share/icons/hicolor/scalable/apps/$NAME.svg"

rebrand_text() {
  sed -i -e "s/RustDesk/$DISPLAY_NAME/g" -e "s/rustdesk/$NAME/g" "$@"
}
rebrand_text \
  "$x/usr/share/$NAME/files/systemd/$NAME.service" \
  "$x/usr/share/applications/$NAME.desktop" \
  "$x/usr/share/applications/$NAME-link.desktop" \
  "$x/DEBIAN/preinst" "$x/DEBIAN/postinst" "$x/DEBIAN/prerm" "$x/DEBIAN/postrm"
sed -i \
  -e "s/^Package: rustdesk$/Package: $NAME/" \
  -e "s/^Maintainer: .*/Maintainer: Intratec Logic <contactus@intrateclogic.com>/" \
  -e "s|^Homepage: .*|Homepage: https://intrateclogic.com|" \
  -e "s/^Description: .*/Description: Intratec Logic remote support client./" \
  "$x/DEBIAN/control"
grep -q "^Package: $NAME$" "$x/DEBIAN/control"

(cd "$x" && find usr -type f -exec md5sum {} + > DEBIAN/md5sums)
dpkg-deb --root-owner-group -b "$x" "$OUT"

if [ -n "$TARBALL" ]; then
  tar -C "$x/usr/share" -czf "$TARBALL" "$NAME"
fi
