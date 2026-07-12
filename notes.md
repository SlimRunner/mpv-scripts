# TODO

Below are random things I want to document about setting this up for my
own ease of use.

## Easy Install for Windows

- [x] open https://github.com/zhongfly/mpv-winbuild
  - [x] go to releases
  - [x] unzip in a permanent location
  - [x] run `mpv-register.bat` (`install.bat` in older builds)
- [x] (optional) create directory `portable_config` (sibling with `mpv.exe`)

Last step allows to share same settings across multiple users.
Otherwise, they are at `%APPDATA%/mpv` and something else. See Wiki for
more info.
