set /p BRANCH=<..\branch.txt

set "GN_DEFINES=use_allocator=none is_official_build=true use_sysroot=true symbol_level=0"
set GYP_MSVS_VERSION=2017
python automate-git.py --download-dir=c:\CEF\chromium_git --depot-tools-dir=c:\CEF\depot_tools --no-distrib --no-build --x64-build --branch=%BRANCH%

