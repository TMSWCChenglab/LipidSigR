#' @title Hclustering
#' @description Hierarchical clustering of lipid species derived from two groups and  print two heatmaps.
#' @param exp_data A data frame includes the expression of lipid features in each sample. NAs are allowed. First column should be gene/lipid name and first column name must be 'feature'.
#' @param DE_result_table A data frame comprises the significant results of differential expression analysis, including fold change, p-value, adjusted p-value. The output of \code{\link{DE_species_2}}.
#' @param group_info A data frame comprises the name of the sample, the label of the sample, the group name of the sample, and the pair number represents 'the pair' for the t-test/Wilcoxon test. NAs are allowed.
#' @param lipid_char_table A data frame. NAs are allowed. The name of first column must be "feature".A data frame with lipid features, such as class, total length. NAs are allowed. The name of first column must be "feature".
#' @param char_var A character string of the first lipid characteristic selected by users from the column name of \bold{lipid_char_table}, such as total length.
#' @param distfun A character string of the distance measure indicating which correlation coefficient (or covariance) is to be computed. Allowed methods include \bold{"pearson"}, \bold{"kendall"}, and \bold{"spearman"}.(default: "pearson")
#' @param hclustfun A character string of the agglomeration method to be used. This should be (an unambiguous abbreviation of) one of \bold{"ward.D"}, \bold{"ward.D2"}, \bold{"single"}, \bold{"complete"}, \bold{"average"} (= UPGMA), \bold{"mcquitty"} (= WPGMA), \bold{"median"} (= WPGMC), or \bold{"centroid"} (= UPGMC). (default: "complete")
#' @param insert_ref_group A character string. The name of 'ctrl' after name conversion.
#' @param ref_group A character string. The name of 'exp' after name conversion.
#' @return Return a list with 2 figures and 2 matrices.
#' \enumerate{
#' \item all.lipid: a heatmap provides an overview of user-selected lipid characteristics that illustrates the differences between the control group and the experimental group.
#' \item sig.lipid: a heatmap provides significant, user-selected lipid characteristics that illustrate the differences between the control group and the experimental group.
#' \item all.lipid.data: the matrix of the heamap-\bold{all.lipid}
#' \item sig.lipid.data: the matrix of the heamap-\bold{sig.lipid}
#' }
#' @export
#' @examples
#' data("DE_exp_data")
#' data("DE_lipid_char_table")
#' data("DE_group_info")
#' exp_data <- DE_exp_data
#' lipid_char_table <- DE_lipid_char_table
#' group_info <- DE_group_info
#' exp_transform <- data_process(exp_data, exclude_var_missing=TRUE,
#'                               missing_pct_limit=50, replace_zero=TRUE,
#'                               zero2what='min', xmin=0.5, replace_NA=TRUE,
#'                               NA2what='min', ymin=0.5, pct_transform=TRUE,
#'                               data_transform=TRUE, trans_type='log',
#'                               centering=FALSE,  scaling=FALSE)
#' exp_transform_non_log <- data_process(exp_data, exclude_var_missing=TRUE,
#'                                       missing_pct_limit=50,
#'                                       replace_zero=TRUE,
#'                                       zero2what='min', xmin=0.5,
#'                                       replace_NA=TRUE, NA2what='min',
#'                                       ymin=0.5, pct_transform=TRUE,
#'                                       data_transform=FALSE, trans_type='log',
#'                                       centering=FALSE, scaling=FALSE)
#' lipid_char_filter <- lipid_char_table %>%
#'    filter(feature %in% exp_transform$feature)
#' DE_species_table_sig <- DE_species_2(exp_transform_non_log,
#'                                      data_transform = TRUE,
#'                                      group_info = group_info, paired = FALSE,
#'                                      test = 't.test',
#'                                      adjust_p_method = 'BH',
#'                                      sig_stat = 'p.adj',
#'                                      sig_pvalue = 0.05,
#'                                      sig_FC = 2)$DE_species_table_sig
#' char_var <- colnames(lipid_char_filter)[-1]
#' Hclustering(exp_transform, DE_result_table = DE_species_table_sig,
#'             group_info = group_info, lipid_char_table = lipid_char_filter,
#'             char_var = char_var[1], distfun = 'pearson',
#'             hclustfun = 'complete')
Hclustering <- function(exp_data, DE_result_table, group_info,
                        lipid_char_table = NULL, char_var = NULL,
                        distfun = 'pearson', hclustfun = 'complete',
                        insert_ref_group=NULL,ref_group=NULL){
  if(ncol(exp_data)==2){
    if(sum(class(exp_data[,-1])%in%c("numeric","integer"))!=1){
      stop("exp_data first column type must be 'character',others must be 'numeric'")
    }
  }else{
    if(sum(sapply(exp_data[,-1], class)%in%c("numeric","integer"))!=ncol(exp_data[,-1])){
      stop("exp_data first column type must be 'character',others must be 'numeric'")
    }
  }
  if(nrow(exp_data)!=length(unique(exp_data[,1]))){
    stop("exp_data lipids name (features) must be unique")
  }
  if(ncol(exp_data)<3){
    stop("exp_data at least 2 samples.")
  }else if(ncol(exp_data)==3){
    warning("exp_data only 2 samples will not show p-value,dotchart will color by log2FC")
  }
  if(nrow(exp_data)<2){
    stop("exp_data number of lipids names (features) must be more than 2.")
  }
  if(sum(!is.na(exp_data[,-1]))==0 | sum(!is.null(exp_data[,-1]))==0){
    stop("exp_data variables can not be all NULL/NA")
  }
  if(ncol(group_info)==4){
    if(sum(sapply(group_info[,seq_len(3)],class)!="character")==0){
      if("pair" %in% colnames(group_info)){
        if(which(colnames(group_info)=="pair")!=4){
          stop("group_info column must arrange in order of sample_name, label_name, group, pair(optional).")
        }
      }else{
        stop("group_info column must arrange in order of sample_name, label_name, group, pair(optional).")
      }
    }else{
      stop("group_info first 3 columns must be characters.")
    }
    if(sum(!is.na(group_info[,4]))!=0 | sum(table(group_info[,4])!=2)!=0 & sum(is.na(group_info[,4]))!=0){
      stop("group_info each pair must have a specific number, staring from 1 to N. Cannot have NA, blank, or skip numbers.")
    }
    if(sum(group_info[,1]%in%colnames(exp_data))!=nrow(group_info) | sum(group_info[,1]%in%colnames(exp_data))!=ncol(exp_data[,-1])){
      stop("group_info 'sample_name' must same as the name of samples of exp_data")
    }
    if(length(unique(group_info[,3]))==2){
      if(sum(table(group_info[,3])>=1)!=2){
        stop("group_info column 'group' only can have 2 groups, and >= 1 sample for each group.")
      }
    }else{
      stop("group_info column 'group' only can have 2 groups, and >= 1 sample for each group.")
    }
  }else if(ncol(group_info)==3){
    if("pair" %in% colnames(group_info)){
      stop("group_info column must arrange in order of sample_name, label_name, group, pair(optional).")
    }
    if(sum(sapply(group_info,class)!="character")!=0){
      stop("group_info first 3 columns must be characters.")
    }
    if(sum(group_info[,1]%in%colnames(exp_data))!=nrow(group_info) | sum(group_info[,1]%in%colnames(exp_data))!=ncol(exp_data[,-1])){
      stop("group_info 'sample_name' must same as the name of samples of exp_data")
    }
    if(length(unique(group_info[,3]))==2){
      if(sum(table(group_info[,3])>=1)!=2){
        stop("group_info column 'group' only can have 2 groups, and >= 1 sample for each group.")
      }
    }else{
      stop("group_info column 'group' only can have 2 groups, and >= 1 sample for each group.")
    }
    if(!is.null(insert_ref_group)){
      if(!insert_ref_group %in% group_info[,3]){
        stop("The insert_ref_group entered by users must be included in the group_info.")
      }
    }
  }
  if(!is.null(lipid_char_table)){
    if(nrow(lipid_char_table)==nrow(exp_data)){
      if(sum(lipid_char_table[,1]%in%exp_data[,1])!=nrow(lipid_char_table)){
        stop("The lipids names (features) of lipid_char_table table must same as exp_data.")
      }
    }else{
      stop("The row number of lipid_char_table table must same as exp_data.")
    }
    if(!is(lipid_char_table[,1], 'character')){
      stop("lipid_char_table first column must contain a list of lipids names (features).")
    }
    if(nrow(lipid_char_table)!=length(unique(lipid_char_table[,1]))){
      stop("lipid_char_table lipids names (features) must be unique.")
    }
    if("class" %in%colnames(lipid_char_table)){
      if(!is(lipid_char_table[,'class'], 'character')){
        stop("lipid_char_table content of column 'class' must be characters")
      }
    }
    if("totallength" %in%colnames(lipid_char_table)){
      if(!class(lipid_char_table[,'totallength'])%in%c("integer","numeric")){
        stop("lipid_char_table content of column 'totallength' must be numeric")
      }
    }
    if("totaldb" %in%colnames(lipid_char_table)){
      if(!class(lipid_char_table[,'totaldb'])%in%c("integer","numeric")){
        stop("lipid_char_table content of column 'totaldb' must be numeric")
      }
    }
    if("totaloh" %in%colnames(lipid_char_table)){
      if(!class(lipid_char_table[,'totaloh'])%in%c("integer","numeric")){
        stop("Thlipid_char_tablee content of column 'totaloh' must be numeric")
      }
    }

    if(ncol(dplyr::select(lipid_char_table,tidyselect::starts_with("FA_")))!=0){
      FA_lipid_char_table <- lipid_char_table %>% dplyr::select(feature,tidyselect::starts_with("FA_"))
      FA_col <- grep("FA_",colnames(FA_lipid_char_table),value = TRUE)
      max_comma <- 0
      for(i in seq_len(length(FA_col))){
        col <- FA_col[i]
        comma_count <- max(stringr::str_count(FA_lipid_char_table[,col], ','),na.rm = TRUE)
        if(comma_count>0){
          FA_lipid_char_table <- tidyr::separate(FA_lipid_char_table,col,c(col,paste0(col,"_",seq_len(comma_count))),",", convert = TRUE)
        }
        if(comma_count>max_comma){max_comma <- comma_count}
      }
      FA_lipid_char_table <- FA_lipid_char_table %>% tidyr::gather(lipid.category, lipid.category.value,-feature)
      if(max_comma>0){
        for (i in seq_len(max_comma)) {
          select_name <- paste0("_",i)
          FA_lipid_char_table <-FA_lipid_char_table[-intersect(grep(select_name,FA_lipid_char_table[,"lipid.category"]),which(is.na(FA_lipid_char_table$lipid.category.value))),]
        }
      }
      if(is(FA_lipid_char_table$lipid.category.value, 'character')){
        stop("In the 'FA_' related analyses, the values are positive integer or zero and separated by comma. i.e., 10,12,11")
      }else if(sum(stats::na.omit(as.numeric(FA_lipid_char_table$lipid.category.value))!=round(stats::na.omit(as.numeric(FA_lipid_char_table$lipid.category.value))))!=0 | min(stats::na.omit(as.numeric(FA_lipid_char_table$lipid.category.value)))<0){
        stop("In the 'FA_' related analyses, the values are positive integer or zero and separated by comma. i.e., 10,12,11")
      }
    }
  }

  colnames(exp_data)[1] <- 'feature'
  colnames(DE_result_table)[1] <- 'feature'

  rownames(exp_data) <- NULL
  exp.mat.all <- exp_data %>%
    dplyr::select(feature, group_info$sample_name) %>%
    tibble::column_to_rownames(var = 'feature') %>%
    as.matrix()
  colnames(exp.mat.all) <- group_info$label_name


  exp.mat.sig <- exp_data %>%
    dplyr::select(feature, group_info$sample_name) %>%
    dplyr::filter(feature %in% DE_result_table$feature) %>%
    tibble::column_to_rownames(var = 'feature') %>%
    as.matrix()
  colnames(exp.mat.sig) <- group_info$label_name

  if(!is.null(insert_ref_group) & !is.null(ref_group)){
    exp_raw_name <- ref_group[-which(insert_ref_group==ref_group)]
    group_info$group[which(group_info$group=='ctrl')] <-  insert_ref_group
    group_info$group[which(group_info$group=='exp')] <-  exp_raw_name
  }

  colGroup <- data.frame(Sample = group_info$group, stringsAsFactors = FALSE)

  if(!is.null(lipid_char_table) & !is.null(char_var)){

    rowGroup.all <- exp.mat.all %>%
      as.data.frame() %>%
      tibble::rownames_to_column(var = 'feature') %>%
      dplyr::select(feature) %>%
      dplyr::left_join(lipid_char_table, by = 'feature') %>%
      dplyr::select(tidyselect::all_of(char_var))

    rowGroup.sig <- exp.mat.sig %>%
      as.data.frame() %>%
      tibble::rownames_to_column(var = 'feature') %>%
      dplyr::select(feature) %>%
      dplyr::left_join(lipid_char_table, by = 'feature') %>%
      dplyr::select(tidyselect::all_of(char_var))

  }

  heatmap_color_scale <- function(data){
    data <- round(data,3)
    if(max(data)<=0 & min(data)<0){
      over_median <- min(data)/2
      if(max(data)<over_median){
        color <-  grDevices::colorRampPalette(c("#157AB5","#92c5de"))(n = 1000)
      }else{
        color_rank <- round(max(data)/(min(data))*1000)
        color_scale <- grDevices::colorRampPalette(c("#0571b0","#92c5de","white"))(n = 1000)
        color <- color_scale[color_rank:1000]
      }
    }else if(min(data)>=0 & max(data)>0){
      over_median <- max(data)/2
      if(min(data)>over_median){
        color <-  grDevices::colorRampPalette(c("#f4a582", "#ca0020"))(n = 1000)
      }else{
        color_rank <- round(min(data)/(max(data))*1000)
        color_scale <- grDevices::colorRampPalette(c("white","#f4a582", "#ca0020"))(n = 1000)
        color <- color_scale[color_rank:1000]
      }
    }
    return(color)
  }
  #### all exp ####
  if(nrow(exp.mat.all) >= 2 & ncol(exp.mat.all) >= 2 & sum(is.na(exp.mat.all))==0){

    if(max(nchar(rownames(exp.mat.all)))<10){
      all_row_text_size <- 0.1
    }else if(max(nchar(rownames(exp.mat.all)))>=10 & max(nchar(rownames(exp.mat.all)))<20){
      all_row_text_size <- 0.2
    }else if(max(nchar(rownames(exp.mat.all)))>=20 & max(nchar(rownames(exp.mat.all)))<30){
      all_row_text_size <- 0.3
    }else if(max(nchar(rownames(exp.mat.all)))>=30 & max(nchar(rownames(exp.mat.all)))<40){
      all_row_text_size <- 0.4
    }else {
      all_row_text_size <- 0.5
    }
    if(max(nchar(colnames(exp.mat.all)))<10){
      all_col_text_size <- 0.1
    }else if(max(nchar(colnames(exp.mat.all)))>=10 & max(nchar(colnames(exp.mat.all)))<20){
      all_col_text_size <- 0.2
    }else if(max(nchar(colnames(exp.mat.all)))>=20 & max(nchar(colnames(exp.mat.all)))<30){
      all_col_text_size <- 0.3
    }else if(max(nchar(colnames(exp.mat.all)))>=30 & max(nchar(colnames(exp.mat.all)))<40){
      all_col_text_size <- 0.4
    }else {
      all_col_text_size <- 0.5
    }

    if(!is.null(lipid_char_table) & !is.null(char_var)){
      exp.mat.all <- sweep(exp.mat.all, 1, rowMeans(exp.mat.all, na.rm = TRUE))
      exp.mat.all <- sweep(exp.mat.all, 1, apply(exp.mat.all, 1, sd, na.rm = TRUE), "/")
      if(sum(is.na(exp.mat.all))>0){
        exp.mat.all <- exp.mat.all[-which(is.na(exp.mat.all[,2])),]
      }
      cb_grid <- iheatmapr::setup_colorbar_grid(y_length =0.6,x_start = 1,y_start = 0.4)
      if(distfun %in% c("pearson","kendall","spearman")){
        col_dend <- stats::hclust(stats::as.dist(1-stats::cor(exp.mat.all, method=distfun)),method = hclustfun)
        row_dend <- stats::hclust(stats::as.dist(1-stats::cor(t(exp.mat.all), method=distfun)),method = hclustfun)
      }else{
        col_dend <- stats::hclust(stats::dist(t(exp.mat.all), method=distfun),method = hclustfun)
        row_dend <- stats::hclust(stats::dist(exp.mat.all, method=distfun),method = hclustfun)
      }
      if(min(exp.mat.all)>=0 || max(exp.mat.all)<=0){
        if(ncol(exp.mat.all)<=50){
          heatmap.all <- iheatmapr::iheatmap(exp.mat.all,colors = heatmap_color_scale(exp.mat.all),colorbar_grid = cb_grid,scale = "rows") %>%
            iheatmapr::add_col_labels(side="bottom",size=all_col_text_size) %>%
            iheatmapr::add_col_annotation(annotation = colGroup,side="top",show_colorbar = FALSE) %>%
            iheatmapr::add_col_dendro(col_dend,side="top",reorder =TRUE) %>%
            iheatmapr::add_row_annotation(annotation = rowGroup.all,side="right",show_colorbar = FALSE) %>%
            iheatmapr::add_row_dendro(row_dend,side="right",reorder =TRUE)
        }else{
          heatmap.all <- iheatmapr::iheatmap(exp.mat.all,colors = heatmap_color_scale(exp.mat.all),colorbar_grid = cb_grid,scale = "rows") %>%
            iheatmapr::add_col_annotation(annotation = colGroup,side="top",show_colorbar = FALSE) %>%
            iheatmapr::add_col_dendro(col_dend,side="top",reorder =TRUE) %>%
            iheatmapr::add_row_annotation(annotation = rowGroup.all,side="right",show_colorbar = FALSE) %>%
            iheatmapr::add_row_dendro(row_dend,side="right",reorder =TRUE)
        }
        if(nrow(exp.mat.all)<=50){ heatmap.all <- heatmap.all %>% iheatmapr::add_row_labels(side="left",size=all_row_text_size) }
      }else{
        if(ncol(exp.mat.all)<=50){
          heatmap.all <- iheatmapr::iheatmap(exp.mat.all,colorbar_grid = cb_grid,scale = "rows") %>%
            iheatmapr::add_col_labels(side="bottom",size=all_col_text_size) %>%
            iheatmapr::add_col_annotation(annotation = colGroup,side="top",show_colorbar = FALSE) %>%
            iheatmapr::add_col_dendro(col_dend,side="top",reorder =TRUE) %>%
            iheatmapr::add_row_annotation(annotation = rowGroup.all,side="right",show_colorbar = FALSE) %>%
            iheatmapr::add_row_dendro(row_dend,side="right",reorder =TRUE)
        }else{
          heatmap.all <- iheatmapr::iheatmap(exp.mat.all,colorbar_grid = cb_grid,scale = "rows") %>%
            iheatmapr::add_col_annotation(annotation = colGroup,side="top",show_colorbar = FALSE) %>%
            iheatmapr::add_col_dendro(col_dend,side="top",reorder =TRUE) %>%
            iheatmapr::add_row_annotation(annotation = rowGroup.all,side="right",show_colorbar = FALSE) %>%
            iheatmapr::add_row_dendro(row_dend,side="right",reorder =TRUE)
        }
        if(nrow(exp.mat.all)<=50){ heatmap.all <- heatmap.all %>% iheatmapr::add_row_labels(side="left",size=all_row_text_size) }
      }

      reorder.data.all<-exp.mat.all[rev(row_dend$order),col_dend$order]

    }else{

      exp.mat.all <- sweep(exp.mat.all, 1, rowMeans(exp.mat.all, na.rm = TRUE))
      exp.mat.all <- sweep(exp.mat.all, 1, apply(exp.mat.all, 1, sd, na.rm = TRUE), "/")
      if(sum(is.na(exp.mat.all))>0){
        exp.mat.all <- exp.mat.all[-which(is.na(exp.mat.all[,2])),]
      }
      cb_grid <- iheatmapr::setup_colorbar_grid(y_length =0.6,x_start = 1,y_start = 0.4)
      if(distfun %in% c("pearson","kendall","spearman")){
        col_dend <- stats::hclust(stats::as.dist(1-stats::cor(exp.mat.all, method=distfun)),method = hclustfun)
        row_dend <- stats::hclust(stats::as.dist(1-stats::cor(t(exp.mat.all), method=distfun)),method = hclustfun)
      }else{
        col_dend <- stats::hclust(stats::dist(t(exp.mat.all), method=distfun),method = hclustfun)
        row_dend <- stats::hclust(stats::dist(exp.mat.all, method=distfun),method = hclustfun)
      }
      if(min(exp.mat.all)>0 || max(exp.mat.all)<0){
        if(ncol(exp.mat.all)<=50){
          heatmap.all <- iheatmapr::iheatmap(exp.mat.all,colors = heatmap_color_scale(exp.mat.all),colorbar_grid = cb_grid,scale = "rows") %>%
            iheatmapr::add_col_labels(size=all_col_text_size) %>%
            iheatmapr::add_col_annotation(annotation = colGroup,show_colorbar = FALSE) %>%
            iheatmapr::add_col_dendro(col_dend,reorder =TRUE) %>%
            iheatmapr::add_row_dendro(row_dend,side="right",reorder =TRUE)
        }else{
          heatmap.all <- iheatmapr::iheatmap(exp.mat.all,colors = heatmap_color_scale(exp.mat.all),colorbar_grid = cb_grid,scale = "rows") %>%
            iheatmapr::add_col_annotation(annotation = colGroup,show_colorbar = FALSE) %>%
            iheatmapr::add_col_dendro(col_dend,reorder =TRUE) %>%
            iheatmapr::add_row_dendro(row_dend,side="right",reorder =TRUE)
        }
        if(nrow(exp.mat.all)<=50){ heatmap.all <- heatmap.all %>% iheatmapr::add_row_labels(side="left",size=all_row_text_size) }
      }else{
        if(ncol(exp.mat.all)<=50){
          heatmap.all <- iheatmapr::iheatmap(exp.mat.all,colorbar_grid = cb_grid,scale = "rows") %>%
            iheatmapr::add_col_labels(size=all_col_text_size) %>%
            iheatmapr::add_col_annotation(annotation = colGroup,show_colorbar = FALSE) %>%
            iheatmapr::add_col_dendro(col_dend,reorder =TRUE) %>%
            iheatmapr::add_row_dendro(row_dend,side="right",reorder =TRUE)
        }else{
          heatmap.all <- iheatmapr::iheatmap(exp.mat.all,colorbar_grid = cb_grid,scale = "rows") %>%
            iheatmapr::add_col_annotation(annotation = colGroup,show_colorbar = FALSE) %>%
            iheatmapr::add_col_dendro(col_dend,reorder =TRUE) %>%
            iheatmapr::add_row_dendro(row_dend,side="right",reorder =TRUE)
        }
        if(nrow(exp.mat.all)<=50){ heatmap.all <- heatmap.all %>% iheatmapr::add_row_labels(side="left",size=all_row_text_size) }
      }

      reorder.data.all<-exp.mat.all[rev(row_dend$order),col_dend$order]

    }

  }else{

    heatmap.all <- NULL
    reorder.data.all <- NULL
  }


  #### sig exp ####
  if(nrow(exp.mat.sig) >= 2 & ncol(exp.mat.sig) >= 2 & sum(is.na(exp.mat.all))==0){

    if(max(nchar(rownames(exp.mat.sig)))<10){
      sig_row_text_size <- 0.1
    }else if(max(nchar(rownames(exp.mat.sig)))>=10 & max(nchar(rownames(exp.mat.sig)))<20){
      sig_row_text_size <- 0.2
    }else if(max(nchar(rownames(exp.mat.sig)))>=20 & max(nchar(rownames(exp.mat.sig)))<30){
      sig_row_text_size <- 0.3
    }else if(max(nchar(rownames(exp.mat.sig)))>=30 & max(nchar(rownames(exp.mat.sig)))<40){
      sig_row_text_size <- 0.4
    }else {
      sig_row_text_size <- 0.5
    }
    if(max(nchar(colnames(exp.mat.sig)))<10){
      sig_col_text_size <- 0.1
    }else if(max(nchar(colnames(exp.mat.sig)))>=10 & max(nchar(colnames(exp.mat.sig)))<20){
      sig_col_text_size <- 0.2
    }else if(max(nchar(colnames(exp.mat.sig)))>=20 & max(nchar(colnames(exp.mat.sig)))<30){
      sig_col_text_size <- 0.3
    }else if(max(nchar(colnames(exp.mat.sig)))>=30 & max(nchar(colnames(exp.mat.sig)))<40){
      sig_col_text_size <- 0.4
    }else {
      sig_col_text_size <- 0.5
    }

    if(!is.null(lipid_char_table) & !is.null(char_var)){
      exp.mat.sig <- sweep(exp.mat.sig, 1, rowMeans(exp.mat.sig, na.rm = TRUE))
      exp.mat.sig <- sweep(exp.mat.sig, 1, apply(exp.mat.sig, 1, sd, na.rm = TRUE), "/")
      cb_grid <- iheatmapr::setup_colorbar_grid(y_length =0.6,x_start = 1,y_start = 0.4)
      if(distfun %in% c("pearson","kendall","spearman")){
        col_dend <- stats::hclust(stats::as.dist(1-stats::cor(exp.mat.sig, method=distfun)),method = hclustfun)
        row_dend <- stats::hclust(stats::as.dist(1-stats::cor(t(exp.mat.sig), method=distfun)),method = hclustfun)
      }else{
        col_dend <- stats::hclust(stats::dist(t(exp.mat.sig), method=distfun),method = hclustfun)
        row_dend <- stats::hclust(stats::dist(exp.mat.sig, method=distfun),method = hclustfun)
      }
      if(min(exp.mat.sig)>0 || max(exp.mat.sig)<0){
        if(ncol(exp.mat.sig)<=50){
          heatmap.sig <- iheatmapr::iheatmap(exp.mat.sig,colors = heatmap_color_scale(exp.mat.sig),colorbar_grid = cb_grid,scale = "rows") %>%
            iheatmapr::add_col_labels(size= sig_col_text_size) %>%
            iheatmapr::add_col_annotation(annotation = colGroup,show_colorbar = FALSE) %>%
            iheatmapr::add_col_dendro(col_dend,reorder =TRUE) %>%
            iheatmapr::add_row_annotation(annotation = rowGroup.sig,show_colorbar = FALSE) %>%
            iheatmapr::add_row_dendro(row_dend,side="right",reorder =TRUE)
        }else{
          heatmap.sig <- iheatmapr::iheatmap(exp.mat.sig,colors = heatmap_color_scale(exp.mat.sig),colorbar_grid = cb_grid,scale = "rows") %>%
            iheatmapr::add_col_annotation(annotation = colGroup,show_colorbar = FALSE) %>%
            iheatmapr::add_col_dendro(col_dend,reorder =TRUE) %>%
            iheatmapr::add_row_annotation(annotation = rowGroup.sig,show_colorbar = FALSE) %>%
            iheatmapr::add_row_dendro(row_dend,side="right",reorder =TRUE)
        }
        if(nrow(exp.mat.sig)<=50){ heatmap.sig <- heatmap.sig %>% iheatmapr::add_row_labels(side="left",size=sig_row_text_size) }
      }else{
        if(ncol(exp.mat.sig)<=50){
          heatmap.sig <- iheatmapr::iheatmap(exp.mat.sig,colorbar_grid = cb_grid,scale = "rows") %>%
            iheatmapr::add_col_labels(size=sig_col_text_size) %>%
            iheatmapr::add_col_annotation(annotation = colGroup,show_colorbar = FALSE) %>%
            iheatmapr::add_col_dendro(col_dend,reorder =TRUE) %>%
            iheatmapr::add_row_annotation(annotation = rowGroup.sig,show_colorbar = FALSE) %>%
            iheatmapr::add_row_dendro(row_dend,side="right",reorder =TRUE)
        }else{
          heatmap.sig <- iheatmapr::iheatmap(exp.mat.sig,colorbar_grid = cb_grid,scale = "rows") %>%
            iheatmapr::add_col_annotation(annotation = colGroup,show_colorbar = FALSE) %>%
            iheatmapr::add_col_dendro(col_dend,reorder =TRUE) %>%
            iheatmapr::add_row_annotation(annotation = rowGroup.sig,show_colorbar = FALSE) %>%
            iheatmapr::add_row_dendro(row_dend,side="right",reorder =TRUE)
        }
        if(nrow(exp.mat.sig)<=50){ heatmap.sig <- heatmap.sig %>% iheatmapr::add_row_labels(side="left",size=sig_row_text_size) }
      }
      reorder.data.sig<-exp.mat.sig[rev(row_dend$order),col_dend$order]

    }else{

      exp.mat.sig <- sweep(exp.mat.sig, 1, rowMeans(exp.mat.sig, na.rm = TRUE))
      exp.mat.sig <- sweep(exp.mat.sig, 1, apply(exp.mat.sig, 1, sd, na.rm = TRUE), "/")
      cb_grid <- iheatmapr::setup_colorbar_grid(y_length =0.6,x_start = 1,y_start = 0.4)
      if(distfun %in% c("pearson","kendall","spearman")){
        col_dend <- stats::hclust(stats::as.dist(1-stats::cor(exp.mat.sig, method=distfun)),method = hclustfun)
        row_dend <- stats::hclust(stats::as.dist(1-stats::cor(t(exp.mat.sig), method=distfun)),method = hclustfun)
      }else{
        col_dend <- stats::hclust(stats::dist(t(exp.mat.sig), method=distfun),method = hclustfun)
        row_dend <- stats::hclust(stats::dist(exp.mat.sig, method=distfun),method = hclustfun)
      }

      if(min(exp.mat.sig)>0 || max(exp.mat.sig)<0){
        if(ncol(exp.mat.sig)<=50){
          heatmap.sig <- iheatmapr::iheatmap(exp.mat.sig,colors = heatmap_color_scale(exp.mat.sig),colorbar_grid = cb_grid,scale = "rows") %>%
            iheatmapr::add_col_labels(size=sig_col_text_size) %>%
            iheatmapr::add_col_annotation(annotation = colGroup,show_colorbar = FALSE) %>%
            iheatmapr::add_col_dendro(col_dend,reorder =TRUE) %>%
            iheatmapr::add_row_dendro(row_dend,side="right",reorder =TRUE)
        }else{
          heatmap.sig <- iheatmapr::iheatmap(exp.mat.sig,colors = heatmap_color_scale(exp.mat.sig),colorbar_grid = cb_grid,scale = "rows") %>%
            iheatmapr::add_col_annotation(annotation = colGroup,show_colorbar = FALSE) %>%
            iheatmapr::add_col_dendro(col_dend,reorder =TRUE) %>%
            iheatmapr::add_row_dendro(row_dend,side="right",reorder =TRUE)
        }
        if(nrow(exp.mat.sig)<=50){ heatmap.sig <- heatmap.sig %>% iheatmapr::add_row_labels(side="left",size=sig_row_text_size) }
      }else{
        if(ncol(exp.mat.sig)<=50){
          heatmap.sig <- iheatmapr::iheatmap(exp.mat.sig,colorbar_grid = cb_grid,scale = "rows") %>%
            iheatmapr::add_col_labels(size=sig_col_text_size) %>%
            iheatmapr::add_col_annotation(annotation = colGroup,show_colorbar = FALSE) %>%
            iheatmapr::add_col_dendro(col_dend,reorder =TRUE) %>%
            iheatmapr::add_row_dendro(row_dend,side="right",reorder =TRUE)
        }else{
          heatmap.sig <- iheatmapr::iheatmap(exp.mat.sig,colorbar_grid = cb_grid,scale = "rows") %>%
            iheatmapr::add_col_annotation(annotation = colGroup,show_colorbar = FALSE) %>%
            iheatmapr::add_col_dendro(col_dend,reorder =TRUE) %>%
            iheatmapr::add_row_dendro(row_dend,side="right",reorder =TRUE)
        }
        if(nrow(exp.mat.sig)<=50){ heatmap.sig <- heatmap.sig %>% iheatmapr::add_row_labels(side="left",size=sig_row_text_size) }
      }
      reorder.data.sig<-exp.mat.sig[rev(row_dend$order),col_dend$order]

    }

  }else{

    heatmap.sig <- NULL
    reorder.data.sig <- NULL
  }

  return(list(all.lipid = heatmap.all, sig.lipid = heatmap.sig,
              all.lipid.data = reorder.data.all, sig.lipid.data = reorder.data.sig))

} #function
