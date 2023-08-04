#!/bin/bash
#SBATCH --job-name=Learning_R_submit
#SBATCH --mail-type=ALL                                 # Mail events (NONE, BEGIN, END, FAIL, ALL)
#SBATCH --mail-user=kabe4658@colorado.edu                       # Where to send mail
#SBATCH --nodes=1                                       # Numbers of nodes
#SBATCH --ntasks=1                                      # Number of CPU (tasks)
#SBATCH --time=00:05:00                                 # Time limit hrs:min:sec
#SBATCH --partition=compute                             # Partition/queue requested on server    
#SBATCH --mem=3mb                                       # Memory limit
#SBATCH --output=/scratch/Users/kaustavbera11/workshop-day6/eofiles/%x_%j.out
#SBATCH --error=/scratch/Users/kaustavbera11/workshop-day6/eofiles/%x_%j.err

################################################################################                  
####################### initialize directories  ################################                                                                                                                                     

Rscript /scratch/Users/kaustavbera11/workshop-day6/scripts/Learning_R_submit_aws.R
