#!/bin/bash

for mass in {700,800,900,1000,1200,1400,1600,1800,2000,2200,2400,2600,2800,3000,3500}
do
    echo $mass
    cat > crabconfigs/sigconfig/${mass}N.py <<EOF
from CRABClient.UserUtilities import config, getUsernameFromSiteDB
config = config()

config.General.requestName = 'Wgamma949Signal16_${mass}_0p01%s'%"Jan16"
config.General.workArea = 'crab_jobs_signal%s'%"Jan16"
config.General.transferOutputs = True
config.General.transferLogs = True

config.JobType.pluginName = 'Analysis'
config.JobType.psetName = 'config_genericMC.py'

config.JobType.sendExternalFolder = True
config.Data.inputDataset = '/MadGraphChargedResonance_WGToJJ_M${mass}_width0p01/RunIISummer16MiniAODv3-PUMoriond17_94X_mcRun2_asymptotic_v3-v2/MINIAODSIM'
config.Data.inputDBS = 'global'
config.Data.splitting = 'FileBased'
config.Data.unitsPerJob = 2

config.Data.outLFNDirBase = '/store/user/%s/' % (getUsernameFromSiteDB())
config.Data.publication = False
config.Data.outputDatasetTag = 'Wgamma949Signal16_${mass}_0p01%s'%"Jan16"
config.Site.storageSite = 'T3_US_Brown'
          
EOF
    crab submit crabconfigs/sigconfig/${mass}N.py 
done
