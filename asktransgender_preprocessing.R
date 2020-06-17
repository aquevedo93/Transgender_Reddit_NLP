#Clearing out environment
rm(list = ls())

#Loading packages
require(tidyverse)
require(stringr)
require(textclean)
require(lubridate)

###### Importing Dataset ######

#Reading in dataframe scrapped on May 6th
at_corpus <- read_csv("asktransgender_corpus.csv")

#Checking dimensions 
#258,636 rows and 9 columns 
dim(at_corpus)

#Checking feature names
names(at_corpus)


###### Pre-Processing ######

#Arranging dataset by `score`, having the most up-voted topics of all time up top
#Changing the order of columns
#Removing 'created' column
at_corpus<- at_corpus %>%
  arrange(desc(score))%>%
  select(id, subreddit, title, body,score, num_comms, timestamp, url)


#Printing the body of a post
at_corpus$body[4]

#Checking for missing values 
#Most of the missing values occur in the `body` feature. Given that we are mostly interested in 
#analyzing the content of the posts, we will filter out NAs. 
colSums(is.na(at_corpus))

#Deleting missing values (keeping only complete cases)
at_corpus<-at_corpus[complete.cases(at_corpus), ]

#There are 70,888 entries with bodies consisting of the following word [deleted] and 11,878 consisting of the word [removed].Removing them from dataset since we are interested in analyzing text from the bodies.
deleted_body<- at_corpus %>% 
  filter(str_detect(body, '^\\[deleted].*$'))

removed_body<- at_corpus %>% 
  filter(str_detect(body, '^\\[removed].*$'))

at_corpus<- at_corpus %>% 
  filter(!str_detect(body, '^\\[deleted].*$'))%>%
  filter(!str_detect(body, '^\\[removed].*$'))

#Filtering out rows whose bodies have no blank spaces. These include bodies consisting of only emojis, hyperlinks, one word texts, or only blank spaces. 
b_body<- at_corpus %>% 
  filter(!str_detect(body, '[:blank:]'))

at_corpus<- at_corpus %>% 
  filter(str_detect(body, '[:blank:]'))

#At this point, we have removed 83,310 posts, resulting in 169,264 rows and 8 columns. 

#Removing hyperlinks
at_corpus$title <-str_replace_all(at_corpus$title," ?(f|ht)tp\\S+\\s*", "")
at_corpus$body <-str_replace_all(at_corpus$body," ?(f|ht)tp\\S+\\s*", "")
at_corpus$title <-str_replace_all(at_corpus$title,"\\S*\\.com\\b|\\S*\\.co.in\\b","")
at_corpus$body <-str_replace_all(at_corpus$body,"\\S*\\.com\\b|\\S*\\.co.in\\b","")
at_corpus$title <-str_replace_all(at_corpus$title,'(www)\\S+\\s*',"")
at_corpus$body <-str_replace_all(at_corpus$body,'(www)\\S+\\s*',"")

#Removing subreddits 
at_corpus$title <-str_replace_all(at_corpus$title,"(?:^| )(/?r/[a-z]+)", "")
at_corpus$body <-str_replace_all(at_corpus$body,"(?:^| )(/?r/[a-z]+)", "")

#Removing mentions to usernames
at_corpus$title <-str_replace_all(at_corpus$title,"(?:^| )(/?u/[a-z]+)", "")
at_corpus$body <-str_replace_all(at_corpus$body,"(?:^| )(/?u/[a-z]+)", "")

#Removing hashtags
at_corpus$title <-str_replace_all(at_corpus$title,"#\\S+", "")
at_corpus$body <-str_replace_all(at_corpus$body,"#\\S+", "")

#Removing mentions
at_corpus$title <-str_replace_all(at_corpus$title,"@\\S+", "")
at_corpus$body <-str_replace_all(at_corpus$body,"@\\S+", "")

#Removing control characters
at_corpus$title <-str_replace_all(at_corpus$title,"[[:cntrl:]]", "")
at_corpus$body <-str_replace_all(at_corpus$body,"[[:cntrl:]]", "")

#Replacing contractions in title and body
at_corpus$title <- replace_contraction(at_corpus$title)
at_corpus$body <- replace_contraction(at_corpus$body)

#Removing all non-ASCII characters (emojis, in this case) from title and body
at_corpus$title <- str_replace_all(at_corpus$title,"[^\x01-\x7F]", "")
at_corpus$body <- str_replace_all(at_corpus$body,"[^\x01-\x7F]", "")

#Removing non alphanumeric or periods and commas (removing special characters)
at_corpus$title <- str_replace_all(at_corpus$title,"[^a-zA-Z0-9.,]", " ")
at_corpus$body <- str_replace_all(at_corpus$body,"[^a-zA-Z0-9.,]", " ")

#Trimming whitespace in title and body
at_corpus$title <- str_squish(at_corpus$title)
at_corpus$body <- str_squish(at_corpus$body)

#Creating a column of all text, combining title and body 
at_corpus <- within(at_corpus,  all_text <- paste(title, body, sep=" "))

#Re-arranging column order and keeping all_text instead of title and body
at_corpus_all<- at_corpus %>%
  select(id,subreddit,all_text,score, num_comms, timestamp)

#Making timestamp a date variable
at_corpus_all$timestamp <- as_date(at_corpus_all$timestamp)

#Creating year, month, week variables 
at_corpus_all$year <- year(at_corpus_all$timestamp)
at_corpus_all$month <- month(at_corpus_all$timestamp)
at_corpus_all$week_day <- weekdays(as.Date(at_corpus_all$timestamp))

#Creating a variable for before or after trump announced his candidacy in 2015
#at_corpus_all$Trump_Candidacy <- if_else(at_corpus_all$timestamp >= "2015-06-15", "After Trump Candidacy", "Before Trump Candidacy")

#Creating a variable for before or after gay marriage was approved federally
at_corpus_all$Gay_Marriage <- if_else(at_corpus_all$timestamp >= "2015-06-26", "After Approval", "Before Approval")

#Creating a variable for length of text
at_corpus_all$char_length<- str_length(at_corpus_all$all_text) 

#Exporting as csv
write_csv(at_corpus_all,'asktransgender_clean.csv')
