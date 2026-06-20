"""Independent advanced-recovery model tests.

These tests do not touch firmware. They verify the safety policy encoded by the GUI:
no transaction is reconstructed unless the active-key combination and every expected
hash match one of the explicitly supported checkpoints.
"""
from dataclasses import dataclass
from itertools import product

D = 'db-default'
D23 = 'db-with-2023'
DX = 'dbx-default'
K = 'kek-default'
P = 'pk-default'

@dataclass(frozen=True)
class EvidenceState:
    pk: str | None = None
    kek: str | None = None
    db: str | None = None
    dbx: str | None = None
    der_present: bool = False
    name_present: bool = False


def checkpoint(s: EvidenceState):
    exists = (s.pk is not None, s.kek is not None, s.db is not None, s.dbx is not None)
    if exists == (False, False, False, False):
        return 'NoKeysReady'
    if exists == (False, False, True, False):
        if s.db == D:
            return 'DbDefaultWritten'
        if s.db == D23 and s.der_present and s.name_present:
            return 'Db2023Written'
        return None
    if exists == (False, False, True, True):
        return 'DbxWritten' if s.db == D23 and s.dbx == DX else None
    if exists == (False, True, True, True):
        return 'KekWritten' if s.db == D23 and s.dbx == DX and s.kek == K else None
    if exists == (True, True, True, True):
        return 'PkWritten' if s.db == D23 and s.dbx == DX and s.kek == K and s.pk == P else None
    return None

# Every possible presence combination: only five explicitly defined combinations may pass.
allowed_presence = {
    (False, False, False, False),
    (False, False, True, False),
    (False, False, True, True),
    (False, True, True, True),
    (True, True, True, True),
}
for combo in product([False, True], repeat=4):
    pk, kek, db, dbx = combo
    state = EvidenceState(
        pk=P if pk else None,
        kek=K if kek else None,
        db=D23 if db else None,
        dbx=DX if dbx else None,
        der_present=True,
        name_present=True,
    )
    got = checkpoint(state)
    assert (got is not None) == (combo in allowed_presence), (combo, got)

# Exact hashes are mandatory at every stage.
assert checkpoint(EvidenceState(db='unknown')) is None
assert checkpoint(EvidenceState(db=D23, der_present=False, name_present=True)) is None
assert checkpoint(EvidenceState(db=D23, der_present=True, name_present=False)) is None
assert checkpoint(EvidenceState(db=D23, dbx='unknown', der_present=True, name_present=True)) is None
assert checkpoint(EvidenceState(db=D23, dbx=DX, kek='unknown', der_present=True, name_present=True)) is None
assert checkpoint(EvidenceState(pk='unknown', kek=K, db=D23, dbx=DX, der_present=True, name_present=True)) is None

# Firmware whose dbDefault already contains the official DER legitimately has D23 == D.
D23_original = D23
D23 = D
try:
    assert checkpoint(EvidenceState(db=D, der_present=True, name_present=True)) == 'DbDefaultWritten'
    assert checkpoint(EvidenceState(db=D, dbx=DX, der_present=True, name_present=True)) == 'DbxWritten'
finally:
    D23 = D23_original

print('ADVANCED_RECOVERY_MODEL_OK')
