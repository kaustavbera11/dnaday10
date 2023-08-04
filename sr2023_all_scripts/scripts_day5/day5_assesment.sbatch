#!/bin/bash
#SBATCH --job-name=day5_assesment_with_loop     # Job name
#SBATCH --mail-type=ALL                         # Mail events (NONE, BEGIN, END, FAIL, ALL)
#SBATCH --mail-user=kabe4658@colorado.edu       # Where to send mail
#SBATCH --nodes=1                               # Number of nodes requested
#SBATCH --ntasks=8                              # Number of CPUs (processor cores/tasks)
#SBATCH --mem=2gb                               # Memory limit
#SBATCH --time=01:30:00                         # Time limit hrs:min:sec
#SBATCH --partition=compute                    # Partition/queue requested on server
#SBATCH --output=/scratch/Users/kaustavbera11/eofiles/%x.%j.out    # Standard output: the %x will be replaced with job_name and the %j by the job id
#SBATCH --error=/scratch/Users/kaustavbera11/eofiles/%x.%j.err     # Standard error log

### Displays the job context
echo Job: $SLURM_JOB_NAME with ID $SLURM_JOB_ID
echo Running on host `hostname`
echo Job started at `date +"%T %a %d %b %Y"`
echo Directory is `pwd`
echo Using $SLURM_NTASKS processors across $SLURM_NNODES nodes

##############################
### Assigns path variables ###
##############################

## the fastq files will be used as input to fastqc and trimmomatic
## trimmed reads will then be passed on to the mapping step


FILENAME=${rootname}
INDIR=${indir}

DATADIR=${INDIR}
FASTQ=${DATADIR}

OUTDIR=${outdir}
FASTQC=${OUTDIR}/fastqc
HISAT2=${OUTDIR}/hisat2
TRIM=${OUTDIR}/trimmomatic

#FILENAME=chr21Ethan_repA

mkdir -p ${OUTDIR}
mkdir -p ${FASTQC}
mkdir -p ${TRIM}
mkdir -p ${HISAT2}

echo "\n Sbash started working upon $FILENAME \n"
######################
### Loads modules   ##
######################
module load fastqc/0.11.5 
module load trimmomatic
module load hisat2/2.1.0
module load samtools/1.8

#######################
##Run the pipeline   ##
#######################
##1: Run fastqc on the samples (here run on example file ${FILENAME}.RNA.end1.fastq)
##1: Run fastqc on the samples (here run on example file ${FILENAME}.RNA.end1.fastq)

fastqc ${FASTQ}/${FILENAME}.RNA.end1.fastq -o ${FASTQC}
fastqc ${FASTQ}/${FILENAME}.RNA.end2.fastq -o ${FASTQC}



##2: Trim FASTQ Files                                                                                                                                                                                                                                                
java -jar /opt/trimmomatic/0.36/trimmomatic-0.36.jar PE \
 -threads 8 \
 -phred33 \
 -trimlog ${TRIM}/trimlog \
 ${FASTQ}/${FILENAME}.RNA.end1.fastq ${FASTQ}/${FILENAME}.RNA.end2.fastq \
 ${TRIM}/${FILENAME}.RNA.end1.trim.fastq ${TRIM}/${FILENAME}.RNA.end1.unpaired.fastq \
 ${TRIM}/${FILENAME}.RNA.end2.trim.fastq ${TRIM}/${FILENAME}.RNA.end2.unpaired.fastq \
 ILLUMINACLIP:/opt/trimmomatic/0.36/adapters/TruSeq3-PE.fa:2:30:10 \
 LEADING:3 TRAILING:3 SLIDINGWINDOW:4:15 MINLEN:36

##3: Check Post-Trimming QC stats

fastqc ${TRIM}/*.trim.fastq -o ${FASTQC}

##4: Map trimmed reads to reference genome                                                                                                                                                     
hisat2 --very-fast -x /scratch/Shares/public/genomes/hisatfiles/hg38/HISAT2/genome \
-1 ${TRIM}/${FILENAME}.RNA.end1.trim.fastq \
-2 ${TRIM}/${FILENAME}.RNA.end2.trim.fastq \
> ${HISAT2}/${FILENAME}.RNA.sam \
2> ${HISAT2}/${FILENAME}.hisat2_maptstats.txt

##5: Convert SAM file to BAM file and index the BAM files
##The BAM file is a compressed binary version of a SAM file, so takes up less space
##The sorted bam also takes up less space

###5.1 - convert SAM to BAM 
samtools view -@ 8 -bS -o ${HISAT2}/${FILENAME}.RNA.bam ${HISAT2}/${FILENAME}.RNA.sam

###5.2 - sort bam file
samtools sort -@ 8 ${HISAT2}/${FILENAME}.RNA.bam > ${HISAT2}/${FILENAME}.RNA.sorted.bam

###5.3 - index sorted bam file
samtools index ${HISAT2}/${FILENAME}.RNA.sorted.bam  ${HISAT2}/${FILENAME}.RNA.sorted.bam.bai

 
#echo Job finished at `date +"%T %a %d %b %Y"`

INDIR=/scratch/Users/kaustavbera11/day5/assesment/hisat2

# We'll also need to give the Genome size and info so that the file can be compressed into a TDF
genomeFasta=/scratch/Shares/public/genomes/hisatfiles/hg38/hg38.fa
genomeSizes=/scratch/Shares/public/genomes/hisatfiles/hg38/hg38.chrom.sizes


##########################################################################################
############### LOAD REQUIRED MODULES ####################################################
module load samtools/1.8
module load bedtools/2.25.0
module load igvtools/2.3.75

##########################################################################################
################## PRINT JOB INFO ########################################################

printf "\nfastq Directory: $INDIR"
printf "\nOutput Directory: $OUTDIR"
printf "\nRun on: $(hostname)"
printf "\nRun from: $(pwd)"
printf "\nScript: $0\n"
date

printf "\nYou've requested $SLURM_CPUS_ON_NODE core(s).\n"

##########################################################################################
################## RUN JOB ###############################################################

echo BedGraph and TDF

BEDGRAPHdir=${OUTDIR}/bedgraphForTdf
TDFdir=${OUTDIR}/tdf
mkdir -p ${BEDGRAPHdir} ${TDFdir}

##########################################################################################
################## PRINT JOB INFO ########################################################
# A bedgraph condenses a BAM file into a simple histogram of reads for each region in the genome.

# Because our file is paired end, we have to process each end separately. To make bedgraphs, we also need to
# process each strand separately. So, we have to make 4 different files:
# First, read1 bedgraph on the + strand. Read1 is reverse-stranded, so we have to flip it!
# Second, read1 bedgraph on the - strand. Read1 is reverse-stranded, so we have to flip it!
# Third, read2 bedgraph on the + strand
# Fourth, read2 bedgraph on the - strand
# Then, we'll concatenate them all together to make 1 big bedgraph file


# First, we extract Read1 from the bamfile. This is a little tricky to understand. SAMtools uses a code to determine read1 and read2. We give it that code
# using the -f parameter. 

# To learn more about these codes, visit http://davetang.org/wiki/tiki-index.php?page=SAMTools#Extracting_only_the_first_read_from_paired_end_BAM_files
# 0x0040 is hexadecimal for 64 (i.e. 16 * 4), which is binary for 1000000, corresponding to the first read in the pair.
samtools view \
        -h -b -f 0x0040 \
        ${INDIR}/${FILENAME}.RNA.sorted.bam \
        > ${BEDGRAPHdir}/${FILENAME}.RNA.pairfirst.bam

echo Finished pulling out the first read with flags.

# Now, we get Read2 from the bamfile. Same story, we need to use a SAMTools flag
# https://broadinstitute.github.io/picard/explain-flags.html
# 128 means second in pair, 128 in hexadecimal is 0x0080
samtools view \
        -h -b -f 0x0080 \
        ${INDIR}/${FILENAME}.RNA.sorted.bam \
        > ${BEDGRAPHdir}/${FILENAME}.RNA.pairsecond.bam

echo Finished pulling out the second read with flags.

# Now, we use genomeCoverageBed to start making bedGraphs. Remember, read1 is reverse-stranded!

genomeCoverageBed \
        -bg -split -strand - \
        -ibam ${BEDGRAPHdir}/${FILENAME}.RNA.pairfirst.bam \
        -g ${genomeSizes} \
        > ${BEDGRAPHdir}/${FILENAME}.RNA.pairfirst.pos.bed

echo Finished putting the read1 negative strand reads on the positive strand in the bedgraph file.

genomeCoverageBed \
        -bg  -split -strand + \
        -ibam ${BEDGRAPHdir}/${FILENAME}.RNA.pairfirst.bam \
        -g ${genomeSizes} | awk -F '\t' -v OFS='\t' '{ $4 = - $4 ; print $0 }' \
        > ${BEDGRAPHdir}/${FILENAME}.RNA.pairfirst.neg.bed

echo Finished putting the read1 postive strand reads on the negative strand in the bedgraph file.

# Now, we repeat the process for Read2!

genomeCoverageBed \
        -bg -split -strand + \
        -ibam ${BEDGRAPHdir}/${FILENAME}.RNA.pairsecond.bam \
        -g ${genomeSizes} \
        > ${BEDGRAPHdir}/${FILENAME}.RNA.pairsecond.pos.bed

echo Finished putting the read2 postive strand reads on the postive strand in the bedgraph file.

genomeCoverageBed \
        -bg -split -strand - \
        -ibam ${BEDGRAPHdir}/${FILENAME}.RNA.pairsecond.bam \
        -g ${genomeSizes} | awk -F '\t' -v OFS='\t' '{ $4 = - $4 ; print $0 }' \
        > ${BEDGRAPHdir}/${FILENAME}.RNA.pairsecond.neg.bed

echo Finished putting the read2 negative strand reads on the negative strand in the bedgraph file.

# Joining the read1 and read2 bedgraphs
    unionBedGraphs \
        -i ${BEDGRAPHdir}/${FILENAME}.RNA.pairfirst.pos.bed ${BEDGRAPHdir}/${FILENAME}.RNA.pairsecond.pos.bed \
        | awk -F '\t' {'print $1"\t"$2"\t"$3"\t"($4+$5)'} \
        > ${BEDGRAPHdir}/${FILENAME}.RNA.pos.bedGraph

    unionBedGraphs \
        -i ${BEDGRAPHdir}/${FILENAME}.RNA.pairfirst.neg.bed ${BEDGRAPHdir}/${FILENAME}.RNA.pairsecond.neg.bed \
        | awk -F '\t' {'print $1"\t"$2"\t"$3"\t"($4+$5)'} \
        > ${BEDGRAPHdir}/${FILENAME}.RNA.neg.bedGraph

echo Finished adding the postive and negative reads from both strands back together.

# Joining the + and - bedGraphs
cat \
        ${BEDGRAPHdir}/${FILENAME}.RNA.pos.bedGraph \
        ${BEDGRAPHdir}/${FILENAME}.RNA.neg.bedGraph \
        > ${BEDGRAPHdir}/${FILENAME}.RNA.bed

# Sorting the final Bedgraph
sortBed \
        -i ${BEDGRAPHdir}/${FILENAME}.RNA.bed \
        > ${BEDGRAPHdir}/${FILENAME}.RNA.BedGraph

echo Finished making the strand corrected sorted bedgraph.

# Compressing the bedGraph into a binary TDF file for easy viewing in IGV
igvtools toTDF \
        ${BEDGRAPHdir}/${FILENAME}.RNA.BedGraph \
        ${TDFdir}/${FILENAME}.tdf \
        ${genomeFasta}

echo Finished making TDF file.
echo Job finished at `date +"%T %a %d %b %Y"`

