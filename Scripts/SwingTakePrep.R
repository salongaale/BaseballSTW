# This R script includes functions that 
# process the data further for building the swing/take model

generate_tendency <- function(df, min.total = 0) {
    
    hitter_tendency_by_zone_stw <- df %>%
        filter( !is.na(zone) ) %>%
        group_by( batter, zone, swingtakewhiff ) %>%
        count()
    
    hitter_tendency_by_zone <- hitter_tendency_by_zone_stw %>%
        group_by( batter, zone ) %>%
        count(wt = n)
    
    hitter_tendency_by_stw <- hitter_tendency_by_zone_stw %>%
        group_by( batter, swingtakewhiff ) %>%
        count(wt = n)
    
    hitter_tendency_total <- hitter_tendency_by_zone %>%
        group_by( batter ) %>%
        count(wt = n, name = "n.total")
    
    hitter_tendency_by_zone_stw <- hitter_tendency_by_zone_stw %>%
        left_join( hitter_tendency_by_zone, by = c("batter", "zone"),
                   suffix = c(".stw", ".byzone") ) %>%
        mutate( pct.byzone = n.stw / n.byzone ) %>% ungroup() %>%
        select( -n.stw ) %>%
        pivot_wider(names_from = swingtakewhiff,
                    names_prefix = "byzone.",
                    values_from = pct.byzone,
                    values_fill = 0 )
    
    hitter_tendency_by_stw <- hitter_tendency_by_stw %>%
        left_join( hitter_tendency_total, by = "batter") %>%
        rename(n.stw = n) %>%
        mutate(pct.total = n.stw / n.total) %>% ungroup() %>%
        select(-n.stw) %>%
        pivot_wider(names_from = swingtakewhiff,
                    names_prefix = "total.",
                    values_from = pct.total,
                    values_fill = 0 )
    
    hitter_tendency <- hitter_tendency_by_zone_stw %>%
        left_join(hitter_tendency_by_stw, by = "batter") %>%
        filter( n.total >= min.total ) %>%
        arrange( desc(n.total) ) %>%
        select( batter, zone,
                n.byzone, byzone.swing, byzone.take, byzone.whiff,
                n.total, total.swing, total.take, total.whiff )
    
    return(hitter_tendency)
        
}

generate_traintest <- function(df, tendency) {
    
    temp <- df %>% 
        filter( !is.na(zone) & !is.na(description) & balls <= 3 ) %>%
        select(sv_id, batter, zone, 
               stand, p_throws,
               home_team, away_team,
               bat_score, fld_score,
               balls, strikes, pitch_number, 
               outs_when_up, inning, inning_topbot,
               on_3b, on_2b, on_1b,
               sz_top, sz_bot,
               pitch_name, release_speed,
               release_pos_x, release_pos_z, release_pos_y,
               release_spin_rate, release_extension,
               pfx_x, pfx_z, plate_x, plate_z,
               if_fielding_alignment, of_fielding_alignment,
               swingtakewhiff ) %>%
        filter( !is.na(pitch_name) & pitch_name != "Unknown" ) %>%
        left_join( tendency, by = c("batter", "zone")) %>%
        mutate( upbyruns = bat_score - fld_score,
                balls = as.factor(balls),
                strikes = as.factor(strikes),
                outs_when_up = as.factor(outs_when_up),
                on_3b = !is.na(on_3b), 
                on_2b = !is.na(on_2b),
                on_1b = !is.na(on_1b) ) %>%
        select( -bat_score, -fld_score ) %>%
        filter( complete.cases(.) & n.byzone >= 20 ) %>%
        mutate( swingtakewhiff = as.factor(swingtakewhiff) )
    
    temp$pitch_name <- factor(temp$pitch_name)
    
    return(temp)
}

generate_ohe <- function(df) {
    
    temp <- df %>%
        select(-sv_id, -batter, -zone,
               -home_team, -away_team )
    
    # temp$stand <- model.matrix( ~ stand - 1, data = temp)
    # temp$p_throws <- model.matrix( ~ p_throws - 1, data = temp)
    # levels(temp$balls) <- c("zero", "one", "two", "three")
    # temp$balls <- model.matrix( ~ balls - 1, data = temp)
    # levels(temp$strikes) <- c("zero", "one", "two")
    # temp$strikes <- model.matrix( ~ strikes - 1 , data = temp)
    # temp$outs_when_up <- model.matrix( ~ outs_when_up - 1, data = temp)
    # temp$inning_topbot <- model.matrix( ~ inning_topbot - 1, data = temp)
    # temp$pitch_name <- model.matrix( ~ pitch_name - 1, data = temp)
    # temp$if_fielding_alignment <- model.matrix( ~ if_fielding_alignment - 1,
    #                                             data = temp)
    # temp$of_fielding_alignment <- model.matrix( ~ of_fielding_alignment - 1,
    #                                             data = temp)
    
    tempstw <- temp %>% select(swingtakewhiff)
    
    dummies <- dummyVars( ~ .,
                         data = temp %>%
                             select(-swingtakewhiff))
    data_traintest_ohe <- predict(dummies, newdata = temp %>%
                                      select(-swingtakewhiff))
    data_traintest_ohe <- cbind(data_traintest_ohe, tempstw)
    
    return(as_tibble(data_traintest_ohe))
    
    
}