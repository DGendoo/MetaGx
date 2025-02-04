getVerhaakSubtypes <- function(eset) {
  ## Load gene sets from the original publication
  # Load Verhaak et al. supplementary from the package inst directory
	#supplementary.data <- read.xls(system.file(file.path("extdata", "JCI65833sd1.xls"), package="MetaGx"), sheet=7, skip=1)
  # Use this instead when running this method from source
	supplementary.data.sheet7 <- gdata::read.xls(system.file("extdata", "JCI65833sd1.xls", package="MetaGx"), sheet=7, skip=1)
	supplementary.data.sheet1 <- gdata::read.xls(system.file("extdata", "JCI65833sd1.xls", package="MetaGx"), skip=1)
  
	genesets <- lapply(levels(supplementary.data.sheet7$CLASS), function(y) {
	  return (as.character(supplementary.data.sheet7[supplementary.data.sheet7$CLASS==y,1]))
	})
	names(genesets) <-  levels(supplementary.data.sheet7$CLASS)
	
	# For ssGSEA scores for the new samples, use the intersecting genes
	genesets <- lapply(genesets, function(x) {
    return (intersect(x, as.character(fData(eset)$gene)))
    })
    
  ## check if some genesets are missing
  if (any(sapply(genesets, length) == 0)) {
    gsva.out <- matrix(NA, nrow=ncol(exprs(eset)), ncol=length(levels(supplementary.data.sheet7$CLASS)), dimnames=list(colnames(exprs(eset)), levels(supplementary.data.sheet7$CLASS)))
    subclasses <- array(NA, dim=ncol(exprs(eset)), dimnames=list(colnames(exprs(eset))))
    eset$Verhaak.subtypes <- subclasses
  } else {
    ## Determine the ssGSEA cutoffs for the IMR and MES subtypes
  	supplementary.tcga.discovery <- supplementary.data.sheet1[ supplementary.data.sheet1$DATASET=="TCGA-discovery", 
                                                               c("ID", "SUBTYPE") ]
  	supplementary.tcga.discovery <- supplementary.tcga.discovery[ supplementary.tcga.discovery$SUBTYPE %in% c("Mesenchymal", "Immunoreactive"), ]
	
    #tcga.gsva.out.with.published.subtype <- merge(tcga.gsva.out, supplementary.tcga.discovery, by="ID")
    IMR.threshold <- 0.63 #min(tcga.gsva.out.with.published.subtype$IMR[ tcga.gsva.out.with.published.subtype$SUBTYPE=="Immunoreactive" ])
    MES.threshold <- 0.56 #min(tcga.gsva.out.with.published.subtype$MES[ tcga.gsva.out.with.published.subtype$SUBTYPE=="Mesenchymal" ])
 
  	expression.matrix <- exprs(eset)
    rownames(expression.matrix) <- as.character(fData(eset)$gene)
  
    ## Get ssGSEA subtype scores
  	gsva.out <- GSVA::gsva(expression.matrix, genesets, method="ssgsea", tau=0.75, parallel.sz=4, mx.diff=FALSE, ssgsea.norm=FALSE)
    gsva.out <- t(gsva.out)
  
    gsva.out <- apply(gsva.out, 2, function(x) ( x - min(x) ) / ( max(x) - min(x) ))
  
    ## Classify each sample according to the max ssGSEA subtype score, using the scheme provided in the methods.
  
    subclasses <- apply(gsva.out, 1, function(x) {
      if(x[which(colnames(gsva.out)=="IMR")] > IMR.threshold && x[which(colnames(gsva.out)=="MES")] > MES.threshold) {
        return(c("IMR", "MES")[which.max(x[c("IMR", "MES")])])
      } else {
        return (colnames(gsva.out)[which.max(x)])
      }
      })
  
    subclasses <- factor(subclasses, levels=levels(supplementary.data.sheet7$CLASS))
    ## Append a new column for Verhaak subtypes
    eset$Verhaak.subtypes <- subclasses
  }
  
    return(list(Annotated.eset=eset, gsva.out=gsva.out))
}
