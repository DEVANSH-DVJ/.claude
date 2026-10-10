"""
Analyses a Bash command for the protect.py hook and returns the paths the command would write.
The caller passes the repo root and the patterns of protected names, and decides what is protected.
"""

import math
import os
import re
from itertools import dropwhile, pairwise, product, takewhile
from pathlib import Path

# repo root and the patterns of protected names, set per command
ROOT = TOKEN_RE = SPAN_RE = NAMES_RE = None
# the path the project runner mounts the root at
MOUNT_RE = re.compile(r"(?<![\w./~$}-])/workspace(?![\w.-])")
# a verb counts as a command only at a command position
CMD = r"(?:^|[;&|(\n][^\S\n]*|\bsudo\s+|\bxargs\s+(?:-\S+\s+)*)"
# commands that write: in-place edits, file ops, one-liners, git reverts
WRITERS = CMD + (
    r"(?:"
    r"(?:tee|mv|cp|rm|ln|install|rsync|truncate|chmod|chown|touch|mkdir|dd|patch)\b"
    r"|sed\s+(?:-\S*i|--in-place)"
    r"|perl\s+-\S*i"
    r"|python[0-9.]*\s+(?:-\s*<<|<<|-c\b)"
    r"|(?:perl|ruby|node)\s+-e\b"
    r"|git\s+(?:checkout|restore|rm|mv|stash|clean|apply)\b"
    r")"
)
# a quoted word of inline code
LITERAL_RE = re.compile(r"(?<=['\"])[\w.-]+(?=['\"])")

# shell text: plain word text, blanks, operators with the longest first
LEX_RE = re.compile(
    r"(?P<word>[^\s\\'\"`$#();<>|&]+)|(?P<gap>[ \t\r]+)"
    r"|(?P<op>\n|;;|&&|\|\||\|&|&>>|&>|>>|>\||>&|<<<|<<-|<<|<&|<>|[;&|()<>])"
)
# single-quoted text; after a $ it takes backslash escapes
QUOTE_RE = re.compile(r"(?s)\$'((?:[^'\\]|\\.)*)'|'([^']*)'")
# double-quoted text free of escapes and expansions
PLAIN_RE = re.compile(r"[^\\\"`$]+")
# a brace list of a word, outside a ${ } expansion
BRACE_RE = re.compile(r"(?<!\$)\{([^{},]*(?:,[^{},]*)+)\}")
# token lists of lifted $( ) and backtick bodies; a mark in a word holds the key
DOCS = []
# keywords ahead of the verb
SKIP = {'if', 'then', 'else', 'elif', 'do', 'while', 'until', '!', '{'}
# wrappers ahead of the verb, with their options that take a value
WRAPS = {'sudo': "-[ug]", 'env': '-u', 'timeout': '-s', 'stdbuf': "-[ioe]", 'exec': '-a'}
WRAPS |= dict.fromkeys(['nice', 'time', 'nohup', 'setsid', 'command', 'busybox'], '')
# words, command words and work units of the command being scanned
WORDS, CMDS, WORK = [], set(), []
# verbs that write every operand
ALL_ARGS = {'rm', 'tee', 'truncate', 'touch', 'mkdir', 'patch'}
# verbs that copy sources onto a destination
COPIES = {'cp', 'mv', 'ln', 'install', 'rsync'}
GIT_WRITES = {'checkout', 'restore', 'rm', 'mv', 'stash', 'clean', 'apply'}
SHELLS = {'bash', 'sh', 'zsh', 'dash', 'ksh'}
VERBS = ALL_ARGS | COPIES | SHELLS | {'chmod', 'chown', 'dd', 'sed', 'perl', 'ruby', 'git'}


def tokens(text):
    """Path-like runs of a text that name a protected path."""
    return [t for m in SPAN_RE.finditer(text) for t in TOKEN_RE.findall(m[0])]


def base(word):
    """Name of a command word, which may be given by path."""
    return word.rsplit('/', 1)[-1]


def spend(deep=0, units=1):
    """Count units of work; nesting or work past the bound raises."""
    if deep > 20 or len(WORK) + units > 50000:
        raise RecursionError('bound')
    WORK.extend([deep] * units)


def braces(path):
    """Paths the brace lists of a path expand to; nested lists and ranges stay."""
    lists = [p.split(',') if i % 2 else [p] for i, p in enumerate(BRACE_RE.split(path))]
    # each further path counts as work, a long one as more
    spend(units=(math.prod(map(len, lists)) - 1) * (1 + len(path) // 100))
    return [''.join(parts) for parts in product(*lists)]


def at(cwd, paths):
    """Paths resolved against a directory, which $PWD names, with brace lists expanded."""
    paths = [b for p in paths for b in braces(p)]
    paths = [re.sub(r"\$PWD\b|\$\{PWD\}", lambda m: str(cwd), p) for p in paths]
    return [cwd / os.path.expanduser(p) for p in paths]


def isdir(cwd, path):
    """Whether a path is a directory: a trailing slash or an existing one."""
    return path.endswith('/') or os.path.isdir(os.path.normpath(at(cwd, [path])[0]))


def after(args, flag):
    """Arguments that directly follow a flag matching the regex."""
    return [b for a, b in pairwise(args) if re.fullmatch(flag, a)]


def plain(args, valued=None):
    """Operands: neither flags nor the values of valued flags."""
    held = {i + 1 for i, a in enumerate(args) if valued and re.fullmatch(valued, a)}
    return [a for i, a in enumerate(args) if a[:1] != '-' and i not in held]


def bare(argv):
    """argv without leading keywords, assignments, wrappers and their options."""
    held, i = '', 0
    while i < len(argv):
        word = argv[i]
        if base(word) in WRAPS:
            held = WRAPS[base(word)]
        elif word == 'function' or (held and re.fullmatch(held, word)):
            # the function name or the option value goes too
            i += 1
        elif not (word in SKIP or re.match(r"-|\w+=|\d[\d.]*[smhd]?$", word)):
            # neither keyword, flag, assignment nor duration
            break
        i += 1
    return argv[i:]


def subst(text, i):
    """Mark of the $( ) or backtick body that starts at i, else the character: (text, end)."""
    if text.startswith('$(', i):
        toks, end = lex(text, i + 2, True)
    elif text[i] == '`' and (end := text.find('`', i + 1) + 1):
        toks = lex(text[i + 1 : end - 1])[0]
    else:
        return text[i], i + 1
    DOCS.append(toks)
    return f"$\x08{len(DOCS) - 1}\x08", end


def quoted(text, i, close):
    """Text up to the closing quote, its $( ) and backtick bodies lifted: (text, end)."""
    out = []
    while i < len(text) and text[i] != close:
        if m := PLAIN_RE.match(text, i):
            part, i = m[0], m.end()
        elif text[i] == '\\':
            # a backslash escapes only $ ` " \ and the newline
            c = text[i + 1 : i + 2]
            part, i = c.strip('\n') if c in '$`"\\\n' else '\\' + c, i + 2
        else:
            part, i = subst(text, i)
        out.append(part)
    if close and i >= len(text):
        raise ValueError("open quote")
    return ''.join(out), i + 1


def lex(text, i=0, sub=False):
    """Tokens of shell text, up to the ')' that ends a $( ) body: ([(token, is_operator)], end)."""
    toks, word, docs, lit, nest = [], None, [], set(), 0
    while i <= len(text):
        m, c, part = LEX_RE.match(text, i), text[i : i + 1], None
        kind = m.lastgroup if m else '' if c else 'gap'
        if word is not None and kind in ('gap', 'op'):
            # a blank, an operator or the end closes the word
            toks.append((''.join(word), False))
            word = None
        if kind == 'word':
            part, i = m[0], m.end()
        elif kind == 'gap':
            i = m.end() if m else i + 1
        elif kind == 'op':
            i, nest = m.end(), nest + (m[0] == '(') - (m[0] == ')')
            if sub and nest < 0:
                return toks, i
            toks.append((m[0], True))
            # the word after << is a heredoc delimiter
            if m[0] in ('<<', '<<-'):
                docs.append(len(toks))
            # heredoc bodies follow the newline, each up to its end line
            while m[0] == '\n' and docs:
                key = docs.pop(0)
                mark = r"^[ \t]*%s[ \t]*$" % re.escape(toks[key][0])
                if not toks[key][1] and (end := re.compile(mark, re.M).search(text, i)):
                    body, i = text[i : end.start()], end.end()
                    # a quoted delimiter makes the body data
                    toks[key] = (body if key in lit else quoted(body, 0, '')[0], False)
        elif c == '#' and word is None:
            # comment runs to the end of the line
            i = text.find('\n', i)
            i = len(text) if i < 0 else i
        elif q := QUOTE_RE.match(text, i):
            part, i = q[2] if c == "'" else re.sub(r"(?s)\\(.)", r"\1", q[1]), q.end()
        elif c == "'":
            raise ValueError("open quote")
        elif c == '"':
            part, i = quoted(text, i + 1, '"')
        elif c == '\\':
            # an escaped newline vanishes; any other escaped character is literal
            part, i = None if text[i + 1 : i + 2] == '\n' else text[i + 1 : i + 2], i + 2
        else:
            part, i = subst(text, i)
        if part is not None:
            # a quote or an escape makes the word literal
            if c in "'\"\\":
                lit.add(len(toks))
            word = word or []
            word.append(part)
    return toks, len(text)


def writes(argv, cwd, deep=0, texts=(), pipe=()):
    """Paths one simple command writes to."""
    spend(deep)
    argv = argv or ['']
    verb = base(argv[0])
    # --flag=value splits into flag and value
    args = [p for a in argv[1:] for p in (a.split('=', 1) if a.startswith('--') else [a])]
    pos, hits, tg, subs, code = plain(args), [], [], [], []
    if verb in ('chmod', 'chown'):
        # the mode or owner leads the operands, or a reference file does
        tg = [a for a in args if not re.fullmatch(r"-[cfvRhHLP]+|--[\w-]+", a)][1:]
    elif verb in ALL_ARGS:
        # touch reads its reference file
        tg = plain(args, r"-[rdt]|--reference|--date") if verb == 'touch' else pos
    elif verb in COPIES:
        # destination: the -t value, also of a flag cluster, else the last operand
        held = r"-\w*t|-[mogS]|--target-directory" if verb != 'rsync' else None
        into = after(args, r"-\w*t|--target-directory")[:1] if held else []
        srcs = plain(argv[1:], held)
        srcs, tg = (srcs, into) if into else (srcs[:-1], srcs[-1:])
        # into a directory: a target per source name; the directory for a tree
        if tg and (into or isdir(cwd, tg[0])):
            deep_copy = any(re.fullmatch(r"-\w*[rRa]\w*|--recursive|--archive", a) for a in args)
            deep_copy = deep_copy or any(isdir(cwd, s) for s in srcs)
            tg = [f"{tg[0]}/{Path(s).name}" for s in srcs] + tg * deep_copy
        # mv writes its sources too
        tg = tg + srcs * (verb == 'mv')
    elif verb == 'dd':
        tg = [a[3:] for a in args if a.startswith('of=')]
    elif verb in ('sed', 'perl', 'ruby') and any(
        re.match(r"-[nErsuzplaw0]*i|--in-place", a) for a in args
    ):
        # in-place edit: operands after the script
        tg = plain(args, r"-\w*[ef]|--expression|--file")
        tg = tg[1:] if tg == pos else tg
    elif verb == 'git':
        # paths of a reverting subcommand, after -- when given; -C moves the directory
        sub = plain(args, "-[CcbBm]|--work-tree|--git-dir")
        dry = sub[:1] == ['clean'] and any(re.fullmatch(r"-\w*n\w*|--dry-run", a) for a in args)
        if sub[:1] and sub[0] in GIT_WRITES and not dry:
            tg = args[args.index('--') + 1 :] if '--' in args else sub[1:]
            # a :/ or :(top) pathspec starts at the root
            tg = [re.sub(r"^:(?:/|\(top\))", lambda m: f"{ROOT}/", t) for t in tg]
        cwd = cwd.joinpath(*after(args, '-C'))
    elif verb == 'find':
        # each start path stands in for {}; the options ahead of them go
        starts = dropwhile(lambda a: a in ('-L', '-H', '-P'), args)
        starts = list(takewhile(lambda a: a[:1] not in ('-', '(', '!'), starts)) or ['.']
        tg, rest = starts if '-delete' in args else [], iter(args)
        for a in rest:
            if a in ('-exec', '-execdir', '-ok', '-okdir'):
                # the command runs to ; or +, once per start path that fills a {}
                run = list(takewhile(lambda x: x not in (';', '+'), rest))
                for s in starts if '{}' in ' '.join(run) else starts[:1]:
                    hits += writes(bare([x.replace('{}', s) for x in run]), cwd, deep + 1)
    elif verb == 'xargs':
        # a stand-in for the stdin operands fills {} or trails the command
        sub = list(dropwhile(lambda a: base(a) not in VERBS, args))
        fill = '{}' in ' '.join(sub)
        xarg = ROOT / '.claude' / 'xargs-stdin'
        got = [a.replace('{}', str(xarg)) for a in sub] + [str(xarg)] * (not fill)
        got = writes(got, cwd, deep + 1)
        hits += [h for h in got if h != xarg]
        # unknown operands: any word or protected token of the pipeline and stdin texts
        seen = ' '.join([*pipe, *argv, *texts])
        tg = seen.split() + tokens(seen) if xarg in got else []
    # command strings recurse; inline code names its paths
    ran = list(dropwhile(lambda a: a[:1] == '-', argv[1:] if verb in SHELLS else argv))
    ours = ''.join(ran[:1]).endswith('exec.sh') and os.path.realpath(at(cwd, ran[:1])[0])
    if ours == str(ROOT / 'docker' / 'exec.sh'):
        # the project runner's string starts at the root, which /workspace names
        subs, cwd = [MOUNT_RE.sub(lambda m: str(ROOT), ' '.join(ran[1:]))], ROOT
    elif verb in SHELLS:
        subs = after(args, r"-\w*c")[:1] + list(texts)
    elif verb == 'eval':
        subs = [' '.join(argv[1:])]
    elif re.fullmatch(r"python[0-9.]*", verb):
        # options, then -c CODE, -m MODULE, a script, or - for stdin
        head = dropwhile(
            lambda p: p[0] in ('-W', '-X') or re.fullmatch(r"-(?!\w*[cm]$).+", p[1]),
            pairwise(['', *argv[1:]]),
        )
        head = [b for _, b in head] or ['-']
        # stdin code: heredoc texts and the words piped in
        code = head[1:2] if re.fullmatch(r"-\w*c", head[0]) else [*texts, *pipe] * (head[0] == '-')
    elif verb in ('perl', 'ruby', 'node'):
        # node takes code after -p too
        code = after(args, r"-\w*[ep]|--eval|--print" if verb == 'node' else r"-\w*e|--eval")
    elif verb == 'awk':
        code = plain(args, "-[Fvf]")[:1]
    elif verb not in ('find', 'xargs'):
        # a shell further along the words runs its -c string in place
        rest = dropwhile(lambda a: base(a) not in SHELLS, args)
        subs = after(list(rest), r"-\w*c")[:1]
    code = '\n'.join(code)
    # quoted words of inline code that name an owned directory
    dirs = [w for w in LITERAL_RE.findall(code) if NAMES_RE.fullmatch(w + '/')]
    tg = tg + tokens(code) + dirs
    return hits + at(cwd, tg) + [h for s in subs for h in walk(s, cwd, deep + 1)]


def walk(cmd, cwd, deep=0):
    """Paths a shell command string, or its token list, writes to."""
    toks = cmd if isinstance(cmd, list) else lex(cmd.replace('\x08', ''))[0]
    hits, stack, argv, outs, texts, pipe, redir, var, vals = [], [], [], [], [], [], '', None, []
    # the directory before the last move, and those pushd left
    back, dirs = cwd, []
    for tok, op in [*toks, ('\n', True)]:
        # a lifted body is a command too
        for key in () if op else re.findall(r"\x08(\d+)\x08", tok):
            hits += walk(DOCS[int(key)], cwd, deep + 1)
        if redir and not op:
            # redirect operand: heredoc text or output file
            if redir[:2] == '<<':
                texts.append(tok)
            elif '>' in redir and not (redir == '>&' and (tok.isdecimal() or tok == '-')):
                outs.append(tok)
        elif not op:
            argv.append(tok)
        elif '<' in tok or '>' in tok:
            # a number ahead of a redirect is its fd
            if argv and argv[-1].isdecimal():
                argv.pop()
        else:
            # separator ends the simple command
            run, each = bare(argv), [(argv, outs)]
            CMDS.update(run[:1])
            WORDS.extend(argv + outs)
            # a loop variable stands for each of its words
            if vals and var.search(' '.join(argv + outs)):
                each = [[[var.sub(lambda m: v, a) for a in part] for part in each[0]] for v in vals]
            for words, files in each:
                hits += writes(bare(words), cwd, deep, texts, pipe) + at(cwd, files)
            if run[:1] == ['for'] and run[2:3] == ['in']:
                var, vals = re.compile(r"\$(\{)?%s\b(?(1)\})" % re.escape(run[1])), run[3:]
            # cd and pushd move the directory for later commands
            if run[:1] in (['cd'], ['pushd']):
                # a bare cd goes home, a bare pushd goes back
                to = [a for a in run[1:] if a != '--'][:1] or ['~' if run[0] == 'cd' else '-']
                # - names the directory before the last move
                dest = back if to == ['-'] else Path(os.path.normpath(at(cwd, to)[0]))
                # a missing directory moves nothing
                if dest.is_dir():
                    dirs += [cwd] * (run[0] == 'pushd')
                    back, cwd = cwd, dest
            elif run[:1] == ['popd'] and dirs:
                back, cwd = cwd, dirs.pop()
            pipe += argv
            argv, outs = [], []
            # words and heredoc texts last for the pipeline
            if tok not in ('|', '|&'):
                pipe, texts = [], []
            # a subshell keeps its own directories
            if tok == '(':
                stack.append((cwd, back, [*dirs]))
            elif tok == ')' and stack:
                cwd, back, dirs = stack.pop()
        redir = tok if op and ('<' in tok or '>' in tok) else ''
    return hits


def scan(cmd, cwd):
    """Paths a Bash command writes to."""
    for state in (WORDS, CMDS, DOCS, WORK):
        state.clear()
    hits = walk(cmd, cwd)
    # run-time target: an expansion not already under work/
    starts = [str(h).split('$')[0] + 'x' for h in hits if '$' in str(h)]
    if any(not os.path.normpath(s).startswith(f"{ROOT}/work/") for s in starts):
        # every protected token but a command word, less a leading expansion
        text = ' '.join(w for w in WORDS if w not in CMDS)
        text = re.sub(r"\$(\w+|\{\w+\}|\x08\d+\x08)/", '', text)
        hits += at(cwd, [t for t in tokens(text) if t not in CMDS])
    return hits


def targets(cmd, cwd, root, token, names):
    """Paths a Bash command would write, by a coarser rule when it cannot be read."""
    global ROOT, TOKEN_RE, SPAN_RE, NAMES_RE
    ROOT, TOKEN_RE, NAMES_RE = root, re.compile(token), re.compile(names)
    # token runs back to back, from the start of a path-like word
    SPAN_RE = re.compile(r"(?<![\w./~${}*?-])(?:" + token + r")+")
    try:
        return scan(cmd, cwd)
    except ValueError:
        # unparsable: any protected token, given a write verb or a redirect onto a name
        wrote = re.search(r">\|?\s*[^\s>]*(?:" + names + r")|" + WRITERS, cmd)
        return tokens(cmd) if wrote else []
    except RecursionError:
        # nested too deep: any word or protected token
        return cmd.split() + tokens(cmd)
