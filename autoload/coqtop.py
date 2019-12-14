import os
import re
import subprocess
import xml.etree.ElementTree as ET
import signal
import vim
import time

from collections import deque, namedtuple

import sys

# + バッファごとに CoqTop インスタンス CT を作ります

# TODO
# - CT に センテンス (ドットで終わるひとかたまり) を投げていきます
# - メッセージとメッセージレベルのセットが帰ってきます
# - error レベルのメッセージが含まれていたなら，
#   CTを操っていた側で，最初に出てきた手前で止めます
#   (ここは CoqIDE と同じで止めずに後ろの方にカーソルがあるように振る舞うべき? )
# - 操作側でエラーの表示などをします．センテンス は バッファ上のどこなのか，
#   という情報があるわけですから，それと組み合わせてエラー表示します
# - CT は 問い合わせ Goal にも答えます
# -


# TODO rename
class CoqTopDriver:
    def __init__(self):
        self.coqtop = None
        self.states = []
        self.root_state = None
        self.state_id = None
        self.restart()

    def restart(self, *args):
        global coqtops, root_states, state_ids

        if self.coqtop:
            self.kill_coqtop()

        # TODO : support coqtop 8.9 or above
        # TODO : support specifying coqtop executable path
        options = [
                'coqtop',
                '-ideslave',
                '-main-channel',
                'stdfds',
                '-async-proofs',
                'on'
                ]
        try:
            if os.name == 'nt':
                # for Windows GVim
                si = subprocess.STARTUPINFO()
                si.dwFlags |= subprocess.STARTF_USESHOWWINDOW

                self.coqtop = subprocess.Popen(
                    options + list(args),
                    stdin=subprocess.PIPE,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    startupinfo=si
                )
            else:
                # TODO : check whether it is not needed startupinfo?
                self.coqtops = subprocess.Popen(
                    options + list(args),
                    stdin=subprocess.PIPE,
                    stdout=subprocess.PIPE,
                    preexec_fn=ignore_sigint
                )

            r = self.call('Init', Option(None))
            assert isinstance(r, Ok)
            self.root_state = r.val
            self.state_id = r.val
        except OSError:
            print("Error: couldn't launch coqtop")
            pass

    def query(self, cmd, encoding='utf-8'):
        r = self.call('Query', (cmd, self.cur_state()), encoding)

        return r

    def get_answer(self):
        fd = self.coqtop.stdout.fileno()
        data = ''

        while True:
            try:
                data += os.read(fd, 0x4000)
                try:
                    time.sleep(.3)
                    print(data)
                    elt = ET.fromstring('<coqtoproot>' + escape(data) + '</coqtoproot>')
                    shouldWait = True
                    valueNode = None
                    messageNode = None
                    isError = False

                    for c in elt:
                        if c.tag == 'value':
                            shouldWait = False
                            valueNode = c
                        # TODO : can reach ???

                        if c.tag == 'message':
                            print("reached!!!!")

                            if messageNode is not None:
                                messageNode = messageNode + "\n\n" + parse_value(c[2])
                            else:
                                messageNode = parse_value(c[2])

                        if c.tag == 'feedback':
                            for fc in c:
                                if fc.tag == 'feedback_content' and 'val' in fc and fc.val == 'message':
                                    mes = "[" + fc[0][0].val + "] " + fc[0][2]

                                    if messageNode is not None:
                                        messageNode = messageNode + "\n\n" + mes
                                    else:
                                        messageNode = mes

                    if shouldWait:
                        continue
                    else:
                        vp = parse_response(valueNode)

                        if messageNode is not None:
                            if isinstance(vp, Ok):
                                return Ok(vp.val, messageNode)

                        return vp
                except ET.ParseError:
                    continue
            except OSError:
                # coqtop died

                return None

    def call(self, name, arg, encoding='utf-8'):
        xml = encode_call(name, arg)
        msg = ET.tostring(xml, encoding)
        self.send_cmd(msg)
        response = self.get_answer()

        return response

    def send_cmd(self, cmd):
        self.coqtop.stdin.write(cmd)

    def cur_state(self):
        if len(self.states) == 0:
            return self.root_state
        else:
            return self.state_id

    def advance(self, sentence, encoding='utf-8'):
        r = self.call(
                'Add',
                ((sentence, -1), (self.cur_state(), True)),
                encoding)

        if r is None:
            return r

        if isinstance(r, Err):
            return r
        self.states.append(self.state_id)
        self.state_id = r.val[0]

        return r

    def rewind(self, step=1):
        assert step <= len(self.states)
        idx = len(self.states) - step
        self.state_id = self.states[idx]
        self.states_dict = self.states[0:idx]

        return self.call('Edit_at', self.state_id)

    def goals(self):
        return self.call('Goal', ())

    def read_states(self):
        return self.states


# miscellaneous

Ok = namedtuple('Ok', ['val', 'msg'])
Err = namedtuple('Err', ['err'])

Inl = namedtuple('Inl', ['val'])
Inr = namedtuple('Inr', ['val'])

StateId = namedtuple('StateId', ['id'])
Option = namedtuple('Option', ['val'])

OptionState = namedtuple('OptionState', ['sync', 'depr', 'name', 'value'])
OptionValue = namedtuple('OptionValue', ['val'])

Status = namedtuple('Status', ['path', 'proofname', 'allproofs', 'proofnum'])

Goals = namedtuple('Goals', ['fg', 'bg', 'shelved', 'given_up'])
Goal = namedtuple('Goal', ['id', 'hyp', 'ccl'])
Evar = namedtuple('Evar', ['info'])


def parse_response(xml):
    assert xml.tag == 'value'

    if xml.get('val') == 'good':
        return Ok(parse_value(xml[0]), None)
    elif xml.get('val') == 'fail':
        return Err(parse_error(xml))
    else:
        assert False, 'expected "good" or "fail" in <value>'


def parse_value(xml):
    if xml.tag == 'unit':
        return ()
    elif xml.tag == 'bool':
        if xml.get('val') == 'true':
            return True
        elif xml.get('val') == 'false':
            return False
        else:
            assert False, 'expected "true" or "false" in <bool>'
    elif xml.tag == 'string':
        return xml.text or ''
    elif xml.tag == 'int':
        return int(xml.text)
    elif xml.tag == 'state_id':
        return StateId(int(xml.get('val')))
    elif xml.tag == 'list':
        return [parse_value(c) for c in xml]
    elif xml.tag == 'option':
        if xml.get('val') == 'none':
            return Option(None)
        elif xml.get('val') == 'some':
            return Option(parse_value(xml[0]))
        else:
            assert False, 'expected "none" or "some" in <option>'
    elif xml.tag == 'pair':
        return tuple(parse_value(c) for c in xml)
    elif xml.tag == 'union':
        if xml.get('val') == 'in_l':
            return Inl(parse_value(xml[0]))
        elif xml.get('val') == 'in_r':
            return Inr(parse_value(xml[0]))
        else:
            assert False, 'expected "in_l" or "in_r" in <union>'
    elif xml.tag == 'option_state':
        sync, depr, name, value = map(parse_value, xml)

        return OptionState(sync, depr, name, value)
    elif xml.tag == 'option_value':
        return OptionValue(parse_value(xml[0]))
    elif xml.tag == 'status':
        path, proofname, allproofs, proofnum = map(parse_value, xml)

        return Status(path, proofname, allproofs, proofnum)
    elif xml.tag == 'goals':
        return Goals(*map(parse_value, xml))
    elif xml.tag == 'goal':
        return Goal(*map(parse_value, xml))
    elif xml.tag == 'evar':
        return Evar(*map(parse_value, xml))
    elif xml.tag == 'xml' or xml.tag == 'richpp':
        return ''.join(xml.itertext())

    def kill_coqtop(self):
        if self.coqtop:
            try:
                self.coqtop.terminate()
                self.coqtop.communicate()
            except OSError:
                pass
            self.coqtop = None


def parse_error(xml):
    return ET.fromstring(
            re.sub(r"<state_id val=\"\d+\" />", '', ET.tostring(xml)))


def build(tag, val=None, children=()):
    attribs = {'val': val} if val is not None else {}
    xml = ET.Element(tag, attribs)
    xml.extend(children)

    return xml


def encode_call(name, arg):
    return build('call', name, [encode_value(arg)])


def encode_value(v):
    if v == ():
        return build('unit')
    elif isinstance(v, bool):
        xml = build('bool', str(v).lower())
        xml.text = str(v)

        return xml
    elif isinstance(v, str):
        xml = build('string')
        xml.text = v

        return xml
    elif isinstance(v, int):
        xml = build('int')
        xml.text = str(v)

        return xml
    elif isinstance(v, StateId):
        return build('state_id', str(v.id))
    elif isinstance(v, list):
        return build('list', None, [encode_value(c) for c in v])
    elif isinstance(v, Option):
        xml = build('option')

        if v.val is not None:
            xml.set('val', 'some')
            xml.append(encode_value(v.val))
        else:
            xml.set('val', 'none')

        return xml
    elif isinstance(v, Inl):
        return build('union', 'in_l', [encode_value(v.val)])
    elif isinstance(v, Inr):
        return build('union', 'in_r', [encode_value(v.val)])
    # NB: `tuple` check must be at the end because it overlaps with () and
    # namedtuples.
    elif isinstance(v, tuple):
        return build('pair', None, [encode_value(c) for c in v])
    else:
        assert False, 'unrecognized type in encode_value: %r' % (type(v),)


def ignore_sigint():
    signal.signal(signal.SIGINT, signal.SIG_IGN)


def escape(cmd):
    return cmd.replace("&nbsp;", ' ') \
              .replace("&apos;", '\'') \
              .replace("&#40;", '(') \
              .replace("&#41;", ')')
