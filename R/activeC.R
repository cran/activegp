
# V[ \nalba f(a), f(X)]
# X - data locs
# a - place where gradient is evaluated.
cov_gen_dy <- function(a, X, l, sigma) {
    K_yXya <- hetGP::cov_gen(X, matrix(a, nrow = 1), l, type = 'Gaussian')
    return(sigma * t(as.numeric(K_yXya) * t(2*(t(X) - a) / l)))
}

#xloc <- X[1,]
#grad(function(a) k(a, xloc), a)
#cov_gen_dy(a, X, l, sigma)

# V[\nabla f(a), \nabla f(a)]
cov_gen_dd <- function(a, X, l, sigma) {
    return(sigma*diag(2/l))
}

#jacobian(function(a2) grad(function(a1) k(a1, a2), a), a)
#cov_gen_dd(a, X, l, sigma)
#

# Double check nugget, especially for Vdf_df term.
C_at_a <- function(a, X, y, l, sigma, gpe, beta = 0, Ki = NULL) {
    # Generate prior variances.
    Vdf_df <- cov_gen_dd(a, X, l, sigma) 
    Vdf_f <- cov_gen_dy(a, X, l, sigma)

    if (missing(Ki)) {
        Vf_f <- sigma*hetGP::cov_gen(X, X, l, type = 'Gaussian')
        sol <- t(solve(Vf_f + diag(gpe, ncol = nrow(X), nrow = nrow(X)), t(Vdf_f)))
    } else {
        sol <- Vdf_f %*% Ki / sigma
    }

    # Get posterior moments via NCE. 
    post_mean <- sol %*% (y - beta)
    post_var <- Vdf_df - sol %*% t(Vdf_f)

    #return(post_var + tcrossprod(post_mean))
    return(post_var + tcrossprod(post_mean))
}

C_GP_empirical <- function(fit) {
    Cxs <- lapply(1:nrow(fit$X), function(n) C_at_a(fit$X[n,], fit$X, fit$Z, fit$theta, fit$nu_hat, Ki = fit$Ki))
    Cxh <- Reduce(function(x, y) x+y, Cxs) / nrow(fit$X)
}

C_GP_discrete <- function(fit, S) {
    Cxs <- lapply(1:nrow(S), function(n) C_at_a(S[n,], fit$X, fit$Z, fit$theta, fit$nu_hat, Ki = fit$Ki))
    Cxh <- Reduce(function(x, y) x+y, Cxs) / nrow(fit$X)
}

#' @title Active Subspace Matrix closed form expression for a GP.
#' @description 
#' Computes the integral over the input domain of the outer product of the gradients of a Gaussian process. 
#' The corresponding matrix is the C matrix central in active subspace methodology.
#' @param modelX This may be either 1) a \code{homGP} or \code{hetGP} GP model, see \code{\link[hetGP]{hetGP-package}} containing, e.g.,
#'  a vector of \code{theta}s, type of covariance \code{ct}, an inverse covariance matrix \code{Ki},
#' a design matrix \code{X0}, and response vector \code{Z0}. 2) A matrix of design locations, in which case a vector of responses must be given as the y argument, and this function will fit a default model for you.  
#' @param y A vector of responses corresponding to the design matrix; may be ommited if a GP fit is provided in the modelX argument. 
#' @param measure One of c("lebesgue", "gaussian", "trunc_gaussian", "sample", "discrete"), indiciating the probability distribution with respect to which the input points are drawn in the definition of the active subspace. "lebesgue" uses the Lebesgue or Uniform measure over the unit hypercube [0,1]^d. "gaussian" uses a Gaussian or Normal distribution, in which case xm and xv should be specified. "trunc_gaussian" gives a truncated Gaussian or Normal distribution over the unit hypercube [0,1]^d, in which case xm and xv should be specified. "sample" gives the Sample or Empirical measure (dirac deltas located at each design point), which is equivalent to calculating the average expected gradient outer product at the design points. "discrete" gives a measure which puts equal weight at points in the input space specified via the S parameter, which should be a matrix with one row for each atom of the measure.  
#' @param xm If measure is "gaussian" or "trunc_gaussian", gives the mean vector. 
#' @param xv If measure is "gaussian" or "trunc_gaussian", gives the marginal variance vector. The covariance matrix is assumed to be diagonal.
#' @param S If measure is "discrete", gives the locations of the measure's atoms. S is a matrix, each row of which gives an atom.
#' @param verbose Should we print progress?
#' @return a \code{const_C} object with elements
#' \itemize{
#' \item \code{model}: GP model provided or estimated;
#' \item \code{mat}: C matrix estimated;
#' \item \code{Wij}: list of W matrices, of size number of variables;
#' \item \code{ct}: covariance type (1 for "Gaussian", 2 for "Matern3_2", 3 for "Matern5_2").
#' }
#' @references 
#' N. Wycoff, M. Binois, S. Wild (2019+), Sequential Learning of Active Subspaces, preprint.\cr
#' 
#' P. Constantine (2015), Active Subspaces, Philadelphia, PA: SIAM.
#' @export
#' @useDynLib activegp
#' @importFrom  Rcpp evalCpp 
#' @import hetGP
#' @seealso \code{\link[activegp]{print.const_C}}, \code{\link[activegp]{plot.const_C}}
#' @examples 
#' ################################################################################
#' ### Active subspace of a Gaussian process
#' ################################################################################
#' \donttest{ 
#' library(hetGP); library(lhs)
#' set.seed(42)
#' 
#' nvar <- 2
#' n <- 100
#' 
#' # theta gives the subspace direction
#' f <- function(x, theta, nugget = 1e-3){
#'   if(is.null(dim(x))) x <- matrix(x, 1)
#'   xact <- cos(theta) * x[,1] - sin(theta) * x[,2]
#'   return(hetGP::f1d(xact) + rnorm(n = nrow(x), sd = rep(nugget, nrow(x))))
#' }
#' 
#' theta_dir <- pi/6
#' act_dir <- c(cos(theta_dir), -sin(theta_dir))
#' 
#' # Create design of experiments and initial GP model
#' design <- X <- matrix(signif(maximinLHS(n, nvar), 2), ncol = nvar)
#' response <- Y <- apply(design, 1, f, theta = theta_dir)
#' model <- mleHomGP(design, response, known = list(beta0 = 0))
#' 
#' C_hat <- C_GP(model)
#' 
#' # Subspace distance to true subspace:
#' print(subspace_dist(C_hat, matrix(act_dir, nrow = nvar), r = 1))
#' plot(design %*% eigen(C_hat$mat)$vectors[,1], response, 
#'   main = "Projection along estimated active direction")
#' plot(design %*% eigen(C_hat$mat)$vectors[,2], response, 
#'   main = "Projection along estimated inactive direction")
#'   
#' # For other plots:
#' # par(mfrow = c(1, 3)) # uncomment to have all plots together
#' plot(C_hat)
#' # par(mfrow = c(1, 1)) # restore graphical window
#' 
#' } 
C_GP <- function(modelX, y, measure = 'lebesgue', xm = NULL, xv = NULL, S = NULL, verbose = TRUE) {
    if ('matrix' %in% class(modelX)) {
        if (missing(y)) {
            stop("If no model is provided, both X and y must be.")
        }
        X <- modelX
        if (verbose) cat("Fitting GP...\n")
        model <- hetGP::mleHomGP(X, y)
    } else if ('homGP' %in% class(modelX) || 'list' %in% class(modelX)) {
        model <- modelX
    } else {
        stop("Unrecognized first argument to C_GP: Should be either a design matrix X (to be accompanied by a response vector y) or a GP fit, typically the result of a call to hetGP::mleHomGP.")
    }
    if (verbose) cat("Calculating Active Subspace Matrix...\n")

    int_measures <- c("lebesgue", "gaussian", "trunc_gaussian")
    sum_measures <-  c("sample", "discrete")
    allowed_measures <- c(int_measures, sum_measures)
    measure <- match.arg(measure, allowed_measures, several.ok = FALSE)
    if (is.null(xm)) xm <- 0
    if (is.null(xv)) xv <- 1

    if (measure %in% c('lebesgue', 'trunc_gaussian'))
      if(max(model$X) > 1 + sqrt(.Machine$double.eps)|| min(model$X) < 0 - sqrt(.Machine$double.eps)) {
          warning("Designs are supposed to be in [0,1]^d for lebesgue or trunc_gaussian; you may wish to rescale. \n Extreme values of ", min(model$X), ", ", max(model$X), " detected in model$X. ")
      }

    if (is.null(model$X)) {
        stop("Model object needs to have design points in X")
    }
    # isotropic measure:
    if (length(xm) == 1) {
        xm = rep(xm,ncol(model$X))
    } else if (length(xm) != ncol(model$X)) {
        stop("Please either supply a scalar or a vector of length equal to the dimension of the data for the Gaussian mean parameter.")
    }
    if (length(xv) == 1) {
        xv = rep(xv,ncol(model$X))
    } else if (length(xv) != ncol(model$X)) {
        stop("Please either supply a scalar or a vector of length equal to the dimension of the data for the Gaussian variance parameter.")
    }
    if (length(model$theta) == 1) {
        model$theta <- rep(model$theta,ncol(model$X))
    } 

    Kir <- model$Ki %*% model$Z0
    # Create a const_C object to return
    C <- list()

    if (model$covtype == 'Gaussian') {
        theta <- sqrt(model$theta/2)
        ct <- 1
    } else if (model$covtype == 'Matern3_2') {
        theta <- model$theta
        ct <- 2
    }else if (model$covtype == 'Matern5_2') {
        theta <- model$theta
        ct <- 3
    } else {
        stop("Unsupported Covariance type in model passed to C_GP")
    }

    if (measure %in% int_measures) {
        measure_ind <- which(measure==int_measures)-1
        #C$mat <- quick_C(measure_ind, model$X, model$Ki, Kir, theta, xm = xm, xv = xv, ct = ct)
        ret <- quick_C(measure_ind, model$X, model$Ki, Kir, theta, xm = xm, xv = xv, ct = ct, verbose)
        C$mat <- ret$C
        C$Wij <- ret$W
    } else if (measure %in% sum_measures) {
        #stop("Not implemented.")
        if (measure == 'sample') {
            S <- model$X
        } else if (measure == 'discrete'){
            if (is.null(S)) {
                stop("For the discrete measure, you must specify the atoms as rows in the matrix S.")
            }
        } else {
            stop("Measure not recognized. ")
        }
        C$mat <- C_GP_discrete(model, S) 
    }

    class(C) <- "const_C"
    #TODO: See if we can back these out.
    #C$Wij <- lapply(1:ncol(model$X), function(i) list())
    C$model <- model
    C$ct <- which(c('Gaussian', 'Matern3_2', 'Matern5_2')==model$covtype)#TODO: Generalize kernels
    C$measure <- measure

    return(C)
}

#' Active Subspace Prewarping
#'
#' Computes a matrix square root of C = Lt %*% t(Lt).
#' @param ... Parameters to be passed to C_GP, if C was not provided. 
#' @param C the result of a call to C_GP. If provided, all other arguments are ignored. 
#' @return The matrix Lt which can be used for sensitivity prewarping, i.e. by computing Xw = X %*% Lt.
#' @export
Lt_GP <- function(..., C) {
    if (missing(C)) {
        C <- C_GP(...) 
    }
    ed <- eigen(C)
    Lt <- ed$vectors %*% diag(sqrt(ed$values))
    return(Lt)
}

#' Extract Matrix
#'
#' Given a const_C object, extracts the actual matrix itself.
#' @param x A const_C object with field 'mat'.
#' @param ... Additional parameters. Not used. 
#' @return The mat entry of C, a matrix.
#' @export
as.matrix.const_C <- function(x, ...) {
    return(x$mat)
}

#' C update with new observations
#'
#' Update Constantine's C with new point(s) for a GP
#' @param object A const_C object, the result of a call to the C_GP function. 
#' @param Xnew matrix (one point per row) corresponding to the new designs
#' @param Znew vector of size \code{nrow(Xnew)} for the new responses at \code{Xnew}
#' @param ... not used (for consistency of update method)
#' @return The updated const_C object originally provided. 
#' @export
#' @seealso \code{\link[activegp]{C_GP}} to generate const_C objects from \code{\link[hetGP]{mleHomGP}} objects; \code{\link[activegp]{update_C2}} for an update using faster expressions.  
#' @useDynLib activegp
#' @importFrom  Rcpp evalCpp
#' @examples
#' \donttest{ 
#' ################################################################################
#' ### Active subspace of a Gaussian process
#' ################################################################################
#' library(hetGP); library(lhs)
#' set.seed(42)
#' 
#' nvar <- 2
#' n <- 100
#' 
#' # theta gives the subspace direction
#' f <- function(x, theta, nugget = 1e-3){
#'   if(is.null(dim(x))) x <- matrix(x, 1)
#'   xact <- cos(theta) * x[,1] - sin(theta) * x[,2]
#'   return(hetGP::f1d(xact) + 
#'     rnorm(n = nrow(x), sd = rep(nugget, nrow(x))))
#' }
#' 
#' theta_dir <- pi/6
#' act_dir <- c(cos(theta_dir), -sin(theta_dir))
#' 
#' # Create design of experiments and initial GP model
#' design <- X <- matrix(signif(maximinLHS(n, nvar), 2), ncol = nvar)
#' response <- Y <- apply(design, 1, f, theta = theta_dir)
#' model <- mleHomGP(design, response, known = list(beta0 = 0))
#' 
#' C_hat <- C_GP(model)
#' 
#' print(C_hat)
#' print(subspace_dist(C_hat, matrix(act_dir, nrow = nvar), r = 1))
#' 
#' # New designs
#' Xnew <- matrix(runif(2), 1)
#' Znew <- f(Xnew, theta_dir)
#' 
#' C_new <- update(C_hat, Xnew, Znew)
#' print(C_new)
#' subspace_dist(C_new, matrix(act_dir, nrow = nvar), r = 1)
#' }
update.const_C <- function(object, Xnew, Znew, ...){
  # Evaluate new quantities
  if(is.null(nrow(Xnew))) Xnew <- matrix(Xnew, nrow = 1)
  n0 <- nrow(object$model$X0) # to identify replicates
  nvar <- ncol(Xnew)

  # Update ancillary quantities.
  object$model <- update(object$model, Xnew = Xnew, Znew = Znew, maxit = 0)

  theta <- object$model$theta
  # isotropic case:
  if(length(theta) < ncol(object$model$X0)) theta <- rep(theta, nvar)
  if(object$ct == 1){
    theta <- sqrt(theta/2)
    M_num <- 1
  }else{
    if(object$ct == 2) M_num <- 3 else M_num <- 5/3
  } 

  n <- nrow(object$model$X0)
  Kir <- crossprod(object$model$Ki, object$model$Z0)

  for(i in 1:nvar) {
    for(j in i:nvar) {
      # If xnew is a replicate, n = n0 and Wijs are unchanged
      if(n > n0){
        Wij <- rbind(cbind(object$Wij[[i]][[j]], matrix(NA, n0, n - n0)), matrix(NA, n - n0, n))
        W_kappa_ij_up(W = Wij, design = object$model$X0, theta, i - 1, j - 1, start = n0, ct = object$ct)
        object$Wij[[i]][[j]] <- Wij
      }else{
        Wij <- object$Wij[[i]][[j]]
      }

      # Cov(dYi(X),dYj(X))
      M <- M_num/theta[i]^2 * (i == j) - sum(object$model$Ki * Wij) + crossprod(Kir, Wij) %*% Kir 
      object$mat[i,j] <- object$mat[j,i] <- M
    }
  }
  return(object)

}

#' Update Constantine's C, using update formula
#'
#' @param C A const_C object, the result of a call to \code{\link[activegp]{C_GP}}.
#' @param xnew The new design point
#' @param ynew The new response
#' @importFrom stats update predict
#' @references 
#' N. Wycoff, M. Binois, S. Wild (2019+), Sequential Learning of Active Subspaces, preprint.\cr
#' @return Updated C matrix, a const_C object.
#' @export
update_C2 <- function(C, xnew, ynew){
  if(is.null(nrow(xnew))) xnew <- matrix(xnew, nrow = 1)
  nvar <- ncol(xnew)
  
  Cup <- C$mat
  
  kn1 <- cov_gen(xnew, C$model$X0, theta = C$model$theta, type = C$model$covtype)
  
  # for shorter expressions
  if (C$ct == 1) {
    theta <- sqrt(C$model$theta/2)
  } else {
    theta <- C$model$theta
  }
  
  new_lambda <- predict(object = C$model, x = xnew, nugs.only = TRUE)$nugs/C$model$nu_hat
  vn <- drop(1 - kn1 %*% tcrossprod(C$model$Ki, kn1)) + new_lambda + C$model$eps
  
  # precomputations
  Kikn <- tcrossprod(C$model$Ki, kn1)
  gn <- - Kikn / vn
  Kiyn <- C$model$Ki %*% C$model$Z0 # Ki yn
  gyn <- crossprod(gn, C$model$Z0)
  
  for(i in 1:nvar) {
    for(j in i:nvar){
      wa <- drop(W_kappa_ij2(C$model$X0, xnew, theta = theta, i - 1, j - 1, ct = C$ct))  # w(X, xnew)
      wb <- drop(W_kappa_ij2(xnew, rbind(C$model$X0, xnew), theta = theta, i - 1, j - 1, ct = C$ct))  # c(w(xnew, X), w(xnew, xnew))
      w <-  wb[length(wb)]# w(xnew, xnew)
      wb <- wb[-length(wb)]
      kntKiWij <- crossprod(Kikn, C$Wij[[i]][[j]])
      
      tmp <- - crossprod(wa + wb, gn)
      tmp <- tmp - (gyn + ynew/vn) * (kntKiWij %*% Kiyn + crossprod(Kiyn, C$Wij[[i]][[j]] %*% Kikn))
      tmp <- tmp + (gyn + ynew/vn) * crossprod(wa + wb, Kiyn + gn * ynew - gn * drop(kn1 %*% Kiyn))
      tmp <- tmp + ((gyn + ynew/vn)^2 - 1/vn) * (w + kntKiWij %*% Kikn)
      
      Cup[i, j] <- Cup[j, i] <- C$mat[i, j] + tmp 
    }
  }
  return(Cup)
}


#' Expected variance of trace of C 
#' 
#' @param C A const_C object, the result of a call to \code{\link[activegp]{C_GP}}.
#' @param xnew The new design point
#' @param grad If \code{FALSE}, calculate variance of trace after update. If \code{TRUE}, returns the gradient.
#' @return A real number giving the expected variance of the trace of C given the current design.
#' @export
#' @references 
#' N. Wycoff, M. Binois, S. Wild (2019+), Sequential Learning of Active Subspaces, preprint.\cr
#' @examples 
#' \donttest{
#' ################################################################################
#' ### Variance of trace criterion landscape
#' ################################################################################
#'     library(hetGP)
#'     set.seed(42)
#'     nvar <- 2
#'     n <- 20
#' 
#'     # theta gives the subspace direction
#'     f <- function(x, theta = pi/6, nugget = 1e-6){
#'      if(is.null(dim(x))) x <- matrix(x, 1)
#'      xact <- cos(theta) * x[,1] - sin(theta) * x[,2]
#'      return(hetGP::f1d(xact) + 
#'        rnorm(n = nrow(x), sd = rep(nugget, nrow(x))))
#'     }
#' 
#'     design <- matrix(signif(runif(nvar*n), 2), ncol = nvar)
#'     response <- apply(design, 1, f)
#'     model <- mleHomGP(design, response, lower = rep(1e-4, nvar),
#'                       upper = rep(0.5,nvar), known = list(g = 1e-4))
#'                       
#'     C_hat <- C_GP(model)
#' 
#'     ngrid <- 101
#'     xgrid <- seq(0, 1,, ngrid)
#'     Xgrid <- as.matrix(expand.grid(xgrid, xgrid))
#'     filled.contour(matrix(f(Xgrid), ngrid))
#' 
#'     Ctr_grid <- apply(Xgrid, 1, C_tr, C = C_hat)
#'     filled.contour(matrix(Ctr_grid, ngrid), color.palette = terrain.colors,
#'                    plot.axes = {axis(1); axis(2); points(design, pch = 20)})
#' }
C_tr <- function(C, xnew, grad = FALSE){
  if(is.null(nrow(xnew))) xnew <- matrix(xnew, nrow = 1)
  nvar <- ncol(xnew)
  #for(i in 1:nvar) {
  #  ret <- get_betagamma(C, xnew, i, i, kn1, Kikn, Kiyn, vn, grad = grad)
  #  beta <- beta + ret$beta
  #  gamma <- gamma + ret$gamma
  #  if (grad) {
  #    dbeta <- dbeta + ret$dbeta
  #    dgamma <- dgamma + ret$dgamma
  #  }
  #}
  #if (grad) {
  #  return(2 * dbeta * beta + 4 * dgamma * gamma)
  #} else {
  #  return(drop(beta^2 + 2*gamma^2))
  #}
  ret <- get_betagamma(C, xnew, grad)
  if (grad) {
    return(sapply(1:nvar, function(d) 2 * sum(diag(ret$dBETA[,,d])) * sum(diag(ret$BETA)) + 4 * sum(diag(ret$dGAMMA[,,d])) * sum(diag(ret$GAMMA))))
  } else {
    return(drop(sum(diag(ret$BETA))^2 + 2*sum(diag(ret$GAMMA))^2))
  }
}

#' Element-wise Cn+1 variance
#'
#' @param C A const_C object, the result of a call to \code{\link[activegp]{C_GP}}.
#' @param xnew The new design point
#' @param grad If \code{FALSE}, calculate variance of update. If \code{TRUE}, returns the gradient.
#' @return A real number giving the expected elementwise variance of C given the current design.
#' @references 
#' N. Wycoff, M. Binois, S. Wild (2019+), Sequential Learning of Active Subspaces, preprint.\cr
#' @export
#' @examples 
#' ################################################################################
#' ### Norm of the variance of C criterion landscape
#' ################################################################################
#' library(hetGP)
#' set.seed(42)
#' nvar <- 2
#' n <- 20
#' 
#' # theta gives the subspace direction
#' f <- function(x, theta = pi/6, nugget = 1e-6){
#'  if(is.null(dim(x))) x <- matrix(x, 1)
#'  xact <- cos(theta) * x[,1] - sin(theta) * x[,2]
#'  return(hetGP::f1d(xact) 
#'    + rnorm(n = nrow(x), sd = rep(nugget, nrow(x))))
#' }
#' 
#' design <- matrix(signif(runif(nvar*n), 2), ncol = nvar)
#' response <- apply(design, 1, f)
#' model <- mleHomGP(design, response, lower = rep(1e-4, nvar),
#'                   upper = rep(0.5,nvar), known = list(g = 1e-4))
#'                   
#' C_hat <- C_GP(model)
#' 
#' ngrid <- 51
#' xgrid <- seq(0, 1,, ngrid)
#' Xgrid <- as.matrix(expand.grid(xgrid, xgrid))
#' filled.contour(matrix(f(Xgrid), ngrid))
#' 
#' cvar_crit <- function(C, xnew){
#'  return(sqrt(sum(C_var(C, xnew)^2)))
#' }
#' 
#' Cvar_grid <- apply(Xgrid, 1, cvar_crit, C = C_hat)
#' filled.contour(matrix(Cvar_grid, ngrid), color.palette = terrain.colors,
#'                plot.axes = {axis(1); axis(2); points(design, pch = 20)})
C_var <- function(C, xnew, grad = FALSE){
  if(is.null(nrow(xnew))) xnew <- matrix(xnew, nrow = 1)
  nvar <- ncol(xnew)
  #for(i in 1:nvar) {
  #  for(j in i:nvar) {
  #    #beta <- (crossprod(Kiyn, C$Wij[[i]][[j]] %*% Kikn) + kntKiWij %*% Kiyn - crossprod(wa + wb, Kiyn))/sqrt(vn)
  #    #gamma <- (w + kntKiWij %*% Kikn - crossprod(wa + wb, Kikn))/vn
  #    ret <- get_betagamma(C, xnew, i, j, kn1, Kikn, Kiyn, vn, grad = grad)
  #    if (grad) {
  #      dCvar[i, j,] <- dCvar[j, i,] <- drop(2*ret$beta*ret$dbeta + 4*ret$gamma*ret$dgamma)
  #    } 
  #    Cvar[i, j] <- Cvar[j, i] <- drop(ret$beta^2 + 2*ret$gamma^2)
  #  }
  #}
  #if (grad) {
  #  normgrads <- 2*sapply(1:nvar, function(d) t(as.numeric(dCvar[,,d])) %*% as.numeric(Cvar))
  #  return(normgrads)
  #  #return(dCvar)
  #} else {
  #  return(norm(Cvar, 'F')^2)
  #  #return(Cvar)
  #}
  ret <- get_betagamma(C, xnew, grad = grad)
  Cvar <- ret$BETA^2 + 2 * ret$GAMMA^2
  if (grad) {
    #return(2*sapply(1:nvar, function(d) t(as.numeric(dCvar[,,d])) %*% as.numeric(Cvar)))
    return(2*sapply(1:nvar, function(d) t(as.numeric(2*ret$BETA*ret$dBETA[,,d] + 4 * ret$GAMMA*ret$dGAMMA[,,d])) %*% as.numeric(Cvar)))
  } else {
    return(norm(Cvar, 'F')^2)
  }
}

#' Alternative Variance of Update
#'
#' Defined as E[(C - E[C])^2], where A^2 = AA (not elementwise multiplication).
#'
#' @param C A const_C object, the result of a call to \code{\link[activegp]{C_GP}}.
#' @param xnew The new design point
#' @param grad If \code{FALSE}, calculate variance of update. If \code{TRUE}, returns the gradient.
#' @return A real number giving the expected variance of C defined via matrix multiplication given the current design.
#' @references 
#' N. Wycoff, M. Binois, S. Wild (2019+), Sequential Learning of Active Subspaces, preprint.\cr
#' @export
#' @examples 
#' ################################################################################
#' ### Norm of the variance of C criterion landscape
#' ################################################################################
#' \donttest{ 
#' library(hetGP)
#' set.seed(42)
#' nvar <- 2
#' n <- 20
#' 
#' # theta gives the subspace direction
#' f <- function(x, theta = pi/6, nugget = 1e-6){
#'  if(is.null(dim(x))) x <- matrix(x, 1)
#'  xact <- cos(theta) * x[,1] - sin(theta) * x[,2]
#'  return(hetGP::f1d(xact) + rnorm(n = nrow(x), sd = rep(nugget, nrow(x))))
#' }
#' 
#' design <- matrix(signif(runif(nvar*n), 2), ncol = nvar)
#' response <- apply(design, 1, f)
#' model <- mleHomGP(design, response, lower = rep(1e-4, nvar),
#'                   upper = rep(0.5,nvar), known = list(g = 1e-4))
#'                   
#' C_hat <- C_GP(model)
#' 
#' ngrid <- 51
#' xgrid <- seq(0, 1,, ngrid)
#' Xgrid <- as.matrix(expand.grid(xgrid, xgrid))
#' filled.contour(matrix(f(Xgrid), ngrid))
#' 
#' cvar_crit <- function(C, xnew){
#'  return(sqrt(sum(C_var(C, xnew)^2)))
#' }
#' 
#' Cvar_grid <- apply(Xgrid, 1, cvar_crit, C = C_hat)
#' filled.contour(matrix(Cvar_grid, ngrid), color.palette = terrain.colors,
#'                plot.axes = {axis(1); axis(2); points(design, pch = 20)})
#' }
C_var2 <- function(C, xnew, grad = FALSE){
  if(is.null(nrow(xnew))) xnew <- matrix(xnew, nrow = 1)
  nvar <- ncol(xnew)
  ret <- get_betagamma(C, xnew, grad = grad)
  Cvar2 <- ret$BETA %*% ret$BETA + 2 * ret$GAMMA %*% ret$GAMMA
  if (grad) {
    Cvar2d <- array(NA, dim = c(nvar, nvar, nvar))
    for (p in 1:nvar) {
      Cvar2d[,,p] <- ret$dBETA[,,p] %*% ret$BETA + ret$BETA %*% ret$dBETA[,,p] + 2 * (ret$dGAMMA[,,p] %*% ret$GAMMA + ret$GAMMA %*% ret$dGAMMA[,,p])
    }
    normgrads <- 2*sapply(1:nvar, function(d) t(as.numeric(Cvar2d[,,d])) %*% as.numeric(Cvar2))
    return(normgrads)
  } else {
    return(norm(Cvar2, 'F')^2)
  }
}

#' Quantities for Acquisition Functions
#'
#' Create a single element of the BETA/GAMMA matrix. Used to compute acquisition functions and their gradients.
#'
#' @param C A const_C object, the result of a call to C_GP
#' @param xnew The new design point
#' @param grad If \code{FALSE}, calculate beta and gamma only. If \code{TRUE}, calculate their gradient too.
#' @return If \code{grad == FALSE}, A numeric vector of length 2, whose first element of beta_ij and the second gamma_ij. 
#' If \code{grad == TRUE}, a list with 3 numeric vector elements, the first giving the gradient for beta_ij, and the second for gamma_ij,
#' and the third is the same vector as would have been returned if grad was \code{FALSE}: simply the values of beta and gamma.
#' @keywords internal
get_betagamma <- function(C, xnew, grad = FALSE) {
  if (C$measure != 'lebesgue') stop("Sequential design only supports Lebesgue measure currently.")
  if(is.null(nrow(xnew))) xnew <- matrix(xnew, nrow = 1)
  nvar <- ncol(xnew)
  kn1 <- cov_gen(xnew, C$model$X0, theta = C$model$theta, type = C$model$covtype)
  Ki <- C$model$Ki
  
  new_lambda <- predict(object = C$model, x = xnew, nugs.only = TRUE)$nugs/C$model$nu_hat
  vn <- drop(1 - kn1 %*% tcrossprod(Ki, kn1)) + new_lambda + C$model$eps
  
  # precomputations
  Kikn <- tcrossprod(Ki, kn1)
  Kiyn <- Ki %*% C$model$Z0 # Ki yn
  
  # h <- 1e-6
  dkn1 <- matrix(NA, nvar, nrow(Ki))
  for (ih in 1:nvar) {
    # xh <- rep(0, nvar)
    # xh[ih] <- h
    # kn1h <- cov_gen(xnew + xh, C$model$X0, theta = C$model$theta, type = C$model$covtype)
    # dkn1 <- rbind(dkn1, (kn1h - kn1) / h)
    dkn1[ih,] <- d1(C$model$X0[, ih], x = xnew[ih], sigma = C$model$theta[ih], type = C$model$covtype) * kn1
  }
  
  dvn <- t(-2 * Ki %*% t(kn1)) %*% t(dkn1)
  
  Cvar <- C$mat
  
  if (C$ct == 1) {
    theta <- sqrt(C$model$theta/2)
  } else {
    theta <- C$model$theta
  }
  
  if (grad) {
    dBETA <- dGAMMA <- array(NA, dim = c(nvar, nvar, nvar))
  }
  BETA <- GAMMA <- matrix(NA, nrow = nvar, ncol = nvar)
  
  for (i in 1:nvar) {
    for (j in i:nvar) {
      wa <- drop(W_kappa_ij2(C$model$X0, xnew, theta = theta, i - 1, j - 1, ct = C$ct))  # w(X, xnew)
      wb <- drop(W_kappa_ij2(xnew, C$model$X0, theta = theta, i - 1, j - 1, ct = C$ct))  # c(w(xnew, X), w(xnew, xnew))
      #Wij <- C$Wij[[i]][[j]]
      Wij <- W_kappa_ij(design = C$model$X0, theta = theta, i1 = i - 1, i2 = j - 1, ct = C$ct)
      kntKiWij <- crossprod(Kikn, Wij)
      WijKiKn <- Wij %*% Kikn
      
      w <- drop(W_kappa_ij2(xnew, xnew, theta = theta, i - 1, j - 1, ct = C$ct))
      
      betanum <- drop((crossprod(Kiyn, WijKiKn) + kntKiWij %*% Kiyn - crossprod(wa + wb, Kiyn)))
      beta <- betanum / sqrt(vn)
      gammanum <- drop((w + kntKiWij %*% Kikn - crossprod(wa + wb, Kikn)))
      gamma <- gammanum / vn
      
      BETA[i,j] <- BETA[j,i] <- beta
      GAMMA[i,j] <- GAMMA[j,i] <- gamma
      
      if (grad) {
        # Get W's derivative via finite differencing
        dWa <- grad_W_kappa_ij2(xnew, C$model$X0, theta = theta, i - 1, j - 1, ct = C$ct)
        dWb <- grad_W_kappa_ij2_w2(xnew, C$model$X0, theta = theta, i - 1, j - 1, ct = C$ct)
        
        dwa <- drop(grad_W_kappa_ij2(xnew, xnew, theta = theta, i - 1, j - 1, ct = C$ct))
        dwb <- drop(grad_W_kappa_ij2_w2(xnew, xnew, theta = theta, i - 1, j - 1, ct = C$ct))
        dw <- dwa + dwb
        #h <- 1e-6
        #dw <- rep(NA, nvar)
        #for (ih in 1:nvar) {
        #  xh <- rep(0, nvar)
        #  xh[ih] <- h
        #  wh <- drop(W_kappa_ij2(xnew + xh, xnew + xh, theta = theta, i - 1, j - 1, ct = C$ct))
        #  dw[ih] <- (wh - w) / h
        #}
        
        AA <- Ki %*% (Wij %*% Kiyn + t(crossprod(Kiyn, Wij)))
        dbeta <- ((t(dkn1 %*% AA) - t((dWa + dWb) %*% Kiyn)) * sqrt(vn) - 
                    drop(betanum * 0.5 * vn^(-0.5)) * dvn) / (vn)
        BB <- t(Ki %*% (WijKiKn + t(kntKiWij))) %*% t(dkn1)
        CC <- t((dWa + dWb) %*% Kikn) + t(dkn1 %*% Ki %*% (wa + wb))
        dgamma <- ((t(dw) + BB - CC) * vn - drop(gammanum * dvn)) / (vn)^2
        dBETA[i,j,] <- dBETA[j,i,] <- dbeta
        dGAMMA[i,j,] <- dGAMMA[j,i,] <- dgamma
      } 
    }
  }
  
  if (grad) {
    return(list(BETA = BETA, GAMMA = GAMMA, dBETA = dBETA, dGAMMA = dGAMMA))
  } else {
    return(list(BETA = BETA, GAMMA = GAMMA))
  }
}

#' Print const_C objects
#' @param x A const_C object, the result of a call to C_GP
#' @param ... Additional parameters. Not used. 
#' @export
print.const_C <- function(x, ...) {
  cts <- c("Gaussian", "Matern3_2", "Matern5_2", 'Discrete')
  cat(paste(cts[x$ct], "kernel GP Estimate of Constantine's C wrt",x$measure,"measure:\n"))
  print(x$mat)
}

#' Plot const_C objectc
#' @param x A const_C object, the result of a call to C_GP
#' @param output one of \code{"image"} (image of the C matrix), \code{"logvals"} (log-eigen values), 
#' \code{"projfn"} projected function on first eigen vector or all plots at once (default).
#' @param ... Additional parameters. Not used. 
#' @importFrom graphics image plot
#' @export
plot.const_C <- function(x, output = c("all", "matrix", "logvals", "projfn"), ...) {
  output <- match.arg(output)
  if(output %in% c("all", "matrix")) image(x$mat, main = "C matrix values heatmap")
  if(output %in% c("all", "logvals")) plot(log(eigen(x$mat)$values), main = "log eigen values of C", xlab = "index", ylab = "")
  if(output %in% c("all", "projfn")) plot(x$model$X0 %*% eigen(x$mat)$vectors[,1], x$model$Z0, xlab = "First AS direction", ylab = "Function values")

}


#' Active subspace for second order linear model
#' @param design A matrix of design points, one in each row, in [-1,1]^d
#' @param response A vector of observations at each design point.
#' @return A matrix corresponding to the active subspace C matrix. 
#' @importFrom stats lm reformulate
#' @keywords internal
#' @export
#' @examples
#' set.seed(42) 
#' A <- matrix(c(1, -1, 0, -1, 2, -1.5, 0, -1.5, 4), nrow = 3, byrow = TRUE)
#' b <- c(1, 4, 9)
#'
#' # Quadratic function
#' ftest <- function(x, sd = 1e-6){
#'    if(is.null(dim(x))) x <- matrix(x, nrow = 1)
#'    return(3 + drop(diag(x %*% A %*% t(x)) + x %*% b) + 
#'      rnorm(nrow(x), sd = sd))
#' }
#' 
#' ntrain <- 10000
#' design <- 2 * matrix(runif(ntrain * 3), ntrain) - 1
#' response <- ftest(design)
#' 
#' C_hat <- C_Q(design, response)
#' 
#' plot(design %*% eigen(C_hat)$vectors[,1], response)
#' 
#' # Test 
#' gfun <- function(x){2 * A %*% t(x) + matrix(b, nrow = nrow(A), ncol = nrow(x))}
#' grads <- gfun(design)
#' C_MC <- tcrossprod(grads)/ntrain
#' C_true <- 4/3 * A %*% A + tcrossprod(b)
#' subspace_dist(eigen(C_MC)$vectors[,1:2], eigen(C_true)$vectors[,1:2]) 
C_Q <- function(design, response){
  d <- ncol(design)
  
  # create second order formula
  formulatmp <- reformulate(c(".^2", paste0("I(X", 1:ncol(design), "^2)")), response = "y") 
  
  model <- lm(formulatmp, data = data.frame(design, y = response))
  b <- model$coefficients[2:(d + 1)]
  A <- matrix(0, d, d)
  A[lower.tri(A)] <- 1/2*model$coefficients[(2*d + 2):length(model$coefficients)]
  A <- (A + t(A))
  diag(A) <- model$coefficients[(d+2):(2 * d + 1)]
  
  return(4/3 * A %*% A + tcrossprod(b))
}

