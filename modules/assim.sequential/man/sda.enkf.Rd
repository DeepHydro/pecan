% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/sda.enkf.R
\name{sda.enkf}
\alias{sda.enkf}
\title{sda.enkf}
\usage{
sda.enkf(settings, obs.mean, obs.cov, IC = NULL, Q = NULL,
  adjustment = TRUE, restart = NULL)
}
\arguments{
\item{settings}{PEcAn settings object}

\item{obs.mean}{list of observations of the means of state variable (time X nstate)}

\item{obs.cov}{list of observations of covariance matrices of state variables (time X nstate X nstate)}

\item{IC}{initial conditions}

\item{Q}{process covariance matrix given if there is no data to estimate it}

\item{adjustment}{flag for using ensemble adjustment filter or not}

\item{restart}{Used for iterative updating previous forecasts. This is a list that includes ens.inputs, the list of inputs by ensemble member, params, the parameters, and old_outdir, the output directory from the previous workflow. These three things are needed to ensure that if a new workflow is started that ensemble members keep there run-specific met and params. See Details}
}
\value{
NONE
}
\description{
State Variable Data Assimilation: Ensemble Kalman Filter
}
\author{
Michael Dietze and Ann Raiho \email{dietze@bu.edu}
}
