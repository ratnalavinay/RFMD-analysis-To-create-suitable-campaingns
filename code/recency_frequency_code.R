rm(list=ls())
library(readxl)
library(rio)
library(moments)
library(stargazer)
library(MASS)
library(PerformanceAnalytics)
library(dplyr)
df <- import("alldata.csv", sheet='alldata')


# creation of an empty tibble
tbl_colnames = c(colnames(df),c('frequency','recency'))
#creating an empty dataframe having colnames same as tribble 
final_frame <- data.frame(matrix(ncol=length(tbl_colnames),nrow=0)) 
colnames(final_frame) = tbl_colnames
str(final_frame)


#for calculating frequency taking lag1,lag2,lag3 for purweek column and replacing NA values with 0 for all the lag columns
#adding up all the lag columns and purweek column to get the frequency 
#for calculating recency we applied lead to the interpurtime column and replaced NA value with 0 and added it to final dataframe using row bind.
for(i in unique(df$id)){
  df1 <- df %>% filter(id==i)
  lag1 = lag(df1$purweek,1)
  lag1[is.na(lag1)] = 0
  lag2 = lag(df1$purweek,2)
  lag2[is.na(lag2)] = 0
  lag3 = lag(df1$purweek,3)
  lag3[is.na(lag3)] = 0
  df1$frequency <- df1$purweek + lag1 + lag2 + lag3
  df1$recency <- dplyr::lead(df1$interpurtime,1)
  df1$recency[is.na(df1$recency)] = 0
  colnames(df1) == colnames(final_frame)
  final_frame <- rbind(final_frame,df1)}



sum(is.na(final_frame$purweek))

final_frame[17802,]$purweek=0

#for d generation
count_dnew=0
for(i in 1:nrow(final_frame)){
  if(i!=73863){
    if(final_frame$id[i]==final_frame$id[i+1])
    {
      if(final_frame$NumAll_Now[i]==0)
      {
        final_frame$d_new[i]=0
        final_frame$log_d[i]=0
      }
      else if(final_frame$NumAll_Now[i]!=0)
      {
        count_dnew=count_dnew+1
        final_frame$d_new[i]=count_dnew
        final_frame$log_d[i]=log(final_frame$d_new[i])
      }
    }
    else if(final_frame$id[i]!=final_frame$id[i+1])
    {
      count_dnew=0;
    }
  }
}
#d$log_d=log(d$d_new)

str(final_frame)

unique(final_frame$id)
# for NumA_Ever_cat,NumB_Ever_catNumC_Ever_cat generation
final_frame$NumA_Ever_cat <- ifelse(final_frame$NumA_Ever>0, "1",0)
final_frame$NumB_Ever_cat <- ifelse(final_frame$NumB_Ever>0, "1",0)
final_frame$NumC_Ever_cat <- ifelse(final_frame$NumC_Ever>0, "1",0)


#factorizing married variable
final_frame$married <- factor(final_frame$married)
library(plm)
#factorizing variables
final_frame$NumA_Ever_cat = as.factor(final_frame$NumA_Ever_cat)
final_frame$NumB_Ever_cat = as.factor(final_frame$NumB_Ever_cat)
final_frame$NumC_Ever_cat = as.factor(final_frame$NumC_Ever_cat)

# fixed effects model
fixed_plm <- plm(weeklyspend ~ recency + frequency + spendingavg + NumA_Ever_cat + NumB_Ever_cat + NumC_Ever_cat + married + log_d, data=final_frame, index=c("id","weeksin"), model="within")

summary(fixed_plm) 
fixef(fixed_plm)

#checking for na values in the final data frame
sum(is.na(final_frame))

str(final_frame)
library(cluster)
library(factoextra)

#converting variables to integers

final_frame$NumA_Ever_cat=as.integer(final_frame$NumA_Ever_cat)
final_frame$NumB_Ever_cat=as.integer(final_frame$NumB_Ever_cat)
final_frame$NumC_Ever_cat=as.integer(final_frame$NumC_Ever_cat)
final_frame$zipcode=as.integer(final_frame$zipcode)

# removing non int variables from the dataframe

d1=subset(final_frame,select=-c(6))
d1 <- na.omit(d1) 
data3 <- subset(d1, select = - c(married)) 
str(d1)

#forming 3 clsuters

kmeans_3 <-kmeans(data3,3,iter.max = 100,nstart = 10)
clusters <- cbind(data3, cluster = kmeans_3$cluster)

#plotting the clusters

fviz_cluster(kmeans_3, data = data3,
             palette = c("#2E9FDF", "#00AFBB", "#E7B800"), 
             geom = "point", ellipse.type = "convex", ggtheme = theme_bw() )

#fviz_cluster(kmeans_3,data=d1)

scaled_data=as.matrix(scale(data3))

set.seed(123)
# Compute and plot wss for k = 2 to k = 15.
k.max <- 6
data <- scaled_data
wss <- sapply(1:k.max, 
              function(k){kmeans(data, k, nstart=10,iter.max = 10 )$tot.withinss})
wss
plot(1:k.max, wss,
     type="b", pch = 19, frame = FALSE, 
     xlab="Number of clusters K",
     ylab="Total within-clusters sum of squares")

library(dplyr)
clusters %>% group_by(cluster) %>% summarise(avg_recency = mean(recency))
clusters %>% group_by(cluster) %>% summarise(avg_frequency = mean(frequency))
clusters %>% group_by(cluster) %>% summarise(avg_spendingavg = mean(spendingavg))
clusters %>% group_by(cluster) %>% summarise(avg_log_d = mean(log_d))



cluster1=subset(clusters,clusters$cluster==1)
f_cluster1=lm(weeklyspend ~ recency+frequency+spendingavg+as.factor(NumA_Ever_cat)+as.factor(NumB_Ever_cat)+as.factor(NumC_Ever_cat)+log_d+as.factor(hhsize),data=cluster1)
summary(f1_cluster1)
unique(cluster1$id)

cluster2=subset(clusters,clusters$cluster==2)
f_cluster2=lm(weeklyspend ~ recency+frequency+spendingavg+as.factor(NumA_Ever_cat)+as.factor(NumB_Ever_cat)+as.factor(NumC_Ever_cat)+log_d+as.factor(hhsize),data=cluster2)
summary(f_cluster2)
unique(cluster2$id)

cluster3=subset(clusters,clusters$cluster==3)
f_cluster3=lm(weeklyspend ~ recency+frequency+spendingavg+as.factor(NumA_Ever_cat)+as.factor(NumB_Ever_cat)+as.factor(NumC_Ever_cat)+log_d
+as.factor(hhsize),data=cluster3)
summary(f_cluster3)
stargazer(f_cluster1,f_cluster2,f_cluster3,type='text',single.row=TRUE)

unique(cluster3$id)

library(cluster)
library(factoextra)
clusplot(d1,kmeans_3$cluster,lines = 0,shade = TRUE,color = TRUE,labels = 2,plotchar = FALSE,span=TRUE)

kmeansDist(as.matrix(dist(d1)), ClusterNo=2,Centers=NULL,RandomNo=1,maxIt = 2000, PlotIt=FALSE,verbose = F)



kmeans_4 <-kmeans(data3,4,iter.max = 100,nstart = 10)
kmeans_4
clusters_4 <- cbind(data3, cluster = kmeans_4$cluster)
clusters_4_1=subset(clusters,clusters_4$cluster==1)
f_cluster_4_1=lm(weeklyspend ~ recency+frequency+spendingavg+as.factor(NumA_Ever_cat)+as.factor(NumB_Ever_cat)+as.factor(NumC_Ever_cat)+log_d
                  +as.factor(hhsize),data=clusters_4_1)
summary(f_cluster_4_1)
clusters_4_2=subset(clusters,clusters_4$cluster==2)
f_cluster_4_2=lm(weeklyspend ~ recency+frequency+spendingavg+as.factor(NumA_Ever_cat)+as.factor(NumB_Ever_cat)+as.factor(NumC_Ever_cat)+log_d+as.factor(hhsize),data=clusters_4_2)
summary(f_cluster_4_2)
clusters_4_3=subset(clusters,clusters_4$cluster==3)
f_cluster_4_3=lm(weeklyspend ~ recency+frequency+spendingavg+as.factor(NumA_Ever_cat)+as.factor(NumB_Ever_cat)+as.factor(NumC_Ever_cat)+log_d
                  +as.factor(hhsize),data=clusters_4_3)
summary(f_cluster_4_3)
clusters_4_4=subset(clusters,clusters_4$cluster==4)
f_cluster_4_4=lm(weeklyspend ~ recency+frequency+spendingavg+as.factor(NumA_Ever_cat)+as.factor(NumB_Ever_cat)+as.factor(NumC_Ever_cat)+log_d
                  +as.factor(hhsize),data=clusters_4_4)
summary(f_cluster_4_4)

stargazer(fe_cluster_4_1,fe_cluster_4_2,fe_cluster_4_3,fe_cluster_4_4,type='text',single.row=TRUE)


clusters_4 %>% group_by(cluster) %>% summarise(avg_recency = mean(recency))
clusters_4 %>% group_by(cluster) %>% summarise(avg_frequency = mean(frequency))
clusters_4 %>% group_by(cluster) %>% summarise(avg_spendingavg = mean(spendingavg))
clusters_4 %>% group_by(cluster) %>% summarise(avg_log_d = mean(log_d))



fviz_cluster(kmeans_4, data = data3,
             palette = c("#2E9FDF", "#00AFBB", "#E7B800","#FF0000"), 
             geom = "point", ellipse.type = "convex", ggtheme = theme_bw() )


AIC(f_cluster_4_1)
AIC(f_cluster_4_2)
AIC(f_cluster_4_3)
AIC(f_cluster_4_4)
AIC(f_cluster1)
AIC(f_cluster2)
AIC(f_cluster3)
