"""Gather information from three gzipped input files -
a tabular file with per-sample date info, a tabular file with pangolin lineage
information, and a JSON file with encoded per-sample variant information -
and write the combined data in tabular form to a zip file.
Also creates an SQL init file with the instructions to build a DB from the
contents of the zip file.
"""

import gzip
import json
import os
import zipfile

from compress_for_dashboard import parse_compressed


print('Reading sample date and study_accession info ...')
with open('gx-surveillance.json') as meta_in:
    all_meta = json.load(meta_in)
    sample_info = {}
    for batch_info in all_meta.values():
        comp_date = batch_info.get('time', '').split('T')[0]
        study_accession = batch_info.get('study_accession', '')
        if 'samples' in batch_info and 'collection_dates' in batch_info:
            for accession, coll_date in zip(
                batch_info['samples'],
                batch_info['collection_dates']
            ):
                assert accession not in sample_info, \
                "Duplicate sample info for: {0}".format(accession)
                if coll_date:
                    sample_info[accession] = (
                        study_accession, coll_date, comp_date, '', ''
                    )


print('Reading pangolin lineage information ...')
with gzip.open('all_pangolin.tsv.gz', 'rt') as pango_in:
    header = pango_in.readline().strip().split('\t')
    assert header[:5] == [
        'taxon', 'lineage', 'conflict', 'ambiguity_score', 'scorpio_call'
    ], "This doesn't look like the expected pangolin output format"

    for line in pango_in:
        fields = line.strip().split('\t')[:5]
        accession, lineage, scorpio_call = fields[0], fields[1], fields[4]
        if accession in sample_info:
            (
                study_acc, coll_date, comp_date,
                exist_lin, exist_scorpio
            ) = sample_info[accession]
            assert not exist_lin and not exist_scorpio, \
                   "Duplicate pangolin output found for: {0}".format(accession)
            sample_info[accession] = (
                study_acc, coll_date, comp_date, lineage, scorpio_call
            )


print('Reading per-sample variants data ...')
with gzip.open('gx-observable_data_PRJEB37886.json.gz', 'rt') as variants_in:
    compressed_data = json.load(variants_in)


print('Generating combined data table ...')
tmp_tabular_file = 'data.tsv'
with open(tmp_tabular_file, 'w') as plain_tabular:
    for accession, variant, af in parse_compressed(compressed_data):
        if accession in sample_info:
            record = (accession,) + sample_info[accession] + variant + (af,)
        else:
            record = (accession,) + ('', '', '', '', '') + variant + (af,)
        plain_tabular.write('\t'.join(str(v) for v in record) + '\n')


print('Writing zip file with combined data ...')
with zipfile.ZipFile(
    'gx-observable.zip', 'w', compression=zipfile.ZIP_DEFLATED
) as zipped_tabular:
    zipped_tabular.write(tmp_tabular_file)

os.remove(tmp_tabular_file)

print('Finished successfully!')
