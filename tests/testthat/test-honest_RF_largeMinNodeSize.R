test_that("Tests large node size", {

  x <- iris[, -1]
  y <- iris[, 1]

  # Set seed for reproductivity
  set.seed(24750371)

  # Test honestRF (mimic RF)
  expect_warning(
    forest <- honestRF(
      x,
      y,
      ntree = 500,
      replace = TRUE,
      sampsize = nrow(x),
      mtry = 4,
      nodesizeSpl = 80,
      nthread = 4,
      splitrule = "variance",
      splitratio = 1,
      nodesizeAvg = 80
    ),
    "honestRF is used as adaptive random forest."
  )

  # Test predict
  y_pred <- predict(forest, x)

  # Mean Square Error
  sum((y_pred - y) ^ 2)
  expect_equal(sum((y_pred - y) ^ 2), 102.1684, tolerance=1e-4)

})
