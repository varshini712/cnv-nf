params.ref_fasta = "/ifs/data/sequence/Illumina/igor/ref/hg19/genome.fa"
params.targetbed = "NGS580_target.bed"
params.tumorBam = "SeraCare-1to1-Positive.bam"
params.tumorBai = "${params.tumorBam}.bai"
params.normalBam = "HapMap-B17-1267.bam"
params.normalBai = "${params.normalBam}.bai"
params.output_dir = "output"


Channel.from( ['Sample1'] ).into { samples; samples2 }
Channel.from( [ [ file(params.tumorBam), file(params.tumorBai), file(params.normalBam), file(params.normalBai), file(params.targetbed), file(params.ref_fasta) ]  ] ).into { input_items; input_items2 }

input_items2.subscribe { println "[input_items2] ${it}" }

process cnvkit {
    tag { "${tumorBam}" }
    publishDir "${params.output_dir}/cnvkit", mode: 'copy', overwrite: true
    echo true

    input:
    set file(tumorBam), file(tumorBai), file(normalBam), file(normalBai), file(targetbed), file(ref_fasta) from input_items

    output:
    set file(output_cns), file(output_cnr) into cnvs
    file(output_diagram)
    file(output_scatter)

    script:
    output_cns = "${tumorBam}".replaceFirst(/.bam$/, ".cns")
    output_cnr = "${tumorBam}".replaceFirst(/.bam$/, ".cnr")
    output_diagram = "${tumorBam}".replaceFirst(/.bam$/, "-diagram.pdf")
    output_scatter = "${tumorBam}".replaceFirst(/.bam$/, "-scatter.pdf")
    """
    cnvkit.py batch "${tumorBam}" \
    --normal "${normalBam}" \
    --targets "${targetbed}" \
    --fasta "${ref_fasta}" \
    --output-reference normal_reference.cnn \
    --diagram  \
    --scatter \
    -p \${NSLOTS:-1}

    """
}

process cnvtweak {
    tag { "${input_cns}" }
    publishDir "${params.output_dir}/cnvkit", mode: 'copy', overwrite: true
    echo true

    input:
    set file(input_cns), file(input_cnr) from cnvs

    output:
    file(output_finalcns) 
    file(output_finalcnr)

    script:
    inputfile_name = "${input_cns}".replaceFirst(/.cns/, "")
    output_finalcns = "${input_cns}".replaceFirst(/.cns$/, ".final.cns")
    output_finalcnr = "${input_cnr}".replaceFirst(/.cnr$/, ".final.cnr")
    """
        cnvkit.py call --filter cn "${input_cns}"
        cnvkit.py gainloss "${input_cnr}" -s ${inputfile_name}.call.cns -t 0.3 -m 5 > ${inputfile_name}.segment-gainloss.txt
        cnvkit.py gainloss "${input_cnr}" -t 0.3 -m 5 > ${inputfile_name}.final.cnr
        cnvkit.py gainloss "${input_cnr}" -s ${inputfile_name}.call.cns -t 0.3 -m 5 | tail -n+2 | cut -f1 | sort > ${inputfile_name}.segment-genes.txt
        cnvkit.py gainloss "${input_cnr}" -t 0.3 -m 5 | tail -n+2 | cut -f1 | sort > ${inputfile_name}.ratio-genes.txt
        comm -12 ${inputfile_name}.ratio-genes.txt ${inputfile_name}.segment-genes.txt > ${inputfile_name}.trusted-genes.txt
        cat ${inputfile_name}.segment-gainloss.txt | head -n +1 > ${inputfile_name}.final.cns
        grep -w -f ${inputfile_name}.trusted-genes.txt ${inputfile_name}.segment-gainloss.txt > ${inputfile_name}.final.cns

    """
}

