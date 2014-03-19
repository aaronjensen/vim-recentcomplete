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
                debounce.timers.remove(debounced.t)
                fn(*args, **kwargs)
            try:
                debounce.timers.remove(debounced.t)
                debounced.t.cancel()
            except(AttributeError):
                pass
            debounced.t = threading.Timer(wait, call_it)
            debounce.timers.append(debounced.t)
            debounced.t.start()
        return debounced
    return decorator

debounce.timers = []


def one_at_a_time():
    def decorator(fn):
        decorator.lock = threading.Lock()

        def onced(*args, **kwargs):
            if decorator.lock.acquire(False):
                try:
                    fn(*args, **kwargs)
                finally:
                    decorator.lock.release()
        return onced
    return decorator


# Functions called from vim
@debounce(2)
def update_cache_eventually():
    update_cache()


cache = []
@debounce(0)
@one_at_a_time()
def update_cache():
    cache = _run_commands(cacheable_commands)


pool = ThreadPool(processes=4)
def run_commands():
    commands = vim.eval("a:commands")

    outputs = _run_commands(commands)

    vim.command('return [%s]' % ','.join(outputs))


def run_command():
    command = vim.eval("a:command")
    output = get_output(command)
    vim.command('return %s' % vim_str(output))


def clear_timers():
    while debounce.timers:
        debounce.timers.pop().cancel()


def get_cache():
    vim.command('return [%s]' % ','.join(cache))


# Support functions
def _run_commands(commands):
    results = pool.map(get_output, commands)
    return [vim_str(result) for result in results]


def get_output(command):
    return subprocess.check_output("%s" % (command), shell=True)


def git_diff(args, extra=""):
    return (" git diff --diff-filter=AM --no-color {} 2>/dev/null"
            " | grep \\^+\s*.. 2>/dev/null"
            " | grep -v '+++ [ab]/' 2>/dev/null"
            " | sed 's/^+//' 2>/dev/null"
            "{}"
            " || true"
            ).format(args, extra)


def untracked_keywords():
    return ('git ls-files --others --exclude-standard 2>/dev/null'
            ' | xargs -I % {}'
            ).format(git_diff('--no-index /dev/null %'))


def uncommitted_keywords():
    return git_diff("HEAD")


def recently_committed_keywords():
    return git_diff("@'{1.hour.ago}' HEAD", "| sed '1!G;h;$!d' 2>/dev/null")

cacheable_commands = [
        untracked_keywords(),
        uncommitted_keywords(),
        recently_committed_keywords(),
        ]

# Vim helpers
def vim_str(text):
    return "'%s'" % text.replace("'", "''")


def echom(text):
    vim.command("echom %s" % vim_str(text))
