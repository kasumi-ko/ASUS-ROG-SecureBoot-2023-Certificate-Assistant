"""Independent model tests for the intended state-machine invariants."""
from dataclasses import dataclass

@dataclass
class S:
    asus: bool = True
    uefi: bool = True
    setup: int | None = 1
    sb_var: int | None = 0
    setup_read: bool = True
    sb_read: bool = True
    active_reads: bool = True
    default_reads: bool = True
    confirm_read: bool = True
    confirm: bool = False
    pk: bool = False
    kek: bool = False
    db: bool = False
    dbx: bool = False
    defaults: bool = True
    tx_consistent: bool = False
    tx_stage: str = ''
    pk_reboot_complete: bool = False
    win2023: bool = False
    ms2011: bool = True
    ms2023: bool = False
    rom2023: bool = False
    kek2023: bool = False
    status: str = 'NotStarted'
    available: int = 0
    error: bool = False


def applicable_complete(s: S) -> bool:
    return (
        s.win2023
        and s.kek2023
        and ((not s.ms2011) or (s.ms2023 and s.rom2023))
    )


def classify(s: S) -> str:
    if not s.uefi:
        return 'UnsupportedLegacy'
    if not s.asus:
        return 'ReadOnlyNonAsus'
    if (
        not s.setup_read or not s.sb_read or not s.active_reads or
        s.setup is None or s.sb_var is None or
        (s.setup == 0 and not s.confirm_read)
    ):
        return 'FirmwareVariableReadFailure'

    count = sum([s.pk, s.kek, s.db, s.dbx])
    all_keys = count == 4
    no_keys = count == 0

    if s.tx_consistent and s.tx_stage == 'PkWritten' and not s.pk_reboot_complete:
        return 'PkWrittenPendingReboot'
    if s.confirm and s.setup == 0 and applicable_complete(s) and s.status == 'Updated':
        return 'Completed'
    if s.setup == 1 and no_keys and not s.default_reads:
        return 'FirmwareVariableReadFailure'
    if s.setup == 1 and no_keys and not s.defaults:
        return 'MissingDefaultVariables'
    if s.setup == 1 and no_keys and s.defaults:
        return 'ReadyForRepair'
    if 0 < count < 4:
        valid = {
            'DbDefaultWritten': (False, False, True, False),
            'Db2023Written': (False, False, True, False),
            'DbxWritten': (False, False, True, True),
            'KekWritten': (False, True, True, True),
        }
        combo = (s.pk, s.kek, s.db, s.dbx)
        return 'RecoverableIntermediate' if s.tx_consistent and valid.get(s.tx_stage) == combo else 'AdvancedRecoveryRequired'
    if s.confirm and s.setup == 0 and s.error:
        return 'OfficialRotationError'
    if s.confirm and s.setup == 0 and s.status == 'Updated' and not applicable_complete(s):
        return 'UpdatedButVerificationMismatch'
    if s.confirm and s.setup == 0 and (s.status == 'InProgress' or s.available not in (0, 0x4000)):
        return 'OfficialRotationNeedsReboot'
    if s.confirm and s.setup == 0 and not applicable_complete(s):
        return 'NeedsOfficialRotation'
    if s.setup == 0 and all_keys and not s.confirm:
        return 'SecureBootDisabledWithKeys'
    if s.setup == 1 and not no_keys:
        return 'InvalidSetupModeState'
    return 'NeedsFirmwareSetup'


def expect(name: str, state: S, wanted: str):
    got = classify(state)
    assert got == wanted, f'{name}: got {got}, wanted {wanted}'

expect('fresh setup', S(), 'ReadyForRepair')
expect('missing defaults', S(defaults=False), 'MissingDefaultVariables')
expect('db default stage', S(db=True, tx_consistent=True, tx_stage='DbDefaultWritten'), 'RecoverableIntermediate')
expect('db 2023 stage', S(db=True, win2023=True, tx_consistent=True, tx_stage='Db2023Written'), 'RecoverableIntermediate')
expect('dbx stage', S(db=True, dbx=True, win2023=True, tx_consistent=True, tx_stage='DbxWritten'), 'RecoverableIntermediate')
expect('kek stage', S(db=True, dbx=True, kek=True, win2023=True, tx_consistent=True, tx_stage='KekWritten'), 'RecoverableIntermediate')
expect('unknown partial requires advanced evidence', S(db=True), 'AdvancedRecoveryRequired')
expect('pk always needs reboot first', S(setup=0, sb_var=1, confirm=True, pk=True, kek=True, db=True, dbx=True, win2023=True, tx_consistent=True, tx_stage='PkWritten'), 'PkWrittenPendingReboot')
expect('official rotation after reboot', S(setup=0, sb_var=1, confirm=True, pk=True, kek=True, db=True, dbx=True, win2023=True, tx_consistent=True, tx_stage='PkWritten', pk_reboot_complete=True), 'NeedsOfficialRotation')
expect('official in progress', S(setup=0, sb_var=1, confirm=True, pk=True, kek=True, db=True, dbx=True, win2023=True, status='InProgress', available=0x4100), 'OfficialRotationNeedsReboot')
expect('updated mismatch', S(setup=0, sb_var=1, confirm=True, pk=True, kek=True, db=True, dbx=True, win2023=True, status='Updated'), 'UpdatedButVerificationMismatch')
expect('complete with third party trust', S(setup=0, sb_var=1, confirm=True, pk=True, kek=True, db=True, dbx=True, win2023=True, ms2023=True, rom2023=True, kek2023=True, status='Updated', available=0x4000), 'Completed')
expect('complete without legacy 3P trust', S(setup=0, sb_var=1, confirm=True, pk=True, kek=True, db=True, dbx=True, win2023=True, ms2011=False, kek2023=True, status='Updated', available=0x4000), 'Completed')
expect('non asus read only', S(asus=False), 'ReadOnlyNonAsus')
expect('legacy blocked', S(uefi=False), 'UnsupportedLegacy')
expect('setup variable read fail', S(setup_read=False), 'FirmwareVariableReadFailure')
expect('active key read fail', S(active_reads=False), 'FirmwareVariableReadFailure')
expect('default variable read fail in setup mode', S(default_reads=False), 'FirmwareVariableReadFailure')
expect('default variable read fail does not block existing secure boot rotation', S(setup=0, sb_var=1, confirm=True, pk=True, kek=True, db=True, dbx=True, default_reads=False, win2023=True), 'NeedsOfficialRotation')
expect('confirm read fail in user mode', S(setup=0, sb_var=1, confirm_read=False, pk=True, kek=True, db=True, dbx=True), 'FirmwareVariableReadFailure')

# Interruption after a successful write but before the transaction completion record.
interruption_states = [
    S(db=True, tx_consistent=True, tx_stage='DbDefaultWritten'),
    S(db=True, win2023=True, tx_consistent=True, tx_stage='Db2023Written'),
    S(db=True, dbx=True, win2023=True, tx_consistent=True, tx_stage='DbxWritten'),
    S(db=True, dbx=True, kek=True, win2023=True, tx_consistent=True, tx_stage='KekWritten'),
    S(setup=0, sb_var=1, confirm=True, pk=True, kek=True, db=True, dbx=True, win2023=True, tx_consistent=True, tx_stage='PkWritten'),
]
assert [classify(x) for x in interruption_states] == [
    'RecoverableIntermediate', 'RecoverableIntermediate', 'RecoverableIntermediate',
    'RecoverableIntermediate', 'PkWrittenPendingReboot'
]

print('STATE_MACHINE_OK')
