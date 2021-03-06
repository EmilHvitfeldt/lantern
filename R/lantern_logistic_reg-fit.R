#' Fit a single layer neural network
#'
#' `lantern_logistic_reg()` fits a model.
#'
#' @param x Depending on the context:
#'
#'   * A __data frame__ of predictors.
#'   * A __matrix__ of predictors.
#'   * A __recipe__ specifying a set of preprocessing steps
#'     created from [recipes::recipe()].
#'
#'  The predictor data should be standardized (e.g. centered or scaled).
#'
#' @param y When `x` is a __data frame__ or __matrix__, `y` is the outcome
#' specified as:
#'
#'   * A __data frame__ with 1 numeric column.
#'   * A __matrix__ with 1 numeric column.
#'   * A numeric __vector__.
#'
#' @param data When a __recipe__ or __formula__ is used, `data` is specified as:
#'
#'   * A __data frame__ containing both the predictors and the outcome.
#'
#' @param formula A formula specifying the outcome terms on the left-hand side,
#' and the predictor terms on the right-hand side.
#'
#' @param epochs An integer for the number of epochs of training.
#' @param penalty The amount of weight decay (i.e., L2 regularization).
#' @param learn_rate A positive number (usually less than 0.1).
#' @param momentum A positive number on `[0, 1]` for the momentum parameter in
#'  gradient decent.
#' @param validation The proportion of the data randomly assigned to a
#'  validation set.
#' @param batch_size An integer for the number of training set points in each
#'  batch.
#' @param conv_crit A non-negative number for convergence.
#' @param verbose A logical that prints out the iteration history.
#'
#' @param ... Not currently used, but required for extensibility.
#'
#' @details
#'
#' Despite its name, this function can be used with three or more classes (e.g.,
#' multinomial regression).
#'
#' The _predictors_ data should all be numeric and encoded in the same units (e.g.
#' standardized to the same range or distribution). If there are factor
#' predictors, use a recipe or formula to create indicator variables (or some
#' other method) to make them numeric.
#'
#' If `conv_crit` is used, it stops training when the difference in the loss
#' function is below `conv_crit` or if it gets worse. The default trains the
#' model over the specified number of epochs.
#'
#' @return
#'
#' A `lantern_logistic_reg` object with elements:
#'  * `models`: a list object of serialized models for each epoch.
#'  * `loss`: A vector of loss values (MSE for regression, negative log-
#'            likelihood for classification) at each epoch.
#'  * `dim`: A list of data dimensions.
#'  * `y_stats`: A list of summary statistics for numeric outcomes.
#'  * `parameters`: A list of some tuning parameter values.
#'  * `blueprint`: The `hardhat` blueprint data.
#'
#' @examples
#' if (torch::torch_is_installed()) {
#'
#'  ## -----------------------------------------------------------------------------
#'  # increase # epochs to get better results
#'
#'  data(cells, package = "modeldata")
#'
#'  cells$case <- NULL
#'
#'  set.seed(122)
#'  in_train <- sample(1:nrow(cells), 1000)
#'  cells_train <- cells[ in_train,]
#'  cells_test  <- cells[-in_train,]
#'
#'  # Using matrices
#'  set.seed(1)
#'  lantern_logistic_reg(x = as.matrix(cells_train[, c("fiber_width_ch_1", "width_ch_1")]),
#'                       y = cells_train$class,
#'                       penalty = 0.10, epochs = 20L, batch_size = 32)
#'
#'  # Using recipe
#'  library(recipes)
#'
#'  cells_rec <-
#'   recipe(class ~ ., data = cells_train) %>%
#'   # Transform some highly skewed predictors
#'   step_YeoJohnson(all_predictors()) %>%
#'   step_normalize(all_predictors())
#'
#'  set.seed(2)
#'  fit <- lantern_logistic_reg(cells_rec, data = cells_train,
#'                              penalty = .01, epochs = 100L, batch_size = 32)
#'  fit
#'
#'  autoplot(fit)
#'
#'  library(yardstick)
#'  predict(fit, cells_test, type = "prob") %>%
#'   bind_cols(cells_test) %>%
#'   roc_auc(class, .pred_PS)
#'
#'  # ------------------------------------------------------------------------------
#'  # multinomial regression
#'
#'  data(penguins, package = "modeldata")
#'
#'  penguins <- penguins %>% na.omit()
#'
#'  set.seed(122)
#'  in_train <- sample(1:nrow(penguins), 200)
#'  penguins_train <- penguins[ in_train,]
#'  penguins_test  <- penguins[-in_train,]
#'
#'  rec <- recipe(island ~ ., data = penguins_train) %>%
#'   step_dummy(species, sex) %>%
#'   step_normalize(all_predictors())
#'
#'  set.seed(3)
#'  fit <- lantern_logistic_reg(rec, data = penguins_train,
#'                              epochs = 200L, batch_size = 32)
#'  fit
#'
#'  predict(fit, penguins_test) %>%
#'   bind_cols(penguins_test) %>%
#'   conf_mat(island, .pred_class)
#' }
#'
#' @export
lantern_logistic_reg <- function(x, ...) {
 UseMethod("lantern_logistic_reg")
}

#' @export
#' @rdname lantern_logistic_reg
lantern_logistic_reg.default <- function(x, ...) {
 stop("`lantern_logistic_reg()` is not defined for a '", class(x)[1], "'.", call. = FALSE)
}

# XY method - data frame

#' @export
#' @rdname lantern_logistic_reg
lantern_logistic_reg.data.frame <-
 function(x,
          y,
          epochs = 100L,
          penalty = 0,
          validation = 0.1,
          learn_rate = 0.01,
          momentum = 0.0,
          batch_size = NULL,
          conv_crit = -Inf,
          verbose = FALSE,
          ...) {
  processed <- hardhat::mold(x, y)

  lantern_logistic_reg_bridge(
   processed,
   epochs = epochs,
   learn_rate = learn_rate,
   penalty = penalty,
   validation = validation,
   momentum = momentum,
   batch_size = batch_size,
   conv_crit = conv_crit,
   verbose = verbose,
   ...
  )
 }

# XY method - matrix

#' @export
#' @rdname lantern_logistic_reg
lantern_logistic_reg.matrix <- function(x,
                               y,
                               epochs = 100L,
                               penalty = 0,
                               validation = 0.1,
                               learn_rate = 0.01,
                               momentum = 0.0,
                               batch_size = NULL,
                               conv_crit = -Inf,
                               verbose = FALSE,
                               ...) {
 processed <- hardhat::mold(x, y)

 lantern_logistic_reg_bridge(
  processed,
  epochs = epochs,
  learn_rate = learn_rate,
  momentum = momentum,
  penalty = penalty,
  validation = validation,
  batch_size = batch_size,
  conv_crit = conv_crit,
  verbose = verbose,
  ...
 )
}

# Formula method

#' @export
#' @rdname lantern_logistic_reg
lantern_logistic_reg.formula <-
 function(formula,
          data,
          epochs = 100L,
          penalty = 0,
          validation = 0.1,
          learn_rate = 0.01,
          momentum = 0.0,
          batch_size = NULL,
          conv_crit = -Inf,
          verbose = FALSE,
          ...) {
  processed <- hardhat::mold(formula, data)

  lantern_logistic_reg_bridge(
   processed,
   epochs = epochs,
   learn_rate = learn_rate,
   momentum = momentum,
   penalty = penalty,
   validation = validation,
   batch_size = batch_size,
   conv_crit = conv_crit,
   verbose = verbose,
   ...
  )
 }

# Recipe method

#' @export
#' @rdname lantern_logistic_reg
lantern_logistic_reg.recipe <-
 function(x,
          data,
          epochs = 100L,
          penalty = 0,
          validation = 0.1,
          learn_rate = 0.01,
          momentum = 0.0,
          batch_size = NULL,
          conv_crit = -Inf,
          verbose = FALSE,
          ...) {
  processed <- hardhat::mold(x, data)

  lantern_logistic_reg_bridge(
   processed,
   epochs = epochs,
   learn_rate = learn_rate,
   momentum = momentum,
   penalty = penalty,
   validation = validation,
   batch_size = batch_size,
   conv_crit = conv_crit,
   verbose = verbose,
   ...
  )
 }

# ------------------------------------------------------------------------------
# Bridge

lantern_logistic_reg_bridge <- function(processed, epochs,
                               learn_rate, momentum, penalty,
                               validation, batch_size, conv_crit, verbose, ...) {
 if(!torch::torch_is_installed()) {
  rlang::abort("The torch backend has not been installed; use `torch::install_torch()`.")
 }

 f_nm <- "lantern_logistic_reg"
 # check values of various argument values
 if (is.numeric(epochs) & !is.integer(epochs)) {
  epochs <- as.integer(epochs)
 }
 check_integer(epochs, single = TRUE, 1, fn = f_nm)
 if (!is.null(batch_size)) {
  if (is.numeric(batch_size) & !is.integer(batch_size)) {
   batch_size <- as.integer(batch_size)
  }
  check_integer(batch_size, single = TRUE, 1, fn = f_nm)
 }
 check_double(penalty, single = TRUE, 0, incl = c(TRUE, TRUE), fn = f_nm)
 check_double(validation, single = TRUE, 0, 1, incl = c(TRUE, FALSE), fn = f_nm)
 check_double(momentum, single = TRUE, 0, 1, incl = c(TRUE, TRUE), fn = f_nm)
 check_double(learn_rate, single = TRUE, 0, incl = c(FALSE, TRUE), fn = f_nm)
 check_logical(verbose, single = TRUE, fn = f_nm)

 ## -----------------------------------------------------------------------------

 predictors <- processed$predictors

 if (!is.matrix(predictors)) {
  predictors <- as.matrix(predictors)
  if (is.character(predictors)) {
   rlang::abort(
    paste(
     "There were some non-numeric columns in the predictors.",
     "Please use a formula or recipe to encode all of the predictors as numeric."
    )
   )
  }
 }

 ## -----------------------------------------------------------------------------

 outcome <- processed$outcomes[[1]]

 ## -----------------------------------------------------------------------------

 fit <-
  lantern_logistic_reg_reg_fit_imp(
   x = predictors,
   y = outcome,
   epochs = epochs,
   learn_rate = learn_rate,
   momentum = momentum,
   penalty = penalty,
   validation = validation,
   batch_size = batch_size,
   conv_crit = conv_crit,
   verbose = verbose
  )

 new_lantern_logistic_reg(
  models = fit$models,
  loss = fit$loss,
  dims = fit$dims,
  y_stats = fit$y_stats,
  parameters = fit$parameters,
  blueprint = processed$blueprint
 )
}

new_lantern_logistic_reg <- function( models, loss, dims, y_stats, parameters, blueprint) {
 if (!is.list(models)) {
  rlang::abort("'models' should be a list.")
 }
 if (!is.vector(loss) || !is.numeric(loss)) {
  rlang::abort("'loss' should be a numeric vector")
 }
 if (!is.list(dims)) {
  rlang::abort("'dims' should be a list")
 }
 if (!is.list(parameters)) {
  rlang::abort("'parameters' should be a list")
 }
 if (!inherits(blueprint, "hardhat_blueprint")) {
  rlang::abort("'blueprint' should be a hardhat blueprint")
 }
 hardhat::new_model(models = models,
                    loss = loss,
                    dims = dims,
                    y_stats = y_stats,
                    parameters = parameters,
                    blueprint = blueprint,
                    class = "lantern_logistic_reg")
}

## -----------------------------------------------------------------------------
# Fit code

lantern_logistic_reg_reg_fit_imp <-
 function(x, y,
          epochs = 100L,
          batch_size = 32,
          penalty = 0,
          validation = 0.1,
          learn_rate = 0.01,
          momentum = 0.0,
          conv_crit = -Inf,
          verbose = FALSE,
          ...) {

  torch::torch_manual_seed(sample.int(10^5, 1))

  ## ---------------------------------------------------------------------------
  # General data checks:

  check_data_att(x, y)

  # Check missing values
  compl_data <- check_missing_data(x, y, "lantern_logistic_reg", verbose)
  x <- compl_data$x
  y <- compl_data$y
  n <- length(y)
  p <- ncol(x)

  y_dim <- length(levels(y))
  # the model will output softmax values.
  # so we need to use negative likelihood loss and
  # pass the log of softmax.
  loss_fn <- function(input, target) {
   nnf_nll_loss(
    input = torch::torch_log(input),
    target = target
   )
  }

  if (validation > 0) {
   in_val <- sample(seq_along(y), floor(n * validation))
   x_val <- x[in_val,, drop = FALSE]
   y_val <- y[in_val]
   x <- x[-in_val,, drop = FALSE]
   y <- y[-in_val]
  }

  y_stats <- list(mean = NA_real_, sd = NA_real_)
  loss_label <- "\tLoss:"

  if (is.null(batch_size)) {
   batch_size <- nrow(x)
  } else {
   batch_size <- min(batch_size, nrow(x))
  }

  ## ---------------------------------------------------------------------------
  # Convert to index sampler and data loader
  ds <- lantern::matrix_to_dataset(x, y)
  dl <- torch::dataloader(ds, batch_size = batch_size)

  if (validation > 0) {
   ds_val <- lantern::matrix_to_dataset(x_val, y_val)
   dl_val <- torch::dataloader(ds_val)
  }

  ## ---------------------------------------------------------------------------
  # Initialize model and optimizer
  model <- logistic_module(ncol(x), y_dim)

  # Write a optim wrapper
  optimizer <-
   torch::optim_sgd(model$parameters, lr = learn_rate,
                    weight_decay = penalty, momentum = momentum)

  ## ---------------------------------------------------------------------------

  loss_prev <- 10^38
  loss_vec <- rep(NA_real_, epochs)
  if (verbose) {
   epoch_chr <- format(1:epochs)
  }

  ## -----------------------------------------------------------------------------

  model_per_epoch <- list()

  # Optimize parameters
  for (epoch in 1:epochs) {

   # training loop
   for (batch in torch::enumerate(dl)) {

    pred <- model(batch$x)
    loss <- loss_fn(pred, batch$y)

    optimizer$zero_grad()
    loss$backward()
    optimizer$step()
   }

   # calculate loss on the full datasets
   if (validation > 0) {
    pred <- model(dl_val$dataset$data$x)
    loss <- loss_fn(pred, dl_val$dataset$data$y)
   } else {
    pred <- model(dl$dataset$data$x)
    loss <- loss_fn(pred, dl$dataset$data$y)
   }

   # calculate losses
   loss_curr <- loss$item()
   loss_vec[epoch] <- loss_curr

   if (is.nan(loss_curr)) {
    rlang::warn("Current loss in NaN. Training wil be stopped.")
    break()
   }

   loss_diff <- (loss_prev - loss_curr)/loss_prev
   loss_prev <- loss_curr

   # persists models and coefficients
   model_per_epoch[[epoch]] <- model_to_raw(model)

   if (verbose) {
    rlang::inform(
     paste("epoch:", epoch_chr[epoch], loss_label, signif(loss_curr, 5))
    )
   }

   if (loss_diff <= conv_crit) {
    break()
   }

   model_per_epoch[[epoch]] <- model_to_raw(model)

  }

  ## ---------------------------------------------------------------------------

  list(
   models = model_per_epoch,
   loss = loss_vec[!is.na(loss_vec)],
   dims = list(p = p, n = n, h = 0, y = y_dim),

   y_stats = y_stats,
   stats = y_stats,
   parameters = list(learn_rate = learn_rate,
                     penalty = penalty, validation = validation,
                     batch_size = batch_size, momentum = momentum)
  )
 }

logistic_module <-
 torch::nn_module(
  "linear_reg_module",
  initialize = function(num_pred, num_classes) {
   self$fc1 <- torch::nn_linear(num_pred, num_classes)
   self$transform <- torch::nn_softmax(dim = 2)
  },
  forward = function(x) {
   x %>%
    self$fc1() %>%
    self$transform()
  }
 )

## -----------------------------------------------------------------------------

get_num_logistic_reg_coef <- function(x) {
 model <- revive_model(x, 1)$parameters
 param <- vapply(model, function(.x) prod(dim(.x)), double(1))
 sum(unlist(param))
}

#' @export
print.lantern_logistic_reg <- function(x, ...) {
 lvl <- get_levels(x)

 if (lvl == 2) {
  cat("Logistic regression\n\n")
 } else {
  cat("Multinomial regression\n\n")
 }

 chr_y <- paste(length(lvl), "classes")
 cat(
  format(x$dims$n, big.mark = ","), "samples,",
  format(x$dims$p, big.mark = ","), "features,",
  chr_y, "\n"
 )
 if (x$parameters$penalty > 0) {
  cat("weight decay:", x$parameters$penalty, "\n")
 }
 cat("batch size:", x$parameters$batch_size, "\n")
 if (!is.null(x$loss)) {

  if(x$parameters$validation > 0) {
   if (is.na(x$y_stats$mean)) {
    cat("final validation loss after", length(x$loss), "epochs:",
        signif(x$loss[length(x$loss)]), "\n")
   } else {
    cat("final scaled validation loss after", length(x$loss), "epochs:",
        signif(x$loss[length(x$loss)]), "\n")
   }
  } else {
   if (is.na(x$y_stats$mean)) {
    cat("final training set loss after", length(x$loss), "epochs:",
        signif(x$loss[length(x$loss)]), "\n")
   } else {
    cat("final scaled training set loss after", length(x$loss), "epochs:",
        signif(x$loss[length(x$loss)]), "\n")
   }
  }
 }
 invisible(x)
}

coef.lantern_logistic_reg <- function(object, ...) {
 module <- revive_model(object, epoch = length(object$models))
 parameters <- module$parameters
 lapply(parameters, as.array)
}

## -----------------------------------------------------------------------------

#' Plot model loss over epochs
#'
#' @param object A `lantern_logistic_reg` object.
#' @param ... Not currently used
#' @return A `ggplot` object.
#' @details This function plots the loss function across the available epochs.
#' @export
autoplot.lantern_logistic_reg <- function(object, ...) {
 x <- tibble::tibble(iteration = seq(along = object$loss), loss = object$loss)

 if(object$parameters$validation > 0) {
  if (is.na(object$y_stats$mean)) {
   lab <- "loss (validation set)"
  } else {
   lab <- "loss (validation set, scaled)"
  }
 } else {
  if (is.na(object$y_stats$mean)) {
   lab <- "loss (training set)"
  } else {
   lab <- "loss (training set, scaled)"
  }
 }

 ggplot2::ggplot(x, ggplot2::aes(x = iteration, y = loss)) +
  ggplot2::geom_line() +
  ggplot2::labs(y = lab)
}
