/ ============================================================
/ lib.q - pure, side-effect-free helpers shared by the q processes.
/ Loading these separately from the process files makes the tricky logic
/ unit-testable (see tests/test_units.q) and keeps it DRY.
/ ============================================================

/ ---- snapshot / live de-duplication guard ----
/ When the rdb subscribes it receives a full snapshot and then live
/ broadcasts. A broadcast must be applied only if it is NEWER than what the
/ snapshot already covered, otherwise rows would be counted twice.
/   lastSeq : dict of table -> sequence number covered by the snapshot
/   t       : the table name from the broadcast
/   seq     : the broadcast's sequence number
applyUpd:{[lastSeq;t;seq]
  / use $ (conditional) so the missing-key branch is never evaluated -
  / lastSeq t on an unknown key is `::` and comparing it would be a type error
  $[t in key lastSeq; seq>lastSeq t; 1b]
  }

/ ---- hdb partition path ----
/ Build the splayed-table directory path for a table on a given date.
/ KDB-X: string[`:hdb] keeps the leading colon and `set` needs a trailing
/ slash to splay, so both are handled here in one place.
/   hdbDir : e.g. `:hdb
/   d      : partition date, e.g. .z.d
/   t      : table name
hdbPath:{[hdbDir;d;t]
  / note the brackets: `string d` would parse as string[d,"/",...] (q is
  / right-to-left), so every function application is bracketed here
  `$string[hdbDir],"/",string[d],"/",string[t],"/"
  }