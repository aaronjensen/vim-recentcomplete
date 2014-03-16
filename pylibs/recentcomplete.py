import vim
import subprocess
import string
import os
from multiprocessing.pool import ThreadPool

def vim_str(text):
    return "'%s'" % text.replace("'", "''")

def echom(text):
    vim.command("echom %s" % vim_str(text))

pool = ThreadPool(processes=4)
def run_commands():
    commands = vim.eval("a:commands")

    results = pool.map(get_output, commands)
    outputs = [vim_str(result) for result in results]

    vim.command('return [%s]' % ','.join(outputs))

def get_output(command):
    return subprocess.check_output("%s" % (command), shell=True)

def run_command():
    command = vim.eval("a:command")
    output = get_output(command)
    vim.command('return %s' % vim_str(output))
