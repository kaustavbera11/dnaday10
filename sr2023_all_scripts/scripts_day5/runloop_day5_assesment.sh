indir=/scratch/Shares/public/sread2023/data_files/day5/fastq/assessment_fastq/

outdir=/scratch/Users/kaustavbera11/day5/assesment_with_loop

mkdir -p $outdir

for pathandfilename in $(ls ${indir}*.end1.fastq);
do
rootname=$(basename $pathandfilename .RNA.end1.fastq)
echo $rootname
#echo ${indir}
#echo ${outdir}
sbatch --export=indir=$indir,rootname=$rootname,outdir=$outdir day5_assesment.sbatch
done
