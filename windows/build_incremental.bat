set /p BUILD=<..\branch.txt

set "GN_DEFINES=use_allocator=none is_official_build=true use_sysroot=true symbol_level=0"
set GYP_MSVS_VERSION=2017
python automate-git.py --no-debug-build --minimal-distrib --client-distrib --x64-build --force-build --branch=%BRANCH% --download-dir=c:\CEF\chromium_git --depot-tools-dir=c:\CEF\depot_tools

