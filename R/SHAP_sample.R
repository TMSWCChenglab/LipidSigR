#' @title SHAP_sample
#' @description Visualize SHAP feature importance of N sample.
#' @param shap_long The output data frame of \code{\link{SHAP}} (list[[2]]).
#' @param n_sample A numeric value specifying N samples of each feature to be shown.
#' @return Return a list of 1 plot.
#' \enumerate{
#' \item SHAP_sample_plot: SHAP feature importance plot.
#' }
#' @export
#' @examples
#' data("ML_exp_data")
#' data("ML_lipid_char_table")
#' data("ML_condition_table")
#' exp_data <- ML_exp_data
#' lipid_char_table <- ML_lipid_char_table
#' condition_table <- ML_condition_table
#' char_var <- colnames(lipid_char_table)[-1]
#' ML_data <- ML_data_process(exp_data, group_info = condition_table,
#'                            lipid_char_table, char_var[1],
#'                            exclude_var_missing=TRUE, missing_pct_limit=50,
#'                            replace_zero=TRUE, zero2what='min', xmin=0.5,
#'                            replace_NA=TRUE, NA2what='min', ymin=0.5,
#'                            pct_transform=TRUE, data_transform=TRUE,
#'                            trans_type='log', centering=FALSE, scaling=FALSE)
#' ML_output <- ML_final(ML_data[[2]], ranking_method='Random_forest',
#'                       ML_method='Random_forest', split_prop=0.3, nfold=10)
#' SHAP_output <- SHAP(ML_data[[2]], best_model=ML_output[[8]],
#'                     best_model_feature=ML_output[[9]],
#'                     ML_method='Random_forest', feature_n=10, nsim=5)
#' SHAP_sample(SHAP_output[[2]], n_sample=10)
SHAP_sample <- function(shap_long,n_sample){

  if(!n_sample %in%unique(shap_long$ID)){
    stop("n_sample must be one of  shap_long 'ID'.")
  }
  feature_n <- length(unique(shap_long$variable))
  if(feature_n>10){topN <- 10}else{topN <- feature_n}

  SHAP_sample_plot <- shap_long %>% dplyr::filter(ID==n_sample) %>%
    dplyr::mutate(abs_value=abs(shapley_value)) %>%
    dplyr::arrange(dplyr::desc(abs_value)) %>% .[seq_len(topN),] %>%
    plotly::plot_ly(x=~shapley_value,y=~reorder(variable, shapley_value), orientation = "h",type = "bar",
            hoverinfo = "text",marker = list(color = ~-shapley_value,colorscale="Blues"),
            text =~paste("Variable :", variable,"<br>Shapley_value :",round(shapley_value,2)))%>%
    plotly::layout(title = stringr::str_c('Feature importance for Sample ',as.character(n_sample)),
           xaxis =list(title="Shapley value",nticks=40,showline=TRUE,mirror='all'),
           yaxis =list(title="",tickfont = list(size = 8),zeroline = FALSE,zerolinewidth = 0))

  return(SHAP_sample_plot)

}



