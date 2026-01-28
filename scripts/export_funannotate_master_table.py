cat > export_funannotate_master_table.py <<'PY'
#!/usr/bin/env python3
import sys, os, re, csv, gzip
from collections import defaultdict, OrderedDict

def read_fasta(path):
    if not path or not os.path.exists(path): return {}
    op = gzip.open if path.endswith(".gz") else open
    seqs={}
    with op(path, "rt") as f:
        hdr=None; parts=[]
        for line in f:
            if line.startswith(">"):
                if hdr is not None:
                    seqs[hdr]= "".join(parts)
                hdr = line[1:].strip().split()[0]
                parts=[]
            else:
                parts.append(line.strip())
        if hdr is not None:
            seqs[hdr]= "".join(parts)
    return seqs

def parse_attrs(attr):
    d={}
    for kv in attr.split(";"):
        if not kv: continue
        if "=" in kv:
            k,v=kv.split("=",1)
            d[k]=v
    return d

def load_annotations_table(path):
    """
    Funannotate writes annotate_results/Aspergillus_calidoustus.annotations.txt.
    Its columns vary by version; we try to map useful ones by header names.
    We key primarily by TranscriptID (ID or Name columns).
    """
    if not path or not os.path.exists(path): return {}
    keep={"EC_number","PFAM","InterPro","EggNog","COG","GO Terms","Secreted","Membrane","Protease","CAZyme","Name","Product","Alias/Synonyms"}
    # Tolerate a variety of header spellings:
    aliases={
        "GO":"GO Terms","GO_terms":"GO Terms","go_terms":"GO Terms",
        "PFAM":"PFAM","Pfam":"PFAM","pfam":"PFAM",
        "InterPro":"InterPro","interpro":"InterPro",
        "EggNog":"EggNog","eggnog":"EggNog","COG":"COG",
        "SignalP":"Secreted","Secreted":"Secreted",
        "TMHMM":"Membrane","Transmembrane":"Membrane",
        "MEROPS":"Protease","CAZy":"CAZyme","CAZyme":"CAZyme",
        "product":"Product","Product":"Product","gene_name":"Name","Name":"Name",
        "Synonyms":"Alias/Synonyms","Alias/Synonyms":"Alias/Synonyms",
        "EC":"EC_number","EC_number":"EC_number"
    }
    ann={}
    with open(path) as f:
        rdr = csv.DictReader(f, delimiter='\t')
        hdrs = rdr.fieldnames or []
        # Build a canonical map for the columns we know:
        canon = {}
        for h in hdrs:
            canon[h] = aliases.get(h,h)
        for row in rdr:
            # find a key (TranscriptID, ID, or Name)
            key = row.get("TranscriptID") or row.get("ID") or row.get("Name")
            if not key:
                continue
            r={}
            for h,v in row.items():
                ch = canon.get(h,h)
                if ch in keep and v:
                    r[ch]=v
            ann[key]=r
    return ann

def main():
    if len(sys.argv) < 6:
        sys.stderr.write("Usage:\n  python3 export_funannotate_master_table.py <in.gff3> <proteins.faa> <mrna.fa> <cds.fa> <out.tsv> [annotations.txt]\n")
        sys.exit(2)
    gff, faa, mrna, cds, out = sys.argv[1:6]
    ann_path = sys.argv[6] if len(sys.argv) > 6 else None

    prot = read_fasta(faa)
    mrna_seqs = read_fasta(mrna)
    cds_seqs  = read_fasta(cds)
    ann_tab = load_annotations_table(ann_path)

    # Map protein -> transcript via .p# -> .t#
    prot2tx = {}
    for pid in prot.keys():
        if ".p" in pid:
            prot2tx[pid] = pid.replace(".p", ".t")
        else:
            # fallback: use the header as-is (may already be transcript)
            prot2tx[pid] = pid

    rows=[]
    # gene->basic info for gDNA extraction is omitted here to avoid reading the genome;
    # we leave gDNA blank (can be filled later if needed).
    with open(gff) as f:
        for line in f:
            if not line or line.startswith("#"): continue
            cols = line.rstrip("\n").split("\t")
            if len(cols) < 9: continue
            seqid, src, ftype, start, end, score, strand, phase, attrs = cols
            A = parse_attrs(attrs)

            if ftype not in ("mRNA","transcript"):
                continue
            tx_id = A.get("ID","")
            gene_id = (A.get("Parent","") or "").split(",")[0]
            name = A.get("Name","")
            product = A.get("product") or A.get("gene_product") or A.get("Product","")

            # sequences
            tx_seq = mrna_seqs.get(tx_id,"")
            cds_seq = cds_seqs.get(tx_id,"")

            # protein: try KZJ39_000001.p1 header; if mrna header present in proteins, fallback by replacing .t -> .p
            pid_guess = tx_id.replace(".t",".p")
            prot_id = pid_guess if pid_guess in prot else None
            if not prot_id:
                # some headers may store transcript IDs; try direct match
                prot_id = tx_id if tx_id in prot else None
            pep_seq = prot.get(prot_id,"")

            # pull function annotations if present; try by TranscriptID or Name
            annot = ann_tab.get(tx_id) or ann_tab.get(name) or {}
            def g(k): return annot.get(k,"")

            row = OrderedDict()
            row["GeneID"]          = gene_id
            row["TranscriptID"]    = tx_id
            row["Feature"]         = ftype
            row["Contig"]          = seqid
            row["Start"]           = start
            row["Stop"]            = end
            row["Strand"]          = strand
            row["Name"]            = name
            row["Product"]         = product
            row["Alias/Synonyms"]  = g("Alias/Synonyms")
            row["EC_number"]       = g("EC_number")
            row["BUSCO"]           = g("BUSCO")              # may be empty if not in annotations.txt
            row["PFAM"]            = g("PFAM")
            row["InterPro"]        = g("InterPro")
            row["EggNog"]          = g("EggNog")
            row["COG"]             = g("COG")
            row["GO Terms"]        = g("GO Terms")
            row["Secreted"]        = g("Secreted")
            row["Membrane"]        = g("Membrane")
            row["Protease"]        = g("Protease")
            row["CAZyme"]          = g("CAZyme")
            row["Notes"]           = ""
            row["gDNA"]            = ""                      # not extracting genomic span here
            row["mRNA"]            = tx_seq
            row["CDS-transcript"]  = cds_seq
            row["Translation"]     = pep_seq

            rows.append(row)

    # write
    cols = list(rows[0].keys()) if rows else ["GeneID"]
    with open(out,"w",newline="") as fo:
        w = csv.writer(fo, delimiter='\t', lineterminator='\n', quoting=csv.QUOTE_NONE, escapechar='\\')
        print(f"Genes: {len(set([r['GeneID'] for r in rows]))}", file=fo)
        w.writerow(cols)
        for r in rows:
            w.writerow([r.get(c,"") for c in cols])
    print(f"[ok] wrote {out} with {len(rows)} transcripts", file=sys.stderr)

if __name__ == "__main__":
    main()
PY
