from CRABClient.UserUtilities import config, getUsernameFromSiteDB
config = config()

config.General.requestName = 'Wgamma949Signal17_3500_0p01%s'%"Mar1"
config.General.workArea = 'crab_jobs_signal%s'%"Mar1"
config.General.transferOutputs = True
config.General.transferLogs = True

config.JobType.allowUndistributedCMSSW = True
config.JobType.pluginName = 'Analysis'
config.JobType.psetName = 'config_genericMC.py'

config.JobType.sendExternalFolder = True
config.Data.inputDataset = '/MadGraphChargedResonance_WGToJJG_M3500_width0p01/RunIIFall17MiniAODv2-PU2017_12Apr2018_94X_mc2017_realistic_v14-v1/MINIAODSIM'
config.Data.inputDBS = 'global'
config.Data.splitting = 'FileBased'
config.Data.unitsPerJob = 5

config.Data.outLFNDirBase = '/store/user/%s/' % (getUsernameFromSiteDB())
config.Data.publication = False
config.Data.outputDatasetTag = 'Wgamma949Signal17_3500_0p01%s'%"Mar1"
config.Site.storageSite = 'T3_US_Brown'
          
