#include "../interface/NtupleBranches.h"

//===================================================================================================================        
NtupleBranches::NtupleBranches( std::map< std::string, bool >& runFlags, TTree* tree )
   : tree_( tree )
{
   branch( runFlags );
}

//===================================================================================================================
NtupleBranches::~NtupleBranches( void )
{
}

//===================================================================================================================      
void NtupleBranches::branch( std::map< std::string, bool >& runFlags ){

  if ( runFlags["runOnMC"] ){
    if ( runFlags["doGenParticles"] ){
      /** genParticles */
      tree_->Branch( "genParticle_N"	                                         , &genParticle_N	       );
      tree_->Branch( "genParticle_pt"	                                         , &genParticle_pt	       ); 
      tree_->Branch( "genParticle_eta"	                                         , &genParticle_eta        ); 
      tree_->Branch( "genParticle_phi"	                                         , &genParticle_phi        ); 
      tree_->Branch( "genParticle_mass"	                                         , &genParticle_mass       ); 
      tree_->Branch( "genParticle_pdgId"                                         , &genParticle_pdgId      );
      tree_->Branch( "genParticle_status"                                        , &genParticle_status     );    
      tree_->Branch( "genParticle_mother"                                        , &genParticle_mother     );
      tree_->Branch( "genParticle_mother_pt"                                     , &genParticle_mother_pt  );
      tree_->Branch( "genParticle_mother_eta"                                    , &genParticle_mother_eta );
      tree_->Branch( "genParticle_mother_phi"                                    , &genParticle_mother_phi );
      tree_->Branch( "genParticle_mother_e"                                      , &genParticle_mother_e   );
      tree_->Branch( "genParticle_nMoth"                                         , &genParticle_nMoth      );
      tree_->Branch( "genParticle_nDau"	                                         , &genParticle_nDau       ); 
      tree_->Branch( "genParticle_dau"	                                         , &genParticle_dau        );
      tree_->Branch( "genParticle_dau_pt"	                                 , &genParticle_dau_pt     );
      tree_->Branch( "genParticle_dau_eta"	                                 , &genParticle_dau_eta    );
      tree_->Branch( "genParticle_dau_phi"	                                 , &genParticle_dau_phi    );
      tree_->Branch( "genParticle_dau_e"	                                 , &genParticle_dau_e      );


    } //doGenParticles
    
  }

  
  /*------------- ------EVENT infos-----------------------------*/
  tree_->Branch("EVENT_event"	 , &EVENT_event     );
  tree_->Branch("EVENT_run"	 , &EVENT_run	    );
  tree_->Branch("EVENT_lumiBlock", &EVENT_lumiBlock );
  
}

//=================================================================================================================== 
void NtupleBranches::reset( void ){

  /** genParticle */
  genParticle_N = 0;
  genParticle_pt.clear();
  genParticle_eta.clear();
  genParticle_phi.clear();
  genParticle_mass.clear();
  genParticle_pdgId.clear();
  genParticle_status.clear();
  genParticle_mother.clear();
  genParticle_mother_pt.clear();
  genParticle_mother_eta.clear();
  genParticle_mother_phi.clear();
  genParticle_mother_e.clear();
  genParticle_nMoth.clear();
  genParticle_nDau.clear();
  genParticle_dau.clear();
  genParticle_dau_pt.clear();
  genParticle_dau_eta.clear();
  genParticle_dau_phi.clear();
  genParticle_dau_e.clear();
  
 

  /*------------------------EVENT infos-------------------------*/    
  EVENT_event = 0;
  EVENT_run = 0;
  EVENT_lumiBlock = 0;

} 
