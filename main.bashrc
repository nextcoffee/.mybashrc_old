source common.bashrc

# the \[ \] escapes around colors make them not count as character positions and the cursor position is not wrong.
export PS1='\n`[[ $? = 0 ]] && echo \[\033[32m\] || echo \[\033[31m\]`[\w]\n\$ \[\033[0m\]'; echo -ne "\033]0;`hostname -s`:`pwd`\007"

# Add context menu on dirctory for cygwin under windows environment
# "C:\cygwin64\bin\mintty.exe" -i /Cygwin-Terminal.ico -w max /bin/env _T="%V" /bin/bash -l
# '\' -> '/'
_T=${_T//\\//}
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

# 
_mycd(){
	local old_ifs=$IFS
	
	IFS=$'\n'
	local cur="${COMP_WORDS[COMP_CWORD]}"
	local dir_lst=($(unset HISTTIMEFORMAT; history | awk '{$1="";print $0}' | sort -u | sed -n 's/^ *cd *\([^;]*\).*/\1/p'))
	local key_lst=($(echo $cur | tr '+' '\n'))
	IFS=$old_ifs

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
	
	for key in ${key_lst[@]}
	do
		verbose
		verbose "key..$key"
		for (( i=0; i<${#dir_lst[@]}; i++ ))
		do
			verbose "dir_lst[$i]..${dir_lst[i]}"
			[[ "${dir_lst[i]}" =~ "$key" ]] || dir_lst[i]=''
		done
		
		#clear up empty elements
		dir_lst=(${dir_lst[@]})
		verbose
	done

	verbose "dir_lst.....[${#dir_lst[@]}]:${dir_lst[@]}"
	
	if [[ ${#dir_lst[@]} < 2 ]]; then
		COMPREPLY=(${dir_lst[@]})
	else
		if [[ ${cur:((${#cur}-1))} = '+' ]]; then
			COMPREPLY=(. ${dir_lst[@]})
		else
			COMPREPLY=($cur'+')
		fi
	fi
}

mycd(){
	cd $@
}
complete -o nospace -F _mycd mycd