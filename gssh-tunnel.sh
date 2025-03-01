#!/bin/bash

echo "Running gssh-tunnel.sh $*"
 
Usage() {
    echo -e "Usage: $(basename $0) -p PROJECT -z ZONE -r REMOTE_PORT -l LOCAL_PORT -i INSTANCE_NAME -u USERNAME -k KEYFILE [-b]"
    echo -e "     : -b makes it to run in background [optional]"
    exit 1
}

unset USE_LOCALHOST
if [[ $# -eq 0 ]] ; then
    Usage
fi
while getopts "hp:z:r:l:i:bu:k:L" opt; do
  case "$opt" in
    p)
      PROJECT="${OPTARG}";;
    z)
      ZONE="${OPTARG}";;
    r)
      REMOTE_PORT="${OPTARG}";;
    l)
      LOCAL_PORT="${OPTARG}";;
    i)
      INSTANCE_NAME="${OPTARG}";;
    b)
      BGND="TRUE";;
    k)
     KEYFILE="${OPTARG}";;
    u)
     USERNAME="${OPTARG}";;
    L)
     USE_LOCALHOST=1;;
    h|*)
      Usage;;
  esac
done

if [[ $USE_LOCALHOST ]]; then
	SERVICE_HOST=localhost
else
	SERVICE_HOST=$INSTANCE_NAME
fi
 
# default to current project
if [ -z ${PROJECT} ]; then
  PROJECT=$(gcloud config get-value project 2>/dev/null)
fi
 
 
#check mandatory options are passed
if [ -z "$PROJECT" ] || [ -z "$ZONE" ] || [ -z "$REMOTE_PORT" ] || [ -z "$LOCAL_PORT" ] || [ -z "$INSTANCE_NAME" ] || [ -z "$KEYFILE" ] || [ -z "$USERNAME" ]; then
  echo "Missing mandatory option"
  Usage
fi

if [ -z "$BGND" ]; then
    echo gcloud compute ssh --ssh-key-file="${KEYFILE}" --project=${PROJECT} --zone=${ZONE} $USERNAME@$INSTANCE_NAME --tunnel-through-iap --ssh-flag="-L ${LOCAL_PORT}:${SERVICE_HOST}:${REMOTE_PORT} -N"
    gcloud compute ssh --ssh-key-file="${KEYFILE}" --project=${PROJECT} --zone=${ZONE} $USERNAME@$INSTANCE_NAME --tunnel-through-iap --ssh-flag="-L ${LOCAL_PORT}:${SERVICE_HOST}:${REMOTE_PORT} -N"
else
    gcloud compute ssh --ssh-key-file="${KEYFILE}" --project=${PROJECT} --zone=${ZONE} $USERNAME@$INSTANCE_NAME --tunnel-through-iap --ssh-flag="-n" --ssh-flag="-L ${LOCAL_PORT}:${SERVICE_HOST}:${REMOTE_PORT} -fN"
fi
