#!/bin/bash
# stjude_sicer 0.0.1
# Generated by dx-app-wizard.
#
# Basic execution pattern: Your app will run on a single machine from
# beginning to end.
#
# Your job's input variables (if any) will be loaded as environment
# variables before this script runs.  Any array inputs will be loaded
# as bash arrays.
#
# Any code outside of main() (or any entry point you may add) is
# ALWAYS executed, followed by running the entry point itself.
#
# See https://wiki.dnanexus.com/Developer-Portal for tutorials on how
# to modify this file.

set -e -x -o pipefail

main() {

    echo "Value of ChIP_bam: '$ChIP_bam'"
    echo "Value of Control_bam: '$Control_bam'"
    echo "Value of out_prefix: '$out_prefix'"
    echo "Value of genome: '$genome'"
    echo "Value of window_size: '$window_size'"
    echo "Value of gap_size: '$gap_size'"
    echo "Value of FDR: '$FDR'"
    echo "Value of fragment_size: '$fragment_size'"

    echo ""
    echo "=== Setup ==="
    sudo apt-get update
    sudo apt-get install libsigsegv2
    export PATH=/user/bin:$PATH
    gawk --version
    sudo apt-get --yes install openjdk-8-jdk
    java -version
    sudo apt-get install tabix

    echo "install spp ..."
    R --version
    R CMD INSTALL /home/bitops_1.0-6.tar.gz
    R CMD INSTALL /home/caTools_1.17.1.tar.gz
    R CMD INSTALL /home/snow_0.4-1.tar.gz
    R CMD INSTALL /home/phantompeakqualtools/spp_1.10.1.tar.gz
    echo "R CMD INSTALL /home/phantompeakqualtools/spp_1.10.1.tar.gz" >> logfile
    echo "install bedtools ..."
    apt-get install bedtools
    echo "install python packages ..."
    add-apt-repository 'deb http://us.archive.ubuntu.com/ubuntu/ precise main' 
    sudo apt-get update
    apt-get install python-numpy
    apt-get install libamd2.3.1 
    apt-get install liblcms1 
    apt-get -y install libumfpack5.6.2 
    apt-get -y install python-imaging 
    apt-get -y install python-scipy
    echo "configure samtools ..."
    export PATH=$PATH:/home/dnanexus/samtools-0.1.18
    echo "export PATH=$PATH:/home/dnanexus/samtools-0.1.18" >> logfile
    

    # The following line(s) use the dx command-line tool to download your file
    # inputs to the local file system using variable names for the filenames. To
    # recover the original filenames, you can use the output of "dx describe
    # "$variable" --name".

    echo "  [*] Downloading input files..."
    dx download "$ChIP_bam" -o ${ChIP_bam_prefix}.bam
    dx download "$Control_bam" -o ${Control_bam_prefix}.bam
    
    if [ "$parameter_file" != "" ]; then 
    echo "  [*] parsing parameters from parameter file ..."
    dx download "$parameter_file" -o parameters.txt
    source parameters.txt
    echo "source parameters.txt"
    echo "$genome"
    echo "$out_prefix"
    fi

    #############################################
    # remove multiple mapped reads
    #############################################
    echo "removing multiple mapped reads and duplicates ..."
    echo "removing multiple mapped reads and duplicates ..." >> logfile
    java -Xmx4g -jar picard.jar SortSam VALIDATION_STRINGENCY=LENIENT I=${ChIP_bam_prefix}.bam O=${ChIP_bam_prefix}.sort.bam SORT_ORDER=coordinate &
    echo "java -Xmx4g -jar picard.jar SortSam VALIDATION_STRINGENCY=LENIENT I=${ChIP_bam_prefix}.bam O=${ChIP_bam_prefix}.sort.bam SORT_ORDER=coordinate &" >> logfile
    java -Xmx4g -jar picard.jar SortSam VALIDATION_STRINGENCY=LENIENT I=${Control_bam_prefix}.bam O=${Control_bam_prefix}.sort.bam SORT_ORDER=coordinate &
    echo "java -Xmx4g -jar picard.jar SortSam VALIDATION_STRINGENCY=LENIENT I=${Control_bam_prefix}.bam O=${Control_bam_prefix}.sort.bam SORT_ORDER=coordinate &" >> logfile
    wait
    java -Xmx4g -jar picard.jar MarkDuplicates VALIDATION_STRINGENCY=LENIENT I=${ChIP_bam_prefix}.sort.bam O=${ChIP_bam_prefix}_processed.1.bam M=marked_dup_metrics.txt REMOVE_DUPLICATES=TRUE &
    echo "java -Xmx4g -jar picard.jar MarkDuplicates VALIDATION_STRINGENCY=LENIENT I=${ChIP_bam_prefix}.sort.bam O=${ChIP_bam_prefix}_processed.1.bam M=marked_dup_metrics.txt REMOVE_DUPLICATES=TRUE &" >> logfile
    java -Xmx4g -jar picard.jar MarkDuplicates VALIDATION_STRINGENCY=LENIENT I=${Control_bam_prefix}.sort.bam O=${Control_bam_prefix}_processed.1.bam M=marked_dup_metrics.txt REMOVE_DUPLICATES=TRUE &
    echo "java -Xmx4g -jar picard.jar MarkDuplicates VALIDATION_STRINGENCY=LENIENT I=${Control_bam_prefix}.sort.bam O=${Control_bam_prefix}_processed.1.bam M=marked_dup_metrics.txt REMOVE_DUPLICATES=TRUE &" >> logfile
    wait
    rm ${ChIP_bam_prefix}.sort.bam ${Control_bam_prefix}.sort.bam


    ######################################################
    # rescue multiple mapped reads from inputted regions 
    #######################################################
    if [ "$is_rescue" == "true" ]; then
        dx download "$rescue_bed" -o rescue.bed
        run_rescue ${ChIP_bam_prefix}_processed.1.bam ${ChIP_bam_prefix}_processed rescue.bed &
        echo "run_rescue ${ChIP_bam_prefix}_processed.1.bam ${ChIP_bam_prefix}_processed rescue.bed &" >> logfile
        run_rescue ${Control_bam_prefix}_processed.1.bam ${Control_bam_prefix}_processed rescue.bed &
        echo "run_rescue ${Control_bam_prefix}_processed.1.bam ${Control_bam_prefix}_processed rescue.bed &" >> logfile
        wait
    else
        samtools view -hb -q 1 ${ChIP_bam_prefix}_processed.1.bam  > ${ChIP_bam_prefix}_processed.bam &
        echo "samtools view -hb -q 1 ${ChIP_bam_prefix}_processed.1.bam  > ${ChIP_bam_prefix}_processed.bam &" >> logfile
        samtools view -hb -q 1 ${Control_bam_prefix}_processed.1.bam  > ${Control_bam_prefix}_processed.bam &
        echo "samtools view -hb -q 1 ${Control_bam_prefix}_processed.1.bam  > ${Control_bam_prefix}_processed.bam &" >> logfile
        wait
    fi
    

    #############################################
    # run spp cross correlation
    #############################################
    echo "run spp cross correlation ..."
    Rscript /home/phantompeakqualtools/run_spp_nodups.R -c=${ChIP_bam_prefix}_processed.bam -savp=${ChIP_bam_prefix}_phantomPeak.pdf -out=${ChIP_bam_prefix}_phantomPeak.out &
    Rscript /home/phantompeakqualtools/run_spp_nodups.R -c=${Control_bam_prefix}_processed.bam -savp=${Control_bam_prefix}_phantomPeak.pdf -out=${Control_bam_prefix}_phantomPeak.out &
    echo "run spp cross correlation ..." >> logfile
    echo "Rscript /home/phantompeakqualtools/run_spp_nodups.R -c=${ChIP_bam_prefix}_processed.bam -savp=${ChIP_bam_prefix}_phantomPeak.pdf -out=${ChIP_bam_prefix}_phantomPeak.out &" >> logfile
    echo "Rscript /home/phantompeakqualtools/run_spp_nodups.R -c=${Control_bam_prefix}_processed.bam -savp=${Control_bam_prefix}_phantomPeak.pdf -out=${Control_bam_prefix}_phantomPeak.out &" >> logfile
    wait

    echo "upload cross correlation plot..."
    # set up the output folder
    dx mkdir -p $DX_PROJECT_CONTEXT_ID:$out_folder/Results/${out_prefix}/SICER/
    ChIP_cc=$(dx upload --tag sjcp-result-file --path $DX_PROJECT_CONTEXT_ID:$out_folder/Results/${out_prefix}/SICER/ ${ChIP_bam_prefix}_phantomPeak.pdf --brief  )
    dx-jobutil-add-output ChIP_cc "$ChIP_cc" --class=file
    Control_cc=$(dx upload --tag sjcp-result-file --path $DX_PROJECT_CONTEXT_ID:$out_folder/Results/${out_prefix}/SICER/ ${Control_bam_prefix}_phantomPeak.pdf --brief  )
    dx-jobutil-add-output Control_cc "$Control_cc" --class=file

    echo "parse fragment size ..."
    if [ "$fragment_size" == "NA" ];then 
    fragment_size=`cat ${ChIP_bam_prefix}_phantomPeak.out | cut -f 3 | sed 's/,/\t/g' | cut -f 1`
    if [ "$fragment_size" -lt 50 ]; then dx-jobutil-report-error "The estimated fragment size for ${ChIP_bam_prefix} is smaller than 50bp based on cross correlation. please manually setup a fix fragment length and rerun the analysis." AppError; fi
    fi


    #############################################
    # run SICER
    #############################################
    echo "convert bam files to bed files ..."
    bamToBed -i ${ChIP_bam_prefix}_processed.bam > ${ChIP_bam_prefix}_processed.bed &
    bamToBed -i ${Control_bam_prefix}_processed.bam > ${Control_bam_prefix}_processed.bed &
    echo "convert bam files to bed files ..." >> logfile
    echo "bamToBed -i ${ChIP_bam_prefix}_processed.bam > ${ChIP_bam_prefix}_processed.bed &" >> logfile
    echo "bamToBed -i ${Control_bam_prefix}_processed.bam > ${Control_bam_prefix}_processed.bed &" >> logfile
    wait
    echo "peak calling using SICER ..."
    mkdir sicer
    bash /home/SICER_V1.1/SICER/SICER.sh . ${ChIP_bam_prefix}_processed.bed ${Control_bam_prefix}_processed.bed sicer $genome 1 $window_size $fragment_size 0.86 $gap_size $FDR
    echo "peak calling using SICER ..." >> logfile
    echo "bash /home/SICER_V1.1/SICER/SICER.sh . ${ChIP_bam_prefix}_processed.bed ${Control_bam_prefix}_processed.bed sicer $genome 1 $window_size $fragment_size 0.86 $gap_size $FDR" >> logfile



    #############################################
    # remove black list
    #############################################
    if [ "$rm_blackList" == "true" ]; then
    echo "Removing peaks overlapped with black list ..."
    black_list=${genome}-Blacklist.bed
    subtractBed -a <(gawk '{if($1 !~ /^chr/ && $1 ~ /^[1-9XYM]/ ) {print "chr"$_} else {print $_} }' sicer/${ChIP_bam_prefix}_processed-W200-G600-islands-summary-FDR*) -b $black_list |cut -f 1-3 > ${ChIP_bam_prefix}_sicer.clean.bed
    echo "subtractBed -a <(gawk '{if($1 !~ /^chr/ && $1 ~ /^[1-9XYM]/ ) {print "chr"$_} else {print $_} }' sicer/${ChIP_bam_prefix}_processed-W200-G600-islands-summary-FDR*) -b $black_list |cut -f 1-3 > ${ChIP_bam_prefix}_sicer.clean.bed" >> logfile
    fi


    #############################################
    # metrics
    #############################################
    echo "TotalReads MappedReads MapRate FinalRead DupRate" > ${ChIP_bam_prefix}.metrics.txt
    for i in ${ChIP_bam_prefix} ${Control_bam_prefix}
    do
	echo $i
	sambamba flagstat ${i}.bam > $i.flagstat
	TotalReads=`head -n 1 $i.flagstat | awk '{print $1}'`
        MappedReads=`head -n 5 $i.flagstat | tail -n 1 | awk '{print $1}'`
        UniqueMappedReads=`sambamba flagstat ${i}_processed.1.bam | head -n 5 | tail -n 1 | awk '{print $1}'`
        AfterDeDup=`sambamba flagstat ${i}_processed.1.bam | head -n 5 | tail -n 1 | awk '{print $1}'`
        FinalRead=`sambamba flagstat ${i}_processed.bam | head -n 5 | tail -n 1 | awk '{print $1}'`
	MapRate=`echo "$MappedReads/$TotalReads" | bc -l `
	DupRate=`echo "1-$AfterDeDup/$MappedReads" | bc -l`
	echo "$TotalReads $MappedReads $MapRate $FinalRead $DupRate"
    done | paste - - >> ${ChIP_bam_prefix}.metrics.txt
    echo >> ${ChIP_bam_prefix}.metrics.txt
    echo "`wc -l sicer/${ChIP_bam_prefix}_processed-W200-G600-islands-summary-FDR*` peaks" >> ${ChIP_bam_prefix}.metrics.txt
    if [ "$rm_blackList" == "true" ]; then
        echo "`wc -l ${ChIP_bam_prefix}_sicer.clean.bed` peaks after subtracting peaks from blacklist" >> ${ChIP_bam_prefix}.metrics.txt
    fi
    echo "fragment size used: $fragment_size" >> ${ChIP_bam_prefix}.metrics.txt


    #############################################
    # output bigwig file
    #############################################
    if [ "$bw_out" == "true" ]; then
function bam2bw {
i=$1
nReads=`head -n 3 ${ChIP_bam_prefix}.metrics.txt| grep -w $i | awk '{print $5}' `
scale=`echo "15000000/$nReads" | bc -l `
bamToBed -i ${i}_processed.bam > ${i}_processed.bed
extendTag.pl ${genome}.chrom.sizes ${i}_processed.bed $fragment_size 
genomeCoverageBed -bg -i ${i}_processed.extended.bed -g ${genome}.chrom.sizes -scale "$scale" | sort -k1,1 -k2,2n > ${i}_processed.bedg
bedGraphToBigWig ${i}_processed.bedg ${genome}.chrom.sizes ${i}.bw
echo "extendTag.pl ${genome}.chrom.sizes ${i}_processed.bed $fragment_size" >> logfile
echo "genomeCoverageBed -bg -i ${i}_processed.extended.bed -g ${genome}.chrom.sizes -scale "$scale" | sort -k1,1 -k2,2n" >> logfile
echo "genomeCoverageBed -bg -i ${i}_processed.extended.bed -g ${genome}.chrom.sizes -scale "$scale" | sort -k1,1 -k2,2n > ${i}_processed.bedg" >> logfile
echo "bedGraphToBigWig ${i}_processed.bedg ${genome}.chrom.sizes ${i}.bw" >> logfile
rm ${i}_processed.bedg
}
    for prefix in ${ChIP_bam_prefix} ${Control_bam_prefix}
    do
	bam2bw $prefix &
    done
    wait
    fi


    # Fill in your application code here.
    #
    # To report any recognized errors in the correct format in
    # $HOME/job_error.json and exit this script, you can use the
    # dx-jobutil-report-error utility as follows:
    #
    #   dx-jobutil-report-error "My error message"
    #
    # Note however that this entire bash script is executed with -e
    # when running in the cloud, so any line which returns a nonzero
    # exit code will prematurely exit the script; if no error was
    # reported in the job_error.json file, then the failure reason
    # will be AppInternalError with a generic error message.

    # The following line(s) use the dx command-line tool to upload your file
    # outputs after you have created them on the local file system.  It assumes
    # that you have used the output field name for the filename for each output,
    # but you can change that behavior to suit your needs.  Run "dx upload -h"
    # to see more options to set metadata.

    if [ "$rm_blackList" == "true" ]; then
    peak_file=$(dx upload --tag sjcp-result-file --path $DX_PROJECT_CONTEXT_ID:$out_folder/Results/${out_prefix}/SICER/ ${ChIP_bam_prefix}_sicer.clean.bed --brief  )
    LC_COLLATE=C sort -k1,1 -k2,2n ${ChIP_bam_prefix}_sicer.clean.bed > ${ChIP_bam_prefix}_sicer.clean.sorted.bed
    bedToBigBed ${ChIP_bam_prefix}_sicer.clean.sorted.bed ${genome}.chrom.sizes ${ChIP_bam_prefix}_sicer.clean.bb
    peak_bb=$(dx upload --tag sjcp-result-file --path $DX_PROJECT_CONTEXT_ID:$out_folder/Results/${out_prefix}/SICER/ ${ChIP_bam_prefix}_sicer.clean.bb --brief  )
    else
    gawk '{if($1 !~ /^chr/) {print "chr"$_} else {print $_} }' sicer/${ChIP_bam_prefix}_processed-W200-G600-islands-summary-FDR* | cut -f 1-3 > ${ChIP_bam_prefix}_sicer.bed
    echo "gawk '{if($1 !~ /^chr/) {print "chr"$_} else {print $_} }' sicer/${ChIP_bam_prefix}_processed-W200-G600-islands-summary-FDR* | cut -f 1-3 > ${ChIP_bam_prefix}_sicer.bed" >> logfile
    peak_file=$(dx upload --tag sjcp-result-file --path $DX_PROJECT_CONTEXT_ID:$out_folder/Results/${out_prefix}/SICER/ ${ChIP_bam_prefix}_sicer.bed --brief  )
    LC_COLLATE=C sort -k1,1 -k2,2n ${ChIP_bam_prefix}_sicer.bed > ${ChIP_bam_prefix}_sicer.sorted.bed
    bedToBigBed ${ChIP_bam_prefix}_sicer.sorted.bed ${genome}.chrom.sizes ${ChIP_bam_prefix}_sicer.bb
    peak_bb=$(dx upload --tag sjcp-result-file --path $DX_PROJECT_CONTEXT_ID:$out_folder/Results/${out_prefix}/SICER/ ${ChIP_bam_prefix}_sicer.bb --brief  )
    fi
    dx-jobutil-add-output peak_file "$peak_file" --class=file
    dx-jobutil-add-output peak_bb "$peak_bb" --class=file

    if [ $bw_out == "true" ]; then 
    ChIP_bw=$(dx upload --tag sjcp-result-file --path $DX_PROJECT_CONTEXT_ID:$out_folder/Results/${out_prefix}/SICER/ ${ChIP_bam_prefix}.bw --brief  )
    Control_bw=$(dx upload --tag sjcp-result-file --path $DX_PROJECT_CONTEXT_ID:$out_folder/Results/${out_prefix}/SICER/ ${Control_bam_prefix}.bw --brief  )
    dx-jobutil-add-output ChIP_bw "$ChIP_bw" --class=file
    dx-jobutil-add-output Control_bw "$Control_bw" --class=file
    fi

    mv logfile ${ChIP_bam_prefix}.sicer.log
    sicer_log=$(dx upload --path $DX_PROJECT_CONTEXT_ID:$out_folder/Results/${out_prefix}/SICER/ ${ChIP_bam_prefix}.sicer.log --brief  )
    dx-jobutil-add-output sicer_log "$sicer_log" --class=file

    metrics_file=$(dx upload --tag sjcp-result-file --path $DX_PROJECT_CONTEXT_ID:$out_folder/Results/${out_prefix}/SICER/ ${ChIP_bam_prefix}.metrics.txt --brief  )
    dx-jobutil-add-output metrics_file "$metrics_file" --class=file
    peak_file_raw=$(dx upload --path $DX_PROJECT_CONTEXT_ID:$out_folder/Results/${out_prefix}/SICER/ sicer/${ChIP_bam_prefix}_processed-W200-G600-islands-summary-FDR* --brief  )
    dx-jobutil-add-output peak_file_raw "$peak_file_raw" --class=file

    # The following line(s) use the utility dx-jobutil-add-output to format and
    # add output variables to your job's output as appropriate for the output
    # class.  Run "dx-jobutil-add-output -h" for more information on what it
    # does.

    # output json bed files
    source bed2jsonbed.sh
    if [ "$rm_blackList" == "true" ]; then
        bed2convert=${ChIP_bam_prefix}_sicer.clean.bed
    else 
        bed2convert=${ChIP_bam_prefix}_sicer.bed
    fi
    run_bed2jsonbed $bed2convert
    out_bedj=$(dx upload --path $DX_PROJECT_CONTEXT_ID:$out_folder/Results/${out_prefix}/SICER/ ${bed2convert%.bed}.bedj.gz --brief  )
    out_bedj_tbi=$(dx upload --path $DX_PROJECT_CONTEXT_ID:$out_folder/Results/${out_prefix}/SICER/ ${bed2convert%.bed}.bedj.gz.tbi --brief  )
    dx-jobutil-add-output bedj --class=file $out_bedj
    dx-jobutil-add-output bedj_tbi --class=file $out_bedj_tbi
}
