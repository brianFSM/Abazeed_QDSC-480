# Abazeed QDSC-480
#### 18-Feb-2021
##### reference: hg38 / mm10
##### workflow: WES, mutsig
##### analyst: Brian Wray

### Description from redcap
##### Title: PDX Genomic Profiling
##### Brief Description entered in to QDSC form:
> Request to run a WES pipeline on 124 samples. 32 tumors to run Mutect using tumor only mode and 92 have matched PBL normals. The human tumors were implanted in mice and have been dissected from the organism. Therefore, we would like to filter the tumor sample reads into mice and human (using BBMap).  A summary of the output including sequencing depth metrics + MutSig (q values for the most significantly mutated genes) and some visualization of the frequency of mutations and the base substitution distribution would be great.
##### excerpts from Email from Mohamed Abazeed on 24-Feb-2021
> Please find attached a sample sheet.
> P1 means human tumor was passaged once through mouse. P2 means twice.
> The matched normals, when available, are all PBLs (human).
> We have made the move over to hg38 in our other sequencing pipelines, so we prefer hg38.
> Beyond an estimate of the proportion of mouse and human (output refstat file from bbmap) in each sample, we will not need to do anything with the mouse reads.
> Feel free to reach out at any time. I ran a few of the initial samples through this pipeline and got stuck distally with the merge bam function and haven’t had the time to go back and resolve.



### Tools used:
- [bbsplit](https://jgi.doe.gov/data-and-tools/bbtools/bb-tools-user-guide/bbmap-guide/):
    > "BBSplit internally uses BBMap to map reads to multiple genomes at once, and determine which genome they match best."
- bwa (created analysis-ready bams per the instructions in GATK's best practices, using GATK bwa reference)
- GATK (mutect2)
- [vcf2maf](https://github.com/mskcc/vcf2maf)
- [mutsig](http://software.broadinstitute.org/cancer/cga/mutsig)
- python


### To run this project (on e.g. fileBases1.txt), run from Abazeed-480 folder unless otherwise noted
<details> 
	<summary>Get data and trim it</summary> 
	<ol>
		<li>Transfer fastq files from FSMResFiles to quest using globus</li>
		<li>rename _1.fq.gz _R1.fq.gz ./*.gz</li>
		<li>rename _2.fq.gz _R2.fq.gz ./*.gz</li>
		<li>in data folder: loopRNASeqPipeline hg38 -trim -pe</li> 
	</ol> 	
</details>

<details>
	<summary>Split data into human and mouse using bbsplit and create filtered bam files</summary>
	<ol, start="5">
		<li>for i in `cat data/reads/fileBases1.txt`; do sbatch scripts/_01_02_bbsplit_to_bam.sh $i; done # This can be split up into 01 (bbmap) and 02 (make bam files)</li>
	</ol>
	<ul>
	<li>_01_02 goes from trimmed reads all the way to processed bam files. Also creates a stat file recording how many reads are mouse and how many are human. See analysis/bbmap_stats</li>
	</ul>
</details>

<details>
	<summary>Create vcf files, convert to maf files</summary>
	<ol, start="6">
		<li>edit scripts/_03_make_mutect2_script.sh to call the proper fileBases file</li>
		<li>zsh scripts/_03_make_mutect2_script.sh</li>
	</ol>
	<ul>
		<li>This bash script uses a python script I wrote which creates the mutect2 script based on the file names (with P1 and P2 being tumor, and PBL being matched normals). The template being used is in Abazeed-480/templates</li>
	</ul>
	<ol, start="8">
		<li>for i in `ls CBX*.sh`; do sbatch $i; done</li>
	</ol>
	<ul>
		<li>This creates the vcf file and converts it to maf. I move the scripts to scripts/mutect2_scripts when they're done</li>
	</ul>
</details>

### do the following steps after all of the samples have been made into MAF files

<details>
	<summary>Concatenate the per-sample MAFs together, making sure that the MAF header is not duplicated</summary>
	<ol, start="9">
		<li>cd analysis/vcf2maf_out</li>
		<li>cat *.maf | egrep "^#|^Hugo_Symbol" | head -2 > allsamples.vep.maf</li>
		<li>cat *.maf | egrep -v "^#|^Hugo_Symbol" >> allsamples.vep.maf</li>
	</ol>
</details>

<details>
	<summary>Run mutsig in matlab</summary>
	<ol, start="12">
		<li>cd ../../ # go back to Abazeed-480 folder</li>
		<li>module load matlab</li> 
		<li>matlab</li>
		<li>cd software/MutSigCV_1.41</li>
		<li>MutSigCV('../../analysis/vcf2maf_out/allsamples.vep.maf', '../../mutsig_files/exome_full192.coverage.txt', '../../mutsig_files/gene.covariates.txt', '../../analysis/mutsig_results/all_samples_hg38.txt', '../../mutsig_files/mutation_type_dictionary_file.txt', 'chr_files_hg38' )</li>
	</ol>
</details>

### Notes:

- Due to space limitations on quest I processed the reads here in batches. I was careful to not split samples across batches. There are a total of 266 PE reads, so 532 fastq files. I split it up into 7 batches.


- The data are available on fsmresfiles at (globus path): /rdss/bwp9287/fsmresfiles/Radiation_Oncology/Abazeed_Lab/CC_Data/mea_corner/Novogene/C202SC18122898/raw_data/all/

#### mutsig notes:
> Mutsig requires input files that are a challenge to figure out. [This link](https://www.biostars.org/p/164608/) suggests that you don't really need to generate these files yourself, but [this link](http://software.broadinstitute.org/cancer/cga/mutsig_run) suggests that the versions of these files provided by mutsig only work for hg18 or hg19, whereas I'm using hg38. It looks to me like the only files that have coordinates in them are the chr_files_hg38 files.

I created the chr_files_hg38 files myself. The chromosome names in the hg38.fa (/projects/b1012/xvault/REFERENCES/builds/hg38/bundle/hg38.fa) from GATK are full of spaces and non-chr information. Here are the steps I used to create the chr_files_hg38
* sed 's/\s.*$//' hg38.fa > hg38_shortChrNames.fa (remove everything after first space in chr names)
* awk '/^>chr/ {OUT=substr($0,2) ".fa";print " ">OUT}; OUT{print >OUT}' hg38_shortChrNames.fa (splits the fasta up into separate files for each contig)
* for i in `ls ./*.fa`; do newFilename=$(echo $i | sed 's/fa/text/g'); echo ${newFilename}; tail -n +3 $i > ${newFilename}; done (remove first 2 lines from each chr file, which are a blank line followed by the chr name)
* for i in `ls ./*.txt`; do newFile=$(echo $i | sed 's/text/txt/g'); tr -d '\n' < $i > ${newFile}; done (remove all new lines from chr files)
* rm *.text

For some reason I could only get mutsig to work when I put chr_files_hg38 in the same directory as mutsig (i.e. software/MutSigCV_1.41)

> For the MAF file, the following fields are needed:
* Hugo_Symbol
* Chromosome
* Start_Position
* End_Position
* Reference_Allele
* Tumor_Seq_Allele1
* Tumor_Seq_Allele2
* Variant_Classification
* Tumor_Sample_Barcode



This project took a long time to get started because I was having difficulty getting access to the reads. They were stored on FSMResFiles, but getting me access took IT some time. Originally, Matt had copied over the reads for me, but he had only succesffully copied over about 120 of the 532 fastq files. 

Here's the complete list of fastq files:
-rw-r--r-- 1 bwp9287  333M Mar  5 12:19 CBX112A_P2_USE160373L-A1-A55_HJF23DSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287  338M Mar  5 12:19 CBX112A_P2_USE160373L-A1-A55_HJF23DSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  5.5G Mar  5 09:02 CBX112A_P2_USE160373L-A1-A55_HJKGJDSXX_L3_R1.fq.gz
-rw-r--r-- 1 bwp9287  5.6G Mar  5 08:58 CBX112A_P2_USE160373L-A1-A55_HJKGJDSXX_L3_R2.fq.gz
-rw-r--r-- 1 bwp9287  161M Mar  5 12:24 CBX112A_P2_USE160373L-A1-A55_HJMTYDSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287  164M Mar  5 12:24 CBX112A_P2_USE160373L-A1-A55_HJMTYDSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  3.1G Mar  5 11:06 CBX112A_PBL_USE160380L-A32-A36_HJKGJDSXX_L4_R1.fq.gz
-rw-r--r-- 1 bwp9287  3.2G Mar  5 11:01 CBX112A_PBL_USE160380L-A32-A36_HJKGJDSXX_L4_R2.fq.gz
-rw-r--r-- 1 bwp9287  2.1G Mar  5 11:54 CBX174_P1_USE160348L-A4-A62_HJ7YMDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  2.2G Mar  5 11:52 CBX174_P1_USE160348L-A4-A62_HJ7YMDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  214M Mar  5 12:22 CBX174_P1_USE160348L-A4-A62_HJF23DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  218M Mar  5 12:21 CBX174_P1_USE160348L-A4-A62_HJF23DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  329M Mar  5 12:19 CBX174_P1_USE160348L-A4-A62_HJMVHDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  337M Mar  5 12:19 CBX174_P1_USE160348L-A4-A62_HJMVHDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  129M Mar  5 12:26 CBX174_PBL_USE160363L-A61-A3_HJF23DSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287  135M Mar  5 12:26 CBX174_PBL_USE160363L-A61-A3_HJF23DSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  3.4G Mar  5 10:48 CBX174_PBL_USE160363L-A61-A3_HJKGJDSXX_L3_R1.fq.gz
-rw-r--r-- 1 bwp9287  3.5G Mar  5 10:29 CBX174_PBL_USE160363L-A61-A3_HJKGJDSXX_L3_R2.fq.gz
-rw-r--r-- 1 bwp9287   92M Mar  5 12:32 CBX174_PBL_USE160363L-A61-A3_HJMTYDSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287   97M Mar  5 12:31 CBX174_PBL_USE160363L-A61-A3_HJMTYDSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  4.6G Mar  5 09:24 CBX18_P2_USE160351L-A15-A55_HJ7YMDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  4.7G Mar  5 09:22 CBX18_P2_USE160351L-A15-A55_HJ7YMDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  118M Mar  5 12:28 CBX18_P2_USE160351L-A15-A55_HJF23DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  120M Mar  5 12:28 CBX18_P2_USE160351L-A15-A55_HJF23DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  3.5G Mar  5 10:32 CBX18_PBL_USE160480L-A6-A36_HJJY2DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  3.7G Mar  5 10:10 CBX18_PBL_USE160480L-A6-A36_HJJY2DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  619M Mar  5 12:10 CBX243_P1_USE160354L-A26-A35_HJ7YMDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  640M Mar  5 12:09 CBX243_P1_USE160354L-A26-A35_HJ7YMDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  132M Mar  5 12:26 CBX243_P1_USE160354L-A26-A35_HJF23DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  137M Mar  5 12:26 CBX243_P1_USE160354L-A26-A35_HJF23DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  3.5G Mar  5 10:26 CBX243_PBL_USE160386L-A54-A67_HJ7YMDSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287  3.6G Mar  5 10:20 CBX243_PBL_USE160386L-A54-A67_HJ7YMDSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  1.3G Mar  5 12:00 CBX258_P1_USE160351L-A13-A3_HJ7YMDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  1.3G Mar  5 11:59 CBX258_P1_USE160351L-A13-A3_HJ7YMDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287   36M Mar  5 12:35 CBX258_P1_USE160351L-A13-A3_HJF23DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287   37M Mar  5 12:35 CBX258_P1_USE160351L-A13-A3_HJF23DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  3.9G Mar  5 09:55 CBX258_PBL_USE160382L-A40-A35_HJ7YMDSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287  4.0G Mar  5 09:49 CBX258_PBL_USE160382L-A40-A35_HJ7YMDSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  207M Mar  5 12:22 CBX258_PBL_USE160382L-A40-A35_HJHYJDSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287  215M Mar  5 12:22 CBX258_PBL_USE160382L-A40-A35_HJHYJDSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  305M Mar  5 12:20 CBX258_PBL_USE160382L-A40-A35_HJKF3DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  311M Mar  5 12:20 CBX258_PBL_USE160382L-A40-A35_HJKF3DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  3.6G Mar  5 10:20 CBX262_P1_USE160351L-A14-A35_HJ7YMDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  3.7G Mar  5 10:07 CBX262_P1_USE160351L-A14-A35_HJ7YMDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287   89M Mar  5 12:32 CBX262_P1_USE160351L-A14-A35_HJF23DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287   92M Mar  5 12:32 CBX262_P1_USE160351L-A14-A35_HJF23DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  2.9G Mar  5 11:25 CBX262_PBL_USE160383L-A41-A56_HJ7YMDSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287  3.0G Mar  5 11:14 CBX262_PBL_USE160383L-A41-A56_HJ7YMDSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287   72M Mar  5 12:34 CBX262_PBL_USE160383L-A41-A56_HJKF3DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287   73M Mar  5 12:34 CBX262_PBL_USE160383L-A41-A56_HJKF3DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  2.9G Mar  5 11:19 CBX266_P1_USE160349L-A6-A36_HJ7YMDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  3.0G Mar  5 11:09 CBX266_P1_USE160349L-A6-A36_HJ7YMDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287   64M Mar  5 12:35 CBX266_P1_USE160349L-A6-A36_HJF23DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287   66M Mar  5 12:35 CBX266_P1_USE160349L-A6-A36_HJF23DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287   88M Mar  5 12:32 CBX266_P1_USE160349L-A6-A36_HJMTYDSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287   92M Mar  5 12:32 CBX266_P1_USE160349L-A6-A36_HJMTYDSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287   58M Mar  5 12:35 CBX266_PBL_USE160381L-A33-A51_HJF23DSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287   59M Mar  5 12:35 CBX266_PBL_USE160381L-A33-A51_HJF23DSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  2.6G Mar  5 11:47 CBX266_PBL_USE160381L-A33-A51_HJKGJDSXX_L4_R1.fq.gz
-rw-r--r-- 1 bwp9287  2.6G Mar  5 11:43 CBX266_PBL_USE160381L-A33-A51_HJKGJDSXX_L4_R2.fq.gz
-rw-r--r-- 1 bwp9287  138M Mar  5 12:25 CBX270_P1_USE160373L-A4-A35_HJF23DSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287  141M Mar  5 12:25 CBX270_P1_USE160373L-A4-A35_HJF23DSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  2.2G Mar  5 11:52 CBX270_P1_USE160373L-A4-A35_HJKGJDSXX_L3_R1.fq.gz
-rw-r--r-- 1 bwp9287  2.3G Mar  5 11:52 CBX270_P1_USE160373L-A4-A35_HJKGJDSXX_L3_R2.fq.gz
-rw-r--r-- 1 bwp9287   65M Mar  5 12:35 CBX270_P1_USE160373L-A4-A35_HJMTYDSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287   67M Mar  5 12:34 CBX270_P1_USE160373L-A4-A35_HJMTYDSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287   66M Mar  5 12:35 CBX270_PBL_USE160381L-A36-A30_HJF23DSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287   67M Mar  5 12:34 CBX270_PBL_USE160381L-A36-A30_HJF23DSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  3.0G Mar  5 11:12 CBX270_PBL_USE160381L-A36-A30_HJKGJDSXX_L4_R1.fq.gz
-rw-r--r-- 1 bwp9287  3.0G Mar  5 11:09 CBX270_PBL_USE160381L-A36-A30_HJKGJDSXX_L4_R2.fq.gz
-rw-r--r-- 1 bwp9287  3.6G Mar  5 10:15 CBX279_P1_USE160353L-A24-A61_HJ7YMDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  3.7G Mar  5 10:08 CBX279_P1_USE160353L-A24-A61_HJ7YMDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  450M Mar  5 12:15 CBX279_P1_USE160353L-A24-A61_HJF23DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  459M Mar  5 12:14 CBX279_P1_USE160353L-A24-A61_HJF23DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  628M Mar  5 12:10 CBX279_P1_USE160353L-A24-A61_HJMVHDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  641M Mar  5 12:09 CBX279_P1_USE160353L-A24-A61_HJMVHDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  4.0G Mar  5 09:50 CBX279_PBL_USE160480L-A8-A67_HJJY2DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  4.2G Mar  5 09:40 CBX279_PBL_USE160480L-A8-A67_HJJY2DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  4.2G Mar  5 09:38 CBX290_P1_USE160356L-A34-A30_HJ7YMDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  4.4G Mar  5 09:29 CBX290_P1_USE160356L-A34-A30_HJ7YMDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  182M Mar  5 12:23 CBX290_P1_USE160356L-A34-A30_HJF23DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  187M Mar  5 12:23 CBX290_P1_USE160356L-A34-A30_HJF23DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  118M Mar  5 12:29 CBX290_P1_USE160356L-A34-A30_HJMTYDSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287  122M Mar  5 12:28 CBX290_P1_USE160356L-A34-A30_HJMTYDSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  2.7G Mar  5 11:40 CBX290_PBL_USE160388L-A61-A55_HJ7YMDSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287  2.8G Mar  5 11:30 CBX290_PBL_USE160388L-A61-A55_HJ7YMDSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287   62M Mar  5 12:35 CBX290_PBL_USE160388L-A61-A55_HJKF3DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287   64M Mar  5 12:35 CBX290_PBL_USE160388L-A61-A55_HJKF3DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287   91M Mar  5 12:33 CBX290_PBL_USE160388L-A61-A55_HJMVHDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287   95M Mar  5 12:31 CBX290_PBL_USE160388L-A61-A55_HJMVHDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  3.0G Mar  5 11:09 CBX303_P1_USE160375L-A10-A61_HJKGJDSXX_L4_R1.fq.gz
-rw-r--r-- 1 bwp9287  3.1G Mar  5 11:07 CBX303_P1_USE160375L-A10-A61_HJKGJDSXX_L4_R2.fq.gz
-rw-r--r-- 1 bwp9287  2.7G Mar  5 11:36 CBX303_PBL_USE160385L-A52-A35_HJ7YMDSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287  2.8G Mar  5 11:33 CBX303_PBL_USE160385L-A52-A35_HJ7YMDSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  121M Mar  5 12:28 CBX303_PBL_USE160385L-A52-A35_HJKF3DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  122M Mar  5 12:28 CBX303_PBL_USE160385L-A52-A35_HJKF3DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  2.7G Mar  5 11:43 CBX310_P1_USE160349L-A93-A56_HJ7YMDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  2.7G Mar  5 11:41 CBX310_P1_USE160349L-A93-A56_HJ7YMDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287   58M Mar  5 12:35 CBX310_P1_USE160349L-A93-A56_HJF23DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287   58M Mar  5 12:35 CBX310_P1_USE160349L-A93-A56_HJF23DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287   80M Mar  5 12:33 CBX310_P1_USE160349L-A93-A56_HJMTYDSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287   81M Mar  5 12:33 CBX310_P1_USE160349L-A93-A56_HJMTYDSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287   96M Mar  5 12:31 CBX310_PBL_USE160363L-A64-A62_HJF23DSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287   99M Mar  5 12:31 CBX310_PBL_USE160363L-A64-A62_HJF23DSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  2.7G Mar  5 11:38 CBX310_PBL_USE160363L-A64-A62_HJKGJDSXX_L3_R1.fq.gz
-rw-r--r-- 1 bwp9287  2.8G Mar  5 11:33 CBX310_PBL_USE160363L-A64-A62_HJKGJDSXX_L3_R2.fq.gz
-rw-r--r-- 1 bwp9287   71M Mar  5 12:34 CBX310_PBL_USE160363L-A64-A62_HJMTYDSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287   73M Mar  5 12:34 CBX310_PBL_USE160363L-A64-A62_HJMTYDSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  3.8G Mar  5 10:00 CBX311_P1_USE160350L-A11-A51_HJ7YMDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  3.8G Mar  5 09:57 CBX311_P1_USE160350L-A11-A51_HJ7YMDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  3.5G Mar  5 10:29 CBX311_PBL_USE160480L-A5-A4_HJJY2DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  3.6G Mar  5 10:17 CBX311_PBL_USE160480L-A5-A4_HJJY2DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  1.9G Mar  5 11:55 CBX312_P1_USE160353L-A22-A30_HJ7YMDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  1.9G Mar  5 11:55 CBX312_P1_USE160353L-A22-A30_HJ7YMDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  229M Mar  5 12:21 CBX312_P1_USE160353L-A22-A30_HJF23DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  233M Mar  5 12:21 CBX312_P1_USE160353L-A22-A30_HJF23DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  315M Mar  5 12:19 CBX312_P1_USE160353L-A22-A30_HJMVHDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  321M Mar  5 12:20 CBX312_P1_USE160353L-A22-A30_HJMVHDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  2.8G Mar  5 11:33 CBX312_PBL_USE160385L-A49-A55_HJ7YMDSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287  2.9G Mar  5 11:28 CBX312_PBL_USE160385L-A49-A55_HJ7YMDSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  124M Mar  5 12:28 CBX312_PBL_USE160385L-A49-A55_HJKF3DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  125M Mar  5 12:27 CBX312_PBL_USE160385L-A49-A55_HJKF3DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  3.3G Mar  5 10:57 CBX313_P2_met_USE160355L-A95-A56_HJ7YMDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  3.3G Mar  5 10:54 CBX313_P2_met_USE160355L-A95-A56_HJ7YMDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  796M Mar  5 12:07 CBX313_P2_met_USE160355L-A95-A56_HJF23DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  805M Mar  5 12:06 CBX313_P2_met_USE160355L-A95-A56_HJF23DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  3.0G Mar  5 11:11 CBX313_PBL_USE160387L-A59-A2_HJ7YMDSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287  3.1G Mar  5 11:04 CBX313_PBL_USE160387L-A59-A2_HJ7YMDSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  130M Mar  5 12:27 CBX313_PBL_USE160387L-A59-A2_HJKF3DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  132M Mar  5 12:26 CBX313_PBL_USE160387L-A59-A2_HJKF3DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  106M Mar  5 12:30 CBX313_PBL_USE160387L-A59-A2_HJMVHDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  109M Mar  5 12:29 CBX313_PBL_USE160387L-A59-A2_HJMVHDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  2.9G Mar  5 11:24 CBX318_P1_USE160358L-A43-A56_HJ7YMDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  3.0G Mar  5 11:14 CBX318_P1_USE160358L-A43-A56_HJ7YMDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  382M Mar  5 12:17 CBX318_P1_USE160358L-A43-A56_HJF23DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  391M Mar  5 12:17 CBX318_P1_USE160358L-A43-A56_HJF23DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  4.2G Mar  5 09:33 CBX318_PBL_USE160390L-A69-A51_HJ7YMDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  4.4G Mar  5 09:28 CBX318_PBL_USE160390L-A69-A51_HJ7YMDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  535M Mar  5 12:12 CBX318_PBL_USE160390L-A69-A51_HJKF3DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  545M Mar  5 12:12 CBX318_PBL_USE160390L-A69-A51_HJKF3DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  129M Mar  5 12:27 CBX318_PBL_USE160390L-A69-A51_HJMTYDSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287  133M Mar  5 12:26 CBX318_PBL_USE160390L-A69-A51_HJMTYDSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  3.2G Mar  5 11:04 CBX324_P1_USE160349L-A5-A4_HJ7YMDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  3.3G Mar  5 10:54 CBX324_P1_USE160349L-A5-A4_HJ7YMDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287   69M Mar  5 12:34 CBX324_P1_USE160349L-A5-A4_HJF23DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287   71M Mar  5 12:34 CBX324_P1_USE160349L-A5-A4_HJF23DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287   93M Mar  5 12:32 CBX324_P1_USE160349L-A5-A4_HJMTYDSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287   95M Mar  5 12:31 CBX324_P1_USE160349L-A5-A4_HJMTYDSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  124M Mar  5 12:28 CBX324_PBL_USE160363L-A62-A35_HJF23DSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287  127M Mar  5 12:27 CBX324_PBL_USE160363L-A62-A35_HJF23DSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  3.4G Mar  5 10:45 CBX324_PBL_USE160363L-A62-A35_HJKGJDSXX_L3_R1.fq.gz
-rw-r--r-- 1 bwp9287  3.5G Mar  5 10:35 CBX324_PBL_USE160363L-A62-A35_HJKGJDSXX_L3_R2.fq.gz
-rw-r--r-- 1 bwp9287   89M Mar  5 12:32 CBX324_PBL_USE160363L-A62-A35_HJMTYDSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287   92M Mar  5 12:32 CBX324_PBL_USE160363L-A62-A35_HJMTYDSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  3.2G Mar  5 11:03 CBX325_P1_USE160353L-A23-A51_HJ7YMDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  3.3G Mar  5 10:56 CBX325_P1_USE160353L-A23-A51_HJ7YMDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  394M Mar  5 12:17 CBX325_P1_USE160353L-A23-A51_HJF23DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  404M Mar  5 12:17 CBX325_P1_USE160353L-A23-A51_HJF23DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  551M Mar  5 12:12 CBX325_P1_USE160353L-A23-A51_HJMVHDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  566M Mar  5 12:12 CBX325_P1_USE160353L-A23-A51_HJMVHDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  3.2G Mar  5 11:00 CBX325_PBL_USE160385L-A50-A62_HJ7YMDSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287  3.3G Mar  5 10:53 CBX325_PBL_USE160385L-A50-A62_HJ7YMDSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  146M Mar  5 12:24 CBX325_PBL_USE160385L-A50-A62_HJKF3DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  148M Mar  5 12:25 CBX325_PBL_USE160385L-A50-A62_HJKF3DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  3.4G Mar  5 10:42 CBX329_P1_USE160352L-A94-A4_HJ7YMDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  3.4G Mar  5 10:39 CBX329_P1_USE160352L-A94-A4_HJ7YMDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  481M Mar  5 12:14 CBX329_P1_USE160352L-A94-A4_HJF23DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  486M Mar  5 12:13 CBX329_P1_USE160352L-A94-A4_HJF23DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  246M Mar  5 12:21 CBX329_P1_USE160352L-A94-A4_HJMVHDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  249M Mar  5 12:21 CBX329_P1_USE160352L-A94-A4_HJMVHDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  3.0G Mar  5 11:16 CBX329_PBL_USE160383L-A43-A4_HJ7YMDSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287  3.0G Mar  5 11:09 CBX329_PBL_USE160383L-A43-A4_HJ7YMDSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287   73M Mar  5 12:34 CBX329_PBL_USE160383L-A43-A4_HJKF3DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287   74M Mar  5 12:33 CBX329_PBL_USE160383L-A43-A4_HJKF3DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  4.0G Mar  5 09:48 CBX336_P1_USE160375L-A12-A30_HJKGJDSXX_L4_R1.fq.gz
-rw-r--r-- 1 bwp9287  4.1G Mar  5 09:44 CBX336_P1_USE160375L-A12-A30_HJKGJDSXX_L4_R2.fq.gz
-rw-r--r-- 1 bwp9287  2.6G Mar  5 11:46 CBX336_PBL_USE160387L-A57-A51_HJ7YMDSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287  2.7G Mar  5 11:36 CBX336_PBL_USE160387L-A57-A51_HJ7YMDSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  112M Mar  5 12:30 CBX336_PBL_USE160387L-A57-A51_HJKF3DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  115M Mar  5 12:29 CBX336_PBL_USE160387L-A57-A51_HJKF3DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287   92M Mar  5 12:32 CBX336_PBL_USE160387L-A57-A51_HJMVHDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287   96M Mar  5 12:31 CBX336_PBL_USE160387L-A57-A51_HJMVHDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  865M Mar  5 12:06 CBX342_P1_USE160374L-A93-A4_HJF23DSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287  869M Mar  5 12:05 CBX342_P1_USE160374L-A93-A4_HJF23DSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  5.9G Mar  5 08:54 CBX342_P1_USE160374L-A93-A4_HJKGJDSXX_L4_R1.fq.gz
-rw-r--r-- 1 bwp9287  5.9G Mar  5 08:51 CBX342_P1_USE160374L-A93-A4_HJKGJDSXX_L4_R2.fq.gz
-rw-r--r-- 1 bwp9287   94M Mar  5 12:31 CBX342_PBL_USE160381L-A35-A2_HJF23DSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287   97M Mar  5 12:31 CBX342_PBL_USE160381L-A35-A2_HJF23DSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  4.2G Mar  5 09:36 CBX342_PBL_USE160381L-A35-A2_HJKGJDSXX_L4_R1.fq.gz
-rw-r--r-- 1 bwp9287  4.3G Mar  5 09:32 CBX342_PBL_USE160381L-A35-A2_HJKGJDSXX_L4_R2.fq.gz
-rw-r--r-- 1 bwp9287  659M Mar  5 12:08 CBX345_P1_USE160374L-A5-A56_HJF23DSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287  672M Mar  5 12:08 CBX345_P1_USE160374L-A5-A56_HJF23DSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  4.6G Mar  5 09:22 CBX345_P1_USE160374L-A5-A56_HJKGJDSXX_L4_R1.fq.gz
-rw-r--r-- 1 bwp9287  4.7G Mar  5 09:20 CBX345_P1_USE160374L-A5-A56_HJKGJDSXX_L4_R2.fq.gz
-rw-r--r-- 1 bwp9287  2.6G Mar  5 11:45 CBX345_PBL_USE160382L-A37-A55_HJ7YMDSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287  2.7G Mar  5 11:42 CBX345_PBL_USE160382L-A37-A55_HJ7YMDSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  138M Mar  5 12:25 CBX345_PBL_USE160382L-A37-A55_HJHYJDSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287  142M Mar  5 12:25 CBX345_PBL_USE160382L-A37-A55_HJHYJDSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  200M Mar  5 12:23 CBX345_PBL_USE160382L-A37-A55_HJKF3DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  202M Mar  5 12:22 CBX345_PBL_USE160382L-A37-A55_HJKF3DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  3.3G Mar  5 10:50 CBX361_PBL_USE160394L-A83-A2_HJKGJDSXX_L3_R1.fq.gz
-rw-r--r-- 1 bwp9287  3.4G Mar  5 10:41 CBX361_PBL_USE160394L-A83-A2_HJKGJDSXX_L3_R2.fq.gz
-rw-r--r-- 1 bwp9287  3.4G Mar  5 10:39 CBX373_P1_USE160359L-A48-A61_HJ7YMDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  3.5G Mar  5 10:23 CBX373_P1_USE160359L-A48-A61_HJ7YMDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287   78M Mar  5 12:33 CBX373_P1_USE160359L-A48-A61_HJF23DSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287   80M Mar  5 12:33 CBX373_P1_USE160359L-A48-A61_HJF23DSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  124M Mar  5 12:27 CBX373_P1_USE160359L-A48-A61_HJMVHDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  128M Mar  5 12:27 CBX373_P1_USE160359L-A48-A61_HJMVHDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  3.6G Mar  5 10:20 CBX373_PBL_USE160392L-A77-A56_HJ7YMDSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287  3.6G Mar  5 10:14 CBX373_PBL_USE160392L-A77-A56_HJ7YMDSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  164M Mar  5 12:24 CBX375_P1_USE160376L-A15-A3_HJF23DSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287  168M Mar  5 12:24 CBX375_P1_USE160376L-A15-A3_HJF23DSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  4.2G Mar  5 09:35 CBX375_P1_USE160376L-A15-A3_HJKGJDSXX_L4_R1.fq.gz
-rw-r--r-- 1 bwp9287  4.3G Mar  5 09:32 CBX375_P1_USE160376L-A15-A3_HJKGJDSXX_L4_R2.fq.gz
-rw-r--r-- 1 bwp9287  2.4G Mar  5 11:50 CBX375_PBL_USE160390L-A72-A30_HJ7YMDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  2.5G Mar  5 11:48 CBX375_PBL_USE160390L-A72-A30_HJ7YMDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  302M Mar  5 12:21 CBX375_PBL_USE160390L-A72-A30_HJKF3DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  315M Mar  5 12:19 CBX375_PBL_USE160390L-A72-A30_HJKF3DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287   71M Mar  5 12:34 CBX375_PBL_USE160390L-A72-A30_HJMTYDSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287   76M Mar  5 12:33 CBX375_PBL_USE160390L-A72-A30_HJMTYDSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  6.8G Mar  5 08:51 CBX376_P1_USE160354L-A27-A55_HJ7YMDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  7.1G Mar  5 08:51 CBX376_P1_USE160354L-A27-A55_HJ7YMDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  1.5G Mar  5 11:59 CBX376_P1_USE160354L-A27-A55_HJF23DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  1.5G Mar  5 11:58 CBX376_P1_USE160354L-A27-A55_HJF23DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  3.5G Mar  5 10:32 CBX376_PBL_USE160386L-A55-A4_HJ7YMDSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287  3.6G Mar  5 10:21 CBX376_PBL_USE160386L-A55-A4_HJ7YMDSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  3.2G Mar  5 10:59 CBX377_P1_USE160359L-A45-A2_HJ7YMDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  3.4G Mar  5 10:43 CBX377_P1_USE160359L-A45-A2_HJ7YMDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287   75M Mar  5 12:33 CBX377_P1_USE160359L-A45-A2_HJF23DSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287   78M Mar  5 12:33 CBX377_P1_USE160359L-A45-A2_HJF23DSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  119M Mar  5 12:28 CBX377_P1_USE160359L-A45-A2_HJMVHDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  125M Mar  5 12:27 CBX377_P1_USE160359L-A45-A2_HJMVHDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  4.0G Mar  5 09:51 CBX377_PBL_USE160391L-A73-A55_HJ7YMDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  4.1G Mar  5 09:46 CBX377_PBL_USE160391L-A73-A55_HJ7YMDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  2.9G Mar  5 11:26 CBX378_P2_USE160360L-A52-A62_HJ7YMDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  2.9G Mar  5 11:22 CBX378_P2_USE160360L-A52-A62_HJ7YMDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  2.6G Mar  5 11:47 CBX378_PBL_USE160393L-A81-A51_HJ7YMDSXX_L4_R1.fq.gz
-rw-r--r-- 1 bwp9287  2.6G Mar  5 11:46 CBX378_PBL_USE160393L-A81-A51_HJ7YMDSXX_L4_R2.fq.gz
-rw-r--r-- 1 bwp9287  143M Mar  5 12:25 CBX378_PBL_USE160393L-A81-A51_HJKF3DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  144M Mar  5 12:25 CBX378_PBL_USE160393L-A81-A51_HJKF3DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  100M Mar  5 12:30 CBX378_PBL_USE160393L-A81-A51_HJMTYDSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287  102M Mar  5 12:30 CBX378_PBL_USE160393L-A81-A51_HJMTYDSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  4.7G Mar  5 09:14 CBX379_P1_USE160354L-A28-A62_HJ7YMDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  4.9G Mar  5 09:09 CBX379_P1_USE160354L-A28-A62_HJ7YMDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  992M Mar  5 12:02 CBX379_P1_USE160354L-A28-A62_HJF23DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287 1022M Mar  5 12:02 CBX379_P1_USE160354L-A28-A62_HJF23DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  3.5G Mar  5 10:35 CBX379_PBL_USE160386L-A56-A36_HJ7YMDSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287  3.5G Mar  5 10:24 CBX379_PBL_USE160386L-A56-A36_HJ7YMDSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  2.9G Mar  5 11:25 CBX380_P2_USE160360L-A50-A35_HJ7YMDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  3.0G Mar  5 11:11 CBX380_P2_USE160360L-A50-A35_HJ7YMDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  4.3G Mar  5 09:32 CBX380_PBL_USE160392L-A79-A4_HJ7YMDSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287  4.5G Mar  5 09:25 CBX380_PBL_USE160392L-A79-A4_HJ7YMDSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  3.9G Mar  5 09:52 CBX381_P2_USE160355L-A29-A4_HJ7YMDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  4.1G Mar  5 09:42 CBX381_P2_USE160355L-A29-A4_HJ7YMDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  952M Mar  5 12:03 CBX381_P2_USE160355L-A29-A4_HJF23DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  990M Mar  5 12:02 CBX381_P2_USE160355L-A29-A4_HJF23DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  144M Mar  5 12:25 CBX381_PBL_USE160387L-A58-A61_HJKF3DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  146M Mar  5 12:25 CBX381_PBL_USE160387L-A58-A61_HJKF3DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  116M Mar  5 12:29 CBX381_PBL_USE160387L-A58-A61_HJMVHDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  119M Mar  5 12:28 CBX381_PBL_USE160387L-A58-A61_HJMVHDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  3.3G Mar  5 10:56 CBX389_P1_USE160351L-A16-A62_HJ7YMDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  3.6G Mar  5 10:17 CBX389_P1_USE160351L-A16-A62_HJ7YMDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287   86M Mar  5 12:33 CBX389_P1_USE160351L-A16-A62_HJF23DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287   92M Mar  5 12:32 CBX389_P1_USE160351L-A16-A62_HJF23DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287   74M Mar  5 12:34 CBX389_PBL_USE160383L-A42-A67_HJKF3DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287   75M Mar  5 12:33 CBX389_PBL_USE160383L-A42-A67_HJKF3DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  3.2G Mar  5 10:58 CBX390_P1_USE160358L-A42-A36_HJ7YMDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  3.4G Mar  5 10:47 CBX390_P1_USE160358L-A42-A36_HJ7YMDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  435M Mar  5 12:16 CBX390_P1_USE160358L-A42-A36_HJF23DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  451M Mar  5 12:15 CBX390_P1_USE160358L-A42-A36_HJF23DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  644M Mar  5 12:09 CBX390_PBL_USE160389L-A68-A36_HJKF3DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  652M Mar  5 12:09 CBX390_PBL_USE160389L-A68-A36_HJKF3DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287   91M Mar  5 12:32 CBX391_P1_USE160376L-A14-A62_HJF23DSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287   94M Mar  5 12:31 CBX391_P1_USE160376L-A14-A62_HJF23DSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  2.3G Mar  5 11:51 CBX391_P1_USE160376L-A14-A62_HJKGJDSXX_L4_R1.fq.gz
-rw-r--r-- 1 bwp9287  2.4G Mar  5 11:50 CBX391_P1_USE160376L-A14-A62_HJKGJDSXX_L4_R2.fq.gz
-rw-r--r-- 1 bwp9287  372M Mar  5 12:18 CBX391_PBL_USE160390L-A71-A2_HJKF3DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  376M Mar  5 12:18 CBX391_PBL_USE160390L-A71-A2_HJKF3DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  174M Mar  5 12:24 CBX397_P1_USE160378L-A22-A61_HJF23DSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287  176M Mar  5 12:24 CBX397_P1_USE160378L-A22-A61_HJF23DSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  1.4G Mar  5 11:59 CBX397_P1_USE160378L-A22-A61_HJKGJDSXX_L4_R1.fq.gz
-rw-r--r-- 1 bwp9287  1.4G Mar  5 11:59 CBX397_P1_USE160378L-A22-A61_HJKGJDSXX_L4_R2.fq.gz
-rw-r--r-- 1 bwp9287  768M Mar  5 12:06 CBX397_P1_USE160547L-A6-A36_HKG5LDSXX_L3_R1.fq.gz
-rw-r--r-- 1 bwp9287  812M Mar  5 12:06 CBX397_P1_USE160547L-A6-A36_HKG5LDSXX_L3_R2.fq.gz
-rw-r--r-- 1 bwp9287  175M Mar  5 12:24 CBX397_PBL_USE160393L-A80-A36_HJKF3DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  177M Mar  5 12:24 CBX397_PBL_USE160393L-A80-A36_HJKF3DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  3.5G Mar  5 10:26 CBX398_P1_USE160352L-A20-A67_HJ7YMDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  3.6G Mar  5 10:14 CBX398_P1_USE160352L-A20-A67_HJ7YMDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  503M Mar  5 12:13 CBX398_P1_USE160352L-A20-A67_HJF23DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  517M Mar  5 12:13 CBX398_P1_USE160352L-A20-A67_HJF23DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  255M Mar  5 12:21 CBX398_P1_USE160352L-A20-A67_HJMVHDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  263M Mar  5 12:21 CBX398_P1_USE160352L-A20-A67_HJMVHDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  110M Mar  5 12:29 CBX398_PBL_USE160384L-A45-A51_HJKF3DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  113M Mar  5 12:29 CBX398_PBL_USE160384L-A45-A51_HJKF3DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  103M Mar  5 12:30 CBX398_PBL_USE160384L-A45-A51_HJMVHDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  107M Mar  5 12:29 CBX398_PBL_USE160384L-A45-A51_HJMVHDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  3.8G Mar  5 10:01 CBX404_P1_USE160355L-A32-A67_HJ7YMDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  3.9G Mar  5 09:53 CBX404_P1_USE160355L-A32-A67_HJ7YMDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  909M Mar  5 12:04 CBX404_P1_USE160355L-A32-A67_HJF23DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  934M Mar  5 12:04 CBX404_P1_USE160355L-A32-A67_HJF23DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  115M Mar  5 12:29 CBX404_PBL_USE160387L-A60-A30_HJKF3DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  117M Mar  5 12:29 CBX404_PBL_USE160387L-A60-A30_HJKF3DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287   94M Mar  5 12:31 CBX404_PBL_USE160387L-A60-A30_HJMVHDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287   97M Mar  5 12:31 CBX404_PBL_USE160387L-A60-A30_HJMVHDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  453M Mar  5 12:15 CBX415_P1_USE160377L-A20-A36_HJF23DSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287  469M Mar  5 12:14 CBX415_P1_USE160377L-A20-A36_HJF23DSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  4.7G Mar  5 09:19 CBX415_P1_USE160377L-A20-A36_HJKGJDSXX_L4_R1.fq.gz
-rw-r--r-- 1 bwp9287  4.9G Mar  5 09:12 CBX415_P1_USE160377L-A20-A36_HJKGJDSXX_L4_R2.fq.gz
-rw-r--r-- 1 bwp9287  2.9G Mar  5 11:19 CBX415_PBL_USE160483L-A94-A4_HJK23DSXX_L4_R1.fq.gz
-rw-r--r-- 1 bwp9287  3.0G Mar  5 11:15 CBX415_PBL_USE160483L-A94-A4_HJK23DSXX_L4_R2.fq.gz
-rw-r--r-- 1 bwp9287   69M Mar  5 12:34 CBX420_PBL_USE160388L-A64-A35_HJKF3DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287   71M Mar  5 12:34 CBX420_PBL_USE160388L-A64-A35_HJKF3DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  103M Mar  5 12:30 CBX420_PBL_USE160388L-A64-A35_HJMVHDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  108M Mar  5 12:29 CBX420_PBL_USE160388L-A64-A35_HJMVHDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  2.9G Mar  5 11:24 CBX44_P1_USE160348L-A1-A3_HJ7YMDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  2.9G Mar  5 11:17 CBX44_P1_USE160348L-A1-A3_HJ7YMDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  292M Mar  5 12:20 CBX44_P1_USE160348L-A1-A3_HJF23DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  297M Mar  5 12:20 CBX44_P1_USE160348L-A1-A3_HJF23DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  441M Mar  5 12:16 CBX44_P1_USE160348L-A1-A3_HJMVHDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  450M Mar  5 12:16 CBX44_P1_USE160348L-A1-A3_HJMVHDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  2.9G Mar  5 11:21 CBX44_PBL_USE160380L-A95-A4_HJKGJDSXX_L4_R1.fq.gz
-rw-r--r-- 1 bwp9287  2.9G Mar  5 11:20 CBX44_PBL_USE160380L-A95-A4_HJKGJDSXX_L4_R2.fq.gz
-rw-r--r-- 1 bwp9287  444M Mar  5 12:16 CBX453_PBL_USE160389L-A66-A67_HJKF3DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  445M Mar  5 12:16 CBX453_PBL_USE160389L-A66-A67_HJKF3DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  3.7G Mar  5 10:13 CBX468_P1_USE160358L-A41-A4_HJ7YMDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  3.8G Mar  5 10:02 CBX468_P1_USE160358L-A41-A4_HJ7YMDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  484M Mar  5 12:13 CBX468_P1_USE160358L-A41-A4_HJF23DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  494M Mar  5 12:13 CBX468_P1_USE160358L-A41-A4_HJF23DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  422M Mar  5 12:16 CBX468_PBL_USE160389L-A67-A4_HJKF3DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  431M Mar  5 12:16 CBX468_PBL_USE160389L-A67-A4_HJKF3DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  359M Mar  5 12:18 CBX498_P1_USE160378L-A21-A51_HJF23DSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287  365M Mar  5 12:18 CBX498_P1_USE160378L-A21-A51_HJF23DSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  2.9G Mar  5 11:28 CBX498_P1_USE160378L-A21-A51_HJKGJDSXX_L4_R1.fq.gz
-rw-r--r-- 1 bwp9287  2.9G Mar  5 11:20 CBX498_P1_USE160378L-A21-A51_HJKGJDSXX_L4_R2.fq.gz
-rw-r--r-- 1 bwp9287  179M Mar  5 12:23 CBX498_PBL_USE160393L-A82-A61_HJKF3DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  180M Mar  5 12:23 CBX498_PBL_USE160393L-A82-A61_HJKF3DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  3.9G Mar  5 09:57 CBX67A_P1_USE160348L-A3-A55_HJ7YMDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  4.1G Mar  5 09:44 CBX67A_P1_USE160348L-A3-A55_HJ7YMDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  394M Mar  5 12:17 CBX67A_P1_USE160348L-A3-A55_HJF23DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  411M Mar  5 12:16 CBX67A_P1_USE160348L-A3-A55_HJF23DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  618M Mar  5 12:11 CBX67A_P1_USE160348L-A3-A55_HJMVHDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  645M Mar  5 12:09 CBX67A_P1_USE160348L-A3-A55_HJMVHDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  3.1G Mar  5 11:06 CBX67A_PBL_USE160362L-A60-A61_HJKGJDSXX_L3_R1.fq.gz
-rw-r--r-- 1 bwp9287  3.1G Mar  5 11:05 CBX67A_PBL_USE160362L-A60-A61_HJKGJDSXX_L3_R2.fq.gz
-rw-r--r-- 1 bwp9287  3.6G Mar  5 10:18 CCX103_P1_USE160353L-A21-A2_HJ7YMDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  3.7G Mar  5 10:11 CCX103_P1_USE160353L-A21-A2_HJ7YMDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  460M Mar  5 12:15 CCX103_P1_USE160353L-A21-A2_HJF23DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  469M Mar  5 12:14 CCX103_P1_USE160353L-A21-A2_HJF23DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  640M Mar  5 12:10 CCX103_P1_USE160353L-A21-A2_HJMVHDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  654M Mar  5 12:09 CCX103_P1_USE160353L-A21-A2_HJMVHDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  3.4G Mar  5 10:44 CCX118_P1_USE160362L-A58-A30_HJKGJDSXX_L3_R1.fq.gz
-rw-r--r-- 1 bwp9287  3.5G Mar  5 10:32 CCX118_P1_USE160362L-A58-A30_HJKGJDSXX_L3_R2.fq.gz
-rw-r--r-- 1 bwp9287  3.2G Mar  5 10:59 CCX118_PBL_USE160483L-A19-A56_HJK23DSXX_L4_R1.fq.gz
-rw-r--r-- 1 bwp9287  3.3G Mar  5 10:51 CCX118_PBL_USE160483L-A19-A56_HJK23DSXX_L4_R2.fq.gz
-rw-r--r-- 1 bwp9287  3.5G Mar  5 10:32 CCX128_P1_USE160350L-A9-A2_HJ7YMDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  3.5G Mar  5 10:27 CCX128_P1_USE160350L-A9-A2_HJ7YMDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  2.7G Mar  5 11:39 CCX129_P1_USE160349L-A8-A67_HJ7YMDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  2.8G Mar  5 11:33 CCX129_P1_USE160349L-A8-A67_HJ7YMDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287   57M Mar  5 12:35 CCX129_P1_USE160349L-A8-A67_HJF23DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287   58M Mar  5 12:35 CCX129_P1_USE160349L-A8-A67_HJF23DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287   78M Mar  5 12:33 CCX129_P1_USE160349L-A8-A67_HJMTYDSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287   80M Mar  5 12:33 CCX129_P1_USE160349L-A8-A67_HJMTYDSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  543M Mar  5 12:12 CCX142_P1_USE160374L-A8-A36_HJF23DSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287  560M Mar  5 12:12 CCX142_P1_USE160374L-A8-A36_HJF23DSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  3.8G Mar  5 10:02 CCX142_P1_USE160374L-A8-A36_HJKGJDSXX_L4_R1.fq.gz
-rw-r--r-- 1 bwp9287  3.9G Mar  5 09:54 CCX142_P1_USE160374L-A8-A36_HJKGJDSXX_L4_R2.fq.gz
-rw-r--r-- 1 bwp9287  106M Mar  5 12:30 CCX142_PBL_USE160384L-A46-A61_HJKF3DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  107M Mar  5 12:30 CCX142_PBL_USE160384L-A46-A61_HJKF3DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287   98M Mar  5 12:31 CCX142_PBL_USE160384L-A46-A61_HJMVHDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  100M Mar  5 12:30 CCX142_PBL_USE160384L-A46-A61_HJMVHDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  2.7G Mar  5 11:35 CCX148_P1_USE160358L-A44-A67_HJ7YMDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  2.8G Mar  5 11:31 CCX148_P1_USE160358L-A44-A67_HJ7YMDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  363M Mar  5 12:18 CCX148_P1_USE160358L-A44-A67_HJF23DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  369M Mar  5 12:18 CCX148_P1_USE160358L-A44-A67_HJF23DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  340M Mar  5 12:19 CCX148_PBL_USE160390L-A70-A61_HJKF3DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  339M Mar  5 12:19 CCX148_PBL_USE160390L-A70-A61_HJKF3DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  921M Mar  5 12:04 CCX172_P1_USE160361L-A54-A36_HJF23DSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287  938M Mar  5 12:03 CCX172_P1_USE160361L-A54-A36_HJF23DSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  4.7G Mar  5 09:16 CCX172_P1_USE160361L-A54-A36_HJKGJDSXX_L3_R1.fq.gz
-rw-r--r-- 1 bwp9287  4.8G Mar  5 09:13 CCX172_P1_USE160361L-A54-A36_HJKGJDSXX_L3_R2.fq.gz
-rw-r--r-- 1 bwp9287  132M Mar  5 12:26 CCX178_P1_USE160376L-A16-A35_HJF23DSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287  146M Mar  5 12:25 CCX178_P1_USE160376L-A16-A35_HJF23DSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  3.4G Mar  5 10:47 CCX178_P1_USE160376L-A16-A35_HJKGJDSXX_L4_R1.fq.gz
-rw-r--r-- 1 bwp9287  3.8G Mar  5 10:04 CCX178_P1_USE160376L-A16-A35_HJKGJDSXX_L4_R2.fq.gz
-rw-r--r-- 1 bwp9287  456M Mar  5 12:15 CCX179P2_USE160377L-A19-A4_HJF23DSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287  474M Mar  5 12:14 CCX179P2_USE160377L-A19-A4_HJF23DSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  4.7G Mar  5 09:13 CCX179P2_USE160377L-A19-A4_HJKGJDSXX_L4_R1.fq.gz
-rw-r--r-- 1 bwp9287  4.9G Mar  5 09:08 CCX179P2_USE160377L-A19-A4_HJKGJDSXX_L4_R2.fq.gz
-rw-r--r-- 1 bwp9287  102M Mar  5 12:30 CCX180_P1_USE160361L-A55-A56_HJF23DSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287  105M Mar  5 12:30 CCX180_P1_USE160361L-A55-A56_HJF23DSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  530M Mar  5 12:13 CCX180_P1_USE160361L-A55-A56_HJKGJDSXX_L3_R1.fq.gz
-rw-r--r-- 1 bwp9287  544M Mar  5 12:12 CCX180_P1_USE160361L-A55-A56_HJKGJDSXX_L3_R2.fq.gz
-rw-r--r-- 1 bwp9287  1.5G Mar  5 11:58 CCX180_P1_USE160546L-A93-A56_HKG5LDSXX_L3_R1.fq.gz
-rw-r--r-- 1 bwp9287  1.6G Mar  5 11:57 CCX180_P1_USE160546L-A93-A56_HKG5LDSXX_L3_R2.fq.gz
-rw-r--r-- 1 bwp9287  4.1G Mar  5 09:44 CCX180_PBL_USE160483L-A18-A36_HJK23DSXX_L4_R1.fq.gz
-rw-r--r-- 1 bwp9287  4.2G Mar  5 09:40 CCX180_PBL_USE160483L-A18-A36_HJK23DSXX_L4_R2.fq.gz
-rw-r--r-- 1 bwp9287  131M Mar  5 12:26 CCX181_P1_USE160376L-A13-A55_HJF23DSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287  132M Mar  5 12:26 CCX181_P1_USE160376L-A13-A55_HJF23DSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  3.4G Mar  5 10:47 CCX181_P1_USE160376L-A13-A55_HJKGJDSXX_L4_R1.fq.gz
-rw-r--r-- 1 bwp9287  3.4G Mar  5 10:35 CCX181_P1_USE160376L-A13-A55_HJKGJDSXX_L4_R2.fq.gz
-rw-r--r-- 1 bwp9287  3.2G Mar  5 11:02 CCX189_P1_USE160354L-A25-A3_HJ7YMDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  3.3G Mar  5 10:53 CCX189_P1_USE160354L-A25-A3_HJ7YMDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  691M Mar  5 12:07 CCX189_P1_USE160354L-A25-A3_HJF23DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  707M Mar  5 12:08 CCX189_P1_USE160354L-A25-A3_HJF23DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  120M Mar  5 12:28 CCX189_PBL_USE160385L-A51-A3_HJKF3DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  121M Mar  5 12:28 CCX189_PBL_USE160385L-A51-A3_HJKF3DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  3.4G Mar  5 10:50 CCX18_P2_USE160350L-A12-A61_HJ7YMDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  3.4G Mar  5 10:41 CCX18_P2_USE160350L-A12-A61_HJ7YMDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  227M Mar  5 12:22 CCX18_PBL_USE160382L-A39-A3_HJHYJDSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287  240M Mar  5 12:21 CCX18_PBL_USE160382L-A39-A3_HJHYJDSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  332M Mar  5 12:19 CCX18_PBL_USE160382L-A39-A3_HJKF3DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  343M Mar  5 12:18 CCX18_PBL_USE160382L-A39-A3_HJKF3DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  4.7G Mar  5 09:16 CCX192_P1_USE160357L-A38-A35_HJ7YMDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  4.9G Mar  5 09:08 CCX192_P1_USE160357L-A38-A35_HJ7YMDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  871M Mar  5 12:06 CCX192_P1_USE160357L-A38-A35_HJF23DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  901M Mar  5 12:05 CCX192_P1_USE160357L-A38-A35_HJF23DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  2.7G Mar  5 11:40 CCX19_P4_USE160375L-A9-A51_HJKGJDSXX_L4_R1.fq.gz
-rw-r--r-- 1 bwp9287  2.7G Mar  5 11:37 CCX19_P4_USE160375L-A9-A51_HJKGJDSXX_L4_R2.fq.gz
-rw-r--r-- 1 bwp9287  136M Mar  5 12:26 CCX19_PBL_USE160384L-A48-A30_HJKF3DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  139M Mar  5 12:25 CCX19_PBL_USE160384L-A48-A30_HJKF3DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  128M Mar  5 12:27 CCX19_PBL_USE160384L-A48-A30_HJMVHDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  133M Mar  5 12:26 CCX19_PBL_USE160384L-A48-A30_HJMVHDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  908M Mar  5 12:05 CCX203_P1_USE160357L-A40-A62_HJ7YMDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  929M Mar  5 12:04 CCX203_P1_USE160357L-A40-A62_HJ7YMDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  171M Mar  5 12:24 CCX203_P1_USE160357L-A40-A62_HJF23DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  174M Mar  5 12:24 CCX203_P1_USE160357L-A40-A62_HJF23DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  1.2G Mar  5 12:01 CCX203_P1_USE160546L-A4-A62_HKG5LDSXX_L3_R1.fq.gz
-rw-r--r-- 1 bwp9287  1.2G Mar  5 12:01 CCX203_P1_USE160546L-A4-A62_HKG5LDSXX_L3_R2.fq.gz
-rw-r--r-- 1 bwp9287  5.2G Mar  5 09:06 CCX205_P1_USE160357L-A37-A3_HJ7YMDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  5.3G Mar  5 09:03 CCX205_P1_USE160357L-A37-A3_HJ7YMDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  960M Mar  5 12:02 CCX205_P1_USE160357L-A37-A3_HJF23DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  979M Mar  5 12:03 CCX205_P1_USE160357L-A37-A3_HJF23DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287   78M Mar  5 12:33 CCX205_PBL_USE160388L-A63-A3_HJKF3DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287   80M Mar  5 12:33 CCX205_PBL_USE160388L-A63-A3_HJKF3DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  112M Mar  5 12:29 CCX205_PBL_USE160388L-A63-A3_HJMVHDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  116M Mar  5 12:29 CCX205_PBL_USE160388L-A63-A3_HJMVHDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  3.7G Mar  5 10:10 CCX208_P1_USE160359L-A96-A51_HJ7YMDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  3.7G Mar  5 10:05 CCX208_P1_USE160359L-A96-A51_HJ7YMDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287   84M Mar  5 12:33 CCX208_P1_USE160359L-A96-A51_HJF23DSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287   85M Mar  5 12:33 CCX208_P1_USE160359L-A96-A51_HJF23DSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  136M Mar  5 12:26 CCX208_P1_USE160359L-A96-A51_HJMVHDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  138M Mar  5 12:25 CCX208_P1_USE160359L-A96-A51_HJMVHDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  124M Mar  5 12:28 CCX215_PBL_USE160384L-A96-A2_HJKF3DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  125M Mar  5 12:27 CCX215_PBL_USE160384L-A96-A2_HJKF3DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  124M Mar  5 12:28 CCX215_PBL_USE160384L-A96-A2_HJMVHDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  126M Mar  5 12:27 CCX215_PBL_USE160384L-A96-A2_HJMVHDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  762M Mar  5 12:07 CCX219A_P1_USE160378L-A23-A2_HJF23DSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287  782M Mar  5 12:06 CCX219A_P1_USE160378L-A23-A2_HJF23DSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  5.9G Mar  5 08:56 CCX219A_P1_USE160378L-A23-A2_HJKGJDSXX_L4_R1.fq.gz
-rw-r--r-- 1 bwp9287  6.0G Mar  5 08:51 CCX219A_P1_USE160378L-A23-A2_HJKGJDSXX_L4_R2.fq.gz
-rw-r--r-- 1 bwp9287  570M Mar  5 12:11 CCX219C_P1_USE160361L-A56-A67_HJF23DSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287  578M Mar  5 12:11 CCX219C_P1_USE160361L-A56-A67_HJF23DSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  2.9G Mar  5 11:17 CCX219C_P1_USE160361L-A56-A67_HJKGJDSXX_L3_R1.fq.gz
-rw-r--r-- 1 bwp9287  3.0G Mar  5 11:15 CCX219C_P1_USE160361L-A56-A67_HJKGJDSXX_L3_R2.fq.gz
-rw-r--r-- 1 bwp9287  656M Mar  5 12:08 CCX219D_P1_USE160378L-A24-A30_HJF23DSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287  673M Mar  5 12:07 CCX219D_P1_USE160378L-A24-A30_HJF23DSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  5.2G Mar  5 09:02 CCX219D_P1_USE160378L-A24-A30_HJKGJDSXX_L4_R1.fq.gz
-rw-r--r-- 1 bwp9287  5.3G Mar  5 09:01 CCX219D_P1_USE160378L-A24-A30_HJKGJDSXX_L4_R2.fq.gz
-rw-r--r-- 1 bwp9287  109M Mar  5 12:29 CCX219E_P1_USE160379L-A25-A55_HJF23DSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287  110M Mar  5 12:29 CCX219E_P1_USE160379L-A25-A55_HJF23DSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  2.1G Mar  5 11:54 CCX219E_P1_USE160379L-A25-A55_HJKGJDSXX_L4_R1.fq.gz
-rw-r--r-- 1 bwp9287  2.1G Mar  5 11:53 CCX219E_P1_USE160379L-A25-A55_HJKGJDSXX_L4_R2.fq.gz
-rw-r--r-- 1 bwp9287   58M Mar  5 12:35 CCX219E_P1_USE160379L-A25-A55_HJMTYDSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287   59M Mar  5 12:35 CCX219E_P1_USE160379L-A25-A55_HJMTYDSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  194M Mar  5 12:22 CCX219F_P1_USE160379L-A26-A62_HJF23DSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287  198M Mar  5 12:22 CCX219F_P1_USE160379L-A26-A62_HJF23DSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  3.7G Mar  5 10:08 CCX219F_P1_USE160379L-A26-A62_HJKGJDSXX_L4_R1.fq.gz
-rw-r--r-- 1 bwp9287  3.8G Mar  5 09:59 CCX219F_P1_USE160379L-A26-A62_HJKGJDSXX_L4_R2.fq.gz
-rw-r--r-- 1 bwp9287   98M Mar  5 12:31 CCX219F_P1_USE160379L-A26-A62_HJMTYDSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287  101M Mar  5 12:31 CCX219F_P1_USE160379L-A26-A62_HJMTYDSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  138M Mar  5 12:26 CCX219_P1_comb_USE160379L-A27-A3_HJF23DSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287  141M Mar  5 12:25 CCX219_P1_comb_USE160379L-A27-A3_HJF23DSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  2.6G Mar  5 11:44 CCX219_P1_comb_USE160379L-A27-A3_HJKGJDSXX_L4_R1.fq.gz
-rw-r--r-- 1 bwp9287  2.7G Mar  5 11:38 CCX219_P1_comb_USE160379L-A27-A3_HJKGJDSXX_L4_R2.fq.gz
-rw-r--r-- 1 bwp9287   70M Mar  5 12:34 CCX219_P1_comb_USE160379L-A27-A3_HJMTYDSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287   73M Mar  5 12:34 CCX219_P1_comb_USE160379L-A27-A3_HJMTYDSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  2.8G Mar  5 11:28 CCX229_P1_USE160360L-A49-A3_HJ7YMDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  2.9G Mar  5 11:22 CCX229_P1_USE160360L-A49-A3_HJ7YMDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  3.7G Mar  5 10:06 CCX24_P1_USE160348L-A2-A35_HJ7YMDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  3.8G Mar  5 09:57 CCX24_P1_USE160348L-A2-A35_HJ7YMDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  390M Mar  5 12:17 CCX24_P1_USE160348L-A2-A35_HJF23DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  399M Mar  5 12:17 CCX24_P1_USE160348L-A2-A35_HJF23DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  601M Mar  5 12:11 CCX24_P1_USE160348L-A2-A35_HJMVHDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  616M Mar  5 12:11 CCX24_P1_USE160348L-A2-A35_HJMVHDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  2.8G Mar  5 11:30 CCX24_PBL_USE160362L-A59-A51_HJKGJDSXX_L3_R1.fq.gz
-rw-r--r-- 1 bwp9287  2.8G Mar  5 11:28 CCX24_PBL_USE160362L-A59-A51_HJKGJDSXX_L3_R2.fq.gz
-rw-r--r-- 1 bwp9287  4.4G Mar  5 09:27 CCX29_P1_USE160356L-A36-A61_HJ7YMDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  4.5G Mar  5 09:27 CCX29_P1_USE160356L-A36-A61_HJ7YMDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  186M Mar  5 12:23 CCX29_P1_USE160356L-A36-A61_HJF23DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  189M Mar  5 12:23 CCX29_P1_USE160356L-A36-A61_HJF23DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  124M Mar  5 12:28 CCX29_P1_USE160356L-A36-A61_HJMTYDSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287  126M Mar  5 12:27 CCX29_P1_USE160356L-A36-A61_HJMTYDSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287   99M Mar  5 12:31 CCX29_PBL_USE160388L-A62-A62_HJKF3DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  100M Mar  5 12:30 CCX29_PBL_USE160388L-A62-A62_HJKF3DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  156M Mar  5 12:24 CCX29_PBL_USE160388L-A62-A62_HJMVHDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  160M Mar  5 12:24 CCX29_PBL_USE160388L-A62-A62_HJMVHDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  4.0G Mar  5 09:47 CCX48_P1_USE160352L-A19-A56_HJ7YMDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  4.2G Mar  5 09:39 CCX48_P1_USE160352L-A19-A56_HJ7YMDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  585M Mar  5 12:11 CCX48_P1_USE160352L-A19-A56_HJF23DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  608M Mar  5 12:10 CCX48_P1_USE160352L-A19-A56_HJF23DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  296M Mar  5 12:20 CCX48_P1_USE160352L-A19-A56_HJMVHDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  308M Mar  5 12:20 CCX48_P1_USE160352L-A19-A56_HJMVHDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287   86M Mar  5 12:33 CCX48_PBL_USE160383L-A44-A36_HJKF3DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287   87M Mar  5 12:32 CCX48_PBL_USE160383L-A44-A36_HJKF3DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  217M Mar  5 12:22 CCX77_P1_USE160373L-A2-A62_HJF23DSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287  218M Mar  5 12:22 CCX77_P1_USE160373L-A2-A62_HJF23DSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  3.5G Mar  5 10:27 CCX77_P1_USE160373L-A2-A62_HJKGJDSXX_L3_R1.fq.gz
-rw-r--r-- 1 bwp9287  3.5G Mar  5 10:23 CCX77_P1_USE160373L-A2-A62_HJKGJDSXX_L3_R2.fq.gz
-rw-r--r-- 1 bwp9287  105M Mar  5 12:30 CCX77_P1_USE160373L-A2-A62_HJMTYDSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287  107M Mar  5 12:30 CCX77_P1_USE160373L-A2-A62_HJMTYDSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287   90M Mar  5 12:32 CCX77_PBL_USE160363L-A63-A55_HJF23DSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287   92M Mar  5 12:32 CCX77_PBL_USE160363L-A63-A55_HJF23DSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  2.5G Mar  5 11:50 CCX77_PBL_USE160363L-A63-A55_HJKGJDSXX_L3_R1.fq.gz
-rw-r--r-- 1 bwp9287  2.5G Mar  5 11:48 CCX77_PBL_USE160363L-A63-A55_HJKGJDSXX_L3_R2.fq.gz
-rw-r--r-- 1 bwp9287   64M Mar  5 12:35 CCX77_PBL_USE160363L-A63-A55_HJMTYDSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287   67M Mar  5 12:34 CCX77_PBL_USE160363L-A63-A55_HJMTYDSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  173M Mar  5 12:24 CCX92_P1_USE160374L-A6-A67_HJF23DSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287  177M Mar  5 12:23 CCX92_P1_USE160374L-A6-A67_HJF23DSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  1.2G Mar  5 12:01 CCX92_P1_USE160374L-A6-A67_HJKGJDSXX_L4_R1.fq.gz
-rw-r--r-- 1 bwp9287  1.2G Mar  5 12:01 CCX92_P1_USE160374L-A6-A67_HJKGJDSXX_L4_R2.fq.gz
-rw-r--r-- 1 bwp9287  125M Mar  5 12:27 CCX92_PBL_USE160382L-A38-A62_HJHYJDSXX_L1_R1.fq.gz
-rw-r--r-- 1 bwp9287  130M Mar  5 12:26 CCX92_PBL_USE160382L-A38-A62_HJHYJDSXX_L1_R2.fq.gz
-rw-r--r-- 1 bwp9287  183M Mar  5 12:23 CCX92_PBL_USE160382L-A38-A62_HJKF3DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  187M Mar  5 12:23 CCX92_PBL_USE160382L-A38-A62_HJKF3DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  1.5G Mar  5 11:58 CCX98_P1_USE160357L-A39-A55_HJ7YMDSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  1.6G Mar  5 11:57 CCX98_P1_USE160357L-A39-A55_HJ7YMDSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  281M Mar  5 12:21 CCX98_P1_USE160357L-A39-A55_HJF23DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  289M Mar  5 12:21 CCX98_P1_USE160357L-A39-A55_HJF23DSXX_L2_R2.fq.gz
-rw-r--r-- 1 bwp9287  1.6G Mar  5 11:56 CCX98_P1_USE160547L-A3-A55_HKG5LDSXX_L3_R1.fq.gz
-rw-r--r-- 1 bwp9287  1.7G Mar  5 11:56 CCX98_P1_USE160547L-A3-A55_HKG5LDSXX_L3_R2.fq.gz
-rw-r--r-- 1 bwp9287  451M Mar  5 12:15 CCX98_PBL_USE160389L-A65-A56_HJKF3DSXX_L2_R1.fq.gz
-rw-r--r-- 1 bwp9287  455M Mar  5 12:14 CCX98_PBL_USE160389L-A65-A56_HJKF3DSXX_L2_R2.fq.gz
