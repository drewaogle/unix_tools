#!/bin/bash
# 2022-2025 Drew Ogle <drew@aperturedata.io>
# all-tunnels.sh - tool to create tunnels for accessing services on cloud providers.

DEBUG=0
debug() (( $DEBUG ))

# location of defintions; one or more files with the suffix '.def' - shell  script 'parts' that use add_zone. 
tunnel_def_dir=${ALL_TUNNELS_DIR:=$(realpath $(dirname "$0")/"tunnel-definitions")}

# functions for defining services

add_service () {
	local -n svc_rec=$1
	local proj=${svc_rec[proj]}
	global_name=projs_${proj}
	svc_rec["zone"]=$2

	if [[ -z "${projs[${proj}]}" ]]; then
		debug && echo "add_service: creating proj info for ${proj}"
		declare -g -A $global_name
		projs[${proj}]=$global_name
	fi


	local -n proj_ref=$global_name
	key=${svc_rec[system]}_${svc_rec[name]}
	safe_key="__${proj}_${1}"
	proj_ref[$key]=$safe_key
	debug && echo "add_service: adding service $1 in zone $2 key $key in $global_name with name $safe_key"
	# copy local definition into global and add namespacing
	tmpdef=$(declare -p $1) && declare -g -A "$safe_key"="${tmpdef#*=}"
}

add_zone () {
	zone_name=$1
	shift

	local -n zone_rec=$zone_name
	local proj=${zone_rec[proj]}
	local zone=${zone_rec[zone]}

	if [ -z $projs_created ]; then
		debug && echo "add_zone: creating zones"
		declare -g -A projs=()
		declare -g -A proj_defs=()
		declare -g projs_created=1
	fi


	debug && echo "add_zone: name: ${proj} data: ${zone_name}"
	proj_defs["${proj}"]="__$zone_name"

	# copy local definition into global and add namespacing
	tmpdef=$(declare -p $zone_name) && declare -g -A "__$zone_name"="${tmpdef#*=}"

	for service in "$@";
	do
		add_service $service $zone
	done
}



add_tunnel_definitions() {
	if [ ! -d "$tunnel_def_dir" ]; then
		echo "FATAL: missing '"${tunnel_def_dir}"' directory for configuration"
		exit 2
	fi

	DEFS=0

	for f in $(ls ${tunnel_def_dir}/*.def);
	do
		debug && echo "tunnel_definitions: Adding definition: $f"
		((DEFS++))
		. ${f}
	done

	if [[ $DEFS == 0 ]]; then
		echo "FATAL: no definitions loaded for configuration"
	fi
	debug && echo "Done"
}

# includes service definitions here
add_tunnel_definitions


# functions for executing user comands 
check_gcp_login() {
	gcloud auth print-access-token >/dev/null 2>&1

	if [ $? -eq 1 ]; then
		if [ -v VERBOSE ]; then echo "check_login: not logged in (no access token)."; fi
		wait
		gcloud auth login
		if [ -v VERBOSE ]; then gcloud auth print-access-token; fi
		if [ $? -eq 1 ]; then
			echo "Auth failed. Run again."
			exit 0
		fi
	else
		if [ -v VERBOSE ]; then echo "Authorization OK"; fi
	fi
}

run_cmds () {

	ran=0
	if [ -v CREATE_TUNNEL -a ! -v REFUSE_LOGIN  ];
	then
		check_gcp_login
	fi

	# iterate over project definition array
	for single in "${projs[@]}"
	do
		_displayed_proj=0
		local -n proj_rf=$single
		# iterate over project array
		for svc in "${proj_rf[@]}"
		do
			local -n svr_rec=$svc
			debug && ( printf -v fmtStr '[%s]=%%q  ' "${!svr_rec[@]}";printf "run: svc $fmtStr\n" "${svr_rec[@]}" )
			system=${svr_rec[system]}
			sysshort=${svr_rec[sysshort]}
			name=${svr_rec[name]}
			lp=${svr_rec[local_port]}
			sp=${svr_rec[service_port]}
			proj=${svr_rec[proj]}
			zone=${svr_rec[zone]}



			local proj_key="${proj}"
			proj_ref_name=${proj_defs[${proj_key}]}
			local -n proj_ref=$proj_ref_name

			zone=${proj_ref[zone]}
			proj_name=${proj_ref[name]}
            username=${proj_ref[username]}
            keyfile=${proj_ref[keyfile]}
            debug && echo "run: Zone $proj_ref_name ${proj_ref[@]}"

			if [ ! -v $PROJ_FILTER ]; then
				if [  ! "$PROJ_FILTER" == "$proj" ]; then
					continue
				fi
			fi

			if [ ! -v $SYSTEM_FILTER ]; then
				if [  ! "$SYSTEM_FILTER" == "$system" -a ! "$SYSTEM_FILTER" == "$sysshort" ]; then
					continue
				fi
			fi

			if [ ! -v $SERVICE_FILTER ]; then
				if [  ! "$SERVICE_FILTER" == "$name"  ]; then
					continue
				fi
			fi

			if [ $_displayed_proj -eq 0 ]; then
				echo " === Project: $proj ==="
				_displayed_proj=1
			fi

			if [ ! -v $DISPLAY_INFO ]; then
				echo "Service: $name Host: $system Service Port: $sp Local Port: $lp" #$single - $svc $system $name"
				#echo "$single - $svc $system $name"
			fi

			if [ ! -v $KILL_TUNNEL ]; then
				tpid=$(lsof -t -i:${lp})
				if [ ! -v $tpid ]; then
					echo "all_tunnels: Killing local pid $tpid for service $name/$system"
					kill -9 $tpid
				fi
			fi

			if [ ! -v $CREATE_TUNNEL ]; then
				(( ran++ ))
				echo "all_tunnels: Creating tunnel for $name on $system in $sysshort"
				./gssh-tunnel.sh -p $proj_name -z $zone -r $sp -l $lp -i $system -u $username -k $keyfile -b
			fi


		done
	done

	if (( ran == 0 && DISPLAY_INFO != 1 )); then
		echo "all_tunnels: Nothing matched to run"
	fi
}

# parse user commands

set -o errexit
params="$(getopt -o hvDKp:s:r:L -l help,verbose,displayconfig,kill,proj:,system:,service:,login,nologin --name "$0" -- "$@")"
eval set -- "$params"
set +o errexit

CREATE_TUNNEL=1
unset KILL_TUNNEL
unset DISPLAY_INFO
unset REFUSE_LOGIN
unset PROJ_FILTER
unset SYSTEM_FILTER
unset SERVICE_FILTER

while true
do
	case "$1" in
		-D|--display)
			unset CREATE_TUNNEL
			unset KILL_TUNNEL
			DISPLAY_INFO=1
			shift
			;;
		-v|--verbose)
			DISPLAY_INFO=1
			shift
			;;
		-K|--kill)
			unset CREATE_TUNNEL
			KILL_TUNNEL=1
			shift
			;;
		-p|--proj)
			PROJ_FILTER="$2"
			shift 2
			;;
		-s|--system)
			SYSTEM_FILTER="$2"
			shift 2
			;;
		-r|--service)
			SERVICE_FILTER="$2"
			shift 2
			;;
		-h|--help)
			APP=$(basename $0)
			echo "$APP - tool for managing remote tunnels in cloud providers"PP=$(basename $0)
			echo "Action Options"
			echo " -K,--kill           kill selected tunnels"
			echo " -D,--display        display selected tunnels"
			echo " -L,--login          check login for selected tunnels"
			echo " No action implies kill and start selected tunnels"
			echo ""
			echo "Selection Options"
			echo " -p,--proj [name]    Select only items with configured project name"
		        echo " -s,--system [name]  Select only items with configured system name"
		        echo " -r,--service [name] Select only items with configured service name"
		        echo ""
		        echo "project names should be unique, but system and service names need not be"
		        echo " a system called 'aperturedb' could exist within 2 different projects"
		        echo " and each could have a 'ssh' service, and -s aperturedb -r ssh would allow"
		        echo " tunneling to be activated for both"
			echo ""
			echo "Utility Options"
			echo " -v,--verbose        set verbose output"
			echo " -h,--help           display this help output"
			exit 0
			;;
		-L|--login)
			echo "Checking Login"
			check_login
			exit 0
			;;
		--nologin)
			REFUSE_LOGIN=1
			shift
			;;
		--)
			shift
			break
			;;
		*)
			echo "Invalid Argument: $1" >&2
			exit 1
			;;
	esac 
done


run_cmds
