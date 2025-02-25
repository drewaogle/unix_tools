These are defintions which are intentended to be shareable

Example:
```
# aio_gcp - definitions for Aperture vms.
declare -A aio_info=( [proj]=aio [name]=aperturedata [zone]=us-central1-a )
#drew stuff
declare -A aio_drew_1=( [proj]=aio [sysshort]=drew_test [system]=drew-client-bq-test [name]=ssh [service_port]=22 [local_port]=5301 )

add_zone aio_info aio_drew_1
```

you need a zone and at least one service to add a zone.
zones and services are declared as associate array.

Define multiple zones in a given project name as .. different zones,
so like aio_c for central servers and aio_w for west servers.

proj has to be in the service defs ( for now )
