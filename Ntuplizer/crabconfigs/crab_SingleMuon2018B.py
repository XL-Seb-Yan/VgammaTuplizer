from CRABClient.UserUtilities import config, getUsernameFromSiteDB
config = config()

config.General.requestName = 'Wgamma102XSingleMuon_%s_2018B'%"Jan16"
config.General.workArea = 'crab_jobs_2018B_muons%s'%"Jan16"
config.General.transferOutputs = True
config.General.transferLogs = True

config.JobType.allowUndistributedCMSSW = True
config.JobType.pluginName = 'Analysis'
config.JobType.psetName = 'config_genericB.py'
config.JobType.inputFiles=[
        'JSON/Cert_314472-325175_13TeV_17SeptEarlyReReco2018ABC_PromptEraD_Collisions18_JSON.txt'
]
config.JobType.sendExternalFolder = True
config.Data.inputDataset = '/SingleMuon/Run2018B-17Sep2018-v1/MINIAOD'
config.Data.inputDBS = 'global'
config.Data.splitting = 'FileBased'
config.Data.unitsPerJob = 3
config.Data.lumiMask='JSON/Cert_314472-325175_13TeV_17SeptEarlyReReco2018ABC_PromptEraD_Collisions18_JSON.txt'
config.Data.outLFNDirBase = '/store/user/%s/' % (getUsernameFromSiteDB())
config.Data.publication = False
config.Data.outputDatasetTag = 'Wgamma102XSingleMuon_%s_2018B'%"Jan16"
config.Site.storageSite = 'T3_US_Brown'
