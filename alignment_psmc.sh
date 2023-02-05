home_dir=/gpfs/group/dut374/default/johanna
programs=/storage/work/dut374/bin

#align the raw genomic sequences

echo "
#!/bin/bash
#PBS -l nodes=1:ppn=1,walltime=3:00:00
#PBS -j oe
#PBS -l feature=rhe17
#PBS -A dut374_c_g_sc_default

$home_dir/bwa/bwa mem -M $home_dir/D1907004328.gapcloser.fasta $home_dir/SRR8236596_icteria_virens_b60879_L001_R1_001.fastq $home_dir/SRR8236596_icteria_virens_b60879_L001_R2_001.fastq > $home_dir/aligned_ybch.sam" >> ybch_alignment.pbs
qsub ybch_alignment.pbs
done

#Hopefully convert the sam file into a fastq, but this doesn't really work. whoops.
grep -v ^@ aligned_ybch.sam | awk '{print "@"$1"\n"$10"\n+\n"$11}' > ybch.fastq

#Trying to convert into bam then convert into fq using picard tools to sort sam file and turn into bam file
java -jar $programs/picard_tools_2.20.8/picard.jar SortSam INPUT=aligned_ybch.sam OUTPUT=sorted_ybch.bam SORT_ORDER=coordinate
#load samtools, then try to convert to fq
cd programs/samtools-1.9
module load gcc/8.3.1 samtools/1.13
samtools bam2fq $home_dir/virens29389_R1.marked.bam > $home_dir/btnw.fq 

#Try running the PSMC code using the parameters from the flycatcher paper
echo "
#!/bin/bash
#PBS -l nodes=1:ppn=1,walltime=3:00:00
#PBS -j oe
#PBS -l feature=rhel7
#PBS -A dut374_c_g_sc_default

$programs/psmc/utils/fq2psmcfa -q20 $home_dir/ybch_frombam.fq > $home_dir/ybch.psmcfa
$programs/psmc/psmc -N30 -t5 -r1 -p "4+30*2+4+6+10" -o $home_dir/ybch.psmc $home_dir/ybch.psmcfa" >> psmc_ybch.pbs
qsub psmc_ybch.pbs
done

#first line of PSMC to try running it on the head node (see if it works or not) Should spit out a psmcfa file with stuff in there
$programs/psmc/utils/fq2psmcfa -q20 $home_dir/btnw.fq > $home_dir/btnw.psmcfa

#ignore this
java -jar /storage/work/dut374/bin/picard_tools_2.20.8/picard.jar SamToFastq \
>      I=aligned_ybch.sam \
>      FASTQ=ybch.fastq


