# load library and data, and preprocess the shapefiles
library(shiny)
library(leaflet)
library(ggplot2)
library(tidyverse)
library(sf)
library(tmap)
library(tidyverse)
library(spData)
library(openintro)
library(anchors)
library(reshape2)
library(lubridate)
library(RColorBrewer)
library(shinythemes)
library(rsconnect)
confirmed <- read.csv("confirmed.csv", header=TRUE)
recovery <- read.csv("recovery.csv", header=TRUE)
##  data cleaning for china map
newline = data.frame("Province.State" = "Sichuan", "Country.Region" = "Mainland China", "Lat" = 30.61710, "Long" = 102.7103)
new = cbind(newline, confirmed[confirmed$Province.State == "Chongqing",5:44] + confirmed[confirmed$Province.State == "Sichuan",5:44])
confirmed2 = confirmed[!(confirmed$Province.State=="Sichuan" | confirmed$Province.State=="Chongqing"),]
confirmed3 = rbind(new, confirmed2) %>%
  dplyr::rename("ADMIN_NAME" = Province.State) 
confirmed3$ADMIN_NAME <- as.character(confirmed3$ADMIN_NAME)
confirmed3$ADMIN_NAME[confirmed3$ADMIN_NAME == "Tibet"] <- "Xizang"  
confirmed3$ADMIN_NAME[confirmed3$ADMIN_NAME == "Inner Mongolia"] <- "Nei Mongol"
# shapefile
cn <- st_read("ch/ch.shp") 
# left join map and confirmed coronavirus data
virus_map = left_join(cn, confirmed3, by = "ADMIN_NAME")
# determine the cutoff based on quantile
cutoff = c(0, 20, 40, 100, 200, 400, 1000, 10000, 80000)
new_names = as.character(seq(as.Date("2020-01-22"), as.Date("2020-03-01"), by="1 day"))
colnames(virus_map)[18:57] <- new_names
## data cleaning for world trend
world_confirmed1 = colSums(confirmed3[,5:44])
china_confirmed1 = confirmed3 %>%
  dplyr::filter(Country.Region == "Mainland China") 
china_confirmed1 = colSums(china_confirmed1[,5:44])
world_recovery1 = colSums(recovery[,5:44]) 
trend_df = data.frame(world_confirmed = world_confirmed1, world_recovery = world_recovery1, china_confirmed = china_confirmed1, date = seq(as.Date("2020-01-22"), as.Date("2020-03-01"), by="days"))
trend_df_melt = melt(trend_df, id = "date")
# a clearer theme
theme2 <- theme(
  plot.background = element_rect(fill = "transparent", colour = NA),
  panel.background = element_rect(fill = "transparent", color = NA), 
  aspect.ratio = 0.2, 
  panel.grid.major.x = element_blank(), 
  panel.grid.major.y = element_line(color = "gray45", size = 0.2), 
  legend.key = element_rect(fill = NA),
  legend.position = "bottom",
  legend.direction = "horizontal"
)


# data cleaning for world map
data(World)
world_shapefiles = World %>%
  rename("Country.Region" = name)
world_cases = confirmed3 %>%
  dplyr::select(!ADMIN_NAME & !Lat & !Long) %>%
  group_by(Country.Region) %>%
  summarise_each(funs(sum))
# replace some country regions, to achieve consistency with World shapefiles
world_cases$Country.Region <- as.character(world_cases$Country.Region)
world_cases$Country.Region[world_cases$Country.Region=="South Korea"] = "Korea"
world_cases$Country.Region[world_cases$Country.Region=="US"] = "United States"
world_cases$Country.Region[world_cases$Country.Region=="UK"] = "United Kingdom"
world_cases$Country.Region[world_cases$Country.Region=="Czech Republic"] = "Czech Rep."
world_cases$Country.Region[world_cases$Country.Region=="Dominican Republic"] = "Dominican Rep."
# add hongkong, macau cases into china, delete others & signapore cases
newline2 = data.frame("Country.Region" = "China")
new2 = cbind(newline2, world_cases[world_cases$Country.Region == "Hong Kong",2:41] + world_cases[world_cases$Country.Region == "Macau",2:41] + world_cases[world_cases$Country.Region == "Mainland China",2:41])
world_cases2 = world_cases[!(world_cases$Country.Region == "Mainland China" | world_cases$Country.Region == "Hong Kong" | world_cases$Country.Region == "Macau" | world_cases$Country.Region == "Singapore" | world_cases$Country.Region == "Bahrain" | world_cases$Country.Region == "Others" | world_cases$Country.Region == "San Marino" | world_cases$Country.Region == "Monaco" | world_cases$Country.Region == "North Macedonia"),]
world_cases3 = rbind(new2, world_cases2)
virus_world_map = left_join(world_shapefiles, world_cases3, by = "Country.Region")
virus_world_map = virus_world_map %>%
  dplyr::select(!sovereignt & !continent & !area & !pop_est & !pop_est_dens & !economy & !income_grp & !gdp_cap_est &! life_exp &!well_being &! footprint &!inequality &!HPI) %>%
  rename("ADMIN_NAME" = Country.Region) 
colnames(virus_world_map)[3:42] <- new_names
# omit na rows for possible label selection
virus_world_map_selection = na.omit(virus_world_map) 

## data cleaning for us map
statemap = st_transform(us_states, 2163) %>%
  dplyr::select(NAME, geometry) %>%
  rename("ADMIN_NAME" = NAME)
us_cases = confirmed3 %>%
  dplyr::filter(Country.Region == "US") %>%
  dplyr::select(!Lat & !Long) %>%
  separate(ADMIN_NAME, c("county", "State"), sep = ", ") %>%
  dplyr::select(!county & !Country.Region)
us_cases = na.omit(us_cases)
us_cases$State[us_cases$State=="NE (From Diamond Princess)"] = "NE"
us_cases$State[us_cases$State=="CA (From Diamond Princess)"] = "CA"
us_cases$State[us_cases$State=="TX (From Diamond Princess)"] = "TX"
us_cases = us_cases %>%
  dplyr::group_by(State) %>%
  summarise_each(funs(sum)) %>%
  rename("ADMIN_NAME" = State)
statemap$ADMIN_NAME = state2abbr(statemap$ADMIN_NAME)
virus_us_map = left_join(statemap, us_cases, by = "ADMIN_NAME")
colnames(virus_us_map)[2:41] <- new_names
virus_us_map <- replace.value(virus_us_map,new_names,0,NA)
total = sum(confirmed3$X3.1.20)
## user interface
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



server = function(input, output) {
  output$chinamap = renderLeaflet({
    cnmap = tm_basemap(leaflet::providers$CartoDB.PositronNoLabels, group = "CartoDB basemap") +
      tm_shape(virus_map) + 
      tm_polygons(col = as.character(input$date), breaks = cutoff, palette="YlOrRd", 
                  title = paste0("Confirmed Cases ", as.character(input$date)), id = "ADMIN_NAME",
                  popup.vars=c("Confirmed "= as.character(input$date))) +
      tm_layout(legend.outside = TRUE, legend.outside.position = "right", legend.text.size = 0.5) +
      tm_text("ADMIN_NAME", col = "grey20", alpha=0.6, size = "AREA", fontfamily = "serif") +
      tm_view(text.size.variable = TRUE)
    tmap_leaflet(cnmap)
  })
  
  output$worldmap = renderLeaflet({
    wdmap = tm_basemap(leaflet::providers$CartoDB.PositronNoLabels, group = "CartoDB basemap") +
      tm_shape(virus_world_map) + 
      tm_polygons(col = as.character(input$date2), border.alpha = 0.5, breaks = cutoff, 
                  palette="YlOrRd", colorNA = "aliceblue", textNA = "< 1", title = paste0("Confirmed Cases ", as.character(input$date2)),
                  id = "ADMIN_NAME", popup.vars=c("Confirmed " = as.character(input$date2))) +
      tm_layout(legend.outside = TRUE, legend.outside.position = "right") +
      tm_text("ADMIN_NAME", col = "grey20", alpha = 0.6, size = "AREA", fontfamily = "serif") +
      tm_format_World() + 
      tm_style_gray() +
      tm_view(text.size.variable = TRUE)
    tmap_leaflet(wdmap)
  })
  
  output$trend = renderPlot({
    ggplot(trend_df_melt, aes(x=date,y=value,colour=variable,group=variable)) + 
      geom_line(size = 1) +
      geom_point() +
      scale_color_manual(name = element_blank(), labels = c("World Confirmed","World Recovery", "China Confirmed"), 
                         values=c("#E41A1C","#4DAF4A","#FF7F00")) + 
      labs(x = "", y = "", title = "2019-ncov Cases World Trend") +
      scale_x_date(date_labels = "%b %d", breaks = seq(as.Date("2020-01-22"), as.Date("2020-03-01"), by="5 days")) + 
      scale_y_continuous(breaks = c(20000, 40000, 60000, 80000), labels = c("20k", "40k", "60k", "80k")) +
      theme2
  })
  
  output$usmap = renderLeaflet({
    unmap = tm_basemap(leaflet::providers$CartoDB.PositronNoLabels, group = "CartoDB basemap") +
      tm_shape(virus_us_map) + 
      tm_polygons(col = as.character(input$date3), breaks = cutoff, palette="YlOrRd", title = "Confirmed Cases", 
                  id = "ADMIN_NAME", popup.vars=c("Confirmed" = as.character(input$date3)), 
                   colorNA = "aliceblue", textNA = "< 1") +
      tm_layout(legend.outside = TRUE, legend.outside.position = "right") +
      tm_text("ADMIN_NAME", col = "grey20", alpha = 0.6, size = as.character(input$date3), fontfamily = "serif")
    tmap_leaflet(unmap)
  })
  
  output$total = renderText({ 
    paste("Total confirmed Cases:", total)
  })
  
  output$update = renderText({ 
    paste("Last Update on March 3")
  })
  
}
shinyApp(ui, server)
