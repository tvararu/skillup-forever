#!/usr/bin/env bash
# Builds the packaged addon from HEAD (ForeverCore embedded, .pkgmeta's ignores dropped) and installs it on t1.
# The installed copy is backed up to ~/skillup-forever-backups on t1 first.
set -euo pipefail

HOST=${SKILLUP_HOST:-t1}
ADDONS=${SKILLUP_ADDONS:-"/home/deity/Games/battlenet/drive_c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns"}
ROOT=$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel)
CORE=${FOREVER_CORE:-"$ROOT/../forever-core"}
BUILD=$(mktemp -d)
trap 'rm -rf "$BUILD"' EXIT

git -C "$ROOT" archive HEAD | tar -x -C "$BUILD"
version="$(git -C "$ROOT" describe --tags --always)-queue"
sed -i.bak "s/@project-version@/$version/" "$BUILD/SkillUpForever.toc" && rm "$BUILD/SkillUpForever.toc.bak"
# The embed reads the pin under tools/, so it runs before the package's ignores are dropped.
(cd "$ROOT" && python3 -m tools.forever_tools.embed --core "$CORE" "$BUILD")
for ignored in AGENTS.md CLAUDE.md tools types tests docs stylua.toml ruff.toml \
	Locales/phrases.txt Locales/README.md media/icon.svg media/icon-400.png .agents .claude .github; do
	rm -rf "${BUILD:?}/$ignored"
done

if ssh "$HOST" "pgrep -f [W]ow.exe >/dev/null"; then
	echo "WoW is running on $HOST: deploying anyway, /reload to pick it up" >&2
fi
stamp=$(date +%Y%m%d-%H%M%S)
ssh "$HOST" "mkdir -p ~/skillup-forever-backups && tar -czf ~/skillup-forever-backups/SkillUpForever-$stamp.tar.gz -C \"$ADDONS\" SkillUpForever"
rsync -a --delete "$BUILD/" "$HOST:\"$ADDONS/SkillUpForever/\""
echo "installed $version on $HOST (backup SkillUpForever-$stamp.tar.gz)"
