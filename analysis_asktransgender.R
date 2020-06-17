#Clearing out environment
rm(list = ls())

#Loading packages
library(tidyverse)
library(stringr)
library(quanteda)
library(scales)
library(SpeedReader)
library(slam)
library(stm)
library(stmCorrViz)
library(xgboost)
library(caret)
library(ROCR)
library(glmnet)
library(pROC)
library(RColorBrewer)
theme_set(theme_bw())



#### Corpus Object and DTM   ####

#Reading in the pre-processed dataframe
at_corpus_all <- read_csv("asktransgender_clean.csv")

#Filtering selected documents 
at_corpus_all<- at_corpus_all%>%
  filter(!(id %in% c("4y91pl", "1tk596","sckyc", 
                     "58yh1n", "5ggm5u", "bb8amq", "2k8dah", 
                     "3kt8bf", "21s8hf", "676lvk", "eph293", "6rmlw4", "7wyr5r")))

#Converting dataframe into a corpus object
reddit_corp<- corpus(at_corpus_all,
                          docid_field = "id",
                          text_field = "all_text")

summary(reddit_corp)

#Pulling out some basic summary data:
summary_data <- as.data.frame(summary(reddit_corp, n= 169251))

#Obtaining a DTM removing punctuation, numbers, and stopwords
dtm_c <- dfm(reddit_corp,
             remove_punct = TRUE,
             remove_numbers = TRUE,
             remove = stopwords("english"))

#Looking at number of features:
dtm_c

#Trimming and making sure no document is dropped 
dtm_c <- dfm_trim(dtm_c,
                  min_docfreq= 0.0001,
                  max_docfreq = 0.1,
                  docfreq_type = "prop")

dtm_c
summary(rowSums(dtm_c))




#### Exploratory Data Analysis  ####

ggplot(at_corpus_all, aes(x = factor(year))) +
  geom_bar(colour = "blue", fill = "white") +
  labs(title = "Distribution of Posts by Year",
       x= "Year",
       y= "Number of Posts")+
  theme(plot.title = element_text(face="bold"),
        axis.text.x = element_text(angle=45,  hjust = 1),
        axis.title.x = element_text(face="bold"),
        axis.title.y = element_text(face="bold"))

ggplot(at_corpus_all, aes(x = timestamp)) +
  geom_bar(colour = "grey", fill = "white") +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y")+
  geom_vline(xintercept = as.numeric(ymd("2015-06-26")), linetype="dashed", 
             color = "red", size=0.8)+
  labs(title = "Distribution of Posts by Date",
       subtitle= "Before and After Obergefell v. Hodges",
       x= "Year",
       y= "Number of Posts")+
  theme(plot.title = element_text(face="bold"),
        axis.text.x = element_text(angle=45,  hjust = 1),
        axis.title.x = element_text(face="bold"),
        axis.title.y = element_text(face="bold"))



#### Unsupervised Learning  ####

### Complete Corpus ### 

#Fitting a simple topic model (LDA)
lda_fit_c <- stm(dtm_c,
                 K = 20,
                 seed = 12345,
                 verbose = TRUE)

#Displaying the top 20 words in each topic:
pdf(file = "Topic_Wordsc1.pdf",
    width = 8,
    height = 11)
plot.STM(lda_fit_c,
         type="labels",
         topics = 1:10)
dev.off()

pdf(file = "Topic_Wordsc11.pdf",
    width = 8,
    height = 11)
plot.STM(lda_fit_c,
         type="labels",
         topics = 11:20)
dev.off()

#Topic Summaries 
pdf(file = "Topic_Summaries_cc.pdf",
    width = 12,
    height = 7)
plot.STM(lda_fit_c ,
         type="summary",
         n = 8)
dev.off()

#Taking a look at topic quality
out_c <- quanteda::convert(dtm_c, to = "stm")
docs_c <- out_c$documents
vocab_c <- out_c$vocab
meta_c <- out_c$meta

#Making a plot for models without content covariates, only returns coherence
#scores for each topic when content covariates are specified:
topicQuality(model=lda_fit_c, documents=docs_c)

#Getting estimates of topic correlcations within documents:
cors_c <- topicCorr(lda_fit_c)

#Making a network plot:
plot(cors_c)

#Fitting an STM
stm_c <- stm(dtm_c,
             prevalence = as.formula("~score+num_comms+Gay_Marriage"),
             data = docvars(dtm_c),
             K = 20,
             seed = 12345,
             verbose = TRUE)

#Topic Summaries 
pdf(file = "Topic_Summaries_STM_frex.pdf",
    width = 12,
    height = 7)
plot.STM(stm_c,
         type="summary",
         labeltype = "frex",
         n = 8)
dev.off()

#Looking at Topic Quality 
topicQuality(model=stm_c, documents=docs_c)
print(sageLabels(stm_c))

#Getting estimated effects
estimates <- estimateEffect(
  1:20~score+num_comms+Gay_Marriage,
  stm_c,
  metadata = meta_c,
  uncertainty = "Global")

#Topic Prevalence Before and After Gay Marriage Ruling 
pdf(file = "Marriage_Estimates.pdf",
    width = 12,
    height = 12)
plot(estimates,
     covariate = "Gay_Marriage",
     topics = c(4,9,19,18,6,14,12,11),
     model = stm_c,
     method = "difference",
     cov.value1 = "Before Approval",
     cov.value2 = "After Approval",
     xlab = "Before Gay Marriage Ruling   ... After Gay Marriage Ruling",
     main = "Effect of Before vs. After Obergefell",
     labeltype = "custom",
     custom.labels = c("Mental Health",
                       "Relationships",
                       "Legal Name",
                       "Family",
                       "Transphobia",
                       "Hormones",
                       "Sexuality", 
                       "Quesioning Identity"))
dev.off()

#Topic Prevalence with Chaning Scores 
pdf(file = "Score_Estimates.pdf",
    width = 12,
    height = 12)
plot(estimates,
     "score",
     method = "continuous",
     topics = c(4,9,19,18,6,14,12,11),
     xlab = "Score",
     main = "Effect of Score on Expected Topic Proportion",
     labeltype = "custom",
     custom.labels = c("Mental Health",
                       "Relationships",
                       "Legal Name",
                       "Family",
                       "Transphobia",
                       "Hormones",
                       "Sexuality",
                       "Identity Questioning"))
dev.off()

#Topic Prevalence with Number of Comments
pdf(file = "Num_Comms_Estimates.pdf",
    width = 12,
    height = 12)
plot(estimates,
     "num_comms",
     method = "continuous",
     topics = c(4,9,19,18,6,14,12,11),
     xlab = "Number of Comments",
     main = "Effect of Number of Comments on Expected Topic Proportion",
     labeltype = "custom",
     custom.labels = c("Mental Health",
                       "Relationships",
                       "Legal Name",
                       "Family",
                       "Transphobia",
                       "Hormones",
                       "Sexuality",
                       "Identity Questioning"))
dev.off()

#Topic heirarchy:
stmCorrViz(stm_c, "stm-interactive-correlation.html",
           documents_raw = texts(reddit_corp),
           documents_matrix = out_c$documents)

#Topic validation
findThoughts(stm_c,
             texts = texts(reddit_corp),
             topics = 4,
             n = 2)

# we can also extracta trace plot of the approximate model log likelihood:
pdf(file = "Trace_Plot.pdf",
    width = 6,
    height = 4)
plot(stm_c$convergence$bound,
     ylab="Approximate Objective",
     main="Trace Plot")
dev.off()



#### Supervised Learning  ####

# pull out the document level covariates:
doc_features <- docvars(dtm_c)

# add a numeric encoding of the features where
# Before = 0, After = 1
doc_features$gay_marriage_numeric <- 0
doc_features$gay_marriage_numeric[which(doc_features$Gay_Marriage== "After Approval")] <- 1

# lets start by training a supervised classifier for a binary classification
# problem using a lasso (regularized) logistic regression model.

# For this problem, lets see if we can classify whether a post was writen before of after the approval of same-sex marriage. 

# partition our data into train and test sets:
trainIndex <- createDataPartition(doc_features $gay_marriage_numeric,
                                  p = 0.8,
                                  list = FALSE,
                                  times = 1)
# pull out the first column as a vector:
trainIndex <- trainIndex[,1]

train <- dtm_c[trainIndex, ]
test <- dtm_c[-trainIndex, ]  

# Create separate vectors of our outcome variable for both our train and test sets
# We'll use these to train and test our model later
train.label  <- doc_features$gay_marriage_numeric[trainIndex]
test.label   <- doc_features$gay_marriage_numeric[-trainIndex]

# train our lasso
cvfit = cv.glmnet(x = train,
                  y = train.label,
                  family = "binomial",
                  type.measure = "class")

log(cvfit$lambda.min)

pdf(file = "Optimal_Lasso_Penalty.pdf",
    width = 10,
    height = 5)
plot(cvfit)
dev.off()

# lets take a look at the coefficients:
head(coef(cvfit, s = "lambda.min"),n = 50)

features<-coef(cvfit, s = "lambda.min")

features<- features%>%
  as.matrix()%>%
  as.data.frame()

# make predictions
pred <- predict(
  cvfit,
  newx = test,
  s = "lambda.min",
  type = "response")

# select a threshold and generate predcited labels:
pred_vals <- ifelse(pred >= 0.5203144, 1, 0)

# Create the confusion matrix
confusionMatrix(table(pred_vals, test.label),positive="1")

# Use ROCR package to plot ROC Curve
lasso.pred <- prediction(pred, test.label)
lasso.perf <- performance(lasso.pred, "tpr", "fpr")

pdf(file = "LASSO_ROC.pdf",
    width = 6,
    height = 6)
plot(lasso.perf,
     avg = "threshold",
     colorize = TRUE,
     lwd = 1,
     main = "ROC Curve w/ Thresholds",
     print.cutoffs.at = c(.9,.8,.7,.6,.5,.4,.3,.2,.1),
     text.adj = c(-0.5, 0.5),
     text.cex = 0.5)
grid(col = "lightgray")
axis(1, at = seq(0, 1, by = 0.1))
axis(2, at = seq(0, 1, by = 0.1))
abline(v = c(0.1, 0.3, 0.5, 0.7, 0.9), col="lightgray", lty="dotted")
abline(h = c(0.1, 0.3, 0.5, 0.7, 0.9), col="lightgray", lty="dotted")
lines(x = c(0, 1), y = c(0, 1), col="black", lty="dotted")
dev.off()

# we can also get the AUC for this predictor:
auc.perf = performance(lasso.pred,
                       measure = "auc")
auc.perf@y.values[[1]]

# and look at accuracy by threshold
acc.perf = performance(lasso.pred, measure = "acc")
plot(acc.perf)

# we can also calculate the optimal accuracy and its associated threshold:
ind = which.max( slot(acc.perf, "y.values")[[1]] )
acc = slot(acc.perf, "y.values")[[1]][ind]
cutoff = slot(acc.perf, "x.values")[[1]][ind]
print(c(accuracy= acc, cutoff = cutoff))



