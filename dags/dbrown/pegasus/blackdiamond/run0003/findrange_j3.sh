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
pegasus-transfer --threads 1  1>&2 << 'EOF'
[
 { "type": "transfer",
   "linkage": "input",
   "lfn": "centos-pycbc",
   "id": 1,
   "src_urls": [
     { "site_label": "condorpool", "url": "file:///cvmfs/singularity.opensciencegrid.org/pycbc/pycbc-el7:latest", "checkpoint": "false" }
   ],
   "dest_urls": [
     { "site_label": "condorpool", "url": "symlink://$PWD/centos-pycbc", "type": "singularity" }
   ] }
 ,
 { "type": "transfer",
   "linkage": "input",
   "lfn": "f.b2",
   "id": 2,
   "generate_checksum": false,
   "src_urls": [
     { "site_label": "local", "url": "gsiftp://sugwg-condor.phy.syr.edu/home/dbrown/projects/osg/condor-blackdiamond-container/local-site-scratch/dbrown/pegasus/blackdiamond/run0003/./f.b2", "checkpoint": "false" }
   ],
   "dest_urls": [
     { "site_label": "condorpool", "url": "file://$PWD/f.b2" }
   ] }
]
EOF

set -e

echo -e "\n########[Pegasus Lite] Writing out script to launch user task in container ########"  1>&2

cat <<EOF > findrange_j3-cont.sh
#!/bin/bash
set -e
# setting environment variables for job
pegasus_lite_version_major=$pegasus_lite_version_major
pegasus_lite_version_minor=$pegasus_lite_version_minor
pegasus_lite_version_patch=$pegasus_lite_version_patch
pegasus_lite_enforce_strict_wp_check=false
pegasus_lite_version_allow_wp_auto_download=$pegasus_lite_version_allow_wp_auto_download
pegasus_lite_work_dir=/srv
echo \$PWD  1>&2
. pegasus-lite-common.sh
pegasus_lite_init


echo -e "\n##############[Container] Figuring out Pegasus worker package to use ##############"  1>&2
# figure out the worker package to use
pegasus_lite_worker_package
echo "PATH in container is set to is set to \$PATH"  1>&2

echo -e "\n##################### Checking file integrity for input files #####################"  1>&2
# do file integrity checks
pegasus-integrity --print-timings --verify=f.b2 1>&2

set +e
job_ec=0
echo -e "\n#########################[Container] Launching user task #########################"  1>&2

pegasus-kickstart  -n pegasus::findrange:4.0 -N j3 -R condorpool  -s f.c2=f.c2 -L blackdiamond -T 2018-10-23T16:55:04-04:00 /usr/bin/pegasus-keg -a findrange -T 60 -i f.b2 -o f.c2
EOF


chmod +x findrange_j3-cont.sh
if ! [ $pegasus_lite_start_dir -ef . ]; then
	cp $pegasus_lite_start_dir/pegasus-lite-common.sh . 
fi

set +e
singularity_init centos-pycbc
job_ec=$(($job_ec + $?))

singularity exec --pwd /srv --home $PWD:/srv centos-pycbc ./findrange_j3-cont.sh 
job_ec=$(($job_ec + $?))


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
     { "site_label": "condorpool", "url": "file://$PWD/f.c2", "checkpoint": "false" }
   ],
   "dest_urls": [
     { "site_label": "local", "url": "gsiftp://sugwg-condor.phy.syr.edu/home/dbrown/projects/osg/condor-blackdiamond-container/local-site-scratch/dbrown/pegasus/blackdiamond/run0003/./f.c2" }
   ] }
]
EOF


# clear the trap, and exit cleanly
trap - EXIT
pegasus_lite_final_exit

