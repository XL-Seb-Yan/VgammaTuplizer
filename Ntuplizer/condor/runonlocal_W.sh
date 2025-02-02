#!/bin/bash

cd ${_CONDOR_SCRATCH_DIR}
source /cvmfs/cms.cern.ch/cmsset_default.sh

if [ -r CMSSW_9_4_13/src ] ; then 
 echo release CMSSW_9_4_13 already exists
else
scram p CMSSW CMSSW_9_4_13
fi
cd CMSSW_9_4_13/src
eval `scramv1 runtime -sh`

xrdcp root://cmseos.fnal.gov//store/user/xuyan/transfer.tgz ./transfer.tgz
tar -xvf transfer.tgz

scram b -j2

eval `scramv1 runtime -sh`

echo ${CMSSW_BASE}

mass=$1
start=$(echo "scale=3; ${2}* 5" | bc -l | awk '{printf "%i\n", $0}')
end=$(echo "scale=3; (${2}+1)* 5" | bc -l | awk '{printf "%i\n", $0}')
width=5
mkdir ${mass}_${width}
for ((i=${start}; i<${end};i++))
do
    name="'root://cmseos.fnal.gov//store/user/xuyan/Spin-0/MadgraphChargedResonance_M${mass}_width${width}_TuneCP5_13TeV_pythia8_GEN-SIM-PREMIX-RECOAOD-MINIAOD_${i}.root'"
    echo $name
    cat > ${mass}_${width}/${i}.py <<EOF
###### Process initialization ##########
import sys
import FWCore.ParameterSet.Config as cms

process = cms.Process("Ntuple")

process.load("Configuration.StandardSequences.MagneticField_cff")
process.load('Configuration.Geometry.GeometryRecoDB_cff')

process.TFileService = cms.Service("TFileService",
                                    fileName = cms.string('flatTuple_${mass}_${width}_${i}.root')
                                   )

#from VgammaTuplizer.Ntuplizer.ntuplizerOptions_data_cfi import config
from VgammaTuplizer.Ntuplizer.ntuplizerOptions_genericMC_cfi import config

				   
####### Config parser ##########

import FWCore.ParameterSet.VarParsing as VarParsing

options = VarParsing.VarParsing ('analysis')

options.maxEvents = -1

#data file


options.inputFiles = (${name})
                     
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
######## Sequence settings ##########

# https://twiki.cern.ch/twiki/bin/view/CMSPublic/WorkBookMiniAOD2015#ETmiss_filters
# For the RunIISpring15DR74 MC campaing, the process name in PAT.
# For Run2015B PromptReco Data, the process name is RECO.
# For Run2015B re-MiniAOD Data 17Jul2015, the process name is PAT.
hltFiltersProcessName = 'RECO'
if config["RUNONMC"] or config["JSONFILE"].find('reMiniAOD') != -1:
  hltFiltersProcessName = 'PAT'
reclusterPuppi=config["DOAK8PUPPIRECLUSTERING"]
if reclusterPuppi:
  print "RECLUSTERING PUPPI with latest tune from CMSSW_8_0_20"

#! To recluster and add AK8 Higgs tagging and softdrop subjet b-tagging (both need to be simoultaneously true or false, if not you will have issues with your softdrop subjets!)
#If you use the softdrop subjets from the slimmedJetsAK8 collection, only CSV seems to be available?
doAK8softdropReclustering = False
if config["DOAK8RECLUSTERING"] == True: doAK8softdropReclustering = True

# ####### Logger ##########
process.load("FWCore.MessageLogger.MessageLogger_cfi")

process.MessageLogger.cerr.threshold = 'INFO'
process.MessageLogger.categories.append('Ntuple')
process.MessageLogger.cerr.INFO = cms.untracked.PSet(
    limit = cms.untracked.int32(1)
)

process.MessageLogger.cerr.FwkReport.reportEvery = 10

####### Define conditions ##########
#process.load("Configuration.StandardSequences.FrontierConditions_GlobalTag_cff")
process.load('Configuration.StandardSequences.FrontierConditions_GlobalTag_condDBv2_cff')
from Configuration.AlCa.GlobalTag import GlobalTag

GT = ''
if config["RUNONMC"]: GT = '94X_mc2017_realistic_v14'
elif config["RUNONReReco"]: GT = '94X_dataRun2_v6'
elif config["RUNONPromptReco"]: GT = '92X_dataRun2_2017Prompt_v11'

print "*************************************** GLOBAL TAG *************************************************" 
print GT
print "****************************************************************************************************" 
process.GlobalTag = GlobalTag(process.GlobalTag, GT)

from RecoEgamma.EgammaTools.EgammaPostRecoTools import setupEgammaPostRecoSeq
setupEgammaPostRecoSeq(process,era='2017-Nov17ReReco')  

jetcorr_levels=[]
jetcorr_levels_groomed=[]
if config["RUNONMC"]:
  jetcorr_levels = cms.vstring(['L1FastJet', 'L2Relative', 'L3Absolute'])
  jetcorr_levels_groomed = cms.vstring(['L2Relative', 'L3Absolute']) # NO L1 corretion for groomed jets
else:
  jetcorr_levels = cms.vstring(['L1FastJet', 'L2Relative', 'L3Absolute', 'L2L3Residual'])
  jetcorr_levels_groomed = cms.vstring(['L2Relative', 'L3Absolute', 'L2L3Residual'])

   
######### read JSON file for data ##########					                                                             
if not(config["RUNONMC"]) and config["USEJSON"]:

  import FWCore.PythonUtilities.LumiList as LumiList
  import FWCore.ParameterSet.Types as CfgTypes
  process.source.lumisToProcess = CfgTypes.untracked(CfgTypes.VLuminosityBlockRange())
  myLumis = LumiList.LumiList(filename = config["JSONFILE"]).getCMSSWString().split(',')
  process.source.lumisToProcess.extend(myLumis) 

  if config["FILTEREVENTS"]:
  
   fname = ""
   if (options.inputFiles)[0].find("SingleMuon") != -1: fname = "RunLumiEventLists/SingleMuon_csc2015_Nov14.txt"
   elif (options.inputFiles)[0].find("SingleElectron") != -1: fname = "RunLumiEventLists/SingleElectron_csc2015_Nov14.txt"
   elif (options.inputFiles)[0].find("JetHT") != -1: fname = "RunLumiEventLists/JetHT_csc2015_Nov27.txt"
   else:
    print "** WARNING: EVENT LIST NOT FOUND! exiting... "
    sys.exit()
   
   print "** FILTERING EVENT LIST: %s" %fname 
   listEventsToSkip = []
   fileEventsToSkip = open(fname,"r")

   for line in fileEventsToSkip:
     cleanLine = line.rstrip()
     listEventsToSkip.append(cleanLine+"-"+cleanLine)

   rangeEventsToSkip = cms.untracked.VEventRange(listEventsToSkip)
   process.source.eventsToSkip = rangeEventsToSkip

####### Redo Jet clustering sequence ##########
betapar = cms.double(0.0)
fatjet_ptmin = 100.0

from RecoJets.Configuration.RecoPFJets_cff import *
from RecoJets.JetProducers.AnomalousCellParameters_cfi import *
from RecoJets.JetProducers.PFJetParameters_cfi import *

from PhysicsTools.PatAlgos.tools.helpers import *
pattask = getPatAlgosToolsTask(process)
                                                                                                          
process.chs = cms.EDFilter("CandPtrSelector",
  src = cms.InputTag('packedPFCandidates'),
  cut = cms.string('fromPV')
)

process.ak4PFJetsCHS = ak4PFJetsCHS.clone( src = 'chs' )
process.ak4PFJetsCHS.doAreaFastjet = True
process.ak8CHSJets = ak8PFJetsCHS.clone( src = 'chs', jetPtMin = fatjet_ptmin )

process.NjettinessAK8 = cms.EDProducer("NjettinessAdder",
             src = cms.InputTag("ak8CHSJets"),
             Njets = cms.vuint32(1, 2, 3, 4),
             # variables for measure definition :
             measureDefinition = cms.uint32( 0 ), # CMS default is normalized measure
             beta = cms.double(1.0),        # CMS default is 1
             R0 = cms.double( 0.8 ),        # CMS default is jet cone size
             Rcutoff = cms.double( 999.0),      # not used by default
             # variables for axes definition :
             axesDefinition = cms.uint32( 6 ),    # CMS default is 1-pass KT axes
             nPass = cms.int32(999),       # not used by default
             akAxesR0 = cms.double(-999.0)      # not used by default
             )

if config["DOAK10TRIMMEDRECLUSTERING"]:			       
  process.ECFAK10 = cms.EDProducer("ECFAdder",
             src = cms.InputTag("ak10CHSJetsTrimmed"),
             Njets = cms.vuint32(1, 2, 3),
             beta = cms.double(1.0),        # CMS default is 1
             )
			       

process.ak8CHSJetsPruned = ak8PFJetsCHSPruned.clone( src = 'chs', jetPtMin = fatjet_ptmin )
process.ak8CHSJetsSoftDrop = ak8PFJetsCHSSoftDrop.clone( src = 'chs', jetPtMin = fatjet_ptmin, beta = betapar  )


if config["DOAK10TRIMMEDRECLUSTERING"]:			       
  process.ak10CHSJetsTrimmed = ak8PFJetsCHSTrimmed.clone( src = 'chs', jetPtMin = fatjet_ptmin, rParam = 1.0, rFilt = 0.2, trimPtFracMin = 0.05 )

if reclusterPuppi:
  process.load('CommonTools/PileupAlgos/Puppi_cff')
  process.puppi.useExistingWeights = False
  process.puppi.candName = cms.InputTag('packedPFCandidates')
  process.puppi.vertexName = cms.InputTag('offlineSlimmedPrimaryVertices')  
  process.ak8PuppiJets = ak8PFJetsCHS.clone( src = 'puppi', jetPtMin = fatjet_ptmin )
  process.ak8PuppiJetsPruned = ak8PFJetsCHSPruned.clone( src = 'puppi', jetPtMin = fatjet_ptmin )
  process.ak8PuppiJetsSoftDrop = ak8PFJetsCHSSoftDrop.clone( src = 'puppi', jetPtMin = fatjet_ptmin, beta = betapar  )
  process.NjettinessAK8Puppi = process.NjettinessAK8.clone( src = 'ak8PuppiJets' )

if config["GETJECFROMDBFILE"]:
  process.load("CondCore.DBCommon.CondDBCommon_cfi")
  process.jec = cms.ESSource("PoolDBESSource",
            DBParameters = cms.PSet(
                messageLevel = cms.untracked.int32(5)
                ),
            timetype = cms.string('runnumber'),
            toGet = cms.VPSet(
            cms.PSet(
                 record = cms.string('JetCorrectionsRecord'),
                 tag    = cms.string('JetCorrectorParametersCollection_Summer15_50nsV5_MC_AK4PFchs'),
                 label  = cms.untracked.string('AK4PFchs')
                 ),
            cms.PSet(
                 record = cms.string('JetCorrectionsRecord'),
                 tag    = cms.string('JetCorrectorParametersCollection_Summer15_50nsV5_MC_AK8PFchs'),
                 label  = cms.untracked.string('AK8PFchs')
                 ),
            cms.PSet(
                 record = cms.string('JetCorrectionsRecord'),
                 tag    = cms.string('JetCorrectorParametersCollection_Summer15_50nsV5_MC_AK8PFPuppi'),
                 label  = cms.untracked.string('AK8PFPuppi')
                 ),
            ),
            connect = cms.string('sqlite:JEC/Summer15_50nsV5_MC.db')
            )
  if not config["RUNONMC"]:
    process.jec.toGet[0].tag =  cms.string('JetCorrectorParametersCollection_Summer15_50nsV5_DATA_AK4PFchs')
    process.jec.toGet[1].tag =  cms.string('JetCorrectorParametersCollection_Summer15_50nsV5_DATA_AK8PFchs')
    process.jec.toGet[2].tag =  cms.string('JetCorrectorParametersCollection_Summer15_50nsV5_DATA_AK8PFPuppi')
    process.jec.connect = cms.string('sqlite:JEC/Summer15_50nsV5_DATA.db')
  process.es_prefer_jec = cms.ESPrefer('PoolDBESSource','jec')



####### Add AK8 GenJets ##########
if config["ADDAK8GENJETS"]:

  from RecoJets.Configuration.RecoGenJets_cff import ak8GenJets
  addToProcessAndTask('ak8GenJets',
                      ak8GenJets.clone(src = 'packedGenParticles'),
                      process,pattask
                      )
  
  
  addToProcessAndTask('NjettinessGenAK8',
                      cms.EDProducer("NjettinessAdder",
                                     src=cms.InputTag("ak8GenJets"),
                                     Njets=cms.vuint32(1,2,3,4),          # compute 1-, 2-, 3-, 4- subjettiness
                                     # variables for measure definition : 
                                     measureDefinition = cms.uint32( 0 ), # CMS default is normalized measure
                                     beta = cms.double(1.0),              # CMS default is 1
                                     R0 = cms.double( 0.8 ),              # CMS default is jet cone size
                                     Rcutoff = cms.double( 999.0),       # not used by default
                                     # variables for axes definition :
                                       axesDefinition = cms.uint32( 6 ),    # CMS default is 1-pass KT axes
                                     nPass = cms.int32(999),             # not used by default
                                     akAxesR0 = cms.double(-999.0)        # not used by default
                                     ),
                      process,pattask
                      )
                      

  addToProcessAndTask('genParticlesForJets',
                      cms.EDProducer("InputGenJetsParticleSelector",
                                     src = cms.InputTag("packedGenParticles"),
                                     ignoreParticleIDs = cms.vuint32(1000022,
                                                                     1000012, 1000014, 1000016,
                                                                     2000012, 2000014, 2000016,
                                                                     1000039, 5100039,
                                                                     4000012, 4000014, 4000016,
                                                                     9900012, 9900014, 9900016,
                                                                     39),
                                     partonicFinalState = cms.bool(False),
                                     excludeResonances = cms.bool(False),
                                     excludeFromResonancePids = cms.vuint32(12, 13, 14, 16),
                                     tausAsJets = cms.bool(False)
                                     ),
                      process,pattask
                      )
           

  from RecoJets.JetProducers.SubJetParameters_cfi import SubJetParameters

  addToProcessAndTask('ak8GenJetsPruned',
                      ak8GenJets.clone(SubJetParameters,
                                       usePruning = cms.bool(True),
                                       writeCompound = cms.bool(True),
                                       jetCollInstanceName=cms.string("SubJets")
                                       ),
                      process,pattask
                      )
  
  addToProcessAndTask('ak8GenJetsSoftDrop',
                      ak8GenJets.clone(SubJetParameters,
                                       useSoftDrop = cms.bool(True),
                                       R0 = cms.double(0.8),
                                       beta = betapar,
                                       writeCompound = cms.bool(True),
                                       jetCollInstanceName=cms.string("SubJets")
                                       ),
                      process,pattask
                      )
  

  addToProcessAndTask('ak8GenJetsPrunedMass',
                      cms.EDProducer("RecoJetDeltaRValueMapProducer",
                                     src = cms.InputTag("ak8GenJets"),
                                     matched = cms.InputTag("ak8GenJetsPruned"),
                                     distMax = cms.double(0.8),
                                     value = cms.string('mass')
                                      ),
                      process,pattask
                      )
  
  
  addToProcessAndTask('ak8GenJetsSoftDropMass',
                      cms.EDProducer("RecoJetDeltaRValueMapProducer",
                                     src = cms.InputTag("ak8GenJets"),
                                     matched = cms.InputTag("ak8GenJetsSoftDrop"), 
                                     distMax = cms.double(0.8),
                                     value = cms.string('mass') 
                                     ),
                      process,pattask
                      )
  

  # process.ak8GenJetsPrunedMass = ak8PFJetsCHSPrunedMass.clone(
  #             matched = cms.InputTag("ak8GenJetsPruned"),
  #             src = cms.InputTag("ak8GenJets")
  #             )
  #
  # process.ak8GenJetsSoftDropMass = ak8PFJetsCHSSoftDropMass.clone(
  #             matched = cms.InputTag("ak8GenJetsSoftDrop"),
  #             beta = betapar,
  #             src = cms.InputTag("ak8GenJets")
  #             )

  # process.substructureSequenceGen+=process.ak8GenJets
  # process.substructureSequenceGen+=process.NjettinessGenAK8
  #
  # process.substructureSequenceGen += process.ak8GenJetsSoftDrop + process.ak8GenJetsSoftDropMass
  # process.substructureSequenceGen += process.ak8GenJetsPruned + process.ak8GenJetsPrunedMass

  from VgammaTuplizer.Ntuplizer.redoPatJets_cff import patJetCorrFactorsAK8, patJetsAK8, selectedPatJetsAK8

  # Redo pat jets from gen AK8

  addToProcessAndTask('genJetsAK8',
                     patJetsAK8.clone( jetSource = 'ak8GenJets' ),
                     process,pattask)

  process.genJetsAK8.userData.userFloats.src = [ cms.InputTag("ak8GenJetsPrunedMass"), cms.InputTag("ak8GenJetsSoftDropMass"), cms.InputTag("NjettinessGenAK8:tau1"), cms.InputTag("NjettinessGenAK8:tau2"), cms.InputTag("NjettinessGenAK8:tau3")]
  process.genJetsAK8.addJetCorrFactors = cms.bool(False)
  process.genJetsAK8.jetCorrFactorsSource = cms.VInputTag( cms.InputTag("") )

  addToProcessAndTask('selectedGenJetsAK8',
                      selectedPatJetsAK8.clone( src = 'genJetsAK8', cut = cms.string('pt > 20') ),
                      process,pattask)

################# Prepare recluster or update jets with b-tagging ######################
bTagDiscriminators = [
    # 'pfJetProbabilityBJetTags',
    # 'pfJetBProbabilityBJetTags',
    # 'pfSimpleSecondaryVertexHighEffBJetTags',
    # 'pfSimpleSecondaryVertexHighPurBJetTags',
    'pfCombinedInclusiveSecondaryVertexV2BJetTags',
    # 'pfTrackCountingHighPurBJetTags',
    # 'pfTrackCountingHighEffBJetTags',
    'pfBoostedDoubleSecondaryVertexAK8BJetTags',
    'pfDeepCSVJetTags:probb',
    'pfDeepCSVJetTags:probbb',
    'pfDeepCSVDiscriminatorsJetTags:BvsAll'

  
]

#Needed in 80X to get the latest Hbb training
if config["UpdateJetCollection"]:
  from PhysicsTools.PatAlgos.tools.jetTools import updateJetCollection
## Update the slimmedJets in miniAOD: corrections from the chosen Global Tag are applied and the b-tag discriminators are re-evaluated
  updateJetCollection(
    process,
    jetSource = cms.InputTag('slimmedJetsAK8'),
    jetCorrections = ('AK8PFchs', cms.vstring(jetcorr_levels), 'None'),
    btagDiscriminators = bTagDiscriminators
  )
## Update to latest PU jet ID training
  process.load("RecoJets.JetProducers.PileupJetID_cfi")
  # requires cnadidate track covaranice matrix, which isn't in miniaod anymore
  #addToProcessAndTask('pileupJetIdUpdated',
  #                    process.pileupJetId.clone(jets=cms.InputTag("slimmedJets"),
  #                                              inputIsCorrected=True,
  #                                              applyJec=True,
  #                                              vertexes=cms.InputTag("offlineSlimmedPrimaryVertices")
  #                                              ),
  #                    process,pattask
  #                    )
  from PhysicsTools.PatAlgos.producersLayer1.jetUpdater_cff import updatedPatJetCorrFactors, updatedPatJets
  addToProcessAndTask('patJetCorrFactorsReapplyJEC',
                      updatedPatJetCorrFactors.clone(src = cms.InputTag("slimmedJets"),
                                                     levels = jetcorr_levels,
                                                     ),
                      process,pattask
                      )
  addToProcessAndTask('updatedJets',
                      updatedPatJets.clone(jetSource = cms.InputTag("slimmedJets"),
                                           jetCorrFactorsSource = cms.VInputTag(cms.InputTag("patJetCorrFactorsReapplyJEC") )
                                           ),
                      process,pattask
                      )                   
  #process.updatedJets.userData.userFloats.src += ['pileupJetIdUpdated:fullDiscriminant']
  #process.updatedJets.userData.userInts.src += ['pileupJetIdUpdated:fullId']

def cap(s): return s[0].upper() + s[1:]

from PhysicsTools.PatAlgos.tools.jetTools import *
#process.load('PhysicsTools.PatAlgos.slimming.unpackedTracksAndVertices_cfi')

bTagParameters = dict(
    #trackSource = cms.InputTag('unpackedTracksAndVertices'),
    pfCandidates = cms.InputTag('packedPFCandidates'),
    pvSource = cms.InputTag('offlineSlimmedPrimaryVertices'),
    svSource = cms.InputTag('slimmedSecondaryVertices'),
    elSource = cms.InputTag('slimmedElectrons'),
    muSource = cms.InputTag('slimmedMuons'),
    btagDiscriminators = bTagDiscriminators
) 

def recluster_addBtagging(process, fatjets_name, groomed_jets_name, jetcorr_label = 'AK8PFchs', jetcorr_label_subjets = 'AK4PFchs', genjets_name = None, verbose = False, btagging = True, subjets = True):
    rParam = getattr(process, fatjets_name).rParam.value()
    algo = None
    if 'ca' in fatjets_name.lower():
	algo = 'ca'
	assert getattr(process, fatjets_name).jetAlgorithm.value() == 'CambridgeAachen'
    elif 'ak' in fatjets_name.lower():
	algo = 'ak'
	assert getattr(process, fatjets_name).jetAlgorithm.value() == 'AntiKt'
    else:
	raise RuntimeError, "Unknown jet algorithm for fatjets name %s" % fatjets_name
  
    subjets_name = groomed_jets_name + 'Subjets' # e.g. AK8CHSPruned + Subjets
  
    # add genjet producers, if requested:
    groomed_genjets_name = 'INVALID'
    ungroomed_genjets_name = 'INVALID'
  
    if genjets_name is not None:
	    groomed_jetproducer = getattr(process, groomed_jets_name)
	    assert groomed_jetproducer.type_() in ('FastjetJetProducer', 'CATopJetProducer'), "do not know how to construct genjet collection for %s" % repr(groomed_jetproducer)
	    groomed_genjets_name = genjets_name(groomed_jets_name)
	    if verbose: print "Adding groomed genjets ", groomed_genjets_name
	    setattr(process, groomed_genjets_name, groomed_jetproducer.clone(src = cms.InputTag('packedGenParticles'), jetType = 'GenJet'))
	    # add for ungroomed jets if not done yet (maybe never used in case ungroomed are not added, but that's ok ..)
	    ungroomed_jetproducer = getattr(process, fatjets_name)
	    assert ungroomed_jetproducer.type_() == 'FastjetJetProducer'
	    ungroomed_genjets_name = genjets_name(fatjets_name)
	    if verbose: print "Adding ungroomed genjets ", ungroomed_genjets_name
	    setattr(process, ungroomed_genjets_name, ungroomed_jetproducer.clone(src = cms.InputTag('packedGenParticles'), jetType = 'GenJet'))
      

    # patify ungroomed jets, if not already done:
    add_ungroomed = not hasattr(process, 'patJets' + cap(fatjets_name))
    addJetCollection(process, labelName = fatjets_name, jetSource = cms.InputTag(fatjets_name), algo = algo, rParam = rParam,
	    jetCorrections = (jetcorr_label, jetcorr_levels, 'None'),
	    genJetCollection = cms.InputTag(ungroomed_genjets_name),
	    **bTagParameters
	)

    # patify groomed fat jets, with b-tagging:
    addJetCollection(process, labelName = groomed_jets_name, jetSource = cms.InputTag(groomed_jets_name), algo = algo, rParam = rParam,
       jetCorrections = (jetcorr_label, jetcorr_levels_groomed, 'None'),
       **bTagParameters)
    # patify subjets, with subjet b-tagging:
    if subjets:
      addJetCollection(process, labelName = subjets_name, jetSource = cms.InputTag(groomed_jets_name, 'SubJets'), algo = algo, rParam = rParam,
	jetCorrections = (jetcorr_label_subjets, jetcorr_levels, 'None'),
	explicitJTA = True,
	svClustering = True,
	fatJets = cms.InputTag(fatjets_name), groomedFatJets = cms.InputTag(groomed_jets_name),
	genJetCollection = cms.InputTag(groomed_genjets_name, 'SubJets'),
	**bTagParameters)
  
      # add the merged jet collection which contains the links from fat jets to subjets:
      setattr(process, 'patJets' + cap(groomed_jets_name) + 'Packed',cms.EDProducer("BoostedJetMerger",
	jetSrc=cms.InputTag("patJets" + cap(groomed_jets_name)),
	subjetSrc=cms.InputTag("patJets" + cap(subjets_name)))
	)
  
    # adapt all for b-tagging, and switch off some PAT features not supported in miniAOD:
    if subjets:
      module_names = [subjets_name, groomed_jets_name]
    else:
      module_names = [groomed_jets_name]
    if add_ungroomed: module_names += [fatjets_name]
    for name in module_names:
	if hasattr(process,'pfInclusiveSecondaryVertexFinderTagInfos' + cap(name)):
	    getattr(process,'pfInclusiveSecondaryVertexFinderTagInfos' + cap(name)).extSVCollection = cms.InputTag('slimmedSecondaryVertices')
	getattr(process, 'patJetPartonMatch' + cap(name)).matched = 'prunedGenParticles'
	producer = getattr(process, 'patJets' + cap(name))
	producer.addJetCharge = False
	producer.addAssociatedTracks = False
	if not config["DOHBBTAG"]:
	    producer.addDiscriminators = True
	    producer.addBTagInfo = True
	producer.addGenJetMatch = genjets_name is not None
	# for fat groomed jets, gen jet match and jet flavor is not working, so switch it off:
	if name == groomed_jets_name:
	    producer.addGenJetMatch = False
	    producer.getJetMCFlavour = False

################# Recluster jets with b-tagging ######################
if config["DOAK8RECLUSTERING"]: 
    recluster_addBtagging(process, 'ak8CHSJets', 'ak8CHSJetsSoftDrop', genjets_name = lambda s: s.replace('CHS', 'Gen'))
    recluster_addBtagging(process, 'ak8CHSJets', 'ak8CHSJetsPruned', genjets_name = lambda s: s.replace('CHS', 'Gen'))
    process.ak8PFJetsCHSPrunedMass = cms.EDProducer("RecoJetDeltaRValueMapProducer",
                                            src = cms.InputTag("ak8CHSJets"),
                                            matched = cms.InputTag("ak8CHSJetsPruned"),
                                            distMax = cms.double(0.8),
                                            value = cms.string('mass')
                                            )

    process.ak8PFJetsCHSSoftDropMass = cms.EDProducer("RecoJetDeltaRValueMapProducer",
                                            src = cms.InputTag("ak8CHSJets"),
                                            matched = cms.InputTag("ak8CHSJetsSoftDrop"),                                         
                                            distMax = cms.double(0.8),
                                            value = cms.string('mass') 
                                            )         
    process.ak8PFJetsCHSPrunedMassCorrected = cms.EDProducer("RecoJetDeltaRValueMapProducer",
                                            src = cms.InputTag("ak8CHSJets"),
                                            matched = cms.InputTag("patJetsAk8CHSJetsPrunedPacked"),
                                            distMax = cms.double(0.8),
                                            value = cms.string('mass')
                                            )

    process.ak8PFJetsCHSSoftDropMassCorrected = cms.EDProducer("RecoJetDeltaRValueMapProducer",
                                            src = cms.InputTag("ak8CHSJets"),
                                            matched = cms.InputTag("patJetsAk8CHSJetsSoftDropPacked"),                                         
                                            distMax = cms.double(0.8),
                                            value = cms.string('mass') 
                                            )    
					         
    process.patJetsAk8CHSJets.userData.userFloats.src += ['ak8PFJetsCHSPrunedMass','ak8PFJetsCHSSoftDropMass','ak8PFJetsCHSPrunedMassCorrected','ak8PFJetsCHSSoftDropMassCorrected']
    process.patJetsAk8CHSJets.userData.userFloats.src += ['NjettinessAK8:tau1','NjettinessAK8:tau2','NjettinessAK8:tau3']
    process.patJetsAk8CHSJets.addTagInfos = True
    #process.patJetsAk8CHSJetsSoftDropSubjets.addBTagInfo = True

################# Recluster trimmed jets ######################
if config["DOAK10TRIMMEDRECLUSTERING"]:	
    recluster_addBtagging(process, 'ak8CHSJets', 'ak10CHSJetsTrimmed', genjets_name = lambda s: s.replace('CHS', 'Gen'), verbose = False, btagging = False, subjets = False)
    process.patJetsAk10CHSJetsTrimmed.userData.userFloats.src += ['ECFAK10:ecf1','ECFAK10:ecf2','ECFAK10:ecf3']
    
################# Recluster puppi jets ######################
if reclusterPuppi:
    recluster_addBtagging(process, 'ak8PuppiJets', 'ak8PuppiJetsSoftDrop', jetcorr_label = 'AK8PFPuppi', genjets_name = lambda s: s.replace('Puppi', 'Gen'))
    recluster_addBtagging(process, 'ak8PuppiJets', 'ak8PuppiJetsPruned', jetcorr_label = 'AK8PFPuppi', genjets_name = lambda s: s.replace('Puppi', 'Gen'))
  
    process.ak8PFJetsPuppiPrunedMass = cms.EDProducer("RecoJetDeltaRValueMapProducer",
    					  src = cms.InputTag("ak8PuppiJets"),
    					  matched = cms.InputTag("ak8PuppiJetsPruned"),
    					  distMax = cms.double(0.8),
    					  value = cms.string('mass')
    					  )

    process.ak8PFJetsPuppiSoftDropMass = cms.EDProducer("RecoJetDeltaRValueMapProducer",
    					  src = cms.InputTag("ak8PuppiJets"),
    					  matched = cms.InputTag("ak8PuppiJetsSoftDrop"),					  
    					  distMax = cms.double(0.8),
    					  value = cms.string('mass') 
    					  )	    
    process.ak8PFJetsPuppiPrunedMassCorrected = cms.EDProducer("RecoJetDeltaRValueMapProducer",
    					  src = cms.InputTag("ak8PuppiJets"),
    					  matched = cms.InputTag("patJetsAk8PuppiJetsPrunedPacked"),
    					  distMax = cms.double(0.8),
    					  value = cms.string('mass')
    					  )

    process.ak8PFJetsPuppiSoftDropMassCorrected = cms.EDProducer("RecoJetDeltaRValueMapProducer",
    					  src = cms.InputTag("ak8PuppiJets"),
    					  matched = cms.InputTag("patJetsAk8PuppiJetsSoftDropPacked"),					 
    					  distMax = cms.double(0.8),
    					  value = cms.string('mass') 
    					  )	    

    process.patJetsAk8PuppiJets.userData.userFloats.src += ['ak8PFJetsPuppiSoftDropMass','ak8PFJetsPuppiSoftDropMassCorrected']
    #process.patJetsAk8PuppiJets.userData.userFloats.src += ['ak8PFJetsPuppiPrunedMass','ak8PFJetsPuppiPrunedMassCorrected']
    process.patJetsAk8PuppiJets.userData.userFloats.src += ['NjettinessAK8Puppi:tau1','NjettinessAK8Puppi:tau2','NjettinessAK8Puppi:tau3']
    process.patJetsAk8PuppiJets.addTagInfos = True

    process.packedJetsAk8PuppiJets = cms.EDProducer("JetSubstructurePacker",
            jetSrc = cms.InputTag("patJetsAk8PuppiJets"),
            distMax = cms.double(0.8),
            algoTags = cms.VInputTag(
                cms.InputTag("patJetsAk8PuppiJetsSoftDropPacked")
            ),
            algoLabels = cms.vstring(
                'SoftDropPuppi'
                ),
            fixDaughters = cms.bool(False),
            packedPFCandidates = cms.InputTag("packedPFCandidates"),
    )

# ###### Recluster MET ##########
if config["DOMETRECLUSTERING"]:

  from PhysicsTools.PatAlgos.tools.jetTools import switchJetCollection
		  
  switchJetCollection(process,
                      jetSource = cms.InputTag('ak4PFJetsCHS'),
                      jetCorrections = ('AK4PFchs', jet_corr_levels, ''),
                      genParticles = cms.InputTag('prunedGenParticles'),
                      pvSource = cms.InputTag('offlineSlimmedPrimaryVertices')
                      )
		  		
  process.patJets.addGenJetMatch = cms.bool(False) 
  process.patJets.addGenPartonMatch = cms.bool(False) 
  process.patJets.addPartonJetMatch = cms.bool(False) 
  
  from PhysicsTools.PatUtils.tools.runMETCorrectionsAndUncertainties import runMetCorAndUncFromMiniAOD

  #default configuration for miniAOD reprocessing, change the isData flag to run on data
  #for a full met computation, remove the pfCandColl input
  runMetCorAndUncFromMiniAOD(process,
                           isData=not(config["RUNONMC"]),
                           )
  process.patPFMetT1T2Corr.type1JetPtThreshold = cms.double(15.0)
  process.patPFMetT2Corr.type1JetPtThreshold = cms.double(15.0)
  process.slimmedMETs.t01Variation = cms.InputTag("slimmedMETs","","RECO")
  
  if config["RUNONMC"]:
    process.patPFMetT1T2Corr.jetCorrLabelRes = cms.InputTag("L3Absolute")
    process.patPFMetT1T2SmearCorr.jetCorrLabelRes = cms.InputTag("L3Absolute")
    process.patPFMetT2Corr.jetCorrLabelRes = cms.InputTag("L3Absolute")
    process.patPFMetT2SmearCorr.jetCorrLabelRes = cms.InputTag("L3Absolute")
    process.shiftedPatJetEnDown.jetCorrLabelUpToL3Res = cms.InputTag("ak4PFCHSL1FastL2L3Corrector")
    process.shiftedPatJetEnUp.jetCorrLabelUpToL3Res = cms.InputTag("ak4PFCHSL1FastL2L3Corrector")
			           
####### Adding HEEP id ##########

from PhysicsTools.SelectorUtils.tools.vid_id_tools import *

dataFormat=DataFormat.MiniAOD

####### Event filters ###########

##___________________________HCAL_Noise_Filter________________________________||
if config["DOHLTFILTERS"]:
 process.load('CommonTools.RecoAlgos.HBHENoiseFilterResultProducer_cfi')
 process.HBHENoiseFilterResultProducer.minZeros = cms.int32(99999)
 process.HBHENoiseFilterResultProducer.IgnoreTS4TS5ifJetInLowBVRegion=cms.bool(False) 
 ##___________________________BadChargedCandidate_Noise_Filter________________________________|| 
 process.load('Configuration.StandardSequences.Services_cff')
 process.load('RecoMET.METFilters.BadChargedCandidateFilter_cfi')
 # process.load('VgammaTuplizer.Ntuplizer.BadChargedCandidateFilter_cfi')
 process.BadChargedCandidateFilter.muons = cms.InputTag("slimmedMuons")
 process.BadChargedCandidateFilter.PFCandidates = cms.InputTag("packedPFCandidates")
 process.BadChargedCandidateFilter.debug = cms.bool(False)
 process.BadChargedCandidateSequence = cms.Sequence (process.BadChargedCandidateFilter)
 

####### Ntuplizer initialization ##########
jetsAK4 = "slimmedJets"
jetsAK8 = "slimmedJetsAK8"
jetsAK8pruned = ""
# jetsAK8softdrop = "slimmedJetsAK8PFCHSSoftDropPacked" (if you want to add this subjet collection, changes need to be made in plugins/JetsNtuplizer.cc! Not needed to obtain subjets)
jetsAK8softdrop = ""
jetsAK10trimmed = ""
jetsAK8Puppi = ""  

METS = "slimmedMETs"
METS_EGclean = "slimmedMETsEGClean"
METS_MEGclean = "slimmedMETsMuEGClean"
METS_uncorr = "slimmedMETsUncorrected"

if config["DOMETRECLUSTERING"]: jetsAK4 = "selectedPatJets"
if config["USENOHF"]: METS = "slimmedMETsNoHF"  

##___________________ MET significance and covariance matrix ______________________##

if config["DOMETSVFIT"]:
  print "Using event pfMET covariance for SVfit"
  process.load("RecoMET.METProducers.METSignificance_cfi")
  process.load("RecoMET.METProducers.METSignificanceParams_cfi")
  pattask.add(process.METSignificance)

if config["DOMVAMET"]:
  from RecoMET.METPUSubtraction.jet_recorrections import recorrectJets
  recorrectJets(process, isData=True)
  
  from RecoMET.METPUSubtraction.MVAMETConfiguration_cff import runMVAMET
  runMVAMET( process, jetCollectionPF="patJetsReapplyJEC")
  process.MVAMET.srcLeptons  = cms.VInputTag("slimmedMuons", "slimmedElectrons", "slimmedTaus")
  process.MVAMET.requireOS = cms.bool(False)

##___________________ taus ______________________##

TAUS = ""
BOOSTEDTAUS = ""
genAK8 = ""

if config["ADDAK8GENJETS"]:
  genAK8 = 'selectedGenJetsAK8'
    
if config["DOAK8RECLUSTERING"]:
  jetsAK8 = "patJetsAk8CHSJets"
if config["UpdateJetCollection"]:
  jetsAK4 = "updatedJets"
  jetsAK8 = "updatedPatJetsTransientCorrected"
if doAK8softdropReclustering:  
  jetsAK8softdrop = "patJetsAk8CHSJetsSoftDropPacked"  
if config["DOAK8PRUNEDRECLUSTERING"]:  
  jetsAK8pruned = "patJetsAk8CHSJetsPrunedPacked"
if config["DOAK10TRIMMEDRECLUSTERING"]:  
  jetsAK10trimmed = "patJetsAk10CHSJetsTrimmed"
if reclusterPuppi:  
  #jetsAK8Puppi = "packedJetsAk8PuppiJets"
  jetsAK8Puppi = "slimmedJetsAK8"  

if config["DOTAUSBOOSTED"]:
#  TAUS = "slimmedTaus"
  TAUS = "NewTauIDsEmbedded"
  BOOSTEDTAUS = "slimmedTausBoosted"     
else:
#  TAUS = "slimmedTaus"
  TAUS = "NewTauIDsEmbedded"
  BOOSTEDTAUS = "slimmedTaus" 
  

######## JEC ########
jecLevelsAK8chs = []
jecLevelsAK8Groomedchs = []
jecLevelsAK4chs = []
jecLevelsAK4 = []
jecLevelsAK8Puppi = []
jecLevelsForMET = []

if config["BUNCHSPACING"] == 25 and config["RUNONMC"] :
   JECprefix = "Fall17_17Nov2017_V32"
   jecAK8chsUncFile = "JEC/%s_MC_Uncertainty_AK8PFPuppi.txt"%(JECprefix)
   #jecAK4chsUncFile = "JEC/%s_MC_Uncertainty_AK4PFchs.txt"%(JECprefix)
   jecAK4chsUncFile = "JEC/%s_MC_Uncertainty_AK4PFPuppi.txt"%(JECprefix)



elif config["BUNCHSPACING"] == 25 and not(config["RUNONMC"]):

   JEC_runDependent_suffix= ""
   if any("Run2017B" in s for s in  options.inputFiles): JEC_runDependent_suffix= "B"
   elif any("Run2017C" in s for s in  options.inputFiles): JEC_runDependent_suffix= "C"
   elif any("Run2017D" in s for s in  options.inputFiles): JEC_runDependent_suffix= "DE"
   elif any("Run2017E" in s for s in  options.inputFiles): JEC_runDependent_suffix= "DE"
   elif any("Run2017F" in s for s in  options.inputFiles): JEC_runDependent_suffix= "F"
  
   JECprefix = "Fall17_17Nov2017"+JEC_runDependent_suffix+"_V32"
   jecAK8chsUncFile = "JEC/%s_DATA_Uncertainty_AK8PFPuppi.txt"%(JECprefix)
   #jecAK4chsUncFile = "JEC/%s_DATA_Uncertainty_AK4PFchs.txt"%(JECprefix)
   jecAK4chsUncFile = "JEC/%s_DATA_Uncertainty_AK4PFPuppi.txt"%(JECprefix)
   print "jec JEC_runDependent_suffix %s ,  prefix %s " %(JEC_runDependent_suffix,JECprefix)

print "jec unc file for ak8 ", jecAK8chsUncFile
print "doing corrections to jets on th fly %s, to met on the fly %s" %(config["CORRJETSONTHEFLY"],config["CORRMETONTHEFLY"])
if config["CORRJETSONTHEFLY"]:
   if config["RUNONMC"]:
     jecLevelsAK8chs = [
     	 'JEC/%s_MC_L1FastJet_AK8PFPuppi.txt'%(JECprefix),
     	 'JEC/%s_MC_L2Relative_AK8PFPuppi.txt'%(JECprefix),
     	 'JEC/%s_MC_L3Absolute_AK8PFPuppi.txt'%(JECprefix)
       ]
     jecLevelsAK8Groomedchs = [
     	 'JEC/%s_MC_L2Relative_AK8PFPuppi.txt'%(JECprefix),
     	 'JEC/%s_MC_L3Absolute_AK8PFPuppi.txt'%(JECprefix)
       ]
     jecLevelsAK8Puppi = [
     	 'JEC/%s_MC_L2Relative_AK8PFPuppi.txt'%(JECprefix),
     	 'JEC/%s_MC_L3Absolute_AK8PFPuppi.txt'%(JECprefix)
       ]
     jecLevelsAK4chs = [
     	 #'JEC/%s_MC_L1FastJet_AK4PFPuppi.txt'%(JECprefix),
     	 'JEC/%s_MC_L2Relative_AK4PFPuppi.txt'%(JECprefix),
     	 'JEC/%s_MC_L3Absolute_AK4PFPuppi.txt'%(JECprefix)
       ]
   else:
     jecLevelsAK8chs = [
     	 'JEC/%s_DATA_L1FastJet_AK8PFPuppi.txt'%(JECprefix),
     	 'JEC/%s_DATA_L2Relative_AK8PFPuppi.txt'%(JECprefix),
     	 'JEC/%s_DATA_L3Absolute_AK8PFPuppi.txt'%(JECprefix),
         'JEC/%s_DATA_L2L3Residual_AK8PFPuppi.txt'%(JECprefix)
       ]
     jecLevelsAK8Groomedchs = [
     	 'JEC/%s_DATA_L2Relative_AK8PFPuppi.txt'%(JECprefix),
     	 'JEC/%s_DATA_L3Absolute_AK8PFPuppi.txt'%(JECprefix),
         'JEC/%s_DATA_L2L3Residual_AK8PFPuppi.txt'%(JECprefix)
       ]
     jecLevelsAK8Puppi = [
     	 'JEC/%s_DATA_L2Relative_AK8PFPuppi.txt'%(JECprefix),
     	 'JEC/%s_DATA_L3Absolute_AK8PFPuppi.txt'%(JECprefix),
         'JEC/%s_DATA_L2L3Residual_AK8PFPuppi.txt'%(JECprefix)
       ]
     jecLevelsAK4chs = [
     	 'JEC/%s_DATA_L1FastJet_AK4PFPuppi.txt'%(JECprefix),
     	 'JEC/%s_DATA_L2Relative_AK4PFPuppi.txt'%(JECprefix),
     	 'JEC/%s_DATA_L3Absolute_AK4PFPuppi.txt'%(JECprefix),
         'JEC/%s_DATA_L2L3Residual_AK4PFPuppi.txt'%(JECprefix)
       ]   
if config["CORRMETONTHEFLY"]:  
   if config["RUNONMC"]:
     jecLevelsForMET = [				       
     	 'JEC/%s_MC_L1FastJet_AK4PFchs.txt'%(JECprefix),
     	 'JEC/%s_MC_L2Relative_AK4PFchs.txt'%(JECprefix),
     	 'JEC/%s_MC_L3Absolute_AK4PFchs.txt'%(JECprefix)
       ]
   else:       					       
     jecLevelsForMET = [
     	 'JEC/%s_DATA_L1FastJet_AK4PFchs.txt'%(JECprefix),
     	 'JEC/%s_DATA_L2Relative_AK4PFchs.txt'%(JECprefix),
     	 'JEC/%s_DATA_L3Absolute_AK4PFchs.txt'%(JECprefix),
         'JEC/%s_DATA_L2L3Residual_AK4PFchs.txt'%(JECprefix)
       ]	
      			    
#from PhysicsTools.SelectorUtils.pfJetIDSelector_cfi import pfJetIDSelector
#process.goodSlimmedJets = cms.EDFilter("PFJetIDSelectionFunctorFilter",
#                        filterParams = pfJetIDSelector.clone(),
#                        src = cms.InputTag("slimmedJets")
#                        )
#process.goodFatJets = cms.EDFilter("PFJetIDSelectionFunctorFilter",
#                        filterParams = pfJetIDSelector.clone(),
#                        src = cms.InputTag(jetsAK8)
#                        )
######## JER ########
JERprefix = "Fall17_V3"
if config["RUNONMC"]:
  jerAK8chsFile_res = "JER/%s_MC_PtResolution_AK8PFchs.txt"%(JERprefix)
  jerAK4chsFile_res = "JER/%s_MC_PtResolution_AK4PFchs.txt"%(JERprefix)
  jerAK8PuppiFile_res = "JER/%s_MC_PtResolution_AK8PFPuppi.txt"%(JERprefix)
  jerAK4PuppiFile_res = "JER/%s_MC_PtResolution_AK4PFPuppi.txt"%(JERprefix)
  jerAK8chsFile_sf = "JER/%s_MC_SF_AK8PFchs.txt"%(JERprefix)
  jerAK4chsFile_sf = "JER/%s_MC_SF_AK4PFchs.txt"%(JERprefix)
  jerAK8PuppiFile_sf = "JER/%s_MC_SF_AK8PFPuppi.txt"%(JERprefix)
  jerAK4PuppiFile_sf = "JER/%s_MC_SF_AK4PFPuppi.txt"%(JERprefix)
else:
  jerAK8chsFile_res = "JER/%s_DATA_PtResolution_AK8PFchs.txt"%(JERprefix)
  jerAK4chsFile_res = "JER/%s_DATA_PtResolution_AK4PFchs.txt"%(JERprefix)
  jerAK8PuppiFile_res = "JER/%s_DATA_PtResolution_AK8PFPuppi.txt"%(JERprefix)
  jerAK4PuppiFile_res = "JER/%s_DATA_PtResolution_AK4PFPuppi.txt"%(JERprefix)
  jerAK8chsFile_sf = "JER/%s_DATA_SF_AK8PFchs.txt"%(JERprefix)
  jerAK4chsFile_sf = "JER/%s_DATA_SF_AK4PFchs.txt"%(JERprefix)
  jerAK8PuppiFile_sf = "JER/%s_DATA_SF_AK8PFPuppi.txt"%(JERprefix)
  jerAK4PuppiFile_sf = "JER/%s_DATA_SF_AK4PFPuppi.txt"%(JERprefix)

print ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
print ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
print "Fatjet Collection: ", jetsAK8
print "PuppiJet Collection: ", jetsAK8Puppi
print ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
print ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
                                                                                           
################## Ntuplizer ###################
process.ntuplizer = cms.EDAnalyzer("Ntuplizer",
    runOnMC	      = cms.bool(config["RUNONMC"]),
    doGenParticles    = cms.bool(config["DOGENPARTICLES"]),
    doGenJets	      = cms.bool(config["DOGENJETS"]),
    doGenEvent	      = cms.bool(config["DOGENEVENT"]),
    doPileUp	      = cms.bool(config["DOPILEUP"]),
    doElectrons       = cms.bool(config["DOELECTRONS"]),
    doPhotons         = cms.bool(config["DOPHOTONS"]),
    doMuons	      = cms.bool(config["DOMUONS"]),
    doTaus	      = cms.bool(config["DOTAUS"]),
    doAK8Jets	      = cms.bool(config["DOAK8JETS"]),
    doAK4Jets	      = cms.bool(config["DOAK4JETS"]),
    doVertices	      = cms.bool(config["DOVERTICES"]),
    doTriggerDecisions= cms.bool(config["DOTRIGGERDECISIONS"]),
    doTriggerObjects  = cms.bool(config["DOTRIGGEROBJECTS"]),
    doHltFilters      = cms.bool(config["DOHLTFILTERS"]),
    doMissingEt       = cms.bool(config["DOMISSINGET"]),
    doHbbTag	      = cms.bool(config["DOHBBTAG"]),
    doPrunedSubjets   = cms.bool(config["DOAK8PRUNEDRECLUSTERING"]),
    doTrimming        = cms.bool(config["DOAK10TRIMMEDRECLUSTERING"]),
    doPuppi           = cms.bool(config["DOAK8PUPPI"]),#NOT IS USE ANYMORE
    doBoostedTaus     = cms.bool(config["DOTAUSBOOSTED"]),
    doMETSVFIT        = cms.bool(config["DOMETSVFIT"]),
    doMVAMET          = cms.bool(config["DOMVAMET"]),
    doMultipleTauMVAversions = cms.bool(config["DOMULTIPLETAUMVAVERSIONS"]),
    vertices = cms.InputTag("offlineSlimmedPrimaryVertices"),
    muons = cms.InputTag("slimmedMuons"),
    photons = cms.InputTag("slimmedPhotons"),
    phoIdVerbose = cms.bool(False),
    #phoLooseIdMap  = cms.InputTag("egmPhotonIDs:cutBasedPhotonID-Fall17-94X-V2-loose"),
    #phoMediumIdMap = cms.InputTag("egmPhotonIDs:cutBasedPhotonID-Fall17-94X-V2-medium"),
    #phoTightIdMap  = cms.InputTag("egmPhotonIDs:cutBasedPhotonID-Fall17-94X-V2-tight"),
    #phoMvaValuesMap = cms.InputTag("photonMVAValueMapProducer:PhotonMVAEstimatorRunIIFall17v2Values"),
    #phoMvaCategoriesMap = cms.InputTag("photonMVAValueMapProducer:PhotonMVAEstimatorRunIIFall17v2Categories"),
    electrons = cms.InputTag("slimmedElectrons"),
    ebRecHits = cms.InputTag("reducedEgamma","reducedEBRecHits"),

#    eleHEEPId51Map = cms.InputTag("egmGsfElectronIDs:heepElectronID-HEEPV51"),
#    eleHEEPIdMap = cms.InputTag("egmGsfElectronIDs:heepElectronID-HEEPV60"),
#    eleVetoIdMap = cms.InputTag("egmGsfElectronIDs:cutBasedElectronID-Spring15-25ns-V1-standalone-veto"),
#    eleLooseIdMap = cms.InputTag("egmGsfElectronIDs:cutBasedElectronID-Spring15-25ns-V1-standalone-loose"),
#    eleMediumIdMap = cms.InputTag("egmGsfElectronIDs:cutBasedElectronID-Spring15-25ns-V1-standalone-medium"),
#    eleTightIdMap = cms.InputTag("egmGsfElectronIDs:cutBasedElectronID-Spring15-25ns-V1-standalone-tight"),

    #eleVetoIdMap = cms.InputTag("egmGsfElectronIDs:cutBasedElectronID-Fall17-94X-V1-veto"),
    #eleLooseIdMap = cms.InputTag("egmGsfElectronIDs:cutBasedElectronID-Fall17-94X-V1-loose"),
    #eleMediumIdMap = cms.InputTag("egmGsfElectronIDs:cutBasedElectronID-Fall17-94X-V1-medium"),
    #eleTightIdMap = cms.InputTag("egmGsfElectronIDs:cutBasedElectronID-Fall17-94X-V1-tight"),

    #eleHLTIdMap = cms.InputTag("egmGsfElectronIDs:cutBasedElectronHLTPreselection-Summer16-V1"), 
    #eleHEEPIdMap = cms.InputTag("egmGsfElectronIDs:heepElectronID-HEEPV70"),
                                   
    #eleMVAMediumIdMap = cms.InputTag("egmGsfElectronIDs:mvaEleID-Fall17-noIso-V1-wp90"),
    #eleMVATightIdMap  = cms.InputTag("egmGsfElectronIDs:mvaEleID-Fall17-noIso-V1-wp80"),
    #mvaValuesMap     = cms.InputTag("electronMVAValueMapProducer:ElectronMVAEstimatorRun2Fall17NoIsoV1Values"),
    #mvaCategoriesMap = cms.InputTag("electronMVAValueMapProducer:ElectronMVAEstimatorRun2Spring16GeneralPurposeV1Categories"),
    dupCluster          = cms.InputTag("particleFlowEGammaGSFixed:dupECALClusters"),
    hitsNotReplaced     = cms.InputTag("ecalMultiAndGSGlobalRecHitEB:hitsNotReplaced"),
    taus = cms.InputTag(TAUS),
    tausBoostedTau = cms.InputTag(BOOSTEDTAUS),
    jets = cms.InputTag(jetsAK4),
    fatjets = cms.InputTag(jetsAK8),
    prunedjets = cms.InputTag(jetsAK8pruned),
    softdropjets = cms.InputTag(jetsAK8softdrop),
    trimmedjets = cms.InputTag(jetsAK10trimmed),
    puppijets = cms.InputTag(jetsAK8Puppi),
    genJets = cms.InputTag("slimmedGenJets"),
    genJetsAK8 = cms.InputTag(genAK8),
    subjetflavour = cms.InputTag("AK8byValAlgo"),
    mets = cms.InputTag(METS),
    mets_EGclean = cms.InputTag(METS_EGclean),
    mets_MEGclean = cms.InputTag(METS_MEGclean),
    mets_uncorr = cms.InputTag(METS_uncorr),
    mets_puppi = cms.InputTag("slimmedMETsPuppi"),
    mets_mva = cms.InputTag("MVAMET","MVAMET"),
    corrMetPx = cms.string("+0.1166 + 0.0200*Nvtx"),
    corrMetPy = cms.string("+0.2764 - 0.1280*Nvtx"),
    jecAK4forMetCorr = cms.vstring( jecLevelsForMET ),
    jetsForMetCorr = cms.InputTag(jetsAK4),
    rho = cms.InputTag("fixedGridRhoFastjetAll"),
    genparticles = cms.InputTag("prunedGenParticles"),
    PUInfo = cms.InputTag("slimmedAddPileupInfo"),
    genEventInfo = cms.InputTag("generator"),
    externallheProducer = cms.InputTag("externalLHEProducer"),
    HLT = cms.InputTag("TriggerResults","","HLT"),
    triggerobjects = cms.InputTag("slimmedPatTrigger"),
    triggerprescales = cms.InputTag("patTrigger"),
    noiseFilter = cms.InputTag('TriggerResults','', hltFiltersProcessName),
    jecAK8chsPayloadNames = cms.vstring( jecLevelsAK8chs ),
    jecAK8chsUnc = cms.string( jecAK8chsUncFile ),
    #jecAK8GroomedchsPayloadNames = cms.vstring( jecLevelsAK8Groomedchs ),
    jecAK8GroomedchsPayloadNames = cms.vstring( jecLevelsAK8Groomedchs ),
    jecAK8PuppiPayloadNames = cms.vstring( jecLevelsAK8Puppi ),
    jecAK4chsPayloadNames = cms.vstring( jecLevelsAK4chs ),
    jecAK4chsUnc = cms.string( jecAK4chsUncFile ),
    jecpath = cms.string(''),
    jerAK8chs_res_PayloadNames = cms.string( jerAK8chsFile_res ),
    jerAK4chs_res_PayloadNames = cms.string( jerAK4chsFile_res ),
    jerAK8Puppi_res_PayloadNames = cms.string(  jerAK8PuppiFile_res ),
    jerAK4Puppi_res_PayloadNames = cms.string(  jerAK4PuppiFile_res ),
    jerAK8chs_sf_PayloadNames = cms.string( jerAK8chsFile_sf ),
    jerAK4chs_sf_PayloadNames = cms.string( jerAK4chsFile_sf ),
    jerAK8Puppi_sf_PayloadNames = cms.string(  jerAK8PuppiFile_sf ),
    jerAK4Puppi_sf_PayloadNames = cms.string(  jerAK4PuppiFile_sf ),

    
    ## Noise Filters ###################################
    # defined here: https://github.com/cms-sw/cmssw/blob/CMSSW_7_4_X/PhysicsTools/PatAlgos/python/slimming/metFilterPaths_cff.py
    noiseFilterSelection_HBHENoiseFilter = cms.string('Flag_HBHENoiseFilter'),
    noiseFilterSelection_HBHENoiseFilterLoose = cms.InputTag("HBHENoiseFilterResultProducer", "HBHENoiseFilterResultRun2Loose"),
    noiseFilterSelection_HBHENoiseFilterTight = cms.InputTag("HBHENoiseFilterResultProducer", "HBHENoiseFilterResultRun2Tight"),
    noiseFilterSelection_HBHENoiseIsoFilter = cms.InputTag("HBHENoiseFilterResultProducer", "HBHEIsoNoiseFilterResult"),    
    noiseFilterSelection_CSCTightHaloFilter = cms.string('Flag_CSCTightHaloFilter'),
    noiseFilterSelection_CSCTightHalo2015Filter = cms.string('Flag_CSCTightHalo2015Filter'),
    noiseFilterSelection_hcalLaserEventFilter = cms.string('Flag_hcalLaserEventFilter'),
    noiseFilterSelection_EcalDeadCellTriggerPrimitiveFilter = cms.string('Flag_EcalDeadCellTriggerPrimitiveFilter'),
    noiseFilterSelection_goodVertices = cms.string('Flag_goodVertices'),
    noiseFilterSelection_trackingFailureFilter = cms.string('Flag_trackingFailureFilter'),
    noiseFilterSelection_eeBadScFilter = cms.string('Flag_eeBadScFilter'),
    noiseFilterSelection_ecalLaserCorrFilter = cms.string('Flag_ecalLaserCorrFilter'),
    noiseFilterSelection_trkPOGFilters = cms.string('Flag_trkPOGFilters'),
    
    #New for ICHEP 2016
    noiseFilterSelection_CSCTightHaloTrkMuUnvetoFilter = cms.string('Flag_CSCTightHaloTrkMuUnvetoFilter'),
    noiseFilterSelection_globalTightHalo2016Filter = cms.string('Flag_globalTightHalo2016Filter'),
    noiseFilterSelection_globalSuperTightHalo2016Filter = cms.string('Flag_globalSuperTightHalo2016Filter'),
    noiseFilterSelection_HcalStripHaloFilter = cms.string('Flag_HcalStripHaloFilter'),
    noiseFilterSelection_chargedHadronTrackResolutionFilter = cms.string('Flag_chargedHadronTrackResolutionFilter'),
    noiseFilterSelection_muonBadTrackFilter = cms.string('Flag_muonBadTrackFilter'),
    
    #New for Moriond
    noiseFilterSelection_badMuonsFilter = cms.string('Flag_badMuons'),
    noiseFilterSelection_duplicateMuonsFilter = cms.string('Flag_duplicateMuons'),
    noiseFilterSelection_nobadMuonsFilter = cms.string('Flag_nobadMuons'),

    # and the sub-filters
    noiseFilterSelection_trkPOG_manystripclus53X = cms.string('Flag_trkPOG_manystripclus53X'),
    noiseFilterSelection_trkPOG_toomanystripclus53X = cms.string('Flag_trkPOG_toomanystripclus53X'),
    noiseFilterSelection_trkPOG_logErrorTooManyClusters = cms.string('Flag_trkPOG_logErrorTooManyClusters'),
    # summary
    noiseFilterSelection_metFilters = cms.string('Flag_METFilters'),

    packedpfcandidates = cms.InputTag('packedPFCandidates')
)




#### Needed to load the new tau ID payloads ####

from RecoTauTag.RecoTau.TauDiscriminatorTools import noPrediscriminants
from RecoTauTag.RecoTau.PATTauDiscriminationByMVAIsolationRun2_cff import patDiscriminationByIsolationMVArun2v1raw, patDiscriminationByIsolationMVArun2v1VLoose



tauIdDiscrMVA_trainings_run2_2017 = {
  'tauIdMVAIsoDBoldDMwLT2017' : "tauIdMVAIsoDBoldDMwLT2017",
  }
tauIdDiscrMVA_WPs_run2_2017 = {
  'tauIdMVAIsoDBoldDMwLT2017' : {
    'Eff95' : "DBoldDMwLTEff95",
    'Eff90' : "DBoldDMwLTEff90",
    'Eff80' : "DBoldDMwLTEff80",
    'Eff70' : "DBoldDMwLTEff70",
    'Eff60' : "DBoldDMwLTEff60",
    'Eff50' : "DBoldDMwLTEff50",
    'Eff40' : "DBoldDMwLTEff40"
    }
  }
tauIdDiscrMVA_2017_version = "v1"


def loadMVA_WPs_run2_2017(process):
                print "LoadMVA_WPs_run2_2017: performed::::"
                #global cms



		for training, gbrForestName in tauIdDiscrMVA_trainings_run2_2017.items():

			process.loadRecoTauTagMVAsFromPrepDB.toGet.append(
				cms.PSet(
					record = cms.string('GBRWrapperRcd'),
					tag = cms.string("RecoTauTag_%s%s" % (gbrForestName, tauIdDiscrMVA_2017_version)),
					label = cms.untracked.string("RecoTauTag_%s%s" % (gbrForestName, tauIdDiscrMVA_2017_version))
				)
			)

			for WP in tauIdDiscrMVA_WPs_run2_2017[training].keys():
				process.loadRecoTauTagMVAsFromPrepDB.toGet.append(
					cms.PSet(
						record = cms.string('PhysicsTGraphPayloadRcd'),
						tag = cms.string("RecoTauTag_%s%s_WP%s" % (gbrForestName, tauIdDiscrMVA_2017_version, WP)),
						label = cms.untracked.string("RecoTauTag_%s%s_WP%s" % (gbrForestName, tauIdDiscrMVA_2017_version, WP))
					)
				)

			process.loadRecoTauTagMVAsFromPrepDB.toGet.append(
				cms.PSet(
					record = cms.string('PhysicsTFormulaPayloadRcd'),
					tag = cms.string("RecoTauTag_%s%s_mvaOutput_normalization" % (gbrForestName, tauIdDiscrMVA_2017_version)),
					label = cms.untracked.string("RecoTauTag_%s%s_mvaOutput_normalization" % (gbrForestName, tauIdDiscrMVA_2017_version))
				)
)


####### Tau new MVA ##########

from RecoTauTag.RecoTau.TauDiscriminatorTools import noPrediscriminants
process.load('RecoTauTag.Configuration.loadRecoTauTagMVAsFromPrepDB_cfi')
from RecoTauTag.RecoTau.PATTauDiscriminationByMVAIsolationRun2_cff import *
loadMVA_WPs_run2_2017(process)

process.rerunDiscriminationByIsolationMVArun2v1raw = patDiscriminationByIsolationMVArun2v1raw.clone(
   PATTauProducer = cms.InputTag('slimmedTaus'),
   Prediscriminants = noPrediscriminants,
   loadMVAfromDB = cms.bool(True),
   mvaName = cms.string("RecoTauTag_tauIdMVAIsoDBoldDMwLT2017v1"),# training with 2017 MC_v1 for oldDM # name of the training you want to use
   mvaOpt = cms.string("DBoldDMwLTwGJ"), # option you want to use for your training (i.e., which variables are used to compute the BDT score)
   requireDecayMode = cms.bool(True),
   verbosity = cms.int32(0)
)


process.rerunDiscriminationByIsolationMVArun2v1VLoose = patDiscriminationByIsolationMVArun2v1VLoose.clone(
   PATTauProducer = cms.InputTag('slimmedTaus'),    
   Prediscriminants = noPrediscriminants,
   toMultiplex = cms.InputTag('rerunDiscriminationByIsolationMVArun2v1raw'),
   key = cms.InputTag('rerunDiscriminationByIsolationMVArun2v1raw:category'),
   loadMVAfromDB = cms.bool(True),
   mvaOutput_normalization = cms.string("RecoTauTag_tauIdMVAIsoDBoldDMwLT2017v1_mvaOutput_normalization"), # normalization fo the training you want to use
   mapping = cms.VPSet(
      cms.PSet(
         category = cms.uint32(0),
         cut = cms.string("RecoTauTag_tauIdMVAIsoDBoldDMwLT2017v1_WPEff90"), # this is the name of the working point you want to use
         variable = cms.string("pt"),
      )
   )
)

# here we produce all the other working points for the training
process.rerunDiscriminationByIsolationMVArun2v1VVLoose = process.rerunDiscriminationByIsolationMVArun2v1VLoose.clone()
process.rerunDiscriminationByIsolationMVArun2v1VVLoose.mapping[0].cut = cms.string("RecoTauTag_tauIdMVAIsoDBoldDMwLT2017v1_WPEff95")
process.rerunDiscriminationByIsolationMVArun2v1Loose = process.rerunDiscriminationByIsolationMVArun2v1VLoose.clone()
process.rerunDiscriminationByIsolationMVArun2v1Loose.mapping[0].cut = cms.string("RecoTauTag_tauIdMVAIsoDBoldDMwLT2017v1_WPEff80")
process.rerunDiscriminationByIsolationMVArun2v1Medium = process.rerunDiscriminationByIsolationMVArun2v1VLoose.clone()
process.rerunDiscriminationByIsolationMVArun2v1Medium.mapping[0].cut = cms.string("RecoTauTag_tauIdMVAIsoDBoldDMwLT2017v1_WPEff70")
process.rerunDiscriminationByIsolationMVArun2v1Tight = process.rerunDiscriminationByIsolationMVArun2v1VLoose.clone()
process.rerunDiscriminationByIsolationMVArun2v1Tight.mapping[0].cut = cms.string("RecoTauTag_tauIdMVAIsoDBoldDMwLT2017v1_WPEff60")
process.rerunDiscriminationByIsolationMVArun2v1VTight = process.rerunDiscriminationByIsolationMVArun2v1VLoose.clone()
process.rerunDiscriminationByIsolationMVArun2v1VTight.mapping[0].cut = cms.string("RecoTauTag_tauIdMVAIsoDBoldDMwLT2017v1_WPEff50")
process.rerunDiscriminationByIsolationMVArun2v1VVTight = process.rerunDiscriminationByIsolationMVArun2v1VLoose.clone()
process.rerunDiscriminationByIsolationMVArun2v1VVTight.mapping[0].cut = cms.string("RecoTauTag_tauIdMVAIsoDBoldDMwLT2017v1_WPEff40")

# this sequence has to be included in your cms.Path() before your analyzer which accesses the new variables is called.
process.rerunMvaIsolation2SeqRun2 = cms.Sequence(
   process.rerunDiscriminationByIsolationMVArun2v1raw
   *process.rerunDiscriminationByIsolationMVArun2v1VLoose
   *process.rerunDiscriminationByIsolationMVArun2v1VVLoose
   *process.rerunDiscriminationByIsolationMVArun2v1Loose
   *process.rerunDiscriminationByIsolationMVArun2v1Medium
   *process.rerunDiscriminationByIsolationMVArun2v1Tight
   *process.rerunDiscriminationByIsolationMVArun2v1VTight
   *process.rerunDiscriminationByIsolationMVArun2v1VVTight
)


if  not config["DOMULTIPLETAUMVAVERSIONS"]: ## skip this partial inclusion, if you are also using a *db file and just do it all together at the end.
# embed new id's into new tau collection
  embedID = cms.EDProducer("PATTauIDEmbedder",
     src = cms.InputTag('slimmedTaus'),
     tauIDSources = cms.PSet(
        byIsolationMVArun2v1DBoldDMwLTrawNew = cms.InputTag('rerunDiscriminationByIsolationMVArun2v1raw'),
        byVLooseIsolationMVArun2v1DBoldDMwLTNew = cms.InputTag('rerunDiscriminationByIsolationMVArun2v1VLoose'),
        byVVLooseIsolationMVArun2v1DBoldDMwLTNew = cms.InputTag('rerunDiscriminationByIsolationMVArun2v1VVLoose'),
        byLooseIsolationMVArun2v1DBoldDMwLTNew = cms.InputTag('rerunDiscriminationByIsolationMVArun2v1Loose'),
        byMediumIsolationMVArun2v1DBoldDMwLTNew = cms.InputTag('rerunDiscriminationByIsolationMVArun2v1Medium'),
        byTightIsolationMVArun2v1DBoldDMwLTNew = cms.InputTag('rerunDiscriminationByIsolationMVArun2v1Tight'),
        byVTightIsolationMVArun2v1DBoldDMwLTNew = cms.InputTag('rerunDiscriminationByIsolationMVArun2v1VTight'),
        byVVTightIsolationMVArun2v1DBoldDMwLTNew = cms.InputTag('rerunDiscriminationByIsolationMVArun2v1VVTight'),
        ),
     )

  setattr(process, "NewTauIDsEmbedded", embedID)

  ##===== V2 of the MVA isolation from qslite file:
  #Do_Tau_isolation_FromDB =True
if  config["DOMULTIPLETAUMVAVERSIONS"]:


  from CondCore.DBCommon.CondDBSetup_cfi import *


  process.loadRecoTauTagMVAsFromPrepDB2 = cms.ESSource("PoolDBESSource",

                                                       CondDBSetup,
                                                       DumpStat = cms.untracked.bool(False),
                                                       toGet = cms.VPSet(),                                             
                                                       #  connect = cms.string("frontier://FrontierPrep/CMS_COND_PHYSICSTOOLS") # prep database
                                                       #connect = cms.string('frontier://FrontierProd/CMS_CONDITIONS') # prod database
                                                       connect = cms.string('sqlite_file:RecoTauTag_MVAs_2018Mar15.db')
  )

  #process.loadRecoTauTagMVAsFromPrepDB2

  tauIdDiscrMVA_trainings_run2_2017_v2 = {
    'tauIdMVAIsoDBoldDMwLT2017' : "tauIdMVAIsoDBoldDMwLT2017",
    'tauIdMVAIsoDBnewDMwLT2017' : "tauIdMVAIsoDBnewDMwLT2017",
    'tauIdMVAIsoDBoldDMdR0p3wLT2017' : "tauIdMVAIsoDBoldDMdR0p3wLT2017",
    }
  tauIdDiscrMVA_WPs_run2_2017_v2 = {
    'tauIdMVAIsoDBoldDMwLT2017' : {
      'Eff95' : "DBoldDMwLTEff95",
      'Eff90' : "DBoldDMwLTEff90",
      'Eff80' : "DBoldDMwLTEff80",
      'Eff70' : "DBoldDMwLTEff70",
      'Eff60' : "DBoldDMwLTEff60",
      'Eff50' : "DBoldDMwLTEff50",
      'Eff40' : "DBoldDMwLTEff40"
      } ,
    'tauIdMVAIsoDBnewDMwLT2017' : {
      'Eff95' : "DBnewDMwLTEff95",
      'Eff90' : "DBnewDMwLTEff90",
      'Eff80' : "DBnewDMwLTEff80",
      'Eff70' : "DBnewDMwLTEff70",
      'Eff60' : "DBnewDMwLTEff60",
      'Eff50' : "DBnewDMwLTEff50",
      'Eff40' : "DBnewDMwLTEff40"
      } ,
    'tauIdMVAIsoDBoldDMdR0p3wLT2017' : {
      'Eff95' : "DBoldDMdR0p3wLTEff95",
      'Eff90' : "DBoldDMdR0p3wLTEff90",
      'Eff80' : "DBoldDMdR0p3wLTEff80",
      'Eff70' : "DBoldDMdR0p3wLTEff70",
      'Eff60' : "DBoldDMdR0p3wLTEff60",
      'Eff50' : "DBoldDMdR0p3wLTEff50",
      'Eff40' : "DBoldDMdR0p3wLTEff40"
     }
    }
  tauIdDiscrMVA_2017_v2_version = "v2"

  tauIdDiscrMVA_mvaOutput_normalizations_v2 = {
    'tauIdMVAIsoDBoldDMwLT2017' : "tauIdMVAIsoDBoldDMwLT_2017v2_dR0p5",
    'tauIdMVAIsoDBnewDMwLT2017' : "tauIdMVAIsoDBnewDMwLT_2017v2_dR0p5",
    'tauIdMVAIsoDBoldDMdR0p3wLT2017' : "tauIdMVAIsoDBoldDMwLT_2017v2_dR0p3",
    }
  def loadMVA_WPs_run2_2017_v2(process):
                  print "LoadMVA_WPs_run2_2017_v2: performed::::"
                  #global cms


                  for training, gbrForestName in tauIdDiscrMVA_trainings_run2_2017_v2.items():
                          print " printing tauIdDiscrMVA_trainings_run2_2017_v2.items(),  training %s , gbrForestName %s" %(training, gbrForestName)
                          print " tauIdDiscrMVA_mvaOutput_normalizations_v2[training] %s"% tauIdDiscrMVA_mvaOutput_normalizations_v2[training]
                          print "printato"
 
                          process.loadRecoTauTagMVAsFromPrepDB2.toGet.append(
                                  cms.PSet(
                                          record = cms.string('GBRWrapperRcd'),
                                          tag = cms.string("RecoTauTag_%s%s" % (gbrForestName, tauIdDiscrMVA_2017_v2_version)),
                                          label = cms.untracked.string("RecoTauTag_%s%s" % (gbrForestName, tauIdDiscrMVA_2017_v2_version))
                                  )
                          )

                          for WP in tauIdDiscrMVA_WPs_run2_2017_v2[training].keys():
                                  process.loadRecoTauTagMVAsFromPrepDB2.toGet.append(
                                          cms.PSet(
                                                  record = cms.string('PhysicsTGraphPayloadRcd'),
                                                  tag = cms.string("RecoTauTag_%s%s_WP%s" % (gbrForestName, tauIdDiscrMVA_2017_v2_version, WP)),
                                                  label = cms.untracked.string("RecoTauTag_%s%s_WP%s" % (gbrForestName, tauIdDiscrMVA_2017_v2_version, WP))
                                          )
                                  )

                          process.loadRecoTauTagMVAsFromPrepDB2.toGet.append(
                                  cms.PSet(
                                          record = cms.string('PhysicsTFormulaPayloadRcd'),
                                          tag = cms.string("RecoTauTag_%s_mvaOutput_normalization" % (tauIdDiscrMVA_mvaOutput_normalizations_v2[training])),
                                          label = cms.untracked.string("RecoTauTag_%s_mvaOutput_normalization" % (tauIdDiscrMVA_mvaOutput_normalizations_v2[training]))### https://github.com/cgalloni/cmssw/blob/CMSSW_8_0_X/RecoTauTag/Configuration/python/loadRecoTauTagMVAsFromPrepDB_cfi.py
                                          #tag = cms.string("RecoTauTag_tauIdMVAIsoDBoldDMwLT_2017v2_dR0p5_mvaOutput_normalization"),
                                          #label = cms.untracked.string("RecoTauTag_tauIdMVAIsoDBoldDMwLT_2017v2_dR0p5_mvaOutput_normalization"),

                                  )
  )







  #======= for v2


  loadMVA_WPs_run2_2017_v2(process)

  process.rerunDiscriminationByIsolationMVArun2v2raw = patDiscriminationByIsolationMVArun2v1raw.clone(
     PATTauProducer = cms.InputTag('slimmedTaus'),
     Prediscriminants = noPrediscriminants,
     loadMVAfromDB = cms.bool(True),
     mvaName = cms.string("RecoTauTag_tauIdMVAIsoDBoldDMwLT2017v2"),# training with 2017 MC_v1 for oldDM # name of the training you want to use
     mvaOpt = cms.string("DBoldDMwLTwGJ"), # option you want to use for your training (i.e., which variables are used to compute the BDT score)
     requireDecayMode = cms.bool(True),
     verbosity = cms.int32(0)
  )


  process.rerunDiscriminationByIsolationMVArun2v2VLoose = patDiscriminationByIsolationMVArun2v1VLoose.clone(
     PATTauProducer = cms.InputTag('slimmedTaus'),    
     Prediscriminants = noPrediscriminants,
     toMultiplex = cms.InputTag('rerunDiscriminationByIsolationMVArun2v2raw'),
     key = cms.InputTag('rerunDiscriminationByIsolationMVArun2v2raw:category'),
     loadMVAfromDB = cms.bool(True),
     mvaOutput_normalization = cms.string("RecoTauTag_tauIdMVAIsoDBoldDMwLT_2017v2_dR0p5_mvaOutput_normalization"), # normalization fo the training you want to use
     mapping = cms.VPSet(
        cms.PSet(
           category = cms.uint32(0),
           cut = cms.string("RecoTauTag_tauIdMVAIsoDBoldDMwLT2017v2_WPEff90"), # this is the name of the working point you want to use
           variable = cms.string("pt"),
        )
     )
  )

  # here we produce all the other working points for the training
  process.rerunDiscriminationByIsolationMVArun2v2VVLoose = process.rerunDiscriminationByIsolationMVArun2v2VLoose.clone()
  process.rerunDiscriminationByIsolationMVArun2v2VVLoose.mapping[0].cut = cms.string("RecoTauTag_tauIdMVAIsoDBoldDMwLT2017v2_WPEff95")
  process.rerunDiscriminationByIsolationMVArun2v2Loose = process.rerunDiscriminationByIsolationMVArun2v2VLoose.clone()
  process.rerunDiscriminationByIsolationMVArun2v2Loose.mapping[0].cut = cms.string("RecoTauTag_tauIdMVAIsoDBoldDMwLT2017v2_WPEff80")
  process.rerunDiscriminationByIsolationMVArun2v2Medium = process.rerunDiscriminationByIsolationMVArun2v2VLoose.clone()
  process.rerunDiscriminationByIsolationMVArun2v2Medium.mapping[0].cut = cms.string("RecoTauTag_tauIdMVAIsoDBoldDMwLT2017v2_WPEff70")
  process.rerunDiscriminationByIsolationMVArun2v2Tight = process.rerunDiscriminationByIsolationMVArun2v2VLoose.clone()
  process.rerunDiscriminationByIsolationMVArun2v2Tight.mapping[0].cut = cms.string("RecoTauTag_tauIdMVAIsoDBoldDMwLT2017v2_WPEff60")
  process.rerunDiscriminationByIsolationMVArun2v2VTight = process.rerunDiscriminationByIsolationMVArun2v2VLoose.clone()
  process.rerunDiscriminationByIsolationMVArun2v2VTight.mapping[0].cut = cms.string("RecoTauTag_tauIdMVAIsoDBoldDMwLT2017v2_WPEff50")
  process.rerunDiscriminationByIsolationMVArun2v2VVTight = process.rerunDiscriminationByIsolationMVArun2v2VLoose.clone()
  process.rerunDiscriminationByIsolationMVArun2v2VVTight.mapping[0].cut = cms.string("RecoTauTag_tauIdMVAIsoDBoldDMwLT2017v2_WPEff40")

  # this sequence has to be included in your cms.Path() before your analyzer which accesses the new variables is called.
  process.rerunMvaIsolation2SeqRun2_2 = cms.Sequence(
     process.rerunDiscriminationByIsolationMVArun2v2raw
     *process.rerunDiscriminationByIsolationMVArun2v2VLoose
     *process.rerunDiscriminationByIsolationMVArun2v2VVLoose
     *process.rerunDiscriminationByIsolationMVArun2v2Loose
     *process.rerunDiscriminationByIsolationMVArun2v2Medium
     *process.rerunDiscriminationByIsolationMVArun2v2Tight
     *process.rerunDiscriminationByIsolationMVArun2v2VTight
     *process.rerunDiscriminationByIsolationMVArun2v2VVTight
  )

  #========== MVA newDM
  process.rerunDiscriminationByIsolationMVArun2v2newDMraw = patDiscriminationByIsolationMVArun2v1raw.clone(
     PATTauProducer = cms.InputTag('slimmedTaus'),
     Prediscriminants = noPrediscriminants,
     loadMVAfromDB = cms.bool(True),
     mvaName = cms.string("RecoTauTag_tauIdMVAIsoDBnewDMwLT2017v2"),# training with 2017 MC_v1 for newDM # name of the training you want to use                                                                                                 
     mvaOpt = cms.string("DBnewDMwLTwGJ"), # option you want to use for your training (i.e., which variables are used to compute the BDT score)                                                                                                 
     requireDecayMode = cms.bool(True),
     verbosity = cms.int32(0)
  )


  process.rerunDiscriminationByIsolationMVArun2v2newDMVLoose = patDiscriminationByIsolationMVArun2v1VLoose.clone(
     PATTauProducer = cms.InputTag('slimmedTaus'),
     Prediscriminants = noPrediscriminants,
     toMultiplex = cms.InputTag('rerunDiscriminationByIsolationMVArun2v2newDMraw'),
     key = cms.InputTag('rerunDiscriminationByIsolationMVArun2v2newDMraw:category'),
     loadMVAfromDB = cms.bool(True),
     mvaOutput_normalization = cms.string("RecoTauTag_tauIdMVAIsoDBnewDMwLT_2017v2_dR0p5_mvaOutput_normalization"), # normalization fo the training you want to use                                                                             
     mapping = cms.VPSet(
        cms.PSet(
           category = cms.uint32(0),
           cut = cms.string("RecoTauTag_tauIdMVAIsoDBnewDMwLT2017v2_WPEff90"), # this is the name of the working point you want to use                                                                                                          
           variable = cms.string("pt"),
        )
     )
  )

  # here we produce all the other working points for the training                                                                                                                                                                               
  process.rerunDiscriminationByIsolationMVArun2v2newDMVVLoose = process.rerunDiscriminationByIsolationMVArun2v2newDMVLoose.clone()
  process.rerunDiscriminationByIsolationMVArun2v2newDMVVLoose.mapping[0].cut = cms.string("RecoTauTag_tauIdMVAIsoDBnewDMwLT2017v2_WPEff95")
  process.rerunDiscriminationByIsolationMVArun2v2newDMLoose = process.rerunDiscriminationByIsolationMVArun2v2newDMVLoose.clone()
  process.rerunDiscriminationByIsolationMVArun2v2newDMLoose.mapping[0].cut = cms.string("RecoTauTag_tauIdMVAIsoDBnewDMwLT2017v2_WPEff80")
  process.rerunDiscriminationByIsolationMVArun2v2newDMMedium = process.rerunDiscriminationByIsolationMVArun2v2newDMVLoose.clone()
  process.rerunDiscriminationByIsolationMVArun2v2newDMMedium.mapping[0].cut = cms.string("RecoTauTag_tauIdMVAIsoDBnewDMwLT2017v2_WPEff70")
  process.rerunDiscriminationByIsolationMVArun2v2newDMTight = process.rerunDiscriminationByIsolationMVArun2v2newDMVLoose.clone()
  process.rerunDiscriminationByIsolationMVArun2v2newDMTight.mapping[0].cut = cms.string("RecoTauTag_tauIdMVAIsoDBnewDMwLT2017v2_WPEff60")
  process.rerunDiscriminationByIsolationMVArun2v2newDMVTight = process.rerunDiscriminationByIsolationMVArun2v2newDMVLoose.clone()
  process.rerunDiscriminationByIsolationMVArun2v2newDMVTight.mapping[0].cut = cms.string("RecoTauTag_tauIdMVAIsoDBnewDMwLT2017v2_WPEff50")
  process.rerunDiscriminationByIsolationMVArun2v2newDMVVTight = process.rerunDiscriminationByIsolationMVArun2v2newDMVLoose.clone()
  process.rerunDiscriminationByIsolationMVArun2v2newDMVVTight.mapping[0].cut = cms.string("RecoTauTag_tauIdMVAIsoDBnewDMwLT2017v2_WPEff40")

  # this sequence has to be included in your cms.Path() before your analyzer which accesses the new variables is called.                                                                                                                        
  process.rerunMvaIsolation2SeqRun2_2_newDM = cms.Sequence(
     process.rerunDiscriminationByIsolationMVArun2v2newDMraw
     *process.rerunDiscriminationByIsolationMVArun2v2newDMVLoose
     *process.rerunDiscriminationByIsolationMVArun2v2newDMVVLoose
     *process.rerunDiscriminationByIsolationMVArun2v2newDMLoose
     *process.rerunDiscriminationByIsolationMVArun2v2newDMMedium
     *process.rerunDiscriminationByIsolationMVArun2v2newDMTight
     *process.rerunDiscriminationByIsolationMVArun2v2newDMVTight
     *process.rerunDiscriminationByIsolationMVArun2v2newDMVVTight
  )


  #========== MVA oldDM _dR0p3

  process.rerunDiscriminationByIsolationMVArun2v2dR0p3raw = patDiscriminationByIsolationMVArun2v1raw.clone(
     PATTauProducer = cms.InputTag('slimmedTaus'),
     Prediscriminants = noPrediscriminants,
     loadMVAfromDB = cms.bool(True),
     mvaName = cms.string("RecoTauTag_tauIdMVAIsoDBoldDMdR0p3wLT2017v2"),#RecoTauTag_tauIdMVAIsoDBoldDMdR0p3wLT2017v2 training with 2017 MC_v1 for oldDM # name of the training you want to use
     mvaOpt = cms.string("DBoldDMwLTwGJ"), # option you want to use for your training (i.e., which variables are used to compute the BDT score)
     requireDecayMode = cms.bool(True),
     verbosity = cms.int32(0)
  )


  process.rerunDiscriminationByIsolationMVArun2v2dR0p3VLoose = patDiscriminationByIsolationMVArun2v1VLoose.clone(
     PATTauProducer = cms.InputTag('slimmedTaus'),    
     Prediscriminants = noPrediscriminants,
     toMultiplex = cms.InputTag('rerunDiscriminationByIsolationMVArun2v2dR0p3raw'),
     key = cms.InputTag('rerunDiscriminationByIsolationMVArun2v2dR0p3raw:category'),
     loadMVAfromDB = cms.bool(True),
     mvaOutput_normalization = cms.string("RecoTauTag_tauIdMVAIsoDBoldDMwLT_2017v2_dR0p3_mvaOutput_normalization"), #RecoTauTag_tauIdMVAIsoDBoldDMwLT_2017v2_dR0p3_mvaOutput_normalization normalization fo the training you want to use
     mapping = cms.VPSet(
        cms.PSet(
           category = cms.uint32(0),
           cut = cms.string("RecoTauTag_tauIdMVAIsoDBoldDMdR0p3wLT2017v2_WPEff90"), # this is the name of the working point you want to use
           variable = cms.string("pt"),
        )
     )
  )

  # here we produce all the other working points for the training
  process.rerunDiscriminationByIsolationMVArun2v2dR0p3VVLoose = process.rerunDiscriminationByIsolationMVArun2v2dR0p3VLoose.clone()
  process.rerunDiscriminationByIsolationMVArun2v2dR0p3VVLoose.mapping[0].cut = cms.string("RecoTauTag_tauIdMVAIsoDBoldDMdR0p3wLT2017v2_WPEff95")
  process.rerunDiscriminationByIsolationMVArun2v2dR0p3Loose = process.rerunDiscriminationByIsolationMVArun2v2dR0p3VLoose.clone()
  process.rerunDiscriminationByIsolationMVArun2v2dR0p3Loose.mapping[0].cut = cms.string("RecoTauTag_tauIdMVAIsoDBoldDMdR0p3wLT2017v2_WPEff80")
  process.rerunDiscriminationByIsolationMVArun2v2dR0p3Medium = process.rerunDiscriminationByIsolationMVArun2v2dR0p3VLoose.clone()
  process.rerunDiscriminationByIsolationMVArun2v2dR0p3Medium.mapping[0].cut = cms.string("RecoTauTag_tauIdMVAIsoDBoldDMdR0p3wLT2017v2_WPEff70")
  process.rerunDiscriminationByIsolationMVArun2v2dR0p3Tight = process.rerunDiscriminationByIsolationMVArun2v2dR0p3VLoose.clone()
  process.rerunDiscriminationByIsolationMVArun2v2dR0p3Tight.mapping[0].cut = cms.string("RecoTauTag_tauIdMVAIsoDBoldDMdR0p3wLT2017v2_WPEff60")
  process.rerunDiscriminationByIsolationMVArun2v2dR0p3VTight = process.rerunDiscriminationByIsolationMVArun2v2dR0p3VLoose.clone()
  process.rerunDiscriminationByIsolationMVArun2v2dR0p3VTight.mapping[0].cut = cms.string("RecoTauTag_tauIdMVAIsoDBoldDMdR0p3wLT2017v2_WPEff50")
  process.rerunDiscriminationByIsolationMVArun2v2dR0p3VVTight = process.rerunDiscriminationByIsolationMVArun2v2dR0p3VLoose.clone()
  process.rerunDiscriminationByIsolationMVArun2v2dR0p3VVTight.mapping[0].cut = cms.string("RecoTauTag_tauIdMVAIsoDBoldDMdR0p3wLT2017v2_WPEff40")

  process.rerunMvaIsolation2SeqRun2_2_dR0p3 = cms.Sequence(
    process.rerunDiscriminationByIsolationMVArun2v2dR0p3raw
    *process.rerunDiscriminationByIsolationMVArun2v2dR0p3VLoose
    *process.rerunDiscriminationByIsolationMVArun2v2dR0p3VVLoose
    *process.rerunDiscriminationByIsolationMVArun2v2dR0p3Loose
    *process.rerunDiscriminationByIsolationMVArun2v2dR0p3Medium
    *process.rerunDiscriminationByIsolationMVArun2v2dR0p3Tight
    *process.rerunDiscriminationByIsolationMVArun2v2dR0p3VTight
    *process.rerunDiscriminationByIsolationMVArun2v2dR0p3VVTight
    )

  # this se






  # embed new id's into new tau collection
  embedID = cms.EDProducer("PATTauIDEmbedder",
     src = cms.InputTag('slimmedTaus'),
     tauIDSources = cms.PSet(
        byIsolationMVArun2v1DBoldDMwLTrawNew = cms.InputTag('rerunDiscriminationByIsolationMVArun2v1raw'),
        byVLooseIsolationMVArun2v1DBoldDMwLTNew = cms.InputTag('rerunDiscriminationByIsolationMVArun2v1VLoose'),
        byVVLooseIsolationMVArun2v1DBoldDMwLTNew = cms.InputTag('rerunDiscriminationByIsolationMVArun2v1VVLoose'),
        byLooseIsolationMVArun2v1DBoldDMwLTNew = cms.InputTag('rerunDiscriminationByIsolationMVArun2v1Loose'),
        byMediumIsolationMVArun2v1DBoldDMwLTNew = cms.InputTag('rerunDiscriminationByIsolationMVArun2v1Medium'),
        byTightIsolationMVArun2v1DBoldDMwLTNew = cms.InputTag('rerunDiscriminationByIsolationMVArun2v1Tight'),
        byVTightIsolationMVArun2v1DBoldDMwLTNew = cms.InputTag('rerunDiscriminationByIsolationMVArun2v1VTight'),
        byVVTightIsolationMVArun2v1DBoldDMwLTNew = cms.InputTag('rerunDiscriminationByIsolationMVArun2v1VVTight'),
        byIsolationMVArun2v2DBoldDMwLTrawNew = cms.InputTag('rerunDiscriminationByIsolationMVArun2v2raw'),
        byVLooseIsolationMVArun2v2DBoldDMwLTNew = cms.InputTag('rerunDiscriminationByIsolationMVArun2v2VLoose'),
        byVVLooseIsolationMVArun2v2DBoldDMwLTNew = cms.InputTag('rerunDiscriminationByIsolationMVArun2v2VVLoose'),
        byLooseIsolationMVArun2v2DBoldDMwLTNew = cms.InputTag('rerunDiscriminationByIsolationMVArun2v2Loose'),
        byMediumIsolationMVArun2v2DBoldDMwLTNew = cms.InputTag('rerunDiscriminationByIsolationMVArun2v2Medium'),
        byTightIsolationMVArun2v2DBoldDMwLTNew = cms.InputTag('rerunDiscriminationByIsolationMVArun2v2Tight'),
        byVTightIsolationMVArun2v2DBoldDMwLTNew = cms.InputTag('rerunDiscriminationByIsolationMVArun2v2VTight'),
        byVVTightIsolationMVArun2v2DBoldDMwLTNew = cms.InputTag('rerunDiscriminationByIsolationMVArun2v2VVTight'), 

        byIsolationMVArun2v2DBnewDMwLTrawNew = cms.InputTag('rerunDiscriminationByIsolationMVArun2v2newDMraw'),
        byVLooseIsolationMVArun2v2DBnewDMwLTNew = cms.InputTag('rerunDiscriminationByIsolationMVArun2v2newDMVLoose'),
        byVVLooseIsolationMVArun2v2DBnewDMwLTNew = cms.InputTag('rerunDiscriminationByIsolationMVArun2v2newDMVVLoose'),
        byLooseIsolationMVArun2v2DBnewDMwLTNew = cms.InputTag('rerunDiscriminationByIsolationMVArun2v2newDMLoose'),
        byMediumIsolationMVArun2v2DBnewDMwLTNew = cms.InputTag('rerunDiscriminationByIsolationMVArun2v2newDMMedium'),
        byTightIsolationMVArun2v2DBnewDMwLTNew = cms.InputTag('rerunDiscriminationByIsolationMVArun2v2newDMTight'),
        byVTightIsolationMVArun2v2DBnewDMwLTNew = cms.InputTag('rerunDiscriminationByIsolationMVArun2v2newDMVTight'),
        byVVTightIsolationMVArun2v2DBnewDMwLTNew = cms.InputTag('rerunDiscriminationByIsolationMVArun2v2newDMVVTight'),

        byIsolationMVArun2v2DBoldDMdR0p3wLTrawNew = cms.InputTag('rerunDiscriminationByIsolationMVArun2v2dR0p3raw'),
        byVLooseIsolationMVArun2v2DBoldDMdR0p3wLTNew = cms.InputTag('rerunDiscriminationByIsolationMVArun2v2dR0p3VLoose'),
        byVVLooseIsolationMVArun2v2DBoldDMdR0p3wLTNew = cms.InputTag('rerunDiscriminationByIsolationMVArun2v2dR0p3VVLoose'),
        byLooseIsolationMVArun2v2DBoldDMdR0p3wLTNew = cms.InputTag('rerunDiscriminationByIsolationMVArun2v2dR0p3Loose'),
        byMediumIsolationMVArun2v2DBoldDMdR0p3wLTNew = cms.InputTag('rerunDiscriminationByIsolationMVArun2v2dR0p3Medium'),
        byTightIsolationMVArun2v2DBoldDMdR0p3wLTNew = cms.InputTag('rerunDiscriminationByIsolationMVArun2v2dR0p3Tight'),
        byVTightIsolationMVArun2v2DBoldDMdR0p3wLTNew = cms.InputTag('rerunDiscriminationByIsolationMVArun2v2dR0p3VTight'),
        byVVTightIsolationMVArun2v2DBoldDMdR0p3wLTNew = cms.InputTag('rerunDiscriminationByIsolationMVArun2v2dR0p3VVTight'),
        ),
     )

  setattr(process, "NewTauIDsEmbedded", embedID)



####### Final path ##########
process.p = cms.Path()
process.p += process.egammaPostRecoSeq
if config["DOHLTFILTERS"]:
 process.p += process.HBHENoiseFilterResultProducer
 process.p += process.BadChargedCandidateSequence

# For new MVA ID !
process.p += process.rerunMvaIsolation2SeqRun2 
if config["DOMULTIPLETAUMVAVERSIONS"]:
  process.p += process.rerunMvaIsolation2SeqRun2_2
  process.p += process.rerunMvaIsolation2SeqRun2_2_dR0p3
  process.p += process.rerunMvaIsolation2SeqRun2_2_newDM

process.p += getattr(process, "NewTauIDsEmbedded")
#process.p += process.egmPhotonIDSequence
# For new MVA ID END!

process.p += process.ntuplizer
process.p.associate(pattask)

print pattask

#  LocalWords:  tauIdMVAIsoDBoldDMwLT
EOF

    cmsRun ${mass}_${width}/${i}.py
    xrdcp -p -f flatTuple_${mass}_${width}_${i}.root root://cmseos.fnal.gov//store/user/xuyan/new_s0_ntuples/flatTuple_spin-0_${mass}_${width}_${i}.root
done