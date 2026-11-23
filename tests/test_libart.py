import subprocess

import hypothesis
from hypothesis import strategies as st
from hypothesis.stateful import Bundle, RuleBasedStateMachine, rule


def enc(b: bytes) -> str:
    if len(b) == 0:
        return "$EMPTY"
    return b.hex()


class Trie:
    proc: subprocess.Popen

    def __init__(self):
        self.proc = subprocess.Popen(["./client.bin"], stdin=subprocess.PIPE, stdout=subprocess.PIPE)

    def write(self, s):
        if self.proc.poll() is not None:
            raise RuntimeError("subprocess unexpectedly stopped")
        self.proc.stdin.write(bytes(s, encoding='ascii'))
        self.proc.stdin.write(b"\n")
        self.proc.stdin.flush()

    def insert(self, k: bytes, v: int):
        self.write(f"insert {enc(k)} {v}")

    def delete(self, k: bytes):
        self.write(f"delete {enc(k)}")

    def search(self, k: bytes):
        self.write(f"search {enc(k)}")
        result = self.proc.stdout.readline()
        if result.startswith(b"value="):
            return int(result[6:])
        else:
            return None

    def length(self):
        self.write("length")
        result = self.proc.stdout.readline()
        return int(result)


class DictComparison(RuleBasedStateMachine):
    keys = Bundle("keys")
    values = Bundle("values")

    def __init__(self):
        super().__init__()
        self.model = {}
        self.trie = Trie()

    @rule(target=keys, k=st.binary())
    def add_key(self, k):
        # TODO: libart struggles a lot with empty keys, need to figure out how to stabilize this
        hypothesis.assume(len(k) > 0)
        return k

    @rule(target=values, v=st.integers(min_value=-2**63, max_value=2**63-1))
    def add_value(self, v):
        return v

    @rule(k=keys, v=values)
    def insert(self, k, v):
        self.model[k] = v
        self.trie.insert(k, v)

    @rule(k=keys)
    def delete(self, k):
        if k in self.model:
            del self.model[k]
        self.trie.delete(k)

    @rule(k=keys)
    def check_value(self, k):
        assert self.model.get(k, None) == self.trie.search(k)

    @rule()
    def check_length(self):
        assert len(self.model) == self.trie.length()

    def teardown(self):
        self.trie.proc.terminate()

TestDictComparison = DictComparison.TestCase
TestDictComparison.settings = hypothesis.settings(max_examples=1000, stateful_step_count=1000)
