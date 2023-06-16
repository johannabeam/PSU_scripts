##### START HERE #####
#Here is the alignment step using the reference genome and both forward and backward reads of the raw data


export PATH=$PATH:/storage/work/dut374/bin/psmc/utils:/storage/work/dut374/bin/psmc:/gpfs/group/dut374/default/johanna/bwa/bwa
export home_dir=/gpfs/group/dut374/default/johanna
export programs=/storage/work/dut374/bin
export picard=/storage/work/dut374/bin/picard_tools_2.20.8/picard.jar


# if this doesn't work, you can try using this as the allocation  wff3_a_g_hc_default
echo "
#!/bin/bash
#PBS -l nodes=1:ppn=5,walltime=24:00:00
#PBS -j oe
#PBS -l feature=rhe17
#PBS -A dut374_c_g_sc_default
#PBS -l pmem=5gb

${home_dir}/bwa/bwa index ${home_dir}/olwa/GCA_013400575.1_ASM1340057v1_genomic.fna" >> index_olwa.pbs
qsub index_olwa.pbs

# ********************************************

#Remove adapters from your sequence
echo "
#!/bin/bash
#PBS -l nodes=1:ppn=10,walltime=24:00:00
#PBS -j oe
#PBS -l feature=rhe17
#PBS -A wff3_a_g_hc_default
#PBS -l pmem=100gb
/storage/work/dut374/bin/adapterremoval-2.1.7/build/AdapterRemoval --file1 /gpfs/group/dut374/default/johanna/olwa/SRR9946480_140719_I168_FCC4RMMACXX_L5_WHANIbtfDUAJDWABPEI-56_1.fq.gz --file2 /gpfs/group/dut374/default/johanna/olwa/SRR9946480_140719_I168_FCC4RMMACXX_L5_WHANIbtfDUAJDWABPEI-56_2.fq.gz --collapse --trimns --minlength 20 --qualitybase 64 --gzip --basename /gpfs/group/dut374/default/johanna/olwa/olwa_adapterrm" >> adapter_removal.pbs
qsub adapter_removal.pbs

echo "
#!/bin/bash
#PBS -l nodes=1:ppn=5,walltime=160:00:00
#PBS -j oe
#PBS -l feature=rhe17
#PBS -A wff3_a_g_hc_default
#PBS -l pmem=100gb


${JODIR}/bwa/bwa mem -M ${JODIR}/olwa/GCA_013400575.1_ASM1340057v1_genomic.fna \
${JODIR}/olwa/olwa_adapterrm.pair1.truncated.gz \
${JODIR}/olwa/olwa_adapterrm.pair2.truncated.gz > ${JODIR}/olwa/olwa_aligned.sam" >> olwa_alignment.pbs
qsub olwa_alignment.pbs



# samtools step to take the aligned sam file and turn it into a bam file

echo "
#!/bin/bash
#PBS -l nodes=1:ppn=10,walltime=24:00:00
#PBS -j oe
#PBS -l feature=rhe17
#PBS -A wff3_a_g_hc_default
#PBS -l pmem=100gb

module load gcc/8.3.1 samtools/1.13
samtools view -S -b /gpfs/group/dut374/default/johanna/olwa/olwa_aligned.sam > /gpfs/group/dut374/default/johanna/olwa/olwa_bam_new.bam" >> olwa_bam_new.pbs
qsub olwa_bam_new.pbs

#Now we can sort the bam file. For some reason I can't get it to work by piping the bam into sort in one line of code, so this is the work-around.

echo "
#!/bin/bash
#PBS -l nodes=1:ppn=10,walltime=24:00:00
#PBS -j oe
#PBS -l feature=rhe17
#PBS -A wff3_a_g_hc_default
#PBS -l pmem=100gb

module load gcc/8.3.1 samtools/1.13
samtools sort $JODIR/olwa/olwa_bam_new.bam -o $JODIR/olwa/olwa_sortedbam_new.bam" >> olwa_sortedbam_new.pbs
qsub olwa_sortedbam_new.pbs

#Mark duplicates using picardtools 

echo "

#!/bin/bash
#PBS -l nodes=1:ppn=20,walltime=25:00:00,pmem=48gb
#PBS -j oe
#PBS -l feature=rhel7
#PBS -A wff3_a_g_hc_default


java -Xmx48g -jar /storage/work/dut374/bin/picard_tools_2.20.8/picard.jar MarkDuplicates \
I=/gpfs/group/dut374/default/johanna/olwa/olwa_sortedbam_new.bam \
O=/gpfs/group/dut374/default/johanna/olwa/olwa_marked.bam \
METRICS_FILE=/gpfs/group/dut374/default/johanna/olwa/olwa.metrics.txt \
MAX_FILE_HANDLES_FOR_READ_ENDS_MAP=80000" >> olwa_marked.pbs

qsub olwa_marked.pbs
done

# Index the marked bam file to make it easier to read

echo "

#!/bin/bash
#PBS -l nodes=1:ppn=1,walltime=1:00:00
#PBS -j oe
#PBS -l feature=rhel7
#PBS -A dut374_c_g_sc_default

module load gcc/8.3.1 samtools/1.13
samtools index /gpfs/group/dut374/default/johanna/olwa/olwa_marked.bam /gpfs/group/dut374/default/johanna/olwa/olwa_marked.bai" >> olwa_bamindex.pbs
qsub olwa_bamindex.pbs

# this is the next step after you make, sort, mark, and index the bam file. This step transfers the file into bcf format using mpileup
# Now we have to use mpileup to create the bcf file using the three sorted files that were the output from the sorting set above

echo "
#!/bin/bash
#PBS -l nodes=1:ppn=10,walltime=24:00:00
#PBS -j oe
#PBS -l feature=rhe17
#PBS -A wff3_a_g_hc_default
#PBS -l pmem=100gb


/storage/work/dut374/bin/bcftools-1.14/bin/bcftools mpileup -f $JODIR/olwa/GCA_013400575.1_ASM1340057v1_genomic.fna $JODIR/olwa/olwa_marked.bam  > $JODIR/olwa/olwa.bcf" >> olwa_bcftools.pbs
qsub olwa_bcftools.pbs

#now we can finally call reads and put this back into a fq format

echo "
#!/bin/bash
#PBS -l nodes=1:ppn=10,walltime=24:00:00
#PBS -j oe
#PBS -l feature=rhe17
#PBS -A dut374_c_g_sc_default
#PBS -l pmem=3gb

/storage/work/dut374/bin/bcftools-1.14/bin/bcftools call -c $JODIR/olwa/olwa.bcf | \
/storage/work/dut374/bin/bcftools-1.14/bin/vcfutils.pl vcf2fq -d 3 -D 100  > \
$JODIR/olwa/olwa.fq" >> bcf_to_fq_olwa.pbs
qsub bcf_to_fq_olwa.pbs

# now we can take that fq file and run psmc. don't forget to check and make sure all the iterations were completed (should be 30)
echo "
#!/bin/bash
#PBS -l nodes=1:ppn=1,walltime=3:00:00
#PBS -j oe
#PBS -l feature=rhel7
#PBS -A dut374_c_g_sc_default
#PBS -l pmem=3gb

/storage/work/dut374/bin/psmc/utils/fq2psmcfa -q20 $JODIR/olwa/olwa.fq > $JODIR/olwa/olwa.psmcfa
/storage/work/dut374/bin/psmc/psmc -N30 -t15 -r1 -p "4+30*2+4+6+10" -o $JODIR/olwa/olwa.psmc $JODIR/olwa/olwa.psmcfa" >> psmc_olwa.pbs
qsub psmc_olwa.pbs

#visualize the plot

echo "
#!/bin/bash
#PBS -l nodes=1:ppn=1,walltime=1:00:00
#PBS -j oe
#PBS -l feature=rhel7
#PBS -A dut374_c_g_sc_default

/storage/work/dut374/bin/psmc/utils/psmc_plot.pl -u 1.4e-9 -g 2 -M OLWA /gpfs/group/dut374/default/johanna/olwa/olwa_plot_psmc_new /gpfs/group/dut374/default/johanna/olwa/olwa.psmc" >> psmc_olwa_plot_new.pbs
qsub psmc_olwa_plot_new.pbs
