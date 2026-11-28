#!/usr/bin/env bash
function install_missing() {
	echo Missing $1
	status=1
	if [ ! "$(command -v sudo)" ]; then
		echo Sudo not found for automatic missing installation
	elif [ "$(command -v apt)" ]; then
		echo Installing $1 with apt
		sudo apt install $1
		status=$?
	elif [ "$(command -v pacman)" ]; then
		echo Installing $1 with pacman
		sudo pacman -S $1
		status=$?
	else
		echo Cannot autoinstall missing command. Please install it manually through your distro.
	fi
	if [ $status -ne 0 ]; then
		echo Missing command installation failed. Aborting
		exit $status;
	fi
}

if [ ! "$(command -v curl)" ]; then install_missing curl; fi

function prompt_search() {
	local fixes=(
		".local/share/Steam/steamapps"
		"steam/steamapps"
		"steamapps"
		""
	)
	local selectedfolder

	while true; do
		echo -n ":"; read selectedfolder
		if [ ! "$selectedfolder" ]; then exit 1; fi
		selectedfolder=$(echo "$selectedfolder" | sed "s/^[\"']//;s/[\"']$//")

		local found=0
		for fix in "${fixes[@]}"; do
			local sub="$selectedfolder/$fix"
			if [ -d "$sub" -a -d "$sub/$balatrosub" ]; then
				gamefolder="$sub"
				found=1
			fi
		done
		if [ $found == 1 ]; then break; fi
		echo 'Not a valid Steam installation path / steamapps folder'
	done
}

balatrosub=common/Balatro

steamfolder="$HOME/.local/share/Steam"
if [ ! -d "$steamfolder" ]; then steamfolder="$HOME/snap/steam/common/.local/share/Steam"; fi
if [ ! -d "$steamfolder" ]; then steamfolder="$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam"; fi
if [ ! -d "$steamfolder" ]; then steamfolder="$HOME/.steam/steam"; fi
if [ ! -d "$steamfolder" ]; then
	echo Steam installation not found
	steamfolder=
else
	echo Steam installation at "$steamfolder"
	gamefolder="$steamfolder/steamapps"
	if [ ! -d "$gamefolder/$balatrosub" ]; then
		gamefolder=
		echo Balatro installation not found
	fi
fi

if [ ! "$gamefolder" ]; then
	echo 'The installer script cannot determine your Steam and Balatro install location.'
	echo 'Provide Steam installation folder or steamapps folder by dragging it here if supported,'
	echo 'or type in the path or leave blank to cancel.'
	echo 'You will need to have Balatro already installed.'
	echo
	prompt_search
fi

balatrofolder="$gamefolder/$balatrosub"
modsfolder="$gamefolder/compatdata/2379780/pfx/drive_c/users/steamuser/AppData/Roaming/Balatro/Mods"
mkdir -p "$modsfolder"
if [ $? -ne 0 ]; then echo Failed creating mods folder, aborting; exit 1; fi

echo "Balatro installation at "$balatrofolder"
Mods folder at "$modsfolder"
"

lovely=0
old_lovely=$([ -f "$balatrofolder/version.dll" ] && echo 1 || echo 0)
if [ ! -f "$balatrofolder/winmm.dll" ]; then
	lovely=1
else
	lovely_hash="$(sha256sum "$balatrofolder/winmm.dll" | cut -d " " -f 1)"
	exp_hash=6f707d32ff022f155584340bfb19cd93205cb47234e8bec80ccfc747222dfea2 #0.10.0
	exp_ver=0.10.0
	if [ "$lovely_hash" != "$exp_hash" ]; then
		echo "Your lovely injector version does not match the expected sha256sum for version $exp_ver"
		echo "(expected $exp_hash, got $lovely_hash)"
		echo "This means your lovely is possibly OUTDATED."
		echo -n 'Do you want to reinstall Lovely? [Y/N] '

		while true; do
			read input
			valid=1
			case "$input" in
				"Y" | "y" | "yes") lovely=1 ;;
				"N" | "n" | "no" | "") lovely=0 ;;
				*)
					echo -n 'Please type [y]es or [n]o: '
					valid=0
				;;
			esac
			if [ $valid == 1 ]; then break; fi
		done
	fi
fi

if [ "$lovely" == 1 ]; then
	if [ ! "$(command -v unzip)" ]; then install_missing unzip; fi

	echo Downloading lovely injector

	swap="$PWD"
	cd "$balatrofolder"
	curl -fSL "https://github.com/ethangreen-dev/lovely-injector/releases/latest/download/lovely-x86_64-pc-windows-msvc.zip" -o __lovely.zip
	if [ $? -ne 0 ]; then echo Failed to download lovely, aborting; exit 1; fi
	unzip -o __lovely.zip
	if [ $? -ne 0 ]; then echo Unzip failed, aborting; exit 1; fi
	rm __lovely.zip
	rm -f version.dll
	cd "$swap"
else
	echo Lovely already installed, skipping
fi

echo Downloading imm
curl -fSL "https://codeberg.org/frostice482/balatro-imm/releases/download/latest/inmodman.zip" -o "$modsfolder/imm.zip"
if [ $? -ne 0 ]; then echo Failed to download imm, aborting; exit 1; fi

if [ "$old_lovely" == 1 ]; then
echo "
!!! IMPORTANT UPDATE: LAUNCH ARGUMENT CHANGE
  version.dll has been renamed to winmm.dll as of Lovely 0.10.0.
  Go to Steam -> Balatro -> Settings -> Launch Options, and set it to:
    WINEDLLOVERRIDES=\"winmm=n,b\" %command%
"
elif [ "$lovely" == 1 ]; then
echo "
!!! ONE LAST STEP:
  Go to Steam -> Balatro -> Settings -> Launch Options, and set it to:
    WINEDLLOVERRIDES=\"winmm=n,b\" %command%
"
fi

echo "
Note:
- Your mods folder will be in $modsfolder
  I recommend making a symlink so you can access the mod folder easier:
    ln -s \"$modsfolder\" \"where_to_put_symlink\"
- There should be a console window (Lovely) that appears when the game starts.
  If it does not appear, please make an issue.
- There should be a Browse and Modpacks button in the main menu screen.
  If it does not appear, please make an issue.

Press Enter to exit
"

read
