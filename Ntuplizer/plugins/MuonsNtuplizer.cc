#include "../interface/MuonsNtuplizer.h"

#include <cmath>

//===================================================================================================================        
MuonsNtuplizer::MuonsNtuplizer( edm::EDGetTokenT<pat::MuonCollection>    muonToken   , 
                                edm::EDGetTokenT<reco::VertexCollection> verticeToken, 
				edm::EDGetTokenT<double>                 rhoToken    , 
				edm::EDGetTokenT<pat::TauCollection>     mutauToken  ,
				NtupleBranches* nBranches,
				std::map< std::string, bool >& runFlags  )
	: CandidateNtuplizer( nBranches    )
	, muonToken_	    ( muonToken    )
	, verticeToken_     ( verticeToken )
	, rhoToken_	    ( rhoToken     )
	, mutauToken_       ( mutauToken   )  
	, doMuonIdVars_    ( runFlags["doMuonIdVars"]  )
	, doMuonIsoVars_    ( runFlags["doMuonIsoVars"]  )
	, doBoostedTaus_    ( runFlags["doBoostedTaus"]  )
{
}

//===================================================================================================================
MuonsNtuplizer::~MuonsNtuplizer( void )
{

}

//===================================================================================================================
float MuonPFIso(pat::Muon muon, bool highpt){

  float sumChargedHadronPt = muon.pfIsolationR04().sumChargedHadronPt;
  float sumNeutralHadronEt = muon.pfIsolationR04().sumNeutralHadronEt;
  float sumPhotonEt = muon.pfIsolationR04().sumPhotonEt;
  float sumPUPt = muon.pfIsolationR04().sumPUPt;
  float iso = (sumChargedHadronPt + std::max( 0. ,sumNeutralHadronEt + sumPhotonEt - 0.5 * sumPUPt));// / muon.pt()
 
  return iso;
}




//===================================================================================================================
float MuonCorrPFIso(pat::Muon muon, bool highpt, edm::Handle<pat::TauCollection>  taus_){
  double TauSumChargedHadronPt = 0.;
  double TauSumNeutralHadronEt = 0.;
  double TauSumPhotonEt        = 0.;
  double dRmin = 0.4;
  pat::TauRef matchedTau;
  size_t numTaus = taus_->size();
  for(size_t tauIndex = 0; tauIndex < numTaus; ++tauIndex){
	pat::TauRef tau(taus_, tauIndex);
	double dR = reco::deltaR(muon.eta(), muon.phi(), tau->eta(), tau->phi());
	if ( dR < dRmin &&
		tau->pt()>20 && 
		fabs(tau->eta())<2.4 && 
		tau->tauID("decayModeFindingNewDMs")>0.5 && 
		tau->tauID("againstMuonLoose")>0.5 && 
		tau->tauID("againstElectronLoose")>0.5 && 
		tau->tauID("byVLooseIsolationMVA3newDMwoLT")>0.5) {
		  matchedTau = tau;
		  dRmin = dR;
	}
  }
  if(matchedTau.isNonnull()){
	for(size_t Ind1=0; Ind1<matchedTau->signalChargedHadrCands().size(); Ind1++){
	  double dRConst = reco::deltaR(muon.eta(), muon.phi(), matchedTau->signalChargedHadrCands()[Ind1]->eta(), matchedTau->signalChargedHadrCands()[Ind1]->phi());
	  if (dRConst <0.4)    	TauSumChargedHadronPt = TauSumChargedHadronPt + matchedTau->signalChargedHadrCands()[Ind1]->pt();
	}
	for(size_t Ind2=0; Ind2<matchedTau->signalNeutrHadrCands().size(); Ind2++){
	  double dRConst = reco::deltaR(muon.eta(), muon.phi(), matchedTau->signalNeutrHadrCands()[Ind2]->eta(), matchedTau->signalNeutrHadrCands()[Ind2]->phi()); 
	  if (dRConst <0.4)  	TauSumNeutralHadronEt = TauSumNeutralHadronEt + matchedTau->signalNeutrHadrCands()[Ind2]->pt();
	}
	for(size_t Ind3=0; Ind3<matchedTau->signalGammaCands().size(); Ind3++){
	  double dRConst = reco::deltaR(muon.eta(), muon.phi(), matchedTau->signalGammaCands()[Ind3]->eta(), matchedTau->signalGammaCands()[Ind3]->phi()); 
	  if (dRConst <0.4)  	TauSumPhotonEt = TauSumPhotonEt + matchedTau->signalGammaCands()[Ind3]->pt();
	}
  }
  float sumChargedHadronPt = std::max(0., muon.pfIsolationR04().sumChargedHadronPt-TauSumChargedHadronPt);
  float sumNeutralEt       = std::max(0., muon.pfIsolationR04().sumNeutralHadronEt-TauSumNeutralHadronEt+muon.pfIsolationR04().sumPhotonEt-TauSumPhotonEt);
  
  float sumPUPt            = muon.pfIsolationR04().sumPUPt;
  float iso = (sumChargedHadronPt+ std::max(0., sumNeutralEt - 0.5 * sumPUPt));
  return iso;
 
  
}
  
//===================================================================================================================
void MuonsNtuplizer::fillBranches( edm::Event const & event, const edm::EventSetup& iSetup ){
  // bool doTausBoosted = event.getByToken( tauInputToken_ , taus_ ); 

  event.getByToken(muonToken_	, muons_    ); 
  event.getByToken(verticeToken_, vertices_ ); 
  event.getByToken(rhoToken_	, rho_      );
  event.getByToken(mutauToken_   , taus_    );  


  // Find the first vertex in the collection that passes good quality criteria
  // reco::VertexCollection::const_iterator firstGoodVertex = vertices_->end();
   reco::VertexCollection::const_iterator firstGoodVertex = vertices_->begin();
  int firstGoodVertexIdx = 0;
  for( reco::VertexCollection::const_iterator vtx = vertices_->begin(); vtx != vertices_->end(); ++vtx, ++firstGoodVertexIdx){
    bool isFake = (vtx->chi2()==0 && vtx->ndof()==0);
    // Check the goodness
    if( !isFake && vtx->ndof()>=4. && vtx->position().Rho()<=2.0 && fabs(vtx->position().Z())<=24.0) {
      firstGoodVertex = vtx;
      break;
    } 
  }
   
  int nmus = 0;

  for (const pat::Muon &mu : *muons_) {
      
    nBranches_->mu_pdgId   	     	    .push_back(mu.pdgId() );
    nBranches_->mu_charge 	     	    .push_back(mu.charge());
    nBranches_->mu_e	   	     	    .push_back(mu.energy());
    nBranches_->mu_eta    	     	    .push_back(mu.eta()   );
    nBranches_->mu_mass   	     	    .push_back(mu.mass()  );
    nBranches_->mu_pt     	     	    .push_back(mu.pt()    );
    nBranches_->mu_phi    		    .push_back(mu.phi()   );

    /*========== IDs ==============*/    
    nBranches_->mu_isHighPtMuon.push_back(mu.isHighPtMuon(*firstGoodVertex));
    nBranches_->mu_isTightMuon .push_back(mu.isTightMuon(*firstGoodVertex));
  
    nBranches_->mu_isSoftMuon  .push_back(mu.isSoftMuon(*firstGoodVertex));
    nBranches_->mu_isLooseMuon .push_back(mu.isLooseMuon());
    nBranches_->mu_isPFMuon    .push_back(mu.isPFMuon());   

    double rho = *(rho_.product());     
    float deltaR = 0.3;
    double energy = TMath::Pi()*deltaR*deltaR*rho;
    if ( doMuonIdVars_ ) {
      float dxy = fabs(mu.muonBestTrack()->dxy( (*firstGoodVertex).position() ));
      nBranches_->mu_d0          .push_back(dxy);
      //nBranches_->mu_dz          .push_back(mu.muonBestTrack()->dz( (*firstGoodVertex).position() ));
      nBranches_->mu_bestTrack_pt.push_back(mu.muonBestTrack()->pt());  
      nBranches_->mu_bestTrack_ptErr.push_back(mu.muonBestTrack()->ptError());
      
          
  
      nBranches_->mu_isGlobalMuon.push_back(mu.isGlobalMuon());  
      
      double normChi2	   = -99;
      int    trackerHits     = -99;
      int    pixelHits	   = -99;
      int    globalMuonHits  = -99;
  
      if( mu.isGlobalMuon() ) 
        normChi2=mu.normChi2();
  
      if( !mu.track().isNull() )
        trackerHits = (mu.track())->hitPattern().trackerLayersWithMeasurement();
  
      if( !mu.innerTrack().isNull() )
        pixelHits = (mu.innerTrack())->hitPattern().numberOfValidPixelHits();
  
      if( !mu.globalTrack().isNull() )
        globalMuonHits = (mu.globalTrack())->hitPattern().numberOfValidMuonHits();
  
      nBranches_->mu_normChi2	   .push_back(normChi2);
      nBranches_->mu_trackerHits    .push_back(trackerHits);
      nBranches_->mu_matchedStations.push_back(mu.numberOfMatchedStations());
      nBranches_->mu_pixelHits	   .push_back(pixelHits);
      nBranches_->mu_globalHits     .push_back(globalMuonHits);
    }
        
    /*===== ISO ====*/
    deltaR = 0.3;
    energy = TMath::Pi()*deltaR*deltaR*rho;    
    if ( doMuonIsoVars_ ) {
      nBranches_->mu_pfRhoCorrRelIso03.push_back((mu.chargedHadronIso() + std::max(0., mu.neutralHadronIso() + mu.photonIso() - energy))/mu.pt());
      nBranches_->mu_pfRhoCorrRelIso03Boost.push_back((mu.userIsolation(pat::PfChargedHadronIso) + std::max(0., mu.userIsolation(pat::PfNeutralHadronIso) + mu.userIsolation(pat::PfGammaIso) - energy))/mu.pt());
      
      deltaR = 0.4;
      energy = TMath::Pi()*deltaR*deltaR*rho;    
      nBranches_->mu_pfRhoCorrRelIso04.push_back((mu.chargedHadronIso() + std::max(0., mu.neutralHadronIso() + mu.photonIso() - energy))/mu.pt());
      nBranches_->mu_pfRhoCorrRelIso04Boost.push_back((mu.userIsolation(pat::PfChargedHadronIso) + std::max(0., mu.userIsolation(pat::PfNeutralHadronIso) + mu.userIsolation(pat::PfGammaIso) - energy))/mu.pt());
      
      nBranches_->mu_pfDeltaCorrRelIso     .push_back((mu.chargedHadronIso() + std::max(0., mu.neutralHadronIso() + mu.photonIso() - 0.5*mu.puChargedHadronIso()))/mu.pt());
      nBranches_->mu_pfRelIso	          .push_back((mu.chargedHadronIso() + mu.neutralHadronIso()+ mu.photonIso())/mu.pt()) ; 
      nBranches_->mu_photonIso	          .push_back(mu.photonIso());
      nBranches_->mu_neutralHadIso         .push_back(mu.neutralHadronIso());
      nBranches_->mu_chargedHadIso         .push_back(mu.chargedHadronIso());
      nBranches_->mu_trackIso	          .push_back(mu.trackIso());
      nBranches_->mu_pfDeltaCorrRelIsoBoost.push_back((mu.userIsolation(pat::PfChargedHadronIso) + std::max(0., mu.userIsolation(pat::PfNeutralHadronIso) + mu.userIsolation(pat::PfGammaIso) - 0.5*mu.userIsolation(pat::PfPUChargedHadronIso)))/mu.pt());
      nBranches_->mu_pfRelIsoBoost	  .push_back((mu.userIsolation(pat::PfChargedHadronIso) + mu.userIsolation(pat::PfNeutralHadronIso)+ mu.userIsolation(pat::PfGammaIso))/mu.pt()) ; 
      nBranches_->mu_photonIsoBoost	  .push_back(mu.userIsolation(pat::PfGammaIso));
      nBranches_->mu_neutralHadIsoBoost    .push_back(mu.userIsolation(pat::PfNeutralHadronIso));
      nBranches_->mu_chargedHadIsoBoost    .push_back(mu.userIsolation(pat::PfChargedHadronIso));
      nBranches_->mu_SemileptonicPFIso	  .push_back(MuonPFIso(mu,true));  
      if (doBoostedTaus_)  nBranches_->mu_SemileptonicCorrPFIso .push_back(MuonCorrPFIso(mu,true, taus_));
    } 

    /*=======================*/

    ++nmus;



  } 

  nBranches_->mu_N =  nmus;
    
}
