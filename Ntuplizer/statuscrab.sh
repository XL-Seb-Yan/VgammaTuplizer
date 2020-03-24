#!/bin/bash


# crab status -d crab_jobs_2017B_photonJan10/crab_Wgamma94XSinglePhoton_Jan10_2017B
# crab status -d crab_jobs_2017C_photonJan10/crab_Wgamma94XSinglePhoton_Jan10_2017C
# crab status -d crab_jobs_2017D_photonJan10/crab_Wgamma94XSinglePhoton_Jan10_2017D
# crab status -d crab_jobs_2017E_photonJan10/crab_Wgamma94XSinglePhoton_Jan10_2017E
# crab status -d crab_jobs_2017F_photonJan10/crab_Wgamma94XSinglePhoton_Jan10_2017F

# crab resubmit -d crab_jobs_2017B_photonJan10/crab_Wgamma94XSinglePhoton_Jan10_2017B
# crab resubmit -d crab_jobs_2017C_photonJan10/crab_Wgamma94XSinglePhoton_Jan10_2017C
# crab resubmit -d crab_jobs_2017D_photonJan10/crab_Wgamma94XSinglePhoton_Jan10_2017D
# crab resubmit -d crab_jobs_2017E_photonJan10/crab_Wgamma94XSinglePhoton_Jan10_2017E
# crab resubmit -d crab_jobs_2017F_photonJan10/crab_Wgamma94XSinglePhoton_Jan10_2017F

# crab status -d crab_jobs_WgammaMC_2017_Jan10/crab_Wgamma949_GJets_HT-100To200_Jan10
# crab status -d crab_jobs_WgammaMC_2017_Jan10/crab_Wgamma949_GJets_HT-200To400_Jan10
# crab status -d crab_jobs_WgammaMC_2017_Jan10/crab_Wgamma949_GJets_HT-400To600_Jan10
# crab status -d crab_jobs_WgammaMC_2017_Jan10/crab_Wgamma949_GJets_HT-600ToInf_Jan10
# crab status -d crab_jobs_WgammaMC_2017_Jan10/crab_Wgamma949_QCD_HT300to500_Jan10
# crab status -d crab_jobs_WgammaMC_2017_Jan10/crab_Wgamma949_QCD_HT500to700_Jan10
#crab status -d crab_jobs_WgammaMC_2017_Jan10/crab_Wgamma949_QCD_HT700to1000_Jan10
# crab status -d crab_jobs_WgammaMC_2017_Jan10/crab_Wgamma949_QCD_HT1000to1500_Jan10
#crab status -d crab_jobs_WgammaMC_2017_Jan10/crab_Wgamma949_QCD_HT1500to2000_Jan10
# crab status -d crab_jobs_WgammaMC_2017_Jan10/crab_Wgamma949_QCD_HT2000toInf_Jan10

# crab resubmit -d crab_jobs_WgammaMC_2017_Jan10/crab_Wgamma949_GJets_HT-100To200_Jan10
# crab resubmit -d crab_jobs_WgammaMC_2017_Jan10/crab_Wgamma949_GJets_HT-200To400_Jan10
# crab resubmit -d crab_jobs_WgammaMC_2017_Jan10/crab_Wgamma949_GJets_HT-400To600_Jan10
# crab resubmit -d crab_jobs_WgammaMC_2017_Jan10/crab_Wgamma949_GJets_HT-600ToInf_Jan10
# crab resubmit -d crab_jobs_WgammaMC_2017_Jan10/crab_Wgamma949_QCD_HT300to500_Jan10
# crab resubmit -d crab_jobs_WgammaMC_2017_Jan10/crab_Wgamma949_QCD_HT500to700_Jan10
#crab resubmit -d crab_jobs_WgammaMC_2017_Jan10/crab_Wgamma949_QCD_HT700to1000_Jan10
# crab resubmit -d crab_jobs_WgammaMC_2017_Jan10/crab_Wgamma949_QCD_HT1000to1500_Jan10
#crab resubmit -d crab_jobs_WgammaMC_2017_Jan10/crab_Wgamma949_QCD_HT1500to2000_Jan10
# crab resubmit -d crab_jobs_WgammaMC_2017_Jan10/crab_Wgamma949_QCD_HT2000toInf_Jan10


for mass in {700,800,900,1000,1200,1400,1600,1800,2000,2200,2400,2600,2800,3000,3500}
do
    crab status -d /afs/cern.ch/work/x/xuyan/work5/PROD17/CMSSW_9_4_13/src/VgammaTuplizer/Ntuplizer/crab_jobs_signalMar1/crab_Wgamma949Signal17_${mass}_0p01Mar1
	crab resubmit -d /afs/cern.ch/work/x/xuyan/work5/PROD17/CMSSW_9_4_13/src/VgammaTuplizer/Ntuplizer/crab_jobs_signalMar1/crab_Wgamma949Signal17_${mass}_0p01Mar1
	crab status -d /afs/cern.ch/work/x/xuyan/work5/PROD17/CMSSW_9_4_13/src/VgammaTuplizer/Ntuplizer/crab_jobs_signalMar1/crab_Wgamma949Signal17_${mass}_5Mar1
	crab resubmit -d /afs/cern.ch/work/x/xuyan/work5/PROD17/CMSSW_9_4_13/src/VgammaTuplizer/Ntuplizer/crab_jobs_signalMar1/crab_Wgamma949Signal17_${mass}_5Mar1
done


