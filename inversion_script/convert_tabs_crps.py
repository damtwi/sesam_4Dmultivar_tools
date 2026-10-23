import re
from collections import defaultdict
import argparse

def clean_rows(rows, region):
    """
    Remove exact duplicates.
    Raise warning if duplicates with same key but different values.
    """
    unique_rows = set(rows)
    
    if len(unique_rows) == len(rows):
        return sorted(rows)

    # Detect problematic duplicates
    from collections import defaultdict
    grouped = defaultdict(list)
    
    for r in rows:
        key = r[:2]  # (idepth, size)
        grouped[key].append(r)

    for key, vals in grouped.items():
        if len(vals) > 1:
            if len(set(vals)) > 1:
                print(f"WARNING: inconsistent duplicates in region {region} for key {key}:")
                for v in vals:
                    print(f"  {v}")
    return sorted(unique_rows)

def parse_arguments():
    parser = argparse.ArgumentParser(
        description="Compare reference ensemble with two inverted ensembles"
    )

    parser.add_argument("--expmcmc", type=str, default="",
                        help="Reference of the mcmc INV1 experience. Type PRIOR for prior ensemble")
    parser.add_argument("--repertory", type=str, default="",
                        help="Reference of the mcmc repertory")
    return parser.parse_args()

args = parse_arguments()
expname = args.expmcmc
repertory = args.repertory
input_file = f"{expname}SMPENS0029_ens_crps_all.txt"
if expname=="PRIOR": 
    input_file = f"ENS0029_ens_crps_all.txt"

filename = repertory +"/" + input_file
print(repertory)
data = defaultdict(list)
idepth = None
with open(filename) as f:
    for line in f:

        # Detect idepth
        m = re.search(r'idepth=(\d+)', line)
        if m:
            idepth = int(m.group(1))

        # Detect region data line
        m = re.match(r'\s*(\d{4})\s+(\d+)\s+([0-9.E+-]+)\s+([0-9.E+-]+)\s+([0-9.E+-]+)', line)
        if m:
            region = m.group(1)
            size = m.group(2)
            reliability = m.group(3)
            resolution = m.group(4)
            crps = m.group(5)
            data[region].append((idepth, size, reliability, resolution, crps))

# Write one ASCII file per region
for region in data:
    ofilename = f"{expname}CRPS_region_{region}.txt"
    with open(repertory+"/"+ofilename, "w") as f:
        f.write("idepth  Size  Reliability  Resolution  CRPS\n")
        cleaned_rows = clean_rows(data[region], region)
        for row in cleaned_rows:
            f.write(f"{row[0]:6d} {row[1]:8s} {row[2]:14s} {row[3]:14s} {row[4]:14s}\n")


input_file = repertory+f"/{expname}SMPENS0029_ens_rcrv_all.txt"
if expname=="PRIOR": 
    input_file = repertory+f"/ENS0029_ens_rcrv_all.txt"
data = defaultdict(list)
idepth = None
with open(input_file) as f:
    for line in f:

        # Detect idepth
        m = re.search(r'idepth=(\d+)', line)
        if m:
            idepth = int(m.group(1))

        # Detect region data line
        m = re.match(r'\s*(\d{4})\s+(\d+)\s*([+-]?\d+\.\d+E[+-]\d+)\s+([0-9.E+-]+)', line)
        if m:
            region = m.group(1)
            size = m.group(2)
            Bias = m.group(3)
            Spread = m.group(4)
            data[region].append((idepth, size, Bias, Spread))

# Write one ASCII file per region
for region in data:
    ofilename = f"{expname}RCRV_region_{region}.txt"
    with open(repertory+"/"+ofilename, "w") as f:
        f.write("idepth  Size  Bias Spread\n")
        cleaned_rows = clean_rows(data[region], region)
        for row in cleaned_rows:
            f.write(f"{row[0]:6d} {row[1]:8s} {row[2]:14s} {row[3]:14s}\n")
