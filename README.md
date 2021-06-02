# fp-build

This script tries to reproduce as much as possible of the flathub checks and flags used in flatpak-builder as
to avoid pushing and then realizing that something was wrong.

It makes the assumption that the one and only argument given will be the properly formatted `com.my.App` with
the appropriate extension (json, yaml, yml).

Example
```sh
fp-build com.discordapp.Discord.json
```

## What does it do?

There are 7 steps :

1) Checks that there is an argument pointing to an existing file
2) Checks that XDG_CACHE_HOME is set and if not, assumes $HOME/.cache
3) git submodule update --init to not forget about shared-modules
4) flatpak-builder download-only and saves those into $XDG_CACHE_HOME/flatpak-builder
5) flatpak-builder builds and saves the builddir is $XDG_CACHE_HOME/flatpak-builder-builddir/com.myApp/
6) flatpak-builder install and saves the repo is $XDG_CACHE_HOME/flatpak-builder-repo/com.my.App/
7) Various checks like the appid in the desktop file is correct, checks that a 128x128 icon is present and that the appstream data is correct

## Why are things saved in $XDG_CACHE_HOME?

It seemed to be most appropriate for testing purposes and it should be avoided by your backup solution most likely.

## Why is there a seperate download step?

I wanted all the downloads to be in the same place to have some level of deduplication.

## Why is it a shell script?

It evolved from my zsh alias as I tried to make it catch more problems and here we are.

# License

I chose LGPLv2.1 because it seemed to me to be the most compatible *GPL license and I wanted to keep it free software so I didn't choose permissive. I'm willing to change that if needed for a good cause.
