#!/usr/bin/python3

import os
import argparse
import shutil
import logging
from pykickstart import parser as kickstart_parser

FRAGMENTS_FOLDER = "fragments"
SHARED_FRAGMENTS_FOLDER = os.path.join(FRAGMENTS_FOLDER, "shared")
RUNTIME_FOLDER = os.path.join(FRAGMENTS_FOLDER, "runtime")
TOPLEVEL_PLATFORM_FOLDER = os.path.join(FRAGMENTS_FOLDER, "platform")

def parse_args():
    _parser = argparse.ArgumentParser(description="Include fragments linked by %ksappend in tests.")
    _parser.add_argument("test_file_path", metavar="TEST.ks.in",
                         help="kickstart test file to process")
    _parser.add_argument("--platform-name", "-p", type=str, required=True,
                         metavar="PLATFORM_NAME",
                         help="Name of the platform folder for platform specific ksappend fragments.")
    _parser.add_argument("--override-folders", "-o", type=str, metavar='OVERRIDE_FOLDERS', default=[], nargs="*",
                         help='Add contents of one or more override folders on top of shared and platform specific fragments.')

    args = _parser.parse_args()
    args.platform_dir_path = os.path.join(TOPLEVEL_PLATFORM_FOLDER, args.platform_name)
    return args


def merge_directories(source_dir, dest_dir):
    """Copy content of source directory to target directory.

    Merge folders and overwrite any existing files.

    One would kinda expect that Python has something like this
    available in it's standard library, but apparently not.
    """
    # list content of the source directory
    for item_name in os.listdir(source_dir):
        item_path = os.path.join(source_dir, item_name)
        # copy any top level files
        if os.path.isfile(item_path):
            shutil.copyfile(item_path, os.path.join(dest_dir, item_name))
        # walk top level directories
        elif os.path.isdir(item_path):
            # copy all directories recursively, merge with existing folders and
            # overwrite existing files
            for root, _, files in os.walk(item_path):
                # we only need the full source path to copy files to the destination,
                # to create all necessary folders we also need the path suffix for
                # the directory being walked and the target path based on the suffix
                root_suffix = os.path.relpath(root, source_dir)
                root_in_dest_dir = os.path.join(dest_dir, root_suffix)
                # create directories
                if not os.path.isdir(root_in_dest_dir):
                    os.makedirs(root_in_dest_dir)
                # copy files
                for file in files:
                   shutil.copyfile(os.path.join(root, file), os.path.join(root_in_dest_dir, file))

def apply_overrides(override_folders, runtime_folder):
    """ Apply ksappend overrides on a runtime folder.

    This takes a list of folders holding the overrides and copies the *content* of the override
    folders on top of what's currently in the given runtime folder.

    If a path to an override_folder is not valid the folder is skipped and a warning is logged
    to stderr.

    :param override_folders: a list of paths to override folders
    :type override_folders: list of str
    :param str runtime_folder: path to the ksappend runtime folder
    """
    for override_folder in override_folders:
        if os.path.exists(override_folder):
            logging.info("adding ksappend override folder %s", override_folder)
            merge_directories(override_folder, runtime_folder)
        else:
            logging.warning("requested ksappend override folder %s not found", override_folder)

def do_ksappend_substitution(runtime_folder, test_file):
    """Do the ksappend substitution.

    This is done by changing PWD to the runtime folder,
    (required by how Pykickstart currently does the substitution)
    running Pykickstart to do the substitution and then
    reverting PWD back.

    Individual substitution runs are logged as are
    failed substitution attempts.

    The result of the substitution is printed to stdout.

    :param str runtime_folder: path to the ksappend runtime folder
    :param str test_file: path to the kickstart .ks.in file
    """

    abs_test_file = os.path.abspath(test_file)

    # change working directory to the runtime folder or else
    # Pykickstart will not find the fragments
    os.chdir(runtime_folder)

    # do the substitution
    logging.info("running ksappend substitution on: %s", test_file)
    # the result should be a temp file
    result_path = kickstart_parser.preprocessKickstart(abs_test_file)
    if result_path:
        # print result to stdout and clean up the temp file
        with open(result_path) as f:
            print(f.read())
        os.remove(result_path)
    else:
        logging.error("ksappend substitution failed for: %s", test_file)
        exit(1)


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(levelname)s:apply-ksappend.py: %(message)s")
    parser = parse_args()

    # check the requested platform folder exists:
    if not os.path.exists(parser.platform_dir_path):
        logging.error("platform folder path not found: %s", parser.platform_dir_path)
        exit(1)

    # make sure the runtime folder exists and is empty
    if os.path.exists(RUNTIME_FOLDER):
        # cleanup the existing runtime folder
        shutil.rmtree(RUNTIME_FOLDER)

    # create new one
    os.makedirs(RUNTIME_FOLDER)

    # copy all shared fragments to the runtime folder
    merge_directories(SHARED_FRAGMENTS_FOLDER, RUNTIME_FOLDER)

    # copy contents of the current platform folder into it as well
    merge_directories(parser.platform_dir_path, RUNTIME_FOLDER)

    # copy any overrides
    apply_overrides(parser.override_folders, RUNTIME_FOLDER)

    # do the actual ksappend substitution
    do_ksappend_substitution(RUNTIME_FOLDER, parser.test_file_path)
