from CRABClient.UserUtilities import config, getUsernameFromSiteDB
config = config()

config.General.requestName = 'Wgamma94XSinglePhoton_%s_2016E'%"Jan16"
config.General.workArea = 'crab_jobs_2016E_photon%s'%"Jan16"
config.General.transferOutputs = True
config.General.transferLogs = True

config.JobType.pluginName = 'Analysis'
config.JobType.psetName = 'config_genericE.py'
config.JobType.inputFiles=[
        'JSON/Cert_271036-284044_13TeV_ReReco_07Aug2017_Collisions16_JSON.txt'
]
config.JobType.sendExternalFolder = True
config.Data.inputDataset = '/SinglePhoton/Run2016E-17Jul2018-v1/MINIAOD'
config.Data.inputDBS = 'global'
config.Data.splitting = 'FileBased'
config.Data.unitsPerJob = 3
config.Data.lumiMask='JSON/Cert_271036-284044_13TeV_ReReco_07Aug2017_Collisions16_JSON.txt'
config.Data.outLFNDirBase = '/store/user/%s/' % (getUsernameFromSiteDB())
config.Data.publication = False
config.Data.outputDatasetTag = 'Wgamma94XSinglePhoton_%s_2016E'%"Jan16"
config.Site.storageSite = 'T3_US_Brown'
