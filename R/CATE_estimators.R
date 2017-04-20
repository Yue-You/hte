#' @include EstimateCate.R
#' @include honestRF.R

setClass("CATE-estimators")
setClass(
  "Meta-learner",
  contains = "CATE-estimators",
  slots = list(
    feature_train = "data.frame",
    tr_train = "numeric",
    yobs_train = "numeric",
    forest = "honestRF",
    creator = "function"
  )
)


setGeneric(
  name = "CateCI",
  def = function(theObject,
                 feature_new,
                 method = "n2TBS",
                 B = 200,
                 nthread = 8,
                 verbose = TRUE)
  {
    standardGeneric("CateCI")
  }
)


#' CateCI-X_hRF
#' @name CateCI-X_hRF
#' @rdname CateCI-X_hRF
#' @description Return the estimated confidence intervals for the CATE
#' @param object A `X_hRF` object.
#' @param feature_new A data frame.
#' @param method different versions of the bootstrap. Only n2TBS implemented
#' @param B number of bootstrap samples.
#' @param nthread number of threats used.
#' @return A data frame of estimated CATE Confidence Intervals
#' @aliases CateCI, X_hRF-method
#' @exportMethod CateCI
setMethod(
  f = "CateCI",
  signature = "Meta-learner",
  definition = function(theObject,
                        feature_new,
                        method,
                        B,
                        nthread,
                        verbose) {
    ## shortcuts:
    feat <- theObject@feature_train
    tr <- theObject@tr_train
    yobs <- theObject@yobs_train
    creator <- theObject@creator
    ntrain <- length(tr)
    if (method == "n2TBS") {
      createbootstrappedData <- function() {
        smpl <- sample(1:ntrain,
                       replace = TRUE,
                       size = round(ntrain / 2))
        return(list(
          feat_b = feat[smpl, ],
          tr_b = tr[smpl],
          yobs_b = yobs[smpl]
        ))
      }
    }

    #### Run the bootstrap CI estimation #####################################

    # pred_B will contain for each simulation the prediction of each of the B
    # simulaions:
    pred_B <-
      as.data.frame(matrix(NA, nrow = nrow(feature_new), ncol = B))

    known_warnings <- c()
    # this is needed such that bootstrapped warnings are only printed once
    for (b in 1:B) {
      if (verbose)
        print(b)
      went_wrong <- 0
      # if that is 100 we really cannot fit it and bootstrap
      # seems to be infeasible.

      while (is.na(pred_B[1, b])) {
        if (went_wrong == 100)
          stop("one of the groups might be too small to
               do valid inference.")
        pred_B[, b] <-
          tryCatch({
            bs <- createbootstrappedData()

            withCallingHandlers(
              # this is needed such that bootstrapped warnings are only
              # printed once
              EstimateCate(
                creator(
                  feat = bs$feat_b,
                  tr = bs$tr_b,
                  yobs = bs$yobs_b
                ),
                feature_new = feature_new
              ),
              warning = function(w) {
                if (w$message %in% known_warnings) {
                  # message was already printed and can be ignored
                  invokeRestart("muffleWarning")
                } else{
                  # message is added to the known_warning list:
                  known_warnings <<- c(known_warnings, w$message)
                }
              }
            )
          },
          error = function(e) {
            return(NA)
          })
        went_wrong <- went_wrong + 1
      }
    }


    # get the predictions from the original method
    pred <- EstimateCate(theObject, feature_new = feature_new)
    # the the 5% and 95% CI from the bootstrapped procedure
    CI_b <- data.frame(
      X5. =  apply(pred_B, 1, function(x)
        quantile(x, c(.025))),
      X95. = apply(pred_B, 1, function(x)
        quantile(x, c(.975))),
      sd = apply(pred_B, 1, function(x)
        sd(x))
    )

    return(data.frame(
      pred = pred,
      X5. =  pred - 1.96 * CI_b$sd,
      X95. = pred + 1.96 * CI_b$sd
      # X5. =  pred - (CI_b$X95. - CI_b$X5.) / 2,
      # X95. = pred + (CI_b$X95. - CI_b$X5.) / 2
      # X5. =  2 * pred - CI_b$X95.,
      # X95. = 2 * pred - CI_b$X5.
    ))
    }
)