#' Explore fit statistics various models and numbers of profiles using MPlus (requires purchasing and installing MPlus to use)
#' @details Explore the BIC values of a range of Mplus models in terms of a) the structure of the residual covariance matrix and b) the number of mixture components (or profiles)
#' @param n_profiles_min lower bound of the number of profiles to explore; defaults to 2
#' @param n_profiles_max upper bound of the number of profiles to explore; defaults to 10
#' @param models which models to include as a list of vectors; for each vector, the first value represents how the variances are estimated and the second value represents how the covariances are estimated; defaults to list(c("equal", "zero"), c("varying", "zero"), c("equal", "equal"), c("varying", "varying"))
#' @param cluster_ID clustering variable to use as part of MPlus 'type is complex' command
#' @param save_models whether to save the models as rds files
#' @param return_table logical (TRUE or FALSE) for whether to return a table of the output instead of a plot; defaults to TRUE
#' @param return_stats_df whether to return a list of fit statistics for the solutions explored; defaults to TRUE
#' @inheritParams estimate_profiles_mplus
#' @return a list with a data.frame with the BIC values and a list with all of the model output; if save_models is the name of an rds file (i.e., "out.rds"), then the model output will be written with that filename and only the data.frame will be returned
#' @examples
#' \dontrun{
#' compare_solutions_mplus(iris, Sepal.Length, Sepal.Width, Petal.Length, Petal.Width,
#' n_profiles_max = 3)
#' }
#' @export

compare_solutions_mplus <- function(df, ...,
                                    n_profiles_min = 2,
                                    n_profiles_max = 10,
                                    models = list(c("equal", "zero"), c("varying", "zero"), c("equal", "equal"), c("varying", "varying")),
                                    starts = c(100, 10),
                                    cluster_ID = NULL,
                                    m_iterations = 500,
                                    st_iterations = 20,
                                    convergence_criterion = 1E-6,
                                    save_models = FALSE,
                                    return_table = TRUE,
                                    n_processors = 1,
                                    return_stats_df = TRUE,
                                    include_VLMR = TRUE,
                                    include_BLRT = FALSE) {
  
  # I would remove the below entirely, at least for the review portion. Seems
  # to me if you're ready to submit to JOSS you're probably out of the 
  # experimental stage, for the most part.

  # message("Note that this and other functions that use MPlus are at the experimental stage! Please provide feedback at https://github.com/jrosen48/tidyLPA")

  out_df <- data.frame(matrix(
    ncol = length(models),
    nrow = (n_profiles_max - (n_profiles_min - 1))
  ))

  all_models_names = list(c("equal", "zero"), c("varying", "zero"), c("equal", "equal"), c("varying", "equal"), c("equal", "varying"), c("varying", "varying"))
1111 # what is this? Looks like something that doesn't belong...
  titles <- c(
      "Equal variances and covariances fixed to 0",
      "Varying variances and covariances fixed to 0",
      "Equal variances and equal covariances",
      "Varying variances and equal covariances",
      "Equal variances and varying covariances",
      "Varying variances and varying covariances"
  )

  names(out_df) <- titles[all_models_names %in% models]

  out_df <- out_df %>%
    mutate(n_profiles = n_profiles_min:n_profiles_max) %>%
    select(.data$n_profiles, everything())

  counter <- 0

  if (save_models == TRUE) {
    if (!dir.exists("compare_solutions_lpa_output")) { 
      dir.create("compare_solutions_lpa_output")
    }
  }

  remove_tmp_files <- FALSE # this isn't in an if... is that an error?

  # Remove/archive the below
  
  # if (save_models == TRUE) {
  #     remove_tmp_files <- FALSE
  # } else {
  #     remove_tmp_files <- TRUE
  # }

  # case_when(
  #     variances == "fixed" & covariances == "zero" ~ 1,
  #     variances == "varying" & covariances == "zero" ~ 2,
  #     variances == "fixed" & covariances == "fixed" ~ 3,
  #     variances == "varying" & covariances == "fixed" ~ 4,
  #     variances == "fixed" & covariances == "varying" ~ 5,
  #     variances == "varying" & covariances == "varying" ~ 6,
  # )

  # Probably more work than it's worth at this point, but I hate nested for
  # loops. I have to practice them more than once every time before I really
  # figure out what they're doing. I'd recommend going to purrr here. Can't
  # remember if you're already importing it or not, but it's a gem
  for (i in n_profiles_min:n_profiles_max) {
    for (j in seq(length(models))) {
      message(str_c("Processing model with n_profiles = ", i, " and model = ", j))

    m <- suppressMessages(estimate_profiles_mplus(
        df, ...,
        n_profiles = i,
        variances = models[[j]][1],
        covariances = models[[j]][2],
        cluster_ID = cluster_ID,
        starts = starts,
        m_iterations = m_iterations,
        convergence_criterion = convergence_criterion,
        st_iterations = st_iterations,
        return_save_data = F,
        n_processors = n_processors,
        include_VLMR = include_VLMR,
        include_BLRT = include_BLRT,
        remove_tmp_files = remove_tmp_files
      ))

      if (save_models == TRUE) {
        if (!dir.exists(str_c("compare_solutions_lpa_output/m", j, "_p", i))) {
          dir.create(str_c("compare_solutions_lpa_output/m", j, "_p", i))  
        }
        capture <- capture.output(m_all <- MplusAutomation::readModels("i.out")) # this will need to be changed to be dynamic # DA: I'd clean these things up too and not have any comments when you submit 
        write_rds(m_all, str_c("compare_solutions_lpa_output/m", j, "_p", i, "/m", j, "_p", i, ".rds")) # I'd *highly* recommend you work on getting all of this code within 80 characters, which is the standard, and helps make it more readable
      }

      counter <- counter + 1

      # fix (remove) suppressWarnings()
      if (m[1] == "Error: Convergence issue" 
          | m[1] == "Warning: LL not replicated") { # here's another example where it just spilled over, hence the suggested change
        message(str_c("Result: ", m))
        out_df[i - (n_profiles_min - 1), j + 1] <- m # This is the sort of stuff I was referring to with nested for loops. Kinda hard to tell what's actually going on here...
      } else {
        n_LL_replicated <- extract_LL_mplus("i.out")
        count_LL <- count(n_LL_replicated, .data$LL) 
        t <- as.character(str_c(table(m$savedata$C), collapse = ", "))
        message(paste0("Result: BIC = ", m$summaries$BIC))
        out_df[i - (n_profiles_min - 1), j + 1] <- m$summaries$BIC

        # This and BLRT might be another candidate for `switch`
        if (!("T11_VLMR_2xLLDiff" %in% names(m$summaries))) {
          VLMR_val <- NA
          VLMR_p <- NA
        } else {
          VLMR_val <- m$summaries$T11_VLMR_2xLLDif
          VLMR_p <- m$summaries$T11_VLMR_PValue
        }

        if (!("BLRT_2xLLDiff" %in% names(m$summaries))) {
          BLRT_val <- NA
          BLRT_p <- NA
        } else {
          BLRT_val <- m$summaries$BLRT_2xLLDiff
          BLRT_p <- m$summaries$BLRT_PValue
        }

        if (is.null(cluster_ID)){
            cluster_ID_label <- NA
        } else {
            cluster_ID_label <- cluster_ID
        }

        model_number <- case_when(
            models[[j]][1] == "equal" & models[[j]][2] == "zero" ~ 1,
            models[[j]][1] == "varying" & models[[j]][2] == "zero" ~ 2,
            models[[j]][1] == "equal" & models[[j]][2] == "equal" ~ 3,
            models[[j]][1] == "varying" & models[[j]][2] == "equal" ~ 4,
            models[[j]][1] == "equal" & models[[j]][2] == "varying" ~ 5,
            models[[j]][1] == "varying" & models[[j]][2] == "varying" ~ 6
        )

        if (counter == 1) {
          stats_df <- data.frame(
            n_profiles = i,
            model_number = model_number,
            variances = models[[j]][1],
            covariances = models[[j]][2],
            cluster_ID = cluster_ID_label,
            LL = m$summaries$LL,
            npar = m$summaries$Parameters,
            AIC = m$summaries$LL,
            BIC = m$summaries$BIC,
            SABIC = m$summaries$aBIC,
            CAIC = m$summaries$AICC,
            AWE = (-2 * m$summaries$LL) + (2 * m$summaries$Parameters * (log(m$summaries$Observations) + 1.5)),
            Entropy = m$summaries$Entropy,
            LL_replicated = str_c(count_LL$n[1], "/", as.character(starts[2])),
            cell_size = t,
            VLMR_val = VLMR_val,
            VLMR_p = VLMR_p,
            LMR_val = m$summaries$T11_LMR_Value,
            LMR_p = m$summaries$T11_LMR_PValue,
            BLRT_val = BLRT_val,
            BLRT_p = BLRT_p
          )
        } else { # I can't actually even see the difference between these two. Is there a way you could write this without so much redundancy of code? Maybe assemble the full df and then just change the value of one column based on counter?
          d <- data.frame(
            n_profiles = i,
            model_number = model_number,
            variances = models[[j]][1],
            covariances = models[[j]][2],
            LL = m$summaries$LL,
            npar = m$summaries$Parameters,
            AIC = m$summaries$LL,
            BIC = m$summaries$BIC,
            SABIC = m$summaries$aBIC,
            CAIC = m$summaries$AICC,
            AWE = (-2 * m$summaries$LL) + (2 * m$summaries$Parameters * (log(m$summaries$Observations) + 1.5)), # long again
            Entropy = m$summaries$Entropy,
            LL_replicated = str_c(count_LL$n[1], "/", as.character(starts[2])),
            cell_size = t,
            VLMR_val = VLMR_val,
            VLMR_p = VLMR_p,
            LMR_val = m$summaries$T11_LMR_Value,
            LMR_p = m$summaries$T11_LMR_PValue,
            BLRT_val = BLRT_val,
            BLRT_p = BLRT_p
          )

          stats_df <- suppressWarnings(bind_rows(stats_df, d))
          stats_df$cell_size <- as.character(stats_df$cell_size)
        }
      }
      # shouldn't the below be wrapped in some sort of if in case the user wants to keep them?
      file.remove("d.dat")
      file.remove("i.inp")
      file.remove("i.out")
      file.remove("d-mod.dat")
      file.remove("Mplus Run Models.log")
    }
  }

  if (return_stats_df == TRUE & return_table == TRUE) {
    return(list(as_tibble(out_df), 
                arrange(as_tibble(stats_df), 
                        .data$npar, 
                        .data$n_profiles)))
  }

  if (return_stats_df == TRUE) {
    print(as_tibble(out_df))
    return(arrange(as_tibble(stats_df), 
                   .data$model, 
                   .data$n_profiles))
  }

  if (return_table == TRUE) {
    print(as_tibble(out_df))
    invisible(as_tibble(out_df))
  } else {
    out_df %>%
      gather("Model", "BIC", -.data$n_profiles) %>%
      filter(str_detect(.data$BIC, "\\d+\\.*\\d*")) %>%
      mutate(
        BIC = as.numeric(.data$BIC),
        n_profiles = as.integer(.data$n_profiles),
        Model = str_extract(.data$Model, "\\d")
      ) %>%
      ggplot(aes_string(x = "n_profiles", 
                        y = "BIC", 
                        shape = "Model", 
                        color = "Model", 
                        group = "Model")) +
      geom_line() +
      geom_point()
  }
}
