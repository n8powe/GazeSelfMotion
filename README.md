# GazeSelfMotion
This is a repository that includes the code for running a machine learning model that predicts head motion given gaze centered images. 

# Data preprocessing

The matlab script builds the dataset. It takes full resolution images and downsamples to a manageable resolution for training. It also creates the labels.

# Modeling running

There are two versions of the model. One without recurrent layers and one with. They otherwise have the same structure and have the same loss function. 