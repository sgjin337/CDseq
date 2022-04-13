import pandas as pd
from snakemake.utils import validate, min_version
##### set minimum snakemake version #####
min_version("5.15.0")

##### load config and sample sheets #####
configfile: "bin/config.yaml"

samples = pd.read_table("bin/samples.tsv").set_index("sample", drop=False)

##### target rules #####

rule all:
    input:
        # # mergeLanesAndRename_PE
        expand("raw_data/{samples.sample}-R1.fastq.gz", samples=samples.itertuples()),
        expand("raw_data/{samples.sample}-R2.fastq.gz", samples=samples.itertuples()),
        # fastq_screen
        expand("analysis/fastq_screen/{samples.sample}-{read}_screen.html", read=["R1","R2"], samples=samples.itertuples()),
        expand("analysis/fastq_screen/{samples.sample}-{read}_screen.txt", read=["R1","R2"], samples=samples.itertuples()),
        # # trim_galore_hardtrim5
        expand("analysis/trim_reads/{samples.sample}-R1.50bp_5prime.fq.gz", samples=samples.itertuples()),
        expand("analysis/trim_reads/{samples.sample}-R2.50bp_5prime.fq.gz", samples=samples.itertuples()),
        # # trim_galore
        expand("analysis/trim_reads/{samples.sample}-R1.50bp_5prime_val_1.fq.gz", samples=samples.itertuples()),
        expand("analysis/trim_reads/{samples.sample}-R2.50bp_5prime_val_2.fq.gz", samples=samples.itertuples()),
        # bwa_mem
        expand("analysis/align/{samples.sample}.sorted.dupremoved.q20.bam", samples=samples.itertuples()),
        # expand("analysis/align/{samples.sample}.sorted.dupremoved.q20.bam.bai", samples=samples.itertuples()),
        # TLEN3_bam
        expand("analysis/extract_TLEN3/{samples.sample}.TLEN3.bam", samples=samples.itertuples()),
        expand("analysis/extract_TLEN3/{samples.sample}.TLEN3.bam.bai", samples=samples.itertuples()),
        # extract_TLEN3_8oxoG
        expand("analysis/extract_TLEN3/{samples.sample}.TLEN3.bed", samples=samples.itertuples()),
        expand("analysis/extract_TLEN3/{samples.sample}.TLEN3.sorted.bed.gz", samples=samples.itertuples()),
        expand("analysis/extract_TLEN3/{samples.sample}.TLEN3.sorted.bed.gz.tbi", samples=samples.itertuples()),
        # # lenX_3prime_bed
        # expand("analysis/extract_TLEN3/{samples.sample}.TLEN3.nt{len}.3prime.bed", len=[1,2], samples=samples.itertuples()),
        # # lenX_5prime_bed
        # expand("analysis/extract_TLEN3/{samples.sample}.TLEN3.nt{len}.5prime.bed", len=[1,2], samples=samples.itertuples()),
        # logo_bed
        expand("analysis/extract_TLEN3/{samples.sample}.TLEN3.logo.bed", samples=samples.itertuples()),
        # logo_bed_agnostic
        expand("analysis/extract_TLEN3/{samples.sample}.TLEN3.logo.agnostic.seq", samples=samples.itertuples()),
        expand("analysis/extract_TLEN3/{samples.sample}.TLEN3.logo.agnostic.bed", samples=samples.itertuples()),
        # render_rmd
        expand("bin/{report}.html", report=config["report"]),

rule mergeLanesAndRename:
    input:
    output:
        "raw_data/{sample}-R1.fastq.gz",
        "raw_data/{sample}-R2.fastq.gz"
    log:
        "logs/mergeLanesAndRename/mergeLanesAndRename_PE-{sample}.log"
    benchmark:
        "benchmarks/mergeLanesAndRename/{sample}.bmk"
    resources:
        nodes = 1,
        threads = 1,
        mem_gb = 16
    envmodules:
        "bbc/R/R-3.6.0"
    script:
        "bin/mergeLanesAndRename.R"

rule fastq_screen:
    input:
        R1 =      "raw_data/{sample}-R1.fastq.gz",
        R2 =      "raw_data/{sample}-R2.fastq.gz",
    output:
        R1_html = "analysis/fastq_screen/{sample}-R1_screen.html",
        R1_txt =  "analysis/fastq_screen/{sample}-R1_screen.txt",
        R2_html = "analysis/fastq_screen/{sample}-R2_screen.html",
        R2_txt =  "analysis/fastq_screen/{sample}-R2_screen.txt",
    log:
        R1 =      "logs/fastq_screen/fastq_screen.{sample}-R1.log",
        R2 =      "logs/fastq_screen/fastq_screen.{sample}-R2.log",
    benchmark:
        "benchmarks/fastq_screen/{sample}.bmk"
    resources:
        nodes = 1,
        threads = 8,
        mem_gb = 64,
    envmodules:
        "bbc/fastq_screen/fastq_screen-0.14.0"
    shell:
        """
        fastq_screen --outdir analysis/fastq_screen/ {input.R1} 2> {log.R1}
        fastq_screen --outdir analysis/fastq_screen/ {input.R2} 2> {log.R2}
        """

rule trim_galore_hardtrim5:
    input:
        R1 = "raw_data/{sample}-R1.fastq.gz",
        R2 = "raw_data/{sample}-R2.fastq.gz",
    output:
        R1 = "analysis/trim_reads/{sample}-R1.50bp_5prime.fq.gz",
        R2 = "analysis/trim_reads/{sample}-R2.50bp_5prime.fq.gz",
    log:
        R1_o = "logs/trim_galore_hardtrim5/{sample}-R1.o",
        R1_e = "logs/trim_galore_hardtrim5/{sample}-R1.e",
        R2_o = "logs/trim_galore_hardtrim5/{sample}-R2.o",
        R2_e = "logs/trim_galore_hardtrim5/{sample}-R2.e",
    benchmark:
        "benchmarks/trim_galore_hardtrim5/{sample}.bmk",
    params:
        outdir="analysis/trim_reads/",
    envmodules:
        "bbc/trim_galore/trim_galore-0.6.0",
        "bbc/pigz/pigz-2.4",
    resources:
        nodes = 1,
        threads = 4,
        mem_gb=80,
    shell:
        """
        trim_galore \
        --hardtrim5 50 \
        --output_dir {params.outdir} \
        --cores {resources.threads} \
        {input.R1} 2> {log.R1_e} 1> {log.R1_o}

        trim_galore \
        --hardtrim5 50 \
        --output_dir {params.outdir} \
        --cores {resources.threads} \
        {input.R2} 2> {log.R2_e} 1> {log.R2_o}
        """
rule trim_galore:
    input:
        "analysis/trim_reads/{sample}-R1.50bp_5prime.fq.gz",
        "analysis/trim_reads/{sample}-R2.50bp_5prime.fq.gz",
    output:
        "analysis/trim_reads/{sample}-R1.50bp_5prime_val_1.fq.gz",
        "analysis/trim_reads/{sample}-R1.50bp_5prime_val_1_fastqc.html",
        "analysis/trim_reads/{sample}-R1.50bp_5prime_val_1_fastqc.zip",
        "analysis/trim_reads/{sample}-R1.50bp_5prime.fq.gz_trimming_report.txt",
        "analysis/trim_reads/{sample}-R2.50bp_5prime_val_2.fq.gz",
        "analysis/trim_reads/{sample}-R2.50bp_5prime_val_2_fastqc.html",
        "analysis/trim_reads/{sample}-R2.50bp_5prime_val_2_fastqc.zip",
        "analysis/trim_reads/{sample}-R2.50bp_5prime.fq.gz_trimming_report.txt",
    log:
        stdout="logs/trim_reads/{sample}.o",
        stderr="logs/trim_reads/{sample}.e"
    benchmark:
        "benchmarks/trim_reads/{sample}.bmk"
    params:
        outdir="analysis/trim_reads/",
    envmodules:
        "bbc/trim_galore/trim_galore-0.6.0",
        "bbc/pigz/pigz-2.4",
    resources:
        nodes = 1,
        threads = 4,
        mem_gb=80,
    shell:
        """
        trim_galore \
        --paired \
        --output_dir {params.outdir} \
        --cores {resources.threads} \
        -q 20 \
        --fastqc \
        {input} \
        2> {log.stderr} 1> {log.stdout}
        """

rule bwa_mem:
    input:
        R1 = "analysis/trim_reads/{sample}-R1.50bp_5prime_val_1.fq.gz",
        R2 = "analysis/trim_reads/{sample}-R2.50bp_5prime_val_2.fq.gz",
    output:
        sorted_dupremoved_q20_bam = "analysis/align/{sample}.sorted.dupremoved.q20.bam",
        #sorted_dupremoved_q20_bam_bai = "analysis/align/{sample}.sorted.dupremoved.q20.bam.bai"
    log:
        bwa =           "logs/align/bwa_mem.{sample}.log",
        samblaster =    "logs/align/samblaster.{sample}.log",
        samtools_view = "logs/align/samtools_view.{sample}.log",
        samtools_sort = "logs/align/samtools_sort.{sample}.log",
    benchmark:
        "benchmarks/bwa/{sample}.bmk"
    params:
        idx = config["idx"],
    envmodules:
        "bbc/bwa/bwa-0.7.17",
        "bbc/samblaster/samblaster-0.1.24",
        "bbc/samtools/samtools-1.9",
    resources:
        nodes = 1,
        threads = 30,
        mem_gb = 300,
    shell:
        """
        bwa mem -t {resources.threads} {params.idx} {input.R1} {input.R2} 2> {log.bwa}| \
        samblaster --removeDups 2> {log.samblaster}| \
        samtools view -@ {resources.threads} -h -q 20 2> {log.samtools_view}| \
        samtools sort -@ {resources.threads} -O BAM -o {output.sorted_dupremoved_q20_bam} 2> {log.samtools_sort}
        """

rule TLEN3_bam:
    input:
        bam = "analysis/align/{sample}.sorted.dupremoved.q20.bam"
    output:
        header =         temp("analysis/extract_TLEN3/{sample}.TLEN3_header.sam"),
        TLEN3_noHeader = temp("analysis/extract_TLEN3/{sample}.TLEN3_noHeader.sam"),
        TLEN3_bam =           "analysis/extract_TLEN3/{sample}.TLEN3.bam",
        TLEN3_bai =           "analysis/extract_TLEN3/{sample}.TLEN3.bam.bai",
    log:
        extract_header = "logs/extract_TLEN3/{sample}.extract_header.log",
        extract_TLEN3 =  "logs/extract_TLEN3/{sample}.extract_TLEN3.log",
        return_header =  "logs/extract_TLEN3/{sample}.return_header.log",
        index =          "logs/extract_TLEN3/{sample}.index.log"
    benchmark:
        "benchmarks/extract_TLEN3/{sample}.bmk"
    resources:
        nodes = 1,
        threads = 16,
        mem_gb = 64
    envmodules:
        "bbc/samtools/samtools-1.9",
    shell:
        """
        samtools view -@ {resources.threads} -H {input.bam} 1> {output.header} 2> {log.extract_header}
        samtools view -@ {resources.threads} {input.bam} | awk '{{ if ($9 == 3 || $9 ==-3) {{ print }} }}' >> {output.TLEN3_noHeader} 2> {log.extract_TLEN3}
        cat {output.header} {output.TLEN3_noHeader} | samtools view -@ {resources.threads} -O BAM -o {output.TLEN3_bam} 2> {log.return_header}
        samtools index -@ {resources.threads} -b {output.TLEN3_bam} 2> {log.index}
        """

# rule extract_TLEN3:
#     input:
#         TLEN3_bam = "analysis/extract_TLEN3/{sample}.TLEN3.bam",
#     output:
#         TLEN3_tmp =         temp("analysis/extract_TLEN3/{sample}.tmp"),
#         seq =               temp("analysis/extract_TLEN3/{sample}.TLEN3.seq"),
#         bed =                    "analysis/extract_TLEN3/{sample}.TLEN3.bed",
#         sorted_bed_gz =          "analysis/extract_TLEN3/{sample}.TLEN3.sorted.bed.gz",
#         sorted_bed_gz_tbi =      "analysis/extract_TLEN3/{sample}.TLEN3.sorted.bed.gz.tbi",
#
#     params:
#         ref =        expand("{ref}", ref=config["ref"]),
#         tmp =        "analysis/extract_TLEN3/{sample}.TLEN3.tmp",
#         sorted_bed = "analysis/extract_TLEN3/{sample}.TLEN3.sorted.bed",
#     log:
#         TLEN3_tmp =     "logs/extract_TLEN3/{sample}.TLEN3_tmp.log",
#         get_bed =       "logs/extract_TLEN3/{sample}.get_bed.log",
#         get_bed_name =  "logs/extract_TLEN3/{sample}.get_bed_name.log",
#         get_seq =       "logs/extract_TLEN3/{sample}.get_seq.log",
#         sort_bed =      "logs/extract_TLEN3/{sample}.sort_bed.log",
#
#     benchmark:
#         "benchmarks/extract_TLEN3/{sample}.bmk"
#     resources:
#         nodes = 1,
#         threads = 12,
#         mem_gb = 300,
#     envmodules:
#         "bbc/samtools/samtools-1.9",
#         "bbc/bedtools/bedtools-2.29.2",
#         "bbc/htslib/htslib-1.10.2",
#     shell:
#         """
#         # make temp SAM for parsing; extract only TLEN=3 (TLEN=-3 are mates, i.e. duplicate entries)
#         samtools view -@ {resources.threads} -h {input.TLEN3_bam} |\
#         awk -v OFS='\t' '{{ if ($9 ==3) {{ print }} }}' 1> {output.TLEN3_tmp} 2> {log.TLEN3_tmp}
#
#         # initiate BED [chr, start, stop]
#         awk -v OFS='\t' '{{ print $3,$8-3,$8 }}' {output.TLEN3_tmp} 1> {output.bed} 2> {log.get_bed}
#
#         # add name for row: [chr, start, stop, name]
#         awk -v OFS='\t' '{{$(NF+1) = "cut_"i++}} 1' {output.bed} > {params.tmp} && mv {params.tmp} {output.bed}
#
#         # get sequences from BED (5'-3' + strand by default)
#         bedtools getfasta -tab -fi {params.ref} -bed {output.bed} -fo {output.seq} 2> {log.get_seq}
#
#         # annotate strand based on middle nucleotide: T|G == (+)strand, A|C == (-)strand
#         awk -v OFS='\t' '{{if( $2 ~ /.[TG]./ ) print $0,"0","+"; else print $0,"0","-"}}' {output.seq} 1> {params.tmp} && mv {params.tmp} {output.seq}
#
#         # add seq, score, strand to BED: [chr, start, stop, name, (seq), score, strand]
#         paste {output.bed} {output.seq} | cut -f 1,2,3,4,6,7,8 > {params.tmp} && mv {params.tmp} {output.bed}
#
#         # merge name & seq fields: [chr, start, stop, name, score, strand]
#         awk 'BEGIN {{FS=OFS="\t"}} {{ $4 = $4 "_" $5; print $1, $2, $3, $4, $6, $7 }}' {output.bed} > {params.tmp} && mv {params.tmp} {output.bed}
#
#         # sort the BED file, bgzip it, index with tabix
#         bedtools sort -i {output.bed} 1> {params.sorted_bed} 2> {log.sort_bed}
#         bgzip -@ {threads} {params.sorted_bed}
#         tabix {output.sorted_bed_gz}
#         """

rule extract_TLEN3_8oxoG:
    input:
        TLEN3_bam =         "analysis/extract_TLEN3/{sample}.TLEN3.bam",
    output:
        bed =               "analysis/extract_TLEN3/{sample}.TLEN3.bed",
        seq =               "analysis/extract_TLEN3/{sample}.TLEN3.seq",
        cut_stats =         "analysis/extract_TLEN3/{sample}.cut_stats",
        sorted_bed_gz =     "analysis/extract_TLEN3/{sample}.TLEN3.sorted.bed.gz",
        sorted_bed_gz_tbi = "analysis/extract_TLEN3/{sample}.TLEN3.sorted.bed.gz.tbi",
    params:
        sorted_bed =        "analysis/extract_TLEN3/{sample}.TLEN3.sorted.bed",
        tmp =               "analysis/extract_TLEN3/{sample}.TLEN3.tmp",
        ref =               expand("{ref}", ref=config["ref"]),
    log:
        get_bed =    "logs/extract_TLEN3/{sample}.get_bed.log",
        get_seq =    "logs/extract_TLEN3/{sample}.get_seq.log",
        sort_bed =   "logs/extract_TLEN3/{sample}.sort_bed.log"
    benchmark:
                     "benchmarks/extract_TLEN3/{sample}.bmk"
    resources:
        nodes =     1,
        threads =   32,
        mem_gb =    300,
    envmodules:
        "bbc/samtools/samtools-1.9",
        "bbc/bedtools/bedtools-2.29.2",
        "bbc/htslib/htslib-1.10.2",
    shell:
        """
        # make temp SAM for parsing
        samtools view -@ {resources.threads} -h {input.TLEN3_bam} |\

        # extract only TLEN=3 (TLEN=-3 are mates, i.e. duplicate entries)
        awk -v OFS='\t' '{{ if ($9 ==3) {{ print }} }}' |\

        # initiate BED [chr, start, stop]
        awk -v OFS='\t' '{{ print $3,$8-3,$8 }}' |\

        # add name for row: [chr, start, stop, name]
        awk -v OFS='\t' '{{$(NF+1) = "cut_"i++}} 1' 1> {output.bed} 2> {log.get_bed}

        # get sequences from BED (5'-3' + strand by default)
        bedtools getfasta -tab -fi {params.ref} -bed {output.bed} -fo {output.seq} 2> {log.get_seq}

        # add strand and score based on middle nucleotide
        awk -v OFS='\t' '{{if( $2 ~ /.[Gg]./ ) print $0,"1","+"; \
        else if( $2 ~ /.[Cc]./ ) print $0,"1","-"; \
        else print $0,"0"," "; }}' {output.seq} 1> {params.tmp} && mv {params.tmp} {output.seq}

        # print stats
        awk -v OFS='\t' '{{if( $2 ~ /.[Gg]./ ) print "G","1","+"; \
        else if( $2 ~ /.[Cc]./ ) print "C","1","-"; \
        else print substr($2, 2, 1),"0"," "; }}' {output.seq} 1> {output.cut_stats}

        # add seq, score, strand to BED: [chr, start, stop, name, (seq), score, strand]
        paste {output.bed} {output.seq} |\
        awk 'BEGIN {{FS=OFS="\t"}} {{ $4 = $4 "_" $6; print $1, $2, $3, $4, $7, $8}}' > {params.tmp} && mv {params.tmp} {output.bed}

        # sort the BED file, bgzip it, index with tabix
        bedtools sort -i {output.bed} 1> {params.sorted_bed} 2> {log.sort_bed}
        bgzip -@ {threads} {params.sorted_bed} {output.sorted_bed_gz}
        tabix {output.sorted_bed_gz}
        """

rule logo_bed:
    input:
        bed =                "analysis/extract_TLEN3/{sample}.TLEN3.bed",
    output:
        bed_tmp =       temp("analysis/extract_TLEN3/{sample}.TLEN3.logo.bed_tmp"),
        logo_seq =           "analysis/extract_TLEN3/{sample}.TLEN3.logo.seq",
        logo_bed =           "analysis/extract_TLEN3/{sample}.TLEN3.logo.bed",
    params:
        ref =         config["ref"],
    log:
        bed_tmp =            "logs/get_logo_seq/{sample}.bed_tmp.log",
        seq =                "logs/get_logo_seq/{sample}.seq_tmp.log",
        logo_bed =           "logs/get_logo_seq/{sample}.logo.bed.log",
    resources:
        nodes = 1,
        threads = 1,
        mem_gb = 8,
    envmodules:
        "bbc/samtools/samtools-1.9",
        "bbc/bedtools/bedtools-2.29.2",
    shell:
        """
        # expand the start and stop coordinates to make a 20bp window around the cut site.
        awk 'BEGIN {{FS=OFS="\t"}} {{print $1, $2-9, $3+9, $4, $5, $6 }}' {input.bed} 1> {output.bed_tmp} 2> {log.bed_tmp}

        # get sequences from BED in strand-SPECIFIC manner.
        bedtools getfasta -s -tab -fi {params.ref} -bed {output.bed_tmp} -fo {output.logo_seq} 2> {log.seq}

        # merge new coordinates [chr, start, stop] with strand-aware element sequence [name, score, strand]
        paste {output.bed_tmp} {output.logo_seq} | \
        awk 'BEGIN {{FS=OFS="\t"}} {{ $4 = "cut_"i++"_"$8; print $1, $2, $3, $4, $5, $6 }}' 1> {output.logo_bed} 2> {log.logo_bed}
        """

rule logo_bed_agnostic:
    input:
        bed =                "analysis/extract_TLEN3/{sample}.TLEN3.bed",
    output:
        bed_tmp =       temp("analysis/extract_TLEN3/{sample}.TLEN3.logo.agnostic.bed_tmp"),
        logo_seq =           "analysis/extract_TLEN3/{sample}.TLEN3.logo.agnostic.seq",
        logo_bed =           "analysis/extract_TLEN3/{sample}.TLEN3.logo.agnostic.bed",
    params:
        ref =         config["ref"],
    log:
        bed_tmp =            "logs/logo_bed_agnostic/{sample}.bed_tmp.log",
        seq =                "logs/logo_bed_agnostic/{sample}.seq_tmp.log",
        logo_bed =           "logs/logo_bed_agnostic/{sample}.logo.bed.log",
    resources:
        nodes = 1,
        threads = 1,
        mem_gb = 8,
    envmodules:
        "bbc/samtools/samtools-1.9",
        "bbc/bedtools/bedtools-2.29.2",
    shell:
        """
        # expand the start and stop coordinates to make a 20bp window around the cut site.
        awk 'BEGIN {{FS=OFS="\t"}} {{print $1, $2-9, $3+9, $4, $5, $6 }}' {input.bed} 1> {output.bed_tmp} 2> {log.bed_tmp}

        # get sequences from BED in strand-AGNOSTIC manner.
        bedtools getfasta -tab -fi {params.ref} -bed {output.bed_tmp} -fo {output.logo_seq} 2> {log.seq}

        # merge new coordinates [chr, start, stop] with strand-aware element sequence [name, score, strand]
        paste {output.bed_tmp} {output.logo_seq} | \
        awk 'BEGIN {{FS=OFS="\t"}} {{ $4 = "cut_"i++"_"$8; print $1, $2, $3, $4, $5, $6 }}' 1> {output.logo_bed} 2> {log.logo_bed}
        """
rule render_rmd:
    input:
        nt_3prime = expand("analysis/extract_TLEN3/{samples.sample}.TLEN3.nt{len}.3prime.bed", len=[1,2], samples=samples.itertuples()),
        nt_5prime = expand("analysis/extract_TLEN3/{samples.sample}.TLEN3.nt{len}.5prime.bed", len=[1,2], samples=samples.itertuples()),
        logo_bed =  expand("analysis/extract_TLEN3/{samples.sample}.TLEN3.logo.bed", samples=samples.itertuples()),
        rmd =       expand("bin/{report}.Rmd", report=config["report"]),
    output:
        expand("bin/{report}.html", report=config["report"])
    params:
        ref = expand("{ref}", ref=config["ref"]),
    log:
        "logs/render_rmd.log",
    resources:
        nodes = "node095",
        threads = 1,
        mem_gb = 300,
    envmodules:
        # using the R on node095 and associated libraries required for rendering figures.
    shell:
        """
        # add rstudio-server pandoc installation to $PATH
        PATH=/usr/lib/rstudio-server/bin/pandoc:$PATH

        # render
        R -e 'rmarkdown::render("{input.rmd}")' 2> {log}
        """
