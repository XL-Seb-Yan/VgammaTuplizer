#!/bin/bash
for i in {700,800,900,1000,1200,1400,1600,1800,2000,2200,2400,2600,2800,3000,3500,4000,5000,6000,7000,8000}
do
  width="N"
  mkdir job_${i}_${width}
  cd job_${i}_${width}
  cp ../runonlocal_${width}.sh ./
  mkdir log
  cat > ${i}_${width}.jdl <<EOF
universe                = vanilla
executable              = runonlocal_${width}.sh
arguments               = ${i} \$(Process)
should_transfer_files   = YES
transfer_output_files   = _condor_stderr, _condor_stdout
when_to_transfer_output = ON_EXIT
output                  = log/Condor_job.\$(Cluster).\$(Process).out
error                   = log/Condor_job.\$(Cluster).\$(Process).err
log                     = log/Condor_job.\$(Cluster).\$(Process).log
request_cpus            = 1
request_memory          = 2 GB
priority                = 8

queue 4
EOF
  condor_submit ${i}_${width}.jdl
  cd ../
done
