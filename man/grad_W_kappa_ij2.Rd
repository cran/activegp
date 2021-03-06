% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/RcppExports.R
\name{grad_W_kappa_ij2}
\alias{grad_W_kappa_ij2}
\title{Covariance of kernel computations}
\usage{
grad_W_kappa_ij2(design1, design2, theta, i1, i2, ct)
}
\arguments{
\item{design1}{A vector representing a new point.}

\item{design2}{matrices of design points}

\item{theta}{lengthscales}

\item{i1, i2}{index of the derivatives (WARNING: starts at 0)}

\item{ct}{Covariance type, 1 means Gaussian, 2 means Matern 3/2, 3 means Matern 5/2}
}
\value{
matrix of size nrow(design1) x nrow(design2)
}
\description{
Computes gradient of Int(kappa_i(X, design1) . kappa_j(design2, X)) with respect to the first argument.
}
\keyword{internal}
