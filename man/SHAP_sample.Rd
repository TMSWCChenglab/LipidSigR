% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/SHAP_sample.R
\name{SHAP_sample}
\alias{SHAP_sample}
\title{SHAP_sample}
\usage{
SHAP_sample(shap_long, n_sample)
}
\arguments{
\item{shap_long}{The output data frame of \code{\link{SHAP}} (list[[2]]).}

\item{n_sample}{A numeric value specifying N samples of each feature to be shown.}
}
\value{
Return a list of 1 plot.
\enumerate{
\item SHAP_sample_plot: SHAP feature importance plot.
}
}
\description{
Visualize SHAP feature importance of N sample.
}
\examples{
data("ML_exp_data")
data("ML_lipid_char_table")
data("ML_condition_table")
exp_data <- ML_exp_data
lipid_char_table <- ML_lipid_char_table
condition_table <- ML_condition_table
char_var <- colnames(lipid_char_table)[-1]
ML_data <- ML_data_process(exp_data, group_info = condition_table,
                           lipid_char_table, char_var[1],
                           exclude_var_missing=TRUE, missing_pct_limit=50,
                           replace_zero=TRUE, zero2what='min', xmin=0.5,
                           replace_NA=TRUE, NA2what='min', ymin=0.5,
                           pct_transform=TRUE, data_transform=TRUE,
                           trans_type='log', centering=FALSE, scaling=FALSE)
ML_output <- ML_final(ML_data[[2]], ranking_method='Random_forest',
                      ML_method='Random_forest', split_prop=0.3, nfold=10)
SHAP_output <- SHAP(ML_data[[2]], best_model=ML_output[[8]],
                    best_model_feature=ML_output[[9]],
                    ML_method='Random_forest', feature_n=10, nsim=5)
SHAP_sample(SHAP_output[[2]], n_sample=10)
}
