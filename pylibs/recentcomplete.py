import vim
import subprocess
import string
import os
import threading
from multiprocessing.pool import ThreadPool

# Decorators
def debounce(wait):
    """ Decorator that will postpone a functions
        execution until after wait seconds
        have elapsed since the last time it was invoked. """
    def decorator(fn):
        def debounced(*args, **kwargs):
            def call_it():
                fn(*args, **kwargs)
            try:
                debounced.t.cancel()
            except(AttributeError):
                pass
            debounced.t = threading.Timer(wait, call_it)
            debounced.t.start()
        return debounced
    return decorator


def one_at_a_time():
    def decorator(fn):
        lock = threading.Lock()

        def onced(*args, **kwargs):
            if lock.acquire(False):
                try:
                    fn(*args, **kwargs)
                finally:
                    lock.release()
        return onced
    return decorator


# Functions called from vim
@debounce(2)
def update_cache_eventually():
    update_cache()


cache = ''
@debounce(0)
@one_at_a_time()
def update_cache():
    return


pool = ThreadPool(processes=4)
def run_commands():
    commands = vim.eval("a:commands")

    results = pool.map(get_output, commands)
    outputs = [vim_str(result) for result in results]

    vim.command('return [%s]' % ','.join(outputs))


def run_command():
    command = vim.eval("a:command")
    output = get_output(command)
    vim.command('return %s' % vim_str(output))


# Support functions
def get_output(command):
    return subprocess.check_output("%s" % (command), shell=True)


# Vim helpers
def vim_str(text):
    return "'%s'" % text.replace("'", "''")


def echom(text):
    vim.command("echom %s" % vim_str(text))
