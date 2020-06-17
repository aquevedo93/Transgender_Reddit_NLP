#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Scraping /r/asktransgender using the Python Reddit API Wrapper (PRAW)
and the Python Pushshift.io API Wrapper (PSAW)

Date: February 4, 2020

@author: Andrea Quevedo
"""

#Using PRAW and PSAW
#The Pushfit.io Reddit API allows us to download more than 1,000 posts
#Will use pushshift search to fetch ids and then use praw to fetch objects
#by using the code from the PRAW scraper.
#The aim is to scrape all the posts in the subreddit /r/asktransgender


#Importing required packages
import praw
from psaw import PushshiftAPI
import pandas as pd
import datetime as dt


#Connecting to Reddit
reddit = praw.Reddit(client_id='PERSONAL_USE_SCRIPT_14_CHARS', 
                     client_secret='SECRET_KEY_27_CHARS ', 
                     user_agent='YOUR_APP_NAME', 
                     username='YOUR_REDDIT_USER_NAME', 
                     password='YOUR_REDDIT_LOGIN_PASSWORD')


#Connecting to the PushfitAPI via reddit credentials
api = PushshiftAPI(reddit)

#Setting start date we want to scrape from
#Set it to August 8th, 2009 since that was the date the /r/asktransgender
#subreddit was created
start_epoch=int(dt.datetime(2009, 8, 8).timestamp())


#`search_submissions` returns a generator object
#The limit was set tp 250,000 since, when checking the subreddit's history in
#Pushfit.io, the total numer of posts till date resulted in 258,634
#You can check on the following link:
# https://api.pushshift.io/reddit/search/submission/?subreddit=asktransgender&metadata=true&size=0&after=1249704000

gen= api.search_submissions(after=start_epoch,
                            subreddit='asktransgender',
                            filter=['title', 'score', 'id','subreddit',
                                    'url', 'num_comments','created', 'selftext'],
                            limit=280000)


#Parsing the data
#Creating a dictionary composed of the different features we want to store
topics_dict = { "title":[],
                "score":[],
                "id":[],
                "subreddit":[],
                "url":[],
                "num_comms": [],
                "created": [],
                "body":[]}


#Scrapping the data from the Reddit API and appending it to dictionary
for submission in gen:
    topics_dict["title"].append(submission.title)
    topics_dict["score"].append(submission.score)
    topics_dict["id"].append(submission.id)
    topics_dict["subreddit"].append(submission.subreddit)
    topics_dict["url"].append(submission.url)
    topics_dict["num_comms"].append(submission.num_comments)
    topics_dict["created"].append(submission.created)
    topics_dict["body"].append(submission.selftext)
 

#Converting to dataframe composed of 258,634 rows and 7 columns
topics_data = pd.DataFrame(topics_dict)


#Changing timestamp into datetime format
def get_date(created):
    return dt.datetime.fromtimestamp(created)

_timestamp = topics_data["created"].apply(get_date)


#Creating a new column with datetime for each post
topics_data = topics_data.assign(timestamp = _timestamp)

#Exporting to csv
topics_data.to_csv('asktransgender_corpus_updated.csv', index=False)
