% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/misc.R
\name{subspace_dist}
\alias{subspace_dist}
\title{Get the distance between subspaces defined as the ranges of A and B}
\usage{
subspace_dist(A, B, r)
}
\arguments{
\item{A}{A matrix or const_C object.}

\item{B}{Another matrix with the same number of rows as A, or const_C object of the same dimension.}

\item{r}{A scalar integer, the dimension of the subspace to compare (only necessary if either A or B is a const_C object).}
}
\value{
A nonnegative scalar giving the cosine of the first principle angle between the two subspaces.
}
\description{
Get the distance between subspaces defined as the ranges of A and B
}
