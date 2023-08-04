indir=/scratch/Shares/public/sread2023/data_files/day7/bam/
outdir=/scratch/Users/kaustavbera11/workshop-day7/

for pathandfilename in `ls ${indir}*sorted.bam`; do
rootname=`basename $pathandfilename .sorted.bam`
sbatch --export=rootname=$rootname,indir=$indir,outdir=$outdir sbatchRNAscript.sh 
echo $rootname
done


