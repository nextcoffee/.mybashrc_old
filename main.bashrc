# Skip this config if we aren't in bash
[[ -n "${BASH_VERSION}" ]] || return

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=3000
HISTFILESIZE=3000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

source $(dirname $BASH_SOURCE)/common.bashrc

# the \[ \] escapes around colors make them not count as character positions and the cursor position is not wrong.
export PS1='\n`[[ $? = 0 ]] && echo \[\033[32m\] || echo \[\033[31m\]`[\w]\n\$ \[\033[0m\]'; echo -ne "\033]0;`hostname -s`:`pwd`\007"

# Add context menu on dirctory for cygwin under windows environment
# "C:\cygwin64\bin\mintty.exe" -i /Cygwin-Terminal.ico -w max /bin/env _T="%V" /bin/bash -l
# '\' -> '/'
_T="${_T//\\//}"
cd "${_T:-${HOME}}"

# customized updatedb and locate
alias myupdatedb='updatedb -U ~/ --require-visibility 0 -o ~/.locate.db'
alias mylocate='locate -d ~/.locate.db'

# adb
alias reg='adb wait-for-device root; adb wait-for-device shell /system/bin/r'
alias log='adb logcat -v threadtime'
alias klog='adb wait-for-device root; adb wait-for-device shell cat /proc/kmsg'

# Use line buffering on output.  This can cause a performance penalty.
alias lbgrep='grep --line-buffered'

# alias adb='_adb'

# _adb(){
	# # ANDROID_SERIAL
	# # adb devices | awk '{if(NR!=1) print $1}'
	# local adb_devs=(`\adb devices | sed 1d | awk '{print $1}'`)
	# local adb_serial

	# if [[ ${#adb_devs[@]} = 0 ]]; then
		# error "insert device please!"
		# return -1
	# fi

	# if [[ ${#adb_devs[@]} = 1 ]]; then
		# adb_serial=$adb_devs
	# else
		# select var in ${adb_devs[@]}; do
			# echo "choosing $var"
			# adb_serial=$var
			# break
		# done
	# fi

	# \adb -s $adb_serial $@
# }

_mycd(){
	local IFS=$'\n'
	local cur="${COMP_WORDS[COMP_CWORD]}"
	local dir_lst=($(unset HISTTIMEFORMAT; history | awk '{$1="";print $0}' | sed -n 's/^ *\(my\)\?cd *\([^;]*\).*/\2/p' | sort -u))
	local key_lst=($(echo $cur | tr '+' '\n'))

	verbose
	verbose "-----------INFO{----------"
	verbose "cur.........[${#cur}]: $cur"
	verbose "dir_lst.....[${#dir_lst[@]}]: ${dir_lst[@]}"
	verbose "key_lst.....[${#key_lst[@]}]: ${key_lst[@]}"
	verbose "-----------INFO}----------"
	verbose

	COMPREPLY=()
	[[ ${#dir_lst[@]} = 0 ]] && return 0

	COMPREPLY=($dir_lst[@])
	[[ ${#key_lst[@]} = 0 ]] && return 0

	local key
	local i
	local cnt=${#dir_lst[@]}
	for key in "${key_lst[@]}"
	do
		verbose
		verbose "key..$key"
		for (( i=0; i<$cnt; i++ ))
		do
			verbose "dir_lst[$i]..${dir_lst[i]}"
			[[ "${dir_lst[i]}" =~ "$key" ]] || unset dir_lst[$i]
		done

		verbose
	done

	verbose "dir_lst.....[${#dir_lst[@]}]:${dir_lst[@]}"

	if [[ ${#dir_lst[@]} < 2 ]]; then
		COMPREPLY=("${dir_lst[@]}")
	else
		if [[ ${cur:((${#cur}-1))} = '+' ]]; then
			COMPREPLY=(. "${dir_lst[@]}")
		else
			COMPREPLY=($cur'+')
		fi
	fi
}

mycd(){
	cd $@
}
complete -o nospace -F _mycd mycd

_genDefFileName ()
{
    case "$1" in
        "splash" | "boot" | "cache" | "userdata" | "recovery" | "system" | "persist")
            echo "$1.img"
        ;;
        "sbl1" | "tz" | "rpm")
            echo "$1.mbn"
        ;;
        "modem")
            echo "NON-HLOS.bin"
        ;;
        "dbi")
            echo "sdi.mbn"
        ;;
        "aboot")
            echo "emmc_appsboot.mbn"
        ;;
        *)
            return 1
        ;;
    esac
}

_array_contain ()
{
    local array="$1[@]"
    local seeking=$2
	local element
    for element in "${!array}"; do
        [[ $element == $seeking ]] && return 0
    done
    return 1
}

myflash ()
{
    [[ -n "$1" ]] || [[ "$1" = "-h" ]] || [[ "$1" = "--help" ]] || {
		_usage
		return 0
	}

	local partition_tbl
	local fastmode=$(fastboot devices 2>/dev/null)
	if [[ $fastmode ]]; then
		warn "already in fastboot mode, can't check battery capacity and partition table"
	else
		local force_flag=false
		[[ "$@" =~ ' -f ' ]] && force_flag=true

		[[ $(adb get-state | tr -d '\r\n') = "device" ]] || {
			error "device not found"
			return 1
		}

		if ! $force_flag; then
			local battery_cap=$(adb shell 'cat /sys/class/power_supply/battery/capacity 2>/dev/null' | tr -d ' \r\n')
			verbose "battery_cap: $battery_cap"
			if [[ -n $battery_cap ]]; then
				(( $battery_cap > 15 )) || {
					error "low battery, use -f to bypass battery check"
					return 1
				}
			else
				warn "can not access file: /sys/class/power_supply/battery/capacity"
			fi
		fi

		partition_tbl=($(adb shell 'ls /dev/block/platform/*/by-name/ 2>/dev/null' | tr -d '\r'))
		verbose "partition_tbl: ${partition_tbl[@]}"
		(( ${#partition_tbl[@]} )) || warn "can not access directory: /dev/block/platform/*/by-name/"

		adb reboot bootloader
	fi

	local op=()
	local mp=(sbl1 modem dbi tz rpm splash)
	local ap=(aboot boot cache userdata recovery system persist)
	local all=("${mp[@]}" "${ap[@]}")

	while (( $# ))
	do
		case "$1" in
			"mp" | "ap" | "all")
				eval op+=(\${$1[@]})
			;;
			*)
				op+=("$1")
			;;
		esac
		shift
	done

	date
	echo "${op[@]}"
	set "${op[@]}"
	while (( $# ))
	do
		verbose "$1";

		if [[ ${#partition_tbl[@]} > 0 ]]; then
			if ! _array_contain partition_tbl "$1"; then
				warn "unknown partition: $1"
				shift
				continue
			fi
		fi

		if [ -f "$2" ]; then
			fastboot flash $1 $2;
			shift;
		else
			local DefautFile=`_genDefFileName $1`;
			verbose "DefautFile=$DefautFile";
			if [ -n "$DefautFile" ]; then
				if [[ -f "$DefautFile" ]]; then
					fastboot flash $1 $DefautFile;
				else
					warn "file not found: $DefautFile"
				fi
			else
				error "unknown partition name ($1)";
				return 1;
			fi;
		fi;
		shift;
	done;
	fastboot reboot;
}
complete -W "all mp ap splash boot cache userdata recovery system persist sbl1 modem dbi tz rpm aboot" myflash

_comp_test ()
{
	echo
	echo -------------------
	set | grep ^COMP_
	echo -------------------
	echo
}

comp_test ()
{
	return 0
}
complete -F _comp_test comp_test

myrebootftm(){
	adb root
	adb wait-for-device

	local IFS=$' \r\n'
	local MMC_NM=($(adb shell ls /dev/block/platform))

	for var in ${MMC_NM[@]}; do
		verbose $var

		if [[ $(adb shell "[[ -w /dev/block/platform/$var/by-name/misc ]] && echo true || echo false") =~ "true" ]]; then
			adb shell 'echo ffbm-1 > /dev/block/platform/'$var'/by-name/misc'
			adb reboot
			return 0
		fi
	done

	error "no valid misc partition"
	return 1
}

##
# ## mygdbsvr
#
# #### SYNOPSIS
#   `mygdbsvr [options] [exe]`
#
# #### DESCRIPTION
#   setup gdbserver
#
# #### OPERATIONS
# - `-a`
#
#     attach mode
#
# - `-p port`
#
#     user specified port number
mygdbsvr ()
{
    local _PORT=5039
    local _ATTACH=false
    local _EXE
    local _PID
    while (( $# )); do
        verbose "$1"
        case "$1" in
            "-a")
                _ATTACH=true
            ;;
            "-p")
                shift
                if [[ ! "$1" =~ ^[0-9]+$ ]]; then
                    error "invalid PID number: ($1)"
                    return 1
                fi
                _PORT=$1
            ;;
            "-h" | "--help")
                _usage
                return 0
            ;;
            *)
                _EXE=$1
                break
            ;;
        esac
        shift
    done
    if $_ATTACH; then
        _PID=`adb shell ps | \grep "$_EXE$" | \grep -v ":" | awk '{print $2}'`
        if [[ ! "$_PID" =~ ^[0-9]+$ ]]; then
            error "Couldn't resolve '$_EXE' to single PID"
            return 1
        fi
    fi
    adb wait-for-device root
    adb kill-server
    adb -a nodaemon server &
    adb forward "tcp:$_PORT" "tcp:$_PORT"
    if $_ATTACH; then
        adb shell gdbserver :$_PORT --attach $_PID
    else
        adb shell gdbserver :$_PORT $_EXE
    fi
}
