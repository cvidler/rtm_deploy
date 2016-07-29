#! /bin/bash
#
# rtm_deploy.sh
# Chris Vidler - Dynatrace DCRUM SME - 2016
# Deploy update... packages to remote AMDs
#

#script defaults
DEPPATH=/tmp
DEPUSER=root
DEPPASS=greenmouse
DEPEXEC=1
IDENT=""
REBOOT=1
REBOOTSCHED=now





#script follows do not edit.

function debugecho {
	if [[ $DEBUG -ne 0 ]]; then echo -e "\e[2m***DEBUG: $@\e[0m"; fi
}


function setdebugecho {
	if [[ $DEBUG -ne 0 ]]; then echo -ne "\e[2m"; fi
}

function unsetdebugecho {
	if [[ $DEBUG -ne 0 ]]; then echo -ne "\e[0m"; fi
}

#command line parameters
OPTS=0
while getopts ":hdeErRf:a:u:p:i:s:" OPT; do
	case $OPT in
		h)
			OPTS=0	#show help
			;;
		d)
			DEBUG=1
			;;
		f)
			OPTS=1
			DEPFILE=$OPTARG
			;;
		e)
			OPTS=1
			DEPEXEC=1
			;;
		E)
			OPTS=1
			DEPEXEC=0
			;;
		r)
			OPTS=1
			REBOOT=1
			;;
		R)
			OPTS=1
			REBOOT=0
			;;
		s)
			OPTS=1
			REBOOTSCHED=$OPTARG
			;;
		a)
			OPTS=1
			AMDADDR=$OPTARG
			;;
		u)
			OPTS=1
			DEPUSER=$OPTARG
			;;
		p)
			OPTS=1
			DEPPASS=$OPTARG
			;;
		i)
			if [ -r $OPTARG ]; then
				OPTS=1
				IDENT=" -i $OPTARG"
				DEPPASS=""
			else
				OPTS=0
				echo -e "\e[31m*** FATAL:\e[0m Identity file $OPTARG not present or inaccessible."
				exit 1
			fi
			;;
		\?)
			OPTS=0 #show help
			echo "*** FATAL: Invalid argument -$OPTARG."
			;;
		:)
			OPTS=0 #show help
			echo "*** FATAL: argument -$OPTARG requires parameter."
			;;
	esac
done

#abort, showing help, if required options are unset
if [ "$DEPFILE" == "" ]; then OPTS=0; fi
if [ "$AMDADDR" == "" ]; then OPTS=0; fi

#check if passed reboot schedule is a valid format 'now' or a +m (number of minutes), or hh:mm (24hr clock)
if [[ $REBOOTSCHED =~ ^now$ ]]; then
	# 'now', OK
	echo -n
elif [[ $REBOOTSCHED =~ ^\+[0-9]+$ ]]; then
	# +m minutes, OK
	echo -n
elif [[ $REBOOTSCHED =~ ^(2[0-3]|1[0-9]|0?[0-9]):[0-5][0-9]$ ]]; then
	# hh:mm 24-hr clock, OK
	echo -n
else
	#unknown schedule, show help
	echo -e "\e[31m*** FATAL:\e[0m Reboot schedule '$REBOOTSCHED' invalid."
	OPTS=0
fi


if [ $OPTS -eq 0 ]; then
	echo -e "*** INFO: Usage: $0 [-h] [-E|-e] [-R|r] [-s hh:mm|+m|now] -a amdaddress|listfile -f deployfile [-u user] [-p password | -i identfile]"
	echo -e "-h This help"
	echo -e "-a amdaddress|listfile address or if a file list one per line for AMDs to deploy to. Required."
	echo -e "-f Full path to upgrade.*.bin file. Required."
	echo -e "-u user with root or sudo rights to copy and execute upgrade file. Default root."
	echo -e "-p password for user. Default greenmouse."
	echo -e "-i SSH private key identity file."
	echo -e "-e Execute upgrade once copied. Default."
	echo -e "-E DO NOT Execute upgrade once copied"
	echo -e "-r Reboot upgrade once copied. Default. (No effect with -E)"
	echo -e "-R DO NOT reboot upgrade once copied."
	echo -e "-s Reboot schedule 'hh:mm' 24hr clock, '+m' m minutes from now, or 'now'. Default 'now'. (No effect with -R)"
	echo -e ""
	echo -e "-p and -i are exclusive, -i takes precedence as it is more secure."
	exit 0
fi

#check if passed file is readable.
if [ ! -r $DEPFILE ]; then
	echo -e "\e[31m*** FATAL:\e[0m Upgrade file $DEPFILE not present or inaccessible."
	exit 1
fi

#check if passed amd address is a file (treat it as a list) or not (a single amd address).
if [ -r $AMDADDR ]; then
	#it's a list file
	#read file loading each line into var
	AMDLIST=""
	while read line; do
		if [[ $line == "#"* ]]; then continue; fi		#skip comments
		if [[ $line == "" ]]; then continue; fi			# blank lines

		if [[ $line =~ ^([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+|[a-zA-Z0-9\.-]+|\[?[0-9a-fA-F:]+\]?)$ ]]; then		#rudimentary ip/fqdn/ipv6 test
			AMDLIST="$AMDLIST$line\n"
		else
			debugecho "AMDLIST nonmatching line: ${line}"
		fi
	done < <(cat $AMDADDR)
	AMDLIST=${AMDLIST%%\\n}		#remove trailing comma
else
	#it's not a list file. nothing to do.
	AMDLIST=$AMDADDR
fi


debugecho "Configuration:"
debugecho "DEPUSER: '$DEPUSER', DEPPASS: '$DEPPASS', IDENT: '$IDENT', AMDADDR: '$AMDADDR' "
debugecho "DEPPATH: '$DEPPATH', REBOOT: '$REBOOT', REBOOTSCHED: '$REBOOTSCHED', DEPEXEC: '$DEPEXEC' "
debugecho "AMDLIST: '$AMDLIST' "

#exit

#get dependencies for config
SCP=`which scp`
if [ $? -ne 0 ]; then
	echo -e "\e[31m*** FATAL:\e[0m dependency 'scp' not found."
	exit 1
fi
SSH=`which ssh`
if [ $? -ne 0 ]; then
	echo -e "\e[31m*** FATAL:\e[0m dependency 'ssh' not found."
	exit 1
fi
debugecho "SCP: '$SCP', SSH: '$SSH' "


#build configs
if [ $DEBUG == 1 ]; then VERBOSE=" -v"; fi		#in debug mode add verbosity to SCP and SSH commands later on

#DEPPASS="$DEPPASS"
if [ ! "$IDENT" == "" ]; then 
	# if ident file to be used clear any default or user set password.
	DEPPASS=""
else
	# if user supplied password is required, need to use 'sshpass' to automatically pass it to both SCP and SSH.
	SSHPASSE=`which sshpass`
	if [ $? -ne 0 ]; then
		echo -e "\e[31m*** FATAL:\e[0m dependency 'sshpass' not found."
		exit 1
	fi
	debugecho "SSHPASSE: $SSHPASSE"
	SSHPASS=${DEPPASS}
	DEPPASS="${SSHPASSE} -e "
	#debugecho "SSHPASS: $SSHPASS"
	debugecho "DEPPASS: '$DEPPASS'"
fi
#AMDADDR="@$AMDADDR"
#DEPPATH=":$DEPPATH" 

if [ ! -x $DEPFILE ]; then chmod +x $DEPFILE; debugecho "chmod +x to '$DEPFILE'"; fi

SUCCESS=""
FAIL=""

while read line; do

	AMDADDR=$line
	echo -e "\e[34mrtm_deploy.sh\e[0m Deploying ${DEPFILE##*/} to ${AMDADDR}"

	#build SCP command line
	SCPCOMMAND="${DEPPASS}${SCP}${VERBOSE} -p${IDENT} ${DEPFILE} ${DEPUSER}@${AMDADDR}:${DEPPATH}"
	debugecho "SCP command: $SCPCOMMAND"

	#export envvar for sshpass
	export SSHPASS=$SSHPASS

	#run SCP command
	setdebugecho
	RESULT=`$SCPCOMMAND`
	EC=$?
	unsetdebugecho
	if [[ $EC -ne 0 ]]; then
		echo -e "\e[31m*** FATAL:\e[0m SCP to ${AMDADDR} failed."
		FAIL="${FAIL}${AMDADDR}\n"
		continue
	fi
	echo -e "\e[32m*** SUCCESS:\e[0m Copied ${DEPFILE##*/} to ${AMDADDR}."
	if [ $DEPEXEC == 0 ]; then SUCCESS="${SUCCESS}${AMDADDR}\n"; fi

	#build SSH command line to run copied file
	if [ "$DEPEXEC" == "1" ]; then
		if [ $REBOOT = 1 ]; then REBOOT=" && shutdown -r $REBOOTSCHED"; else REBOOT=""; fi
		SSHCOMMAND="${DEPPASS}${SSH}${VERBOSE} ${IDENT} ${DEPUSER}@${AMDADDR} /usr/bin/yes n | /usr/bin/perl ${DEPPATH}/${DEPFILE##*/}${REBOOT}"
		debugecho "SSH command: $SSHCOMMAND"

		#run SSH command
		setdebugecho
		RESULT=`$SSHCOMMAND`
		EC=$?
		unsetdebugecho
		debugecho $RESULT
		if [ $EC == 0 ]; then
			echo -n
		elif [ $EC == 255 ]; then
			echo -e "\e[31m*** FATAL:\e[0m SSH to ${AMDADDR} failed. EC=$EC"
			FAIL="${FAIL}${AMDADDR}\n"
			continue
		else
			echo -e "\e[31m*** FATAL:\e[0m Remote command to ${AMDADDR} failed. EC=$EC"
			echo -e "\e[31m*** DEBUG:\e[0m Command line: '${SSHCOMMAND}'"
			echo -e "\e[31m*** DEBUG:\e[0m Result: '${RESULT}'"
			FAIL="${FAIL}${AMDADDR}\n"
			continue
		fi

		echo -e "\e[32m*** SUCCESS:\e[0m Deployed ${DEPFILE##*/} on ${AMDADDR}."
		SUCCESS="${SUCCESS}${AMDADDR}\n"
	fi
done < <(echo -e "$AMDLIST")


#finish
echo
echo -e "rtm_deploy.sh complete"
RET=0
if [[ $FAIL == "" ]]; then FAIL="(none)"; else RET=1; fi
if [[ $SUCCESS == "" ]]; then SUCCESS="(none)"; RET=1; fi
echo -e "\e[32mSuccessfully deployed to:\e[0m"
echo -e "${SUCCESS}"
echo -e "\e[31mFailed deployment to:\e[0m"
echo -e "${FAIL}"
debugecho "RET: $RET"
exit $RET

