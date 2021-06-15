#!/bin/zsh
#SBATCH -A b1042             ## account (unchanged)
#SBATCH -p genomics          ## "-p" instead of "-q"
#SBATCH -J mutect2_hg38
#SBATCH --mail-type=FAIL,TIME_LIMIT_90
#SBATCH --mail-user=brian.wray@northwestern.edu
#SBATCH -o "%x.o%j"
#SBATCH -N 1                 ## number of nodes
#SBATCH -n 4                 ## number of cores
#SBATCH -t 10:00:00          ## walltime
#SBATCH --mem=100G
source /etc/zshrc

module purge all
module load gatk/4.1.0
module load java/jdk1.8.0_25

sample={{sample}}
reference_dir="/projects/b1012/xvault/REFERENCES/builds/{{reference}}/bundle"
bam_dir=analysis/bam_files
outfile=analysis/variants/${sample}_{{reference}}_somatic.vcf
bam_outfile=${bam_dir}/${sample}_tumor_norm_mutect2.bam

printf "Running mutect2 on %s, with reference {{reference}}, at " $sample 
date

START=$(date +%s.%N)

set -x
gatk Mutect2 \
	-R ${reference_dir}/{{reference}}.fa \
     {{tumor_files}} {{normal_files}} {{normal_samples}}	--germline-resource ${reference_dir}/somatic-hg38-af-only-gnomad.hg38.vcf.gz \
	--disable-read-filter MateOnSameContigOrNoMappedMateReadFilter \
	-O $outfile 2> logs/${sample}_mutect2.log \
	-bamout $bam_outfile

set +x
END_MUTECT=$(date +%s.%N)
DIFF=$(echo "$END_MUTECT - $START" | bc)
printf "\nMutect2 Processed in %f seconds\n" $DIFF

printf "Finished running mutect2 on %s at " $sample
date
module load python/anaconda3
source activate /projects/b1012/xvault/software/vcf2maf-py37


# sample info
vcfDir=../../analysis/variants
mafDir=../../analysis/vcf2maf_out

fileStub=${sample}_hg38_somatic
inputVcf=${vcfDir}/${fileStub}.vcf
outputMaf=${mafDir}/${fileStub}.maf

cd /projects/b1012/xvault/PROJECTS/Illumina/Abazeed-480/software/mskcc-vcf2maf-754d68a
pwd

START_VCF2MAF=$(date +%s.%N)
set -x
perl vcf2maf.pl --input-vcf ${inputVcf} --output-maf ${outputMaf} --ref-fasta ${reference_dir}/{{reference}}.fa --vep-path=/projects/b1012/xvault/software/vcf2maf-py37/bin {{tumor_ids}} {{normal_ids}} 
set +x

printf "\nFinished at "
date
END_ALL=$(date +%s.%N)
VCF2MAF_DIFF=$(echo "$END_ALL - $START_VCF2MAF" | bc)
DIFF=$(echo "$END_ALL - $START" | bc)
printf "\nVCF2MAF Processed in %f seconds\n" $VCF2MAF_DIFF
printf "\nWhole thing Processed in %f seconds\n" $DIFF
