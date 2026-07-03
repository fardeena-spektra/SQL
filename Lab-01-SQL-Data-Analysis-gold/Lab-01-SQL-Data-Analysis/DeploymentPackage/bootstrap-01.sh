#!/usr/bin/env bash
# =============================================================================
# Lab 01 - SQL (Data Analysis Queries)
# bootstrap-01.sh  -  CloudLabs Custom Script Extension bootstrap
#
# Runs on ONE SQL Server on Linux node:
#   * labvm-<DeploymentID> (hostname "labvm", 10.0.0.4) -> hosts the SalesDB
#     analytics database the candidate queries.
#
# On this node the script:
#   - installs SQL Server 2022 for Ubuntu (mssql-server) + mssql-tools (sqlcmd),
#   - sets the SA password and accepts the EULA (Developer edition),
#   - seeds an analytics database SalesDB with DETERMINISTIC data so every
#     query in the lab has a single known answer:
#       * dbo.Sales            - 2,100 dated rows (Jan-Jun 2026), Amount = 10.00
#                                each, a Region/Category, and a Status. Designed
#                                so monthly totals form a clean trend and the
#                                per-status totals are fixed.
#       * dbo.CustomerStaging  - 1,500 rows that DELIBERATELY contain duplicate
#                                CustomerId rows (3 copies each, different
#                                LoadDate) over 500 distinct customers, so the
#                                dedup task has a known unique count.
#
# Scenario 1 (s1): Sales trend analysis - aggregate revenue by month and expose
#                  it as a view dbo.vw_SalesTrend (one row per period).
# Scenario 2 (s2): Remove duplicates with ranking - ROW_NUMBER()/RANK() to keep
#                  the latest row per CustomerId, exposed as dbo.vw_DedupedCustomers.
# Scenario 3 (s3): Conditional aggregation - SUM(CASE WHEN Status = ...) pivot,
#                  exposed as dbo.vw_SalesByStatus.
#
# GROUND TRUTH (documented for facilitators in the Solution Guide):
#   * Grand total Amount               = 21000.00
#   * Distinct months (trend periods)  = 6  (2026-01 .. 2026-06)
#   * Monthly totals                   = 1000/2000/3000/4000/5000/6000
#   * Status totals  OPEN/SHIPPED/CLOSED = 10500 / 6300 / 4200
#   * Distinct customers (after dedup) = 500  (from 1500 staged rows)
#
# NOTE: SQL Server package install needs INTERNET ACCESS at deploy time. Every
#       install step is guarded (try/continue) and must NOT hard-fail the CSE.
#
# Usage: bash bootstrap-01.sh <labuser>   (default: labuser)
# =============================================================================
set -uo pipefail

LAB_USER="${1:-labuser}"
LAB_HOME="/home/${LAB_USER}"

# Sample credentials (documented for candidates in README.txt).
SA_PASSWORD="NedSQL@1234!"
PRIMARY_IP="10.0.0.4"          # CloudLabs primary NIC (dynamic, typically .4)
DB_NAME="SalesDB"

# sqlcmd lives in one of these locations depending on the tools package.
SQLCMD_CLASSIC="/opt/mssql-tools/bin/sqlcmd"
SQLCMD_18="/opt/mssql-tools18/bin/sqlcmd"

log() { echo "[bootstrap] $*"; }

HOSTNAME_NOW="$(hostname 2>/dev/null || echo unknown)"
log "Starting Lab 01 SQL Data Analysis bootstrap for user '${LAB_USER}' on host '${HOSTNAME_NOW}'"

# Ensure the lab user/home exists (CloudLabs normally provisions it; be safe).
if ! id "${LAB_USER}" >/dev/null 2>&1; then
    log "User ${LAB_USER} missing - creating it"
    useradd -m -s /bin/bash "${LAB_USER}" || true
fi
mkdir -p "${LAB_HOME}"

export DEBIAN_FRONTEND=noninteractive

# -----------------------------------------------------------------------------
# Base packages (best-effort)
# -----------------------------------------------------------------------------
log "Ensuring base packages (curl, gnupg, apt-transport-https) are present"
apt-get update -y >/dev/null 2>&1 || log "apt-get update failed (continuing)"
apt-get install -y curl gnupg apt-transport-https software-properties-common >/dev/null 2>&1 || \
    log "base package install reported issues (continuing)"

# -----------------------------------------------------------------------------
# Install SQL Server 2022 for Ubuntu (mssql-server) - guarded, never hard-fail
# -----------------------------------------------------------------------------
install_sql_server() {
    log "[SQL] Adding Microsoft package signing key and SQL Server 2022 repo (Ubuntu 22.04)"
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc 2>/dev/null \
        | gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg 2>/dev/null \
        || { log "[SQL] WARNING: could not fetch signing key (needs internet) - skipping SQL install"; return 0; }

    curl -fsSL https://packages.microsoft.com/config/ubuntu/22.04/mssql-server-2022.list 2>/dev/null \
        -o /etc/apt/sources.list.d/mssql-server-2022.list \
        || { log "[SQL] WARNING: could not fetch mssql-server repo list - skipping SQL install"; return 0; }

    apt-get update -y >/dev/null 2>&1 || log "[SQL] apt-get update (mssql repo) failed (continuing)"
    apt-get install -y mssql-server >/dev/null 2>&1 \
        || { log "[SQL] WARNING: mssql-server install failed (needs internet) - continuing"; return 0; }

    # Unattended setup: Developer edition (free), accept EULA, set SA password.
    log "[SQL] Running mssql-conf setup (Developer edition, EULA accepted)"
    MSSQL_SA_PASSWORD="${SA_PASSWORD}" \
    MSSQL_PID="Developer" \
    ACCEPT_EULA="Y" \
        /opt/mssql/bin/mssql-conf -n setup >/dev/null 2>&1 \
        || log "[SQL] WARNING: mssql-conf setup reported issues (continuing)"

    systemctl enable mssql-server >/dev/null 2>&1 || true
    systemctl restart mssql-server >/dev/null 2>&1 \
        || log "[SQL] WARNING: could not (re)start mssql-server (continuing)"
}

install_sql_tools() {
    log "[SQL] Installing mssql-tools (sqlcmd) + unixodbc-dev"
    curl -fsSL https://packages.microsoft.com/config/ubuntu/22.04/prod.list 2>/dev/null \
        -o /etc/apt/sources.list.d/msprod.list \
        || { log "[SQL] WARNING: could not fetch prod repo list for tools - skipping tools install"; return 0; }
    apt-get update -y >/dev/null 2>&1 || true
    ACCEPT_EULA=Y apt-get install -y mssql-tools18 unixodbc-dev >/dev/null 2>&1 \
        || ACCEPT_EULA=Y apt-get install -y mssql-tools unixodbc-dev >/dev/null 2>&1 \
        || { log "[SQL] WARNING: mssql-tools install failed (needs internet) - continuing"; return 0; }
}

install_sql_server
install_sql_tools

# Pick whichever sqlcmd got installed (classic first, then v18 with -C for trust).
SQLCMD=""
SQLCMD_ARGS=""
if [ -x "${SQLCMD_CLASSIC}" ]; then
    SQLCMD="${SQLCMD_CLASSIC}"
elif [ -x "${SQLCMD_18}" ]; then
    SQLCMD="${SQLCMD_18}"
    SQLCMD_ARGS="-C"   # trust self-signed server cert
fi

# Helper: run a T-SQL batch on the local instance (best-effort, retries while
# the engine finishes starting). Never hard-fails the CSE.
run_tsql() {
    local db="$1"; shift
    local sql="$1"; shift
    [ -z "${SQLCMD}" ] && { log "[SQL] sqlcmd not available - skipping T-SQL batch"; return 0; }
    local attempt=1
    while [ "${attempt}" -le 10 ]; do
        if "${SQLCMD}" ${SQLCMD_ARGS} -S localhost -U SA -P "${SA_PASSWORD}" -d "${db}" -b -Q "${sql}" >/dev/null 2>&1; then
            return 0
        fi
        log "[SQL] T-SQL attempt ${attempt}/10 not ready yet (engine starting?) - retrying"
        sleep 6
        attempt=$((attempt + 1))
    done
    log "[SQL] WARNING: T-SQL batch did not complete (engine may be offline) - continuing"
    return 0
}

# =============================================================================
# SEED: SalesDB analytics data (deterministic, known answers)
# =============================================================================
log "[Seed] Creating ${DB_NAME} analytics database"
run_tsql "master" "IF DB_ID('${DB_NAME}') IS NULL CREATE DATABASE [${DB_NAME}];"

# -----------------------------------------------------------------------------
# dbo.Sales : 2,100 dated rows, Amount = 10.00 each.
#   For each month m (1..6) the row count is 100*m, so:
#     * monthly totals  = 1000*m  -> 1000/2000/3000/4000/5000/6000 (a clean trend)
#     * grand total     = 21000.00
#   Within each month the rows split into statuses by a fixed unit
#   (OPEN 50, SHIPPED 30, CLOSED 20 per month-unit m), so:
#     * OPEN    = SUM(50*m)*10 = 10500
#     * SHIPPED = SUM(30*m)*10 = 6300
#     * CLOSED  = SUM(20*m)*10 = 4200
# -----------------------------------------------------------------------------
log "[Seed] Building dbo.Sales (2100 rows, monthly trend + fixed status totals)"
run_tsql "${DB_NAME}" "
SET NOCOUNT ON;
IF OBJECT_ID('dbo.Sales','U') IS NOT NULL DROP TABLE dbo.Sales;
CREATE TABLE dbo.Sales (
    SaleId     INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Sales PRIMARY KEY CLUSTERED,
    SaleDate   DATE          NOT NULL,
    Amount     DECIMAL(10,2) NOT NULL,
    Region     VARCHAR(20)   NOT NULL,
    Category   VARCHAR(20)   NOT NULL,
    Status     VARCHAR(20)   NOT NULL
);

WITH months AS (
    SELECT 1 AS m UNION ALL SELECT 2 UNION ALL SELECT 3
    UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6
),
statuses AS (
    SELECT 'OPEN' AS Status, 50 AS per_unit
    UNION ALL SELECT 'SHIPPED', 30
    UNION ALL SELECT 'CLOSED', 20
),
tally AS (
    SELECT TOP (300) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS k
    FROM sys.all_objects
)
INSERT INTO dbo.Sales (SaleDate, Amount, Region, Category, Status)
SELECT
    DATEFROMPARTS(2026, mo.m, (t.k % 27) + 1)                                  AS SaleDate,
    CAST(10.00 AS DECIMAL(10,2))                                               AS Amount,
    CASE t.k % 4 WHEN 0 THEN 'North' WHEN 1 THEN 'South' WHEN 2 THEN 'East' ELSE 'West' END AS Region,
    CASE t.k % 3 WHEN 0 THEN 'Hardware' WHEN 1 THEN 'Software' ELSE 'Services' END          AS Category,
    st.Status                                                                  AS Status
FROM months mo
CROSS JOIN statuses st
JOIN tally t ON t.k <= mo.m * st.per_unit;"

# -----------------------------------------------------------------------------
# dbo.CustomerStaging : 1,500 rows = 500 distinct customers x 3 duplicate loads.
#   Each customer appears 3 times with a different LoadDate (and Tier), so the
#   dedup task that keeps the LATEST row per CustomerId must return exactly 500.
# -----------------------------------------------------------------------------
log "[Seed] Building dbo.CustomerStaging (1500 rows, 500 distinct customers x3 dupes)"
run_tsql "${DB_NAME}" "
SET NOCOUNT ON;
IF OBJECT_ID('dbo.CustomerStaging','U') IS NOT NULL DROP TABLE dbo.CustomerStaging;
CREATE TABLE dbo.CustomerStaging (
    StagingId    INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_CustomerStaging PRIMARY KEY CLUSTERED,
    CustomerId   INT          NOT NULL,
    CustomerName VARCHAR(100) NOT NULL,
    Region       VARCHAR(20)  NOT NULL,
    Tier         VARCHAR(10)  NOT NULL,
    LoadDate     DATETIME2(0) NOT NULL
);

WITH cust AS (
    SELECT TOP (500) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS cid
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
),
copies AS (
    SELECT 1 AS c UNION ALL SELECT 2 UNION ALL SELECT 3
)
INSERT INTO dbo.CustomerStaging (CustomerId, CustomerName, Region, Tier, LoadDate)
SELECT
    cu.cid                                                                     AS CustomerId,
    CONCAT('Customer ', cu.cid)                                                AS CustomerName,
    CASE cu.cid % 4 WHEN 0 THEN 'North' WHEN 1 THEN 'South' WHEN 2 THEN 'East' ELSE 'West' END AS Region,
    CASE co.c WHEN 3 THEN 'Gold' WHEN 2 THEN 'Silver' ELSE 'Bronze' END        AS Tier,
    DATEADD(DAY, co.c, CAST('2026-01-01' AS DATETIME2(0)))                      AS LoadDate
FROM cust cu
CROSS JOIN copies co;"

log "[Seed] ${DB_NAME} seeded: dbo.Sales (~2100 rows) + dbo.CustomerStaging (1500 rows, 500 distinct)"

# =============================================================================
# README for the candidate
# =============================================================================
cat > "${LAB_HOME}/README.txt" <<EOF
Lab 01 - SQL (Data Analysis Queries)
====================================

One SQL Server 2022 on Linux (Ubuntu 22.04) node is provisioned:

  labvm-<DeploymentID>   private IP ${PRIMARY_IP} (hostname labvm)
                         -> hosts the ${DB_NAME} analytics database

SQL Server credentials:
  Server   : localhost
  Login    : SA
  Password : ${SA_PASSWORD}
  sqlcmd   : ${SQLCMD_CLASSIC}   (or ${SQLCMD_18} with -C to trust the cert)

Connect example:
  ${SQLCMD_CLASSIC} -S localhost -U SA -P '${SA_PASSWORD}' -d ${DB_NAME}
  ${SQLCMD_18} -C -S localhost -U SA -P '${SA_PASSWORD}' -d ${DB_NAME}

-------------------------------------------------------------------
Seeded data (database ${DB_NAME})
-------------------------------------------------------------------
  dbo.Sales            : 2,100 sales rows dated Jan-Jun 2026.
                         Columns: SaleId, SaleDate, Amount, Region, Category, Status.
  dbo.CustomerStaging  : 1,500 rows that intentionally contain DUPLICATE
                         CustomerId rows (the same customer loaded several times
                         with different LoadDate / Tier).
                         Columns: StagingId, CustomerId, CustomerName, Region,
                                  Tier, LoadDate.

-------------------------------------------------------------------
What you must build (named views the validators check)
-------------------------------------------------------------------
  s1  dbo.vw_SalesTrend        - one row per month; columns SalesPeriod, TotalAmount.
  s2  dbo.vw_DedupedCustomers  - exactly one row per CustomerId (the LATEST load).
  s3  dbo.vw_SalesByStatus     - one row; columns OpenAmount, ShippedAmount, ClosedAmount
                                 (conditional aggregation with SUM(CASE WHEN ...)).

Support: labs-support@spektrasystems.com | https://cloudlabs.ai/labs-support
EOF

# Ownership: lab user owns everything under its home.
log "Setting ownership of ${LAB_HOME} to ${LAB_USER}"
chown -R "${LAB_USER}:${LAB_USER}" "${LAB_HOME}" 2>/dev/null || \
    chown -R "${LAB_USER}" "${LAB_HOME}" 2>/dev/null || \
    log "WARNING: chown of ${LAB_HOME} failed"

log "Bootstrap complete. ${DB_NAME} seeded with dbo.Sales + dbo.CustomerStaging (deterministic analytics data)."
exit 0
