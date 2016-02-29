#include "../interface/GenEventNtuplizer.h"

//===================================================================================================================
GenEventNtuplizer::GenEventNtuplizer( std::vector< edm::EDGetTokenT< GenEventInfoProduct > > tokens,
                                     std::vector< edm::EDGetTokenT< LHEEventProduct > > tokens2,
                                     bool doPDF,
                                     NtupleBranches* nBranches )
: CandidateNtuplizer( nBranches )
, geneventToken_( tokens[0] )
, lheeventToken_( tokens2[0] )
, doPDF_(doPDF)
{
    
}

//===================================================================================================================
GenEventNtuplizer::~GenEventNtuplizer( void )
{
    
}

//===================================================================================================================
void GenEventNtuplizer::fillBranches( edm::Event const & event, const edm::EventSetup& iSetup ){
    
    event.getByToken(geneventToken_, geneventInfo_);
    
    if (doPDF_) {
        event.getByToken(lheeventToken_, lheeventInfo_);
        nBranches_->originalXWGTUP=lheeventInfo_->originalXWGTUP();
        for(unsigned int k=0; k<lheeventInfo_->weights().size(); k++){
            nBranches_->sys_weights.push_back(lheeventInfo_->weights().at(k).wgt);
        }
    }
    
    nBranches_->genWeight=geneventInfo_->weight();
    nBranches_->qScale=geneventInfo_->qScale();
    nBranches_->pdf_scalePDF=geneventInfo_->pdf()->scalePDF;
    nBranches_->PDF_x.push_back((geneventInfo_->pdf()->x).first);
    nBranches_->PDF_x.push_back((geneventInfo_->pdf()->x).second);
    nBranches_->PDF_xPDF.push_back((geneventInfo_->pdf()->xPDF).first);
    nBranches_->PDF_xPDF.push_back((geneventInfo_->pdf()->xPDF).second);
    nBranches_->PDF_id.push_back((geneventInfo_->pdf()->id).first);
    nBranches_->PDF_id.push_back((geneventInfo_->pdf()->id).second);
    
}
