import FWCore.ParameterSet.Config as cms

config = dict()

#--------- general ----------#

#--------- Set Just one to true ----------#
config["RUNONMC"] = True
config["RUNONPromptReco"] = False
config["RUNONReReco"] = False
#-----------------------------------------#

config["USEJSON"] = not (config["RUNONMC"])
#config["JSONFILE"] = "JSON/Cert_294927-306462_13TeV_PromptReco_Collisions17_JSON.txt"
config["JSONFILE"] =  "JSON/Cert_294927-306462_13TeV_EOY2017ReReco_Collisions17_JSONv1.txt"
config["BUNCHSPACING"] = 25
config["USENOHF"] = False
config["FILTEREVENTS"] = False

#--------- basic sequences ----------#
config["DOGENPARTICLES"] = (True and config["RUNONMC"])
config["DOGENJETS"] = (True and config["RUNONMC"])
config["DOGENEVENT"] = (True and config["RUNONMC"])
config["DOPILEUP"] = (True and config["RUNONMC"])
config["DOPHOTONS"] = True
config["DOELECTRONS"] = False
config["DOMUONS"] = False
config["DOTAUS"] = False
config["DOAK8JETS"] = True
config["DOAK4JETS"] = True
config["DOVERTICES"] = True
config["DOTRIGGERDECISIONS"] = True
config["DOTRIGGEROBJECTS"] = False
config["DOHLTFILTERS"] = False
config["DOMISSINGET"] = False
config["DOTAUSBOOSTED"] = False
config["DOMETSVFIT"] = False
config["DOMVAMET"] = False

#--------- AK8 jets reclustering ----------#
config["ADDAK8GENJETS"] = (True and config["RUNONMC"]) #! Add AK8 gen jet collection with pruned and softdrop mass
config["DOAK8RECLUSTERING"] = False
config["DOAK8PRUNEDRECLUSTERING"] = False #! To add pruned jet and pruned subjet collection (not in MINIAOD)
config["DOAK8PUPPI"] = True # Only control the loop in Jet Tuplizer, need to be true
config["DOAK10TRIMMEDRECLUSTERING"] = False #ATLAS sequence
config["DOHBBTAG"] = False #Higgs-tagger
config["DOAK8PUPPIRECLUSTERING"] = True # No impact?
config["UpdateJetCollection"] = False #needed for Higgs-tagger in 80X

#--------- MET reclustering ----------#
config["DOMETRECLUSTERING"] = False

#--------- JEC ----------#
config["CORRJETSONTHEFLY"] = True # at the moment JEC available just for MC Fall17
config["CORRMETONTHEFLY"] = False  # at the moment JEC available just for MC Fall17
config["GETJECFROMDBFILE"] = False # If not yet in global tag, but db file available
#--------- TAU ----------#
config["DOMULTIPLETAUMVAVERSIONS"] = False #This flag eneables the possibility to access a sqlite *db file and save the latest training of the tau MVA isolation "v2" in parellel as the one of "v1" taken from the CMSSW database.
