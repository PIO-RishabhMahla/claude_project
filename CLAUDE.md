# CLAUDE.md — RPGLE / SQLRPGLE Coding Standards
## IBM i (AS/400) — Fully Free Format

> This file governs how Claude assists with writing, reviewing, and refactoring RPGLE and SQLRPGLE programs on IBM i. All generated code must conform to these standards unless explicitly overridden by the user.

---

## 1. Language & Format

- **Always** use fully free format RPGLE (`**FREE` as the very first line, column 1, no leading spaces).
- Never use fixed-format columns, `/FREE`…`/END-FREE` blocks, or column-dependent syntax.
- File spec (`F`), Definition spec (`D`), and Calculation spec (`C`) keywords are **forbidden** — use their modern equivalents (`DCL-F`, `DCL-S`, `DCL-DS`, `DCL-PR`, `DCL-PI`).
- Target minimum compiler level: **IBM i 7.3 TR7+** (or 7.4/7.5 where features are noted).

---

## 2. Program Structure

Every program must follow this top-to-bottom layout:

```rpgle
**FREE
// ============================================================
// Program  : MYPGM
// Purpose  : Brief one-line description
// Author   : Developer Name
// Date     : YYYY-MM-DD
// Changes  :
//   YYYY-MM-DD  Name  INC#  Description of change
// ============================================================

// --- Control Options ---
Ctl-Opt ...;

// --- File Declarations ---
Dcl-F ...;

// --- Standalone Variables & Constants ---
Dcl-S ...;
Dcl-C ...;

// --- Data Structures ---
Dcl-Ds ...;

// --- Procedure Prototypes ---
Dcl-Pr ...;

// --- Main Logic ---
...

*InLR = *On;
Return;

// --- Subroutines (if unavoidable) ---

// --- Subprocedures ---
Dcl-Proc ...;
  Dcl-Pi ...;
  ...
  Return ...;
End-Proc;
```

---

## 3. Control Options (`Ctl-Opt`)

Always specify the following as a minimum:

```rpgle
Ctl-Opt Option(*SrcStmt : *NoDebugIO)
        DftActGrp(*No)
        ActGrp(*Caller)       // or a named group for service programs
        BndDir('QC2LE')       // add others as required
        Main(MainProc)        // use a main procedure, not cycle main
        ExtBinInt(*Yes)
        Date(*ISO)
        DateFmt(*ISO)
        TimFmt(*ISO)
        AlwNull(*UsrCtl)
        Debug(*Yes);
```

- **Never** use `DftActGrp(*Yes)` for new programs.
- Use `ActGrp('GROUPNAME')` for ILE service programs that share state.
- `Main(MainProc)` is **required** — linear-main programs are preferred over cycle-main.

---

## 4. Naming Conventions

### 4.1 General Rules
- Names are **mixed case** for readability; the compiler is case-insensitive.
- Use **camelCase** for variables and parameters.
- Use **PascalCase** for procedures, prototypes, and data structures.
- Use **ALL_CAPS** for named constants.
- No Hungarian notation prefixes (avoid `wkString`, `inFlag`).

### 4.2 Specific Conventions

| Object Type          | Convention            | Example                  |
|----------------------|-----------------------|--------------------------|
| Standalone variable  | camelCase noun        | `customerName`           |
| Boolean-like flag    | camelCase + `Flag`    | `recordFoundFlag`        |
| Constant             | ALL_CAPS              | `MAX_RETRIES`            |
| Data structure       | PascalCase + `Ds`     | `CustomerDs`             |
| DS subfield          | camelCase             | `CustomerDs.firstName`   |
| Procedure / function | PascalCase verb+noun  | `GetCustomerById`        |
| Prototype            | Same as procedure     | `GetCustomerById`        |
| Parameter            | camelCase             | `custId`, `outputDs`     |
| File                 | UPPERCASE (as-is)     | `CUSTMAST`               |
| Indicator            | Avoid; use variables  | `recordFoundFlag`        |
| Program              | UPPERCASE 8-char      | `CUSTPGM`                |
| Service program      | UPPERCASE 8-char      | `CUSTSRV`                |

### 4.3 Indicators
- **Never** use numbered indicators (`*IN01`–`*IN99`) in new code.
- Use `Dcl-S myFlag Ind;` and assign `*On`/`*Off`.
- `*InLR`, `*InKB` are acceptable where required by the cycle.

---

## 5. Data Declarations

### Variables
```rpgle
Dcl-S customerName    Varchar(100);
Dcl-S orderId         Packed(9:0);
Dcl-S orderDate       Date;
Dcl-S taxRate         Packed(5:4) Inz(0);
Dcl-S recordFoundFlag Ind         Inz(*Off);
```

- Always initialise with `Inz(...)` when a default value is meaningful.
- Prefer `Varchar` over fixed-length `Char` for string data that varies.
- Use `Packed` for numeric business data; use `Int(10)` / `Int(20)` for loop counters and IDs.
- Use `Date`, `Time`, `Timestamp` for temporal data — never store dates in numeric fields.

### Constants
```rpgle
Dcl-C MAX_RETRIES     3;
Dcl-C COMPANY_CODE    'ACME';
Dcl-C ERR_NOT_FOUND   '0001';
```

### Data Structures
```rpgle
Dcl-Ds CustomerDs Qualified;
  id        Packed(9:0);
  firstName Varchar(50);
  lastName  Varchar(50);
  email     Varchar(100);
End-Ds;
```

- Always use `Qualified` keyword — reference subfields as `CustomerDs.firstName`.
- Use `LikeRec(CUSTMAST : *Input)` or `LikeRec(CUSTMAST : *All)` for file-based DS.
- Use `LikeDs(templateDs)` to create instances of a DS template.
- Avoid `Based` pointers unless absolutely required.

---

## 6. File Declarations

```rpgle
Dcl-F CUSTMAST  Disk  Usage(*Input)  Keyed;
Dcl-F ORDHIST   Disk  Usage(*Output);
Dcl-F QSYSPRT   Printer  OflInd(overflowFlag)  UsrOpn;
```

- Specify `Usage(*)` explicitly — never rely on defaults.
- Use `Keyed` for all keyed access.
- Declare print files with `OflInd`.
- Open/close display and printer files with `Open`/`Close` when `UsrOpn` is set.
- **Prefer SQL over native file I/O** for any non-trivial data access (see Section 8).

---

## 7. Procedure & Subprocedure Standards

### Prototype (in a separate `/COPY` member or at top of source)
```rpgle
Dcl-Pr GetCustomerById Ind;
  custId    Packed(9:0) Const;
  outputDs  LikeDs(CustomerDs);
End-Pr;
```

### Procedure Implementation
```rpgle
Dcl-Proc GetCustomerById;
  Dcl-Pi *N Ind;
    custId    Packed(9:0) Const;
    outputDs  LikeDs(CustomerDs);
  End-Pi;

  Dcl-S foundFlag Ind Inz(*Off);

  // Logic here
  Exec SQL
    Select id, firstName, lastName, email
      Into  :outputDs.id
           ,:outputDs.firstName
           ,:outputDs.lastName
           ,:outputDs.email
      From  CUSTMAST
      Where id = :custId
      Fetch First Row Only;

  If SqlCode = 0;
    foundFlag = *On;
  EndIf;

  Return foundFlag;

End-Proc;
```

**Rules:**
- Every procedure must have a **single entry** (`Dcl-Pi`) and **single exit** (`Return`) point where practical.
- Keep procedures **short and focused** — one procedure does one thing.
- Aim for procedures under 50 lines; refactor if longer.
- Pass parameters by `Const` for input-only, by `Value` for small scalars, by reference (default) for output/update.
- Avoid global variables — pass data through parameters.

---

## 8. SQL (SQLRPGLE) Standards

### 8.1 General
- Use **embedded SQL** (`Exec SQL`) for all database access in SQLRPGLE programs.
- SQL keywords in **UPPERCASE**; host variables prefixed with `:`.
- Always specify a column list — **never** use `SELECT *`.
- Always include `FETCH FIRST n ROWS ONLY` on singleton selects.

### 8.2 Error Handling (SQLCA)
```rpgle
Dcl-S sqlState Char(5);

// After every SQL statement:
If SqlCode < 0;
  // Log error, set return flag, do NOT crash silently
  LogError(SqlCode : SqlState : 'Procedure name : context info');
  Return *Off;
EndIf;
```

- Check `SqlCode` after **every** SQL statement.
- `SqlCode = 0` → success; `SqlCode = 100` → not found; `SqlCode < 0` → error.
- Never ignore a negative `SqlCode`.

### 8.3 Cursors
```rpgle
Exec SQL
  Declare C_Orders Cursor For
    Select orderId, orderDate, amount
      From ORDHIST
      Where custId = :custId
      Order By orderDate Desc;

Exec SQL Open  C_Orders;

Dou SqlCode <> 0;
  Exec SQL
    Fetch Next From C_Orders
      Into :orderDs.orderId
          ,:orderDs.orderDate
          ,:orderDs.amount;

  If SqlCode = 0;
    ProcessOrder(orderDs);
  EndIf;
EndDou;

Exec SQL Close C_Orders;
```

- Always `Open` and `Close` cursors explicitly.
- Use `FOR READ ONLY` on read-only cursors for performance.
- Use `WITH HOLD` only when a cursor must span commits.
- Prefer `FOR UPDATE OF col1, col2` over table-level locks.

### 8.4 Commitment Control
- Specify `COMMIT(*NONE)` in compile options unless the program requires transactions.
- Use `EXEC SQL COMMIT` / `EXEC SQL ROLLBACK` explicitly for transactional programs.
- Never mix native file I/O commitment control with SQL commitment control.

---

## 9. Error Handling & Logging

- Define a standard error data structure used across all programs:
```rpgle
Dcl-Ds ErrorDs Qualified;
  msgId    Char(7);
  msgText  Varchar(256);
  pgmName  Char(10);
  procName Char(128);
  sqlCode  Int(10);
  sqlState Char(5);
End-Ds;
```

- Use `Monitor` / `On-Error` blocks for operation-level errors:
```rpgle
Monitor;
  result = DivideValue(numerator : denominator);
On-Error *All;
  LogError(%Status() : 'DivideValue' : 'Division failed');
EndMon;
```

- Send escape messages to the caller via `QMHSNDPM` API or a wrapper procedure — do not use `Dsply` for production errors.
- Never use `*PSSR` in fully free-format linear-main programs; handle errors locally.

---

## 10. Comments & Documentation

```rpgle
// Single-line comment — use for brief explanations

// ----------------------------------------------------------------
// Block comment for complex logic:
// Step 1 — Validate input parameters
// Step 2 — Retrieve customer record
// Step 3 — Calculate discount tier
// ----------------------------------------------------------------

// TODO: Remove after June cutover
// FIXME: Handle null email case — INC-4421
```

- **Every procedure** must have a header comment describing: purpose, parameters, and return value.
- Comment the *why*, not the *what* — the code shows what; comments explain intent.
- Use `TODO:` and `FIXME:` tags with ticket/INC numbers.
- Do not leave commented-out dead code in production — delete it and rely on source control.

---

## 11. Copy Members & Prototypes

- Place all cross-program prototypes in `/COPY` (or `/INCLUDE`) members, not inline.
- Naming convention for copy members: `QCPYSRCxxx` or a dedicated `QCPYSRC` source physical file.
- Guard against double inclusion:
```rpgle
/If Not Defined(CUSTPROTS_INCLUDED)
/Define CUSTPROTS_INCLUDED
  Dcl-Pr GetCustomerById Ind; ...  End-Pr;
/EndIf
```

---

## 12. Performance Guidelines

- Use `SetLL` / `ReadE` chains only when SQL is genuinely impractical.
- Add `OPTIMIZE FOR n ROWS` to SQL cursors when fetching a known small result set.
- Use **local variables** inside procedures, not module-level globals, to reduce contention.
- Avoid `EVAL` chains that recalculate the same expression — assign once to a variable.
- Close cursors and files as soon as they are no longer needed.
- Use `QSQPTABL` / Explain (`Explain=*`) to verify SQL access plans during development.

---

## 13. Service Programs & Binding

- Encapsulate reusable logic in **service programs** (`*SRVPGM`), not copybooks of code.
- Export only what is necessary — use a binding source (`.bnd`) file to control exports.
- Bump the signature level in the binding source when changing exported interfaces.
- Group related service programs in a binding directory (`BNDDIR`).

---

## 14. Source Member Naming

| Type             | Source File  | Member prefix | Example        |
|------------------|--------------|---------------|----------------|
| RPG Program      | QRPGLESRC    | (none)        | `CUSTPGM`      |
| RPG Service Pgm  | QRPGLESRC    | (none)        | `CUSTSRV`      |
| SQLRPGLE Program | QRPGLESRC    | (none)        | `ORDPGM`       |
| Copy Member      | QCPYSRC      | (none)        | `CUSTPROTS`    |
| Display File     | QDDSSRC      | (none)        | `CUSTDSP`      |
| Printer File     | QDDSSRC      | (none)        | `CUSTRPT`      |
| CL Program       | QCLSRC       | (none)        | `CUSTCL`       |
| Binding Source   | QSRVSRC      | (none)        | `CUSTSRV`      |

---

## 15. Compile Options (Reference)

### RPGLE
```
CRTRPGMOD / CRTBNDRPG:
  DFTACTGRP(*NO)
  ACTGRP(*CALLER or named)
  BNDDIR(...)
  OPTION(*SRCSTMT *DEBUGIO)
  DBGVIEW(*SOURCE)
  TGTRLS(*CURRENT or specific VxRx)
```

### SQLRPGLE (CRTSQLRPGI)
```
  COMMIT(*NONE or *CHG)
  DATFMT(*ISO)
  TIMFMT(*ISO)
  CLOSQLCSR(*ENDMOD)
  ALWBLK(*ALLREAD)
  ALWCPYDTA(*OPTIMIZE)
  DYNUSRPRF(*USER)
  OPTION(*SRCSTMT *DEBUGIO)
  DBGVIEW(*SOURCE)
```

---

## 16. Prohibited Patterns

The following are **never** acceptable in new code:

| Prohibited                          | Use Instead                                 |
|-------------------------------------|---------------------------------------------|
| Fixed-format specs (F/D/C columns)  | `Dcl-F`, `Dcl-S`, `Dcl-Ds`, free-format ops |
| `GOTO` / `TAG`                      | Structured loops and procedures             |
| Numbered indicators `*IN01`–`*IN99` | `Dcl-S flag Ind`                            |
| `MOVE` / `MOVEL`                    | `=` assignment, `%SubSt`, `%Trim`           |
| `CHAIN`/`READE` when SQL is viable  | `Exec SQL SELECT / Cursor`                  |
| `SELECT *` in SQL                   | Explicit column list                        |
| Ignoring `SqlCode`                  | Always check after every SQL statement      |
| `DftActGrp(*Yes)`                   | `DftActGrp(*No)` with explicit `ActGrp`     |
| `*PSSR` subroutine                  | `Monitor/On-Error`, procedure-level handling |
| Hard-coded library names in SQL     | Use naming convention or `SET SCHEMA`       |
| Magic numbers inline                | Named constants (`Dcl-C`)                   |

---

## 17. Code Review Checklist

Before marking any program complete, verify:

- [ ] `**FREE` on line 1, column 1
- [ ] `Ctl-Opt` includes `DftActGrp(*No)`, `Main(...)`, `Date(*ISO)`
- [ ] All variables declared with `Dcl-S` / `Dcl-Ds` / `Dcl-C`
- [ ] No numbered indicators
- [ ] `SqlCode` checked after every `Exec SQL` statement
- [ ] Every procedure has a header comment
- [ ] No `SELECT *` in any SQL statement
- [ ] Error paths return meaningful messages to the caller
- [ ] Constants used for all literal values
- [ ] No dead/commented-out code blocks
- [ ] Compile options set per Section 15

---

*Last updated: 2026-04-07 — Fully Free Format RPGLE/SQLRPGLE on IBM i*
