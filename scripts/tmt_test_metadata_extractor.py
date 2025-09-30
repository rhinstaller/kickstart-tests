#!/usr/bin/python3

import click
from glob import glob
from subprocess import check_output
import yaml
from pprint import pprint
import os

KSTESTDIR_ENV="KSTESTDIR"
MAX_DEPTH = 2

class RawTMTMetadata:
    tmt_file = "tests.fmf"
    tmt_tag = "tag"
    tmt_test = "test"
    launch_data_var = "--data /var/tmp/ks_data"
    platform_var = "--platform rhel10"
    tmt_test_prefix = f"./containers/runner/launch {launch_data_var} {platform_var} "
    tmt_base_test_structure_list = []
    tmt_stuff_item = ["_"]


    def __init__(self, filename: str, extension: str, delimiter: str, metadata: str, kstestdir:str):
        self.filename = filename
        self.extension = extension
        self.delimiter = delimiter
        self.metadata = metadata
        self.kstestdir = kstestdir
        self.data = {}

    def parse_file_name_structure(self, extension_part=".", max_depth=MAX_DEPTH) -> list:
        item_no_extension=self.filename.rsplit(extension_part, 1)[:-1][0].rsplit("/",1)[-1]
        if not self.delimiter:
            return self.tmt_base_test_structure_list + [item_no_extension]
        strct_items = item_no_extension.split(self.delimiter, max_depth)
        return self.tmt_base_test_structure_list + strct_items + self.tmt_stuff_item * (max_depth + 1 - len(strct_items))

    def get_file_tags(self):
        out = check_output(f"""bash -c '{KSTESTDIR_ENV}="{self.kstestdir}" source {self.filename}; echo $TESTTYPE || true'""", shell=True)
        return out.decode().strip().split()

    def load_tmt_file(self):
        with open(self.tmt_file) as stream:
            self.data = yaml.safe_load(stream)

    def store_tmt_file(self):
        with open(self.tmt_file, 'w') as outfile:
            yaml.dump(self.data, outfile)

    def create_or_update_base_structure(self):
        if not self.data.get(self.tmt_test):
            self.data[self.tmt_test] = self.tmt_test_prefix
        item = "duration"
        if not self.data.get(item):
            self.data[item] = "50m"
        

    def go(self):
        try: 
            self.load_tmt_file()
        except FileNotFoundError:
            pass
        self.create_or_update_base_structure()
        traverse_dict = self.data
        clean_filename=self.filename.rsplit("/",1)[-1]
        structure = self.parse_file_name_structure()
        tags = self.get_file_tags()

        for item in structure:
            slashed_item = "/" + item
            if slashed_item not in traverse_dict.keys():
                traverse_dict[slashed_item] = dict()
            traverse_dict = traverse_dict[slashed_item]
        
        if traverse_dict.get(self.tmt_tag): 
            tags = list(set(tags + traverse_dict[self.tmt_tag]))
        traverse_dict[self.tmt_tag] = tags
        traverse_dict[self.tmt_test + "+"] = f"{clean_filename}"
        self.store_tmt_file()

def list_files(path: str, pattern: str) -> list:
    files = glob(f"{path}/{pattern}")
    return [f for f in files if os.access(f, os.X_OK)]



@click.command()
@click.option('--path', default=".", help='dir path of tests and stored metadata')
@click.option('--extension', default="sh", help='test file extension to parse')
@click.option('--metadata', default="TESTTYPE", help='shell variable vhat contains metadata')
@click.option('--delimiter', default="-", help='create tmt test strucure based on delimiter')
@click.option('--kstestdir', default=".", help='position where are located additional functions for rhinstaller tests')
def main(path, extension, metadata, delimiter, kstestdir):
    file_list = list_files(path, "*." + extension)
    click.echo(f"{file_list}")
    max_depth = [foo.rsplit(".", 1)[:-1][0].rsplit("/",1)[-1].split(delimiter) for foo in file_list]
    click.echo(f"Align cases to max depth, to avoid mixing cases for test inheritance: MAX={max_depth}")
    for item in file_list:
        click.echo(f"Processing file: {item}")
        item = RawTMTMetadata(filename=item, extension=extension, delimiter=delimiter, metadata=metadata, kstestdir=kstestdir)
        item.go()
    click.echo(f"TMT test data export finished")


if __name__ == '__main__':
    main()
