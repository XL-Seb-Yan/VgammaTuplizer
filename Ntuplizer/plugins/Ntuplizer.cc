#include "../interface/Ntuplizer.h"
#include "../interface/CandidateNtuplizer.h"
#include "../interface/GenParticlesNtuplizer.h"
#include "DataFormats/PatCandidates/interface/TriggerObjectStandAlone.h"
#include "DataFormats/PatCandidates/interface/PackedTriggerPrescales.h"

#include "FWCore/ParameterSet/interface/FileInPath.h"

// #include "DataFormats/METReco/interface/PFMET.h"


///////////////////////////////////////////////////////////////////////////////////
Ntuplizer::Ntuplizer(const edm::ParameterSet& iConfig):
	    
	genparticleToken_     	    (consumes<reco::GenParticleCollection>(iConfig.getParameter<edm::InputTag>("genparticles")))

{
  /*=======================================================================================*/
  edm::Service<TFileService> fs;
  TTree* tree = fs->make<TTree>( "tree", "tree" );
  
  std::map< std::string, bool > runFlags;
  runFlags["runOnMC"] = iConfig.getParameter<bool>("runOnMC");
  runFlags["doGenParticles"] = iConfig.getParameter<bool>("doGenParticles");
 
  nBranches_ = new NtupleBranches( runFlags, tree );
  
  /*=======================================================================================*/
 
  /*=======================================================================================*/    
  if ( runFlags["runOnMC"] ){

    if (runFlags["doGenParticles"]) {
      std::vector<edm::EDGetTokenT<reco::GenParticleCollection>> genpTokens;
      genpTokens.push_back( genparticleToken_ );

      nTuplizers_["genParticles"] = new GenParticlesNtuplizer( genpTokens, nBranches_ );
    }
  }
}

///////////////////////////////////////////////////////////////////////////////////
Ntuplizer::~Ntuplizer()
{
	  
   for( std::map<std::string,CandidateNtuplizer*>::iterator it = nTuplizers_.begin(); it != nTuplizers_.end(); ++it )
      delete it->second;
   
   nTuplizers_.clear();
   
   delete nBranches_;
   
}

///////////////////////////////////////////////////////////////////////////////////
void Ntuplizer::analyze(const edm::Event& iEvent, const edm::EventSetup& iSetup){
  
  nBranches_->reset();
  
  nBranches_->EVENT_event     = iEvent.id().event();
  nBranches_->EVENT_run       = iEvent.id().run();
  nBranches_->EVENT_lumiBlock = iEvent.id().luminosityBlock();  
         
  for( std::map<std::string,CandidateNtuplizer*>::iterator it = nTuplizers_.begin(); it != nTuplizers_.end(); ++it )
    (it->second)->fillBranches( iEvent, iSetup );
  
  nBranches_->fillTree();
  
  nBranches_->reset();    
  
}


///////////////////////////////////////////////////////////////////////////////////
void Ntuplizer::beginJob(){
}

///////////////////////////////////////////////////////////////////////////////////
void Ntuplizer::endJob() {
}

///////////////////////////////////////////////////////////////////////////////////
void Ntuplizer::beginRun(edm::Run const&, edm::EventSetup const&){
}


///////////////////////////////////////////////////////////////////////////////////
void Ntuplizer::endRun(edm::Run const&, edm::EventSetup const&){
}

///////////////////////////////////////////////////////////////////////////////////
void Ntuplizer::beginLuminosityBlock(edm::LuminosityBlock const&, edm::EventSetup const&){
}


///////////////////////////////////////////////////////////////////////////////////
void Ntuplizer::endLuminosityBlock(edm::LuminosityBlock const&, edm::EventSetup const&){
}


///////////////////////////////////////////////////////////////////////////////////
void Ntuplizer::fillDescriptions(edm::ConfigurationDescriptions& descriptions) {
  //The following says we do not know what parameters are allowed so do no validation
  // Please change this to state exactly what you do use, even if it is no parameters
  edm::ParameterSetDescription desc;
  desc.setUnknown();
  descriptions.addDefault(desc);
}

//define this as a plug-in
DEFINE_FWK_MODULE(Ntuplizer);
