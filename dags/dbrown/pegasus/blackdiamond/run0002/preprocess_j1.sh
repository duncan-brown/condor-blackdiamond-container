#!/bin/bash
set -e
pegasus_lite_version_major="4"
pegasus_lite_version_minor="9"
pegasus_lite_version_patch="0dev"
pegasus_lite_enforce_strict_wp_check="true"
pegasus_lite_version_allow_wp_auto_download="true"

. pegasus-lite-common.sh

pegasus_lite_init

# cleanup in case of failures
trap pegasus_lite_signal_int INT
trap pegasus_lite_signal_term TERM
trap pegasus_lite_unexpected_exit EXIT

echo -e "\n########################[Pegasus Lite] Setting up workdir ########################"  1>&2
# work dir
pegasus_lite_setup_work_dir

echo -e "\n##############[Pegasus Lite] Figuring out the worker package to use ##############"  1>&2
# figure out the worker package to use
pegasus_lite_worker_package

echo -e "\n###############[Pegasus Lite] Staging in input data and executables ###############"  1>&2
# stage in data and executables
pegasus-transfer --threads 1  --symlink  1>&2 << 'EOF'
[
 { "type": "transfer",
   "linkage": "input",
   "lfn": "f.a",
   "id": 1,
   "src_urls": [
     { "site_label": "local", "url": "file:///home/dbrown/projects/osg/condor-blackdiamond-container/local-site-scratch/dbrown/pegasus/blackdiamond/run0002/./f.a", "checkpoint": "false" }
   ],
   "dest_urls": [
     { "site_label": "local", "url": "symlink://$PWD/f.a" }
   ] }
]
EOF

echo -e "\n##################### Checking file integrity for input files #####################"  1>&2
# do file integrity checks
pegasus-integrity --print-timings --verify=f.a 1>&2

set +e
job_ec=0
echo -e "\n######################[Pegasus Lite] Executing the user task ######################"  1>&2
pegasus-kickstart -n pegasus::preprocess:4.0 -N j1 -R local  -s f.b2=f.b2 -s f.b1=f.b1 -L blackdiamond -T 2018-10-23T16:55:04-04:00 /usr/bin/pegasus-keg -a preprocess -T 60 -i f.a -o f.b1  f.b2
job_ec=$?

set -e

echo -e "\n#####################[Pegasus Lite] Staging out output files #####################"  1>&2
# stage out
pegasus-transfer --threads 1  1>&2 << 'EOF'
[
 { "type": "transfer",
   "linkage": "output",
   "lfn": "",
   "id": 1,
   "src_urls": [
     { "site_label": "local", "url": "file://$PWD/f.b2", "checkpoint": "false" }
   ],
   "dest_urls": [
     { "site_label": "local", "url": "file:///home/dbrown/projects/osg/condor-blackdiamond-container/local-site-scratch/dbrown/pegasus/blackdiamond/run0002/./f.b2" }
   ] }
 ,
 { "type": "transfer",
   "linkage": "output",
   "lfn": "",
   "id": 2,
   "src_urls": [
     { "site_label": "local", "url": "file://$PWD/f.b1", "checkpoint": "false" }
   ],
   "dest_urls": [
     { "site_label": "local", "url": "file:///home/dbrown/projects/osg/condor-blackdiamond-container/local-site-scratch/dbrown/pegasus/blackdiamond/run0002/./f.b1" }
   ] }
]
EOF


# clear the trap, and exit cleanly
trap - EXIT
pegasus_lite_final_exit

