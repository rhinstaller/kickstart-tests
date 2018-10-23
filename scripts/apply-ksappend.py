#!/usr/bin/python3

import sys
import os
import argparse
import shutil
import glob
from pykickstart import parser as kickstart_parser

FRAGMENTS_FOLDER = "fragments"
SHARED_FRAGMENTS_FOLDER = os.path.join(FRAGMENTS_FOLDER, "shared")
RUNTIME_FOLDER = os.path.join(FRAGMENTS_FOLDER, "runtime")
TOPLEVEL_PLATFORM_FOLDER = os.path.join(FRAGMENTS_FOLDER, "platform")

class ArgumentParser(object):

    def __init__(self):
        super().__init__()
        self._parser = argparse.ArgumentParser(description="""
        Include fragments linked by %ksappend in tests.
        """)

        self._test_file_paths = ""
        self._platform_name = ""

        self._configure_parser()

    @property
    def test_file_paths(self):
        return self._test_file_paths

    @property
    def platform_name(self):
        return self._platform_name

    @property
    def override_folders(self):
        return self._override_folders

    @property
    def platform_dir_path(self):
        return os.path.join(TOPLEVEL_PLATFORM_FOLDER, self._platform_name)

    def _configure_parser(self):
        self._parser.add_argument("--test-file-paths", "-t", required=True, type=str, nargs="+",
                                  metavar="TEST_FILE_PATHS",
                                  help="Space delimited kickstart test files to process.")
        self._parser.add_argument("--platform-name", "-p", type=str, required=True,
                                  metavar="PLATFORM_NAME",
                                  help="Name of the platform folder for platform specific ksappend fragments.")
        self._parser.add_argument("--override-folders", "-o", type=str, metavar='OVERRIDE_FOLDERS', default=[], nargs="*",
                                  help='Add contents of one or more override folders on top of shared and platform specific fragments.')

    def parse(self):
        print("ARGV")
        print(sys.argv)
        ns = self._parser.parse_args()

        self._test_file_paths = ns.test_file_paths
        self._platform_name = ns.platform_name
        self._override_folders = ns.override_folders

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
            for root, dirs, files in os.walk(item_path):
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

    If a path to an override_folder is not valid the folder is skipped and a warning is printed
    to stdout.

    :param override_folders: a list of paths to override folders
    :type override_folders: list of str
    :param str runtime_folder: path to the ksappend runtime folder
    """
    for override_folder in parser.override_folders:
        if os.path.exists(override_folder):
            print("adding ksappend override folder {}".format(override_folder))
            merge_directories(override_folder, runtime_folder)
        else:
            print("requested ksappend override folder {} not found".format(override_folder))

def get_available_kickstart_tests(kstests):
    """Check which kickstart test files from a list are available.

    Return a list of test files that actually exist and print any files we can't
    find to stdout.

    :param kstests: a list of kickstart test file paths
    :type kstests: list of str
    :returns: a list of kickstart test file paths that exist
    :rtype: list of str
    """
    available_test_files = []
    for test_path in kstests:
        if os.path.exists(test_path) and os.path.isfile(test_path):
            available_test_files.append(test_path)
        else:
            print("test file requested for ksappend substitution is missing: %s", test_path)
    return available_test_files

def do_ksappend_substitution(runtime_folder):
    """Do the ksappend substitution.

    This is done by changing PWD to the runtime folder,
    (required by how Pykickstart currently does the substitution)
    running Pykickstart to do the substitution and then
    reverting PWD back.

    Individual substitution runs are printed to stdout as are
    failed substitution attempts.

    We keep all the input files and rename them to <name>.ks.input
    and rename all files that failed the substitution to <name>.ks.input.FAILED.

    :param str runtime_folder: path to the ksappend runtime folder
    :returns: list of successfully processed kickstart test files
    :rtype: list of str
    """

    # save current PWD
    pwd = os.path.abspath(".")

    # change working directory to the runtime folder or else
    # Pykickstart will not find the fragments
    os.chdir(runtime_folder)

    # do the substitution
    resolved_ks_files = []
    for test_file in glob.glob("*.ks"):
        test_base_name = os.path.split(test_file)[1].rsplit(".ks")[0]
        print("running ksappend substitution on: {}".format(test_file))
        # the result should be a temp file
        result_path = kickstart_parser.preprocessKickstart(test_file)
        if result_path:
            # rename the input file and keep it for reference
            input_file = "{}.ks.input".format(test_base_name)
            shutil.move(test_file, input_file)
            # move the result file in place of the original ks file
            shutil.move(result_path, test_file)
            # register the successfully resolved file
            resolved_ks_files.append(test_file)
        else:
            print("ksappend substitution failed for: {}".format(test_file))
            # rename the input file to mark it as failed
            failed_input_file = "{}.ks.input.FAILED".format(test_base_name)
            shutil.move(test_file, failed_input_file)

    # restore working directory back
    os.chdir(pwd)

    # return a list of all successfully processed file names & paths in runtime folder
    # in the [(<file name>, <path to file in runtime folder>),] format
    return resolved_ks_files

def move_results_in_place(resolved_test_files, runtime_folder):
    """Move resolved kickstart test files from the ksappend runtime folder.

    :param resolved_ks_files: list of names of all successfully resolved kickstart test files
    :type: resolved_ks_files: list of str
    :param str runtime_folder: path to the ksappend runtime folder
    """
    for file_name in resolved_test_files:
        shutil.copyfile(os.path.join(runtime_folder, file_name), file_name)

if __name__ == "__main__":
    parser = ArgumentParser()
    parser.parse()

    # check the requested platform folder exists:
    if not os.path.exists(parser.platform_dir_path):
        print("platform folder path not found: {}".format(parser.platform_dir_path))
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

    # copy all the test files that actually exist to runtime folder
    available_test_files = get_available_kickstart_tests(parser.test_file_paths)

    for test_path in available_test_files:
        shutil.copy(test_path, RUNTIME_FOLDER)

    # do the actual ksappend substitution
    resolved_test_files = do_ksappend_substitution(RUNTIME_FOLDER)

    # move the results in place
    move_results_in_place(resolved_test_files, RUNTIME_FOLDER)

    print("ksappend with platform name {} resolved {}/{} test files".format(parser.platform_name,
                                                                            len(parser.test_file_paths),
                                                                            len(resolved_test_files)))
    # and we are done
    exit(0)
