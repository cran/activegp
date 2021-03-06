% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/activeC.R
\name{C_Q}
\alias{C_Q}
\title{Active subspace for second order linear model}
\usage{
C_Q(design, response)
}
\arguments{
\item{design}{A matrix of design points, one in each row, in [-1,1]^d}

\item{response}{A vector of observations at each design point.}
}
\value{
A matrix corresponding to the active subspace C matrix.
}
\description{
Active subspace for second order linear model
}
\examples{
set.seed(42) 
A <- matrix(c(1, -1, 0, -1, 2, -1.5, 0, -1.5, 4), nrow = 3, byrow = TRUE)
b <- c(1, 4, 9)

# Quadratic function
ftest <- function(x, sd = 1e-6){
   if(is.null(dim(x))) x <- matrix(x, nrow = 1)
   return(3 + drop(diag(x \%*\% A \%*\% t(x)) + x \%*\% b) + 
     rnorm(nrow(x), sd = sd))
}

ntrain <- 10000
design <- 2 * matrix(runif(ntrain * 3), ntrain) - 1
response <- ftest(design)

C_hat <- C_Q(design, response)

plot(design \%*\% eigen(C_hat)$vectors[,1], response)

# Test 
gfun <- function(x){2 * A \%*\% t(x) + matrix(b, nrow = nrow(A), ncol = nrow(x))}
grads <- gfun(design)
C_MC <- tcrossprod(grads)/ntrain
C_true <- 4/3 * A \%*\% A + tcrossprod(b)
subspace_dist(eigen(C_MC)$vectors[,1:2], eigen(C_true)$vectors[,1:2]) 
}
\keyword{internal}
