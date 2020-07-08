library(shiny)
library(leaflet)
library(shinythemes)
library(rsconnect)

ui = fluidPage(theme = shinytheme("simplex"),
               #Application title
               headerPanel("Novel Coronavirus 2019-nCoV World Cases"), 
               fluidRow(column(width = 5,  
                               tabsetPanel(id= "tabs",
                                           tabPanel("Map(China)", id = "Map1", 
                                                    br(), 
                                                    p("Click on the map to see exact confirmed number"),
                                                    sliderInput(inputId = "date", "Choose a date to display the distrbution of 2019-ncov in China", 
                                                                min = as.Date("2020-01-22"), max = as.Date("2020-03-01"),
                                                                value = as.Date("2020-02-28"),
                                                                timeFormat="%Y-%m-%d")
                                           ),
                                           tabPanel("Map(Global)", id = "Map2", 
                                                    br(), 
                                                    p("Click on the map to see exact confirmed number"),
                                                    sliderInput(inputId = "date2", "Choose a date to display the distrbution of 2019-ncov Wolrdwide", 
                                                                min = as.Date("2020-01-22"), max = as.Date("2020-03-01"),
                                                                value = as.Date("2020-02-28"),
                                                                timeFormat="%Y-%m-%d")
                                           ),
                                           tabPanel("Map(US)", id = "Map3", 
                                                    br(), 
                                                    p("Click on the map to see exact confirmed number"),
                                                    sliderInput(inputId = "date3", "Choose a date to display the distrbution of 2019-ncov in United States", 
                                                                min = as.Date("2020-01-22"), max = as.Date("2020-03-01"),
                                                                value = as.Date("2020-02-28"),
                                                                timeFormat="%Y-%m-%d")
                                           )
                               ),
                               plotOutput("trend")
               ),
               column(width = 7,
                      tabsetPanel(
                        tabPanel("Map(China)", leafletOutput(outputId = "chinamap")),
                        tabPanel("Map(Global)", leafletOutput(outputId = "worldmap")),
                        tabPanel("Map(US)", leafletOutput(outputId = "usmap"))
                      ),
                      mainPanel(
                        textOutput("total"),
                        textOutput("update")
                      )
               )
               )
)

