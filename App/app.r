library(readr)
library(rvest)
library(dplyr)
library(ggplot2)
library(caret)
library(shiny)
library(plotly)
library(ggplot2)
library(ggthemes)
library(shinythemes)
library(ggmap)


#Upload election integrity dataset
election_integrity_full <- read_csv("PEI US 2016 state-level (PEI_US_1.0) 16-12-2017.csv")

election_integrity <- election_integrity_full %>%
  select(stateabbr, PEIIndexi, PEIIndex_rank, PEItype, ratingstate, ratingstate_lci, ratingstate_hci, ratingcountry, ratingcountry_lci, ratingcountry_hci, lawsunfair2, favoredincumbent2, citizens2, lawsi, managed, votinginfo, fairofficials, legalelections, proceduresi, bfavored2, boundariesi, voteregi, oppprevent2, womenopp, minorityopp, leaderselect2, rallies2, partyregi, newspapers, tv2, fairaccess, faircoverage, mediai, donations, rich2, financei, violence2, fraudulent2, easy, choice, postal, expats, internet, rigged2, machinesaccurate, recordssecure, waited2, multiple2, regrestrictive2, popularwill, timely, votingi)

#Upload voter turnout dataset
voter_turnout <- read_csv("2016 November General Election - Turnout Rates.csv")
voter_turnout <- voter_turnout %>%
  select(State, "VEP_Highest_Office" = "X5", "VAP_Highest_Office" = "X6", "Total_Ballots_Counted_(Estimate)" = "Numerators", "Highest_Office" = "X8", "Voting_Eligible_Population_VEP" = "Denominators", "Voting_Age_Population_VAP" = "X10", "Total_Ineligible_Felons" = "X15", "Abbreviation" = "X17") %>%
  filter(!is.na(State) & State != "United States") %>%
  mutate(Voting_Eligible_Population_VEP = as.numeric(gsub(",", "", as.character(Voting_Eligible_Population_VEP))), Voting_Age_Population_VAP = as.numeric(gsub(",", "", as.character(Voting_Age_Population_VAP))), Total_Ineligible_Felons = as.numeric(gsub(",", "", as.character(Total_Ineligible_Felons)))) %>%
  mutate(Voters_Disenfranchised = Voting_Age_Population_VAP - Voting_Eligible_Population_VEP, Pct_Felon_Disenfranchised = Total_Ineligible_Felons / Voting_Age_Population_VAP) %>%
  select(-State)

#Scrape election results dataset
url <- "https://en.wikipedia.org/wiki/United_States_presidential_election,_2016"
tables <- url %>%
  read_html() %>%
  html_nodes(css = "table") 
election_results <- html_table(tables[[38]], fill = TRUE)
names(election_results) <- c("State", "Voting_Type", "Clinton_Number", "Clinton_Percent", "Clinton_Electoral", "Trump_Number", "Trump_Percent", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "Abbreviation", "q")
election_results <- election_results %>%
  select(State, Clinton_Percent, Trump_Percent, Abbreviation) %>%
  filter(State != "U.S. Total", State != "Nebraska, 1st", State != "Nebraska, 2nd", State != "Nebraska, 3rd", State != "Maine, 1st", State != "Maine, 2nd", Clinton_Percent != "%")  %>%
  select(-State)

election_results$Abbreviation[election_results$Abbreviation == "ME–a/l"] <- "ME"
election_results$Abbreviation[election_results$Abbreviation == "NE–a/l"] <- "NE"

election_results <- election_results %>% 
  mutate(Clinton_Percent = as.numeric(sub("%", "", as.character(Clinton_Percent))), Trump_Percent = as.numeric(sub("%", "", as.character(Trump_Percent)))) %>%
  mutate(Vote_Clinton = ifelse(Clinton_Percent - Trump_Percent > 0, "Clinton", "Trump"))

#Merge datasets
integrity_turnout <- inner_join(election_integrity, voter_turnout, by = c("stateabbr" = "Abbreviation"))
all <- inner_join(integrity_turnout, election_results, by = c("stateabbr" = "Abbreviation"))

#Shiny app

#Nice labels
x_label <- data.frame(var = c("PEIIndexi", "lawsi", "proceduresi", "boundariesi", "voteregi", "partyregi", "mediai", "financei", "votingi", "Pct_Felon_Disenfranchised"), names = c("Overall Election Integrity Index (Imputed)", "Legal Integrity Index (Imputed)", "Procedures Integrity Index (Imputed)", "Boundaries Integrity Index (Imputed)", "Voter Registration Integrity Index (Imputed)", "Party Registration Integrity Index (Imputed)", "Media Coverage Integrity Index (Imputed)", "Campaign Finance Integrity Index (Imputed)", "Voting Integrity Index (Imputed)", "Dienfranchised Felons (% of total eligible pop.)"))

y_label <- data.frame(var = c("PEIIndexi", "lawsi", "proceduresi", "boundariesi", "voteregi", "partyregi", "mediai", "financei", "votingi", "Pct_Felon_Disenfranchised"), names = c("Overall Election Integrity Index (Imputed)", "Legal Integrity Index (Imputed)", "Procedures Integrity Index (Imputed)", "Boundaries Integrity Index (Imputed)", "Voter Registration Integrity Index (Imputed)", "Party Registration Integrity Index (Imputed)", "Media Coverage Integrity Index (Imputed)", "Campaign Finance Integrity Index (Imputed)", "Voting Integrity Index (Imputed)", "Dienfranchised Felons (% of total eligible pop.)"))

#Loading data for longitudes and latitudes of states for map
states <- map_data("state")
election_integrity_full <- election_integrity_full %>%
  mutate(state = tolower(state))
map <- inner_join(election_integrity_full, states, by = c("state" = "region"))
map <- inner_join(map, election_results, by = c("stateabbr" = "Abbreviation"))


all_quant <- all %>%
  select(stateabbr, Vote_Clinton, PEIIndexi, lawsi, proceduresi, boundariesi, voteregi, partyregi, mediai, financei, votingi, Pct_Felon_Disenfranchised) 

all_qual <- map %>%
  select(stateabbr, Vote_Clinton, lawsunfair, favoredincumbent, citizens, managed, votinginfo, fairofficials, legalelections, bfavored, oppprevent, womenopp, minorityopp, leaderselect, rallies, newspapers, tv, fairaccess, faircoverage, donations, rich, violence, fraudulent, easy, choice, postal, expats, internet, rigged, machinesaccurate, recordssecure, waited, multiple, regrestrictive, popularwill, timely, long, lat, group)


##### UI Side ######
ui <- navbarPage("Looking Deeper into Election Integrity",
                 theme = shinythemes::shinytheme("sandstone"),
                 tabsetPanel(type = "tabs",
                             tabPanel("Quantitative Variables",
                                      fluidRow(
                                        p("In order to calculate the overall election integrity index, The Electoral Integrity Project created a few subcategories that aggregated ratings the various experts gave for some topics. Below, you can explore the relationships between the subcategory scores and the overall index.")
                                      ),
                                      plotlyOutput("quant"),
                                      
                                      hr(),
                                      fluidRow(
                                        column(6,
                                               selectInput("x", "X-Axis", 
                                                           c("Overall Election Integrity Index (Imputed)" = "PEIIndexi", 
                                                             "Legal Integrity Index (Imputed)" = "lawsi", 
                                                             "Procedures Integrity Index (Imputed)" = "proceduresi", 
                                                             "Boundaries Integrity Index (Imputed)" = "boundariesi",
                                                             "Voter Registration Integrity Index (Imputed)" = "voteregi", 
                                                             "Party Registration Integrity Index (Imputed)" = "partyregi", 
                                                             "Media Coverage Integrity Index (Imputed)" = "mediai", 
                                                             "Campaign Finance Integrity Index (Imputed)" = "financei", 
                                                             "Voting Integrity Index (Imputed)" = "votingi")),
                                               
                                               selectInput(inputId = "y", "Y-Axis",
                                                           c("Overall Election Integrity Index (Imputed)" = "PEIIndexi", 
                                                             "Legal Integrity Index (Imputed)" = "lawsi", 
                                                             "Procedures Integrity Index (Imputed)" = "proceduresi", 
                                                             "Boundaries Integrity Index (Imputed)" = "boundariesi",
                                                             "Voter Registration Integrity Index (Imputed)" = "voteregi", 
                                                             "Party Registration Integrity Index (Imputed)" = "partyregi", 
                                                             "Media Coverage Integrity Index (Imputed)" = "mediai", 
                                                             "Campaign Finance Integrity Index (Imputed)" = "financei", 
                                                             "Voting Integrity Index (Imputed)" = "votingi"))
                                        ),
                                        column(2,
                                               checkboxGroupInput("candidate", "Candidate Chosen", 
                                                                  choices = list("Clinton", "Trump"),
                                                                  selected = unique(all_quant$Vote_Clinton))
                                        ),
                                        column(4,
                                               selectInput("state", "What state do you want to see?",
                                                           choices = unique(all_quant$stateabbr))
                                        )
                                      )
                             ),
                             
                             tabPanel("Categorical Variables",
                                      plotOutput("qual"),
                                      
                                      hr(),
                                      
                                      fluidRow(
                                        column(5,
                                               selectInput("var", "What Variable Do You Want to Look At?", 
                                                           c("Laws are unfair" = "lawsunfair", "Incumbent is favored" = "favoredincumbent", "Citizens prevented from voting" = "citizens", "Elections well managed" = "managed", "Voting information widely available" = "votinginfo", "Officials were fair" = "fairofficials", "Elections followed the law" = "legalelections", "Boundaries favored incumbents" = "bfavored", "Opponent prevented from running" = "oppprevent", "Equal opportunities for women" = "womenopp", "Equal opportunities for minorities" = "minorityopp", "Top party leaders chose candidates" = "leaderselect", "Some candidates restricted from rallies" = "rallies", "Balanced newspaper coverage" = "newspapers", "TV favored governing party" = "tv", "Fair access to advertising" = "fairaccess", "Fair coverage of election" = "faircoverage", "Equal access to donations" = "donations", "Rich people buy elections" = "rich", "Some voters threatened at polls" = "violence", "Some fraudulent votes case" = "fraudulent", "Voting process was easy" = "easy", "Genuine choice at ballot box" = "choice", "Postal ballots available" = "postal", "Citizens abroad could vote" = "expats", "Internet voting available" = "internet", "Election was rigged" = "rigged", "Voting machines were accurate" = "machinesaccurate", "Voting records are secure" = "recordssecure", "People waited more than 30 min in line to vote" = "waited", "Some people voted more than once" = "multiple", "Registration deadlines too restrictive" = "regrestrictive", "Outcome reflected popular will" = "popularwill", "Ballots counted in timely fashion" = "timely"))
                                        ),
                                        
                                        column(2,
                                               checkboxGroupInput("candidate2", "Candidate Chosen", 
                                                                  choices = list("Clinton", "Trump"),
                                                                  selected = unique(all_qual$Vote_Clinton))
                                        ),
                                        
                                        column(5,
                                               p("Click the button to update the candidate!"),
                                               actionButton("action", "Update"))
                                      ),
                                      
                                      fluidRow(
                                        p(tags$b("Note:"), "For all these variables, experts were asked to rate the various states on a scale of 1-5 based on various statements, with 1 being strongly disagree and 5 being strongly agree, which is why we called them categorical. However, all the experts' ratings were averaged, allowing them to be plotted as quantitative.")
                                      )
                             )
                 ))

##### Server Side #####
server <- function(input, output) {
  
  #Label names
  xlab_var_name <- reactive({
    filter(x_label, var == input$x) %>%
      select(names) #.$names
  })
  
  ylab_var_name <- reactive({
    y_label %>%
      filter(var == input$y) %>%
      select(names) #.$names
  })
  
  output$quant <- renderPlotly({
    req(input$candidate)
    all_reactive <- filter(all_quant, Vote_Clinton %in% input$candidate)
    state_reactive <- filter(all_quant, stateabbr %in% input$state)
    ggplot(all_reactive, aes(color = Vote_Clinton, "State" = stateabbr)) +
      geom_point(alpha =.80, aes_string(x = input$x, y = input$y)) +
      geom_text(data = state_reactive, mapping = aes_string(x = input$x, y = input$y), label = input$state) +
      scale_color_manual(values = c("royalblue2", "firebrick3"), breaks = c("Trump", "Clinton"), name = "") +
      theme_classic() +
      labs(x = as.character(xlab_var_name()[1,1]), y = as.character(ylab_var_name()[1,1])) +
      theme(legend.position = c(.80,.85), legend.box.background = element_rect()) + 
      coord_cartesian(xlim = c(0, 100), ylim = c(0, 100))
  })
  
  output$qual <- renderPlot({
    qual_reactive <- eventReactive(input$action,
                                   {select(all_qual,
                                           stateabbr, long, lat, Vote_Clinton, group, input$var)
                                     filter(all_qual, Vote_Clinton == input$candidate2)
                                   })
    ggplot(data = qual_reactive()) + 
      geom_polygon(aes_string(x = "long", 
                              y = "lat", 
                              group = "group", 
                              fill = input$var), 
                   color = "white") + 
      scale_fill_gradient(high = "#E32F12", low = "#FBF0EE") +
      labs(fill = "Score") +
      coord_map() + 
      theme_void()
  })
}

shinyApp(ui, server)