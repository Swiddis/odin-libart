import os
import subprocess

import hypothesis
from hypothesis import strategies as st
from hypothesis.stateful import Bundle, RuleBasedStateMachine, rule

CLIENT_BIN = os.environ.get("LIBART_CLIENT", "./client.bin")

# libart's MAX_PREFIX_LEN; prefixes longer than this take the "pessimistic"
# path that recovers prefix bytes from a leaf, so we want to cross it.
MAX_PREFIX_LEN = 10

# Bytes that cause the most trouble
INTERESTING = [0x00, 0x01, 0xFF]


def enc(b: bytes) -> str:
    if len(b) == 0:
        return "$EMPTY"
    return b.hex()


# Small alphabets make shared prefixes (and keys that are prefixes of each
# other) far more likely than uniform st.binary().
small_alphabet_keys = st.lists(
    st.sampled_from(INTERESTING + [ord("a")]), max_size=2 * MAX_PREFIX_LEN
).map(bytes)
null_heavy_keys = st.lists(
    st.one_of(st.just(0), st.integers(0, 255)), max_size=2 * MAX_PREFIX_LEN
).map(bytes)
long_shared_prefix_keys = st.builds(
    lambda pre, tail: pre + tail,
    st.sampled_from([b"\x00" * (MAX_PREFIX_LEN + 2), b"ab" * MAX_PREFIX_LEN]),
    st.binary(max_size=4),
)
any_key = st.one_of(st.binary(), small_alphabet_keys, null_heavy_keys, long_shared_prefix_keys)
suffix_bytes = st.one_of(
    st.lists(st.sampled_from(INTERESTING), min_size=1, max_size=3).map(bytes),
    st.binary(min_size=1, max_size=MAX_PREFIX_LEN + 3),
)


class Trie:
    proc: subprocess.Popen

    def __init__(self):
        self.reported = False
        self.proc = subprocess.Popen(
            [CLIENT_BIN], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE
        )

    def died(self):
        # Surface sanitizer reports / crashes instead of a confusing mismatch.
        self.proc.wait(timeout=5)
        err = self.proc.stderr.read().decode(errors="replace")
        self.reported = True
        raise RuntimeError(f"client exited with {self.proc.returncode}:\n{err}")

    def write(self, s):
        if self.proc.poll() is not None:
            self.died()
        try:
            self.proc.stdin.write(bytes(s, encoding="ascii"))
            self.proc.stdin.write(b"\n")
            self.proc.stdin.flush()
        except BrokenPipeError:
            self.died()

    def readline(self):
        line = self.proc.stdout.readline()
        if not line:
            self.died()
        return line

    def insert(self, k: bytes, v: int):
        self.write(f"insert {enc(k)} {v}")

    def delete(self, k: bytes):
        self.write(f"delete {enc(k)}")

    def search(self, k: bytes):
        self.write(f"search {enc(k)}")
        result = self.readline()
        if result.startswith(b"value="):
            return int(result[6:])
        else:
            return None

    def length(self):
        self.write("length")
        return int(self.readline())

    def close(self):
        if self.reported:
            return
        if self.proc.poll() is None:
            self.proc.stdin.close()
            # Timeout is necessary for ASan to have a chance to output
            try:
                self.proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.proc.kill()
                self.proc.wait()
        err = self.proc.stderr.read().decode(errors="replace")
        self.proc.stdout.close()
        self.proc.stderr.close()
        if "ERROR: AddressSanitizer" in err or self.proc.returncode not in (0, None):
            raise RuntimeError(f"client exited with {self.proc.returncode} at teardown:\n{err}")


class DictComparison(RuleBasedStateMachine):
    keys = Bundle("keys")
    values = Bundle("values")

    def __init__(self):
        super().__init__()
        self.model = {}
        self.trie = Trie()

    @staticmethod
    def usable(k: bytes) -> bool:
        # TODO: libart struggles a lot with empty keys, need to figure out how to stabilize this
        return len(k) > 0

    @rule(target=keys, k=any_key)
    def add_key(self, k):
        hypothesis.assume(self.usable(k))
        return k

    @rule(target=values, v=st.integers(min_value=-2**63, max_value=2**63-1))
    def add_value(self, v):
        return v

    def near(self, data, base: bytes) -> bytes:
        op = data.draw(st.sampled_from(["trunc", "extend", "flip", "trunc_extend"]), label="op")
        match op:
            case "trunc":
                cut = data.draw(st.integers(0, len(base) - 1), label="cut")
                return base[:cut]
            case "extend":
                return base + data.draw(suffix_bytes, label="suffix")
            case "flip":
                i = data.draw(st.integers(0, len(base) - 1), label="pos")
                b = data.draw(st.sampled_from(INTERESTING + [base[i] ^ 1]), label="byte")
                return base[:i] + bytes([b]) + base[i + 1:]
            case "trunc_extend":
                cut = data.draw(st.integers(0, len(base)), label="cut")
                return base[:cut] + data.draw(suffix_bytes, label="suffix")
        raise RuntimeError("invalid op")

    def draw_near(self, data, pool) -> bytes:
        hypothesis.assume(pool)
        base = data.draw(st.sampled_from(sorted(pool)), label="base")
        k = self.near(data, base)
        hypothesis.assume(self.usable(k))
        return k

    @rule(k=keys, v=values)
    def insert(self, k, v):
        self.model[k] = v
        self.trie.insert(k, v)

    @rule(target=keys, data=st.data(), v=values)
    def insert_near_existing(self, data, v):
        k = self.draw_near(data, self.model)
        self.model[k] = v
        self.trie.insert(k, v)
        return k

    @rule(k=keys)
    def delete(self, k):
        if k in self.model:
            del self.model[k]
        self.trie.delete(k)

    @rule(data=st.data())
    def delete_near_existing(self, data):
        k = self.draw_near(data, self.model)
        self.model.pop(k, None)
        self.trie.delete(k)

    @rule(k=keys)
    def check_value(self, k):
        assert self.model.get(k, None) == self.trie.search(k)

    @rule(data=st.data())
    def check_near_existing(self, data):
        # Probe keys that are usually *absent* but share structure with
        # present ones -- this is where the search path over-reads.
        k = self.draw_near(data, self.model)
        assert self.model.get(k, None) == self.trie.search(k)

    @rule()
    def check_all(self):
        # Inserting a prefix key can corrupt lookups for *other* keys, so
        # periodically verify everything rather than only the key just touched.
        for k, v in self.model.items():
            assert self.trie.search(k) == v, k
        assert len(self.model) == self.trie.length()

    @rule()
    def check_length(self):
        assert len(self.model) == self.trie.length()

    def teardown(self):
        self.trie.close()


TestDictComparison = DictComparison.TestCase
TestDictComparison.settings = hypothesis.settings(max_examples=1000, stateful_step_count=1000)
