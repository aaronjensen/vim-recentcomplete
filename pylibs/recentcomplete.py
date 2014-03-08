import vim
import subprocess
import string
import os

def vim_str(string):
    return "'%s'" % string.replace("'", "''")

def echom(string):
    vim.command("echom %s" % vim_str(string))

def run_command():
    command = vim.eval("a:command")
    # echom("")
    # echom("")
    # echom(command)
    output = subprocess.check_output("%s" % (command), shell=True)
    # echom(output)
    vim.command('return %s' % vim_str(output))
