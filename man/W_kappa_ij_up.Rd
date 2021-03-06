% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/RcppExports.R
\name{W_kappa_ij_up}
\alias{W_kappa_ij_up}
\title{Covariance of kernel computations}
\usage{
W_kappa_ij_up(W, design, theta, i1, i2, start, ct)
}
\arguments{
\item{W}{The matrix to store the computation in}

\item{design}{matrix of design points}

\item{theta}{lengthscales}

\item{i1, i2}{index of the derivatives (WARNING: starts at 0)}

\item{start}{The column/row index at which to start the computation (doesn't touch the start by start submatrix).}

\item{ct}{Covariance type, 1 means Gaussian, 2 means Matern 3/2, 3 means Matern 5/2}
}
\value{
W is modified in-place.
}
\description{
Computes Int(kappa_i(X, design) . kappa_j(design, X)). This function is preferred for updates
}
\keyword{internal}
