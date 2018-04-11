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

    script:
    """
    echo "[cnvtweak] ${input_cns} ${input_cnr}"
    """

    // """
    // cnvkit.py call --filter cn $T.cns
    // cnvkit.py gainloss $T.cnr -s $T.call.cns -t 0.3 -m 5 > $T.segment-gainloss.txt
    // cnvkit.py gainloss $T.cnr -t 0.3 -m 5 > $T.final.cnr
    // cnvkit.py gainloss $T.cnr -s $T.call.cns -t 0.3 -m 5 | tail -n+2 | cut -f1 | sort > $T.segment-genes.txt
    // cnvkit.py gainloss $T.cnr -t 0.3 -m 5 | tail -n+2 | cut -f1 | sort > $T.ratio-genes.txt
    // comm -12 $T.ratio-genes.txt $T.segment-genes.txt > $T.trusted-genes.txt
    // cat $T.segment-gainloss.txt | head -n +1 > $T.final.cns
    // for gene in `cat $T.trusted-genes.txt`; do grep -e $gene $T.segment-gainloss.txt; done >> $T.final.cns
    // """
}
