#PBS -S /bin/bash
#PBS -q batch
#PBS -N methylpy
#PBS -l nodes=1:ppn=12:HIGHMEM
#PBS -l walltime=999:00:00
#PBS -l mem=100gb

echo "Starting"
cd $PBS_O_WORKDIR
module load sratoolkit/2.8.0
sample=$(pwd | sed s/.*data\\/// | sed s/\\///)

#Download data
fastq=$(ls fastq/*fastq.gz | wc -l)
if [ $fastq > 0 ]
then
	echo "Sequence data exists"
	cd fastq
	for i in *fastq.gz
	do
		gunzip "$i"
	done
else
	echo "No Sequence data, retrieving sequencing data"
	cd fastq
	module load python/3.5.1
	python3.5 ../../../scripts/download_fastq.py "$i"
	for i in *sra
	do
		fastq-dump --gzip --split-3 "$i"
		rm "$i"
	done
fi

if [ SRR*_2.fastq ]
then
	echo "Data is paired-end"
	for i in SRR*_2.fastq
	do
		output=$(echo "$i" | sed s/.fastq/_2.fastq/)
		python /usr/local/apps/cutadapt/1.9.dev1/bin/cutadapt \
		-a AGATCGGAAGAGCGTCGTGTAGGGA -o tmp.fastq "$i"
		time /usr/local/apps/fastx/0.0.14/bin/fastx_reverse_complement \
		-i tmp.fastq -o "$output"
		rm tmp.fastq
		gzip "$i"
fi

#Map bisulfite data
cd ../methylCseq
module load python/2.7.8
echo "Running methylpy"
if [ ../fastq/SRR*_2.fastq ]
then
	python ../../../scripts/run_methylpy.py "$sample" \
	"../fastq/*.fastq" "../ref/$sample" "10" "9" "AGATCGGAAGAGCACACGTCTGAAC" \
	"ChrL" > "$sample"_output.txt
else
	python ../../../scripts/run_methylpy.py "$sample" \
	"../fastq/*.fastq" "../ref/$sample" "10" "9" "AGATCGGAAGAGCTCGTATGCC" \
	"ChrL" > "$sample"_output.txt
fi

#Organize files
echo "Organizing and cleaning up"
rm *mpileup* *.bam *.bam.bai
mkdir tmp
head -1 allc_"$sample"_ChrL.tsv > tmp/header
for i in allc_"$sample"_*
do
  sed '1d' "$i" > tmp/"$i"
done
tar -cjvf "$sample"_allc.tar.bz2 allc_"$sample"_*
rm allc_*
cd tmp
rm allc_"$sample"_ChrL.tsv allc_"$sample"_ChrC.tsv
cat header allc_* > ../"$sample"_allc_total.tsv
cd ../
rm -R tmp
tar -cjvf "$sample"_allc_total.tar.bz2 "$sample"_allc_total.tsv
cd ../fastq
for i in *fastq
do
  gzip "$i"
done

echo "Done"
