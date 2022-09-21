#\!/bin/bash
# 2022-08-08
# Run GATK pipeline 

# Path variants user
# SAMPLE_NAME=diagseq284f106
gatk_path=/nfs/goldstein/software/gatk-4.1.8.1/gatk
# JAVA_PATH=/nfs/goldstein/software/jdk-11.0.2/bin/java
pharmcat_path=/usr/local/igm/non-atav-tools/pharmcat-1.8.0/pharmcat-1.8.0-all.jar
pharmcat_git=/nfs/projects/gatk-workflows/PharmCAT
picard_path=/nfs/goldstein/software/picard-tools-2.23.8/picard.jar
dbsnp_file=/nfs/projects/gatk-workflows/google_downloads/Homo_sapiens_assembly19.dbsnp138.vcf
reference_grch38=/nfs/projects/gatk-workflows/google_downloads/Homo_sapiens_assembly38.fasta 
########## Source correct versions
source /nfs/goldstein/software/centos7/python-3.9.7-x86_64_shared/python3.9.7-ENV.sh
source /usr/local/igm/non-atav-tools/jdk-18.0.2/jdk-18.0.2-ENV.sh
source /usr/local/igm/non-atav-tools/bcftools-1.15.1-x86_64/bcftools-1.15.1-ENV.sh
source /usr/local/igm/non-atav-tools/htslib-1.15.1-x86_64/htslib-1.15.1-x86_64-ENV.sh


########## set up directory structure
mkdir single_sample/input
mkdir single_sample/intermediate
mkdir single_sample/output
mkdir multi_sample/input
mkdir multi_sample/intermediate
mkdir multi_sample/output

############### single sample
sample_name=$(cat single_sample/input/single_sample_pgx.yaml | shyaml get-value single_sample.sample_name)
echo $sample_name

gvcf_for_pgx="single_sample/intermediate/$sample_name.g.vcf.gz"
if [[ $1 = "run_haplotypecaller_bp_resolution" ]]
then

  cram_path=$(cat single_sample/input/single_sample_pgx.yaml | shyaml get-value single_sample.cram_path)
  echo "here"

  $gatk_path --java-options "-Xmx4G" HaplotypeCaller \
  -R $reference_grch38 \
  -L $pharmcat_git/pharmcat_positions.vcf.bgz \
  -I $cram_path \
  -O $gvcf_for_pgx -ERC BP_RESOLUTION #--dbsnp $dbsnp_file

fi


gt_vcf="single_sample/intermediate/$sample_name.gt.vcf.gz"
if [[ $1 = "single_sample_genotype_gvcf" ]]
then
  echo "single_sample_genotype_gvcf"
  # gvcf_path=$(cat single_sample/input/single_sample_pgx.yaml | shyaml get-value single_sample.gvcf_path)
  # echo $gvcf_path

 $gatk_path --java-options "-Xmx4g" GenotypeGVCFs \
   -R $reference_grch38 \
   -V $gvcf_for_pgx \
   -O $gt_vcf  --include-non-variant-sites true # --dbsnp $dbsnp_file
fi



############### run pharmcat preprocess
if [[ $1 = "pharmCAT_preprocess" ]]
then
  echo "Run pharmCat preporcessor ..."
  # pip3 install -r ./PharmCAT/src/scripts/preprocessor/PharmCAT_VCF_Preprocess_py3_requirements.txt 


  python $pharmcat_git/src/scripts/preprocessor/PharmCAT_VCF_Preprocess.py --input_vcf $gt_vcf --output_folder single_sample/intermediate  --ref_pgx_vcf $pharmcat_git/pharmcat_positions.vcf.bgz --ref_seq $pharmcat_git/reference_download/reference.fasta.bgz --keep_intermediate_files --output_prefix $sample_name

fi



############### run pharmcat
pharmcat_vcf_path="single_sample/intermediate/PharmCAT_preprocess_"$sample_name".pgx_regions.normalized.vcf"
# gzip -d file.gz
if [[ $1 = "pharmCAT_run" ]]
then
  echo "Run pharmCat ..."
  # gvcf_path="$WORKFLOW_DIR/cromwell-executions/HaplotypeCallerGvcf_GATK4/*/call-MergeGVCFs/execution/*.g.vcf"
  echo $pharmcat_vcf_path


  java -jar $pharmcat_path -vcf $pharmcat_vcf_path -o single_sample/output -j -pj -f $sample_name
  mv ./pharmcat.log single_sample/output

fi


