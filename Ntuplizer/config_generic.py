###### Process initialization ##########
import sys
import FWCore.ParameterSet.Config as cms

process = cms.Process("Ntuple")

process.load("Configuration.StandardSequences.MagneticField_cff")
process.load('Configuration.Geometry.GeometryRecoDB_cff')

process.TFileService = cms.Service("TFileService",
                                    fileName = cms.string('flatTuple.root')
                                   )

#from VgammaTuplizer.Ntuplizer.ntuplizerOptions_data_cfi import config
from VgammaTuplizer.Ntuplizer.ntuplizerOptions_generic_cfi import config

				   
####### Config parser ##########

import FWCore.ParameterSet.VarParsing as VarParsing

options = VarParsing.VarParsing ('analysis')

options.maxEvents = -1

#data file


#options.inputFiles = ('/store/data/Run2017F/SinglePhoton/MINIAOD/31Mar2018-v1/80000/24EE7C33-1039-E811-98A4-1CB72C1B6C32.root')

options.inputFiles = ('file:/afs/cern.ch/work/x/xuyan/work5/DEV/CMSSW_9_4_9/src/WGamma-M1600_W0.05_GEN-SIM_0.root')

                     
options.parseArguments()

process.options  = cms.untracked.PSet( 
                     wantSummary = cms.untracked.bool(True),
                     SkipEvent = cms.untracked.vstring('ProductNotFound'),
                     allowUnscheduled = cms.untracked.bool(True)
                     )

process.maxEvents = cms.untracked.PSet( input = cms.untracked.int32(options.maxEvents) )

process.source = cms.Source("PoolSource",
                            fileNames = cms.untracked.vstring(options.inputFiles),
#                            eventsToProcess = cms.untracked.VEventRange('282917:76757818-282917:76757820'),
#                            lumisToProcess = cms.untracked.VLuminosityBlockRange('282917:126'),
                            )                     


print " process source filenames %s" %(process.source) 

# ####### Logger ##########
process.load("FWCore.MessageLogger.MessageLogger_cfi")

process.MessageLogger.cerr.threshold = 'INFO'
process.MessageLogger.categories.append('Ntuple')
process.MessageLogger.cerr.INFO = cms.untracked.PSet(
    limit = cms.untracked.int32(1)
)

process.MessageLogger.cerr.FwkReport.reportEvery = 1000
                                                                                           
process.ntuplizer = cms.EDAnalyzer("Ntuplizer",
    runOnMC	      = cms.bool(config["RUNONMC"]),
    doGenParticles    = cms.bool(config["DOGENPARTICLES"]),
    genparticles = cms.InputTag("genParticles")
)


####### Final path ##########
process.p = cms.Path()

process.p += process.ntuplizer
