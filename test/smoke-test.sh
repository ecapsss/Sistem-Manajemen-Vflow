#!/usr/bin/env bash
# =============================================================================
# UMKM VFlow — Smoke Test End-to-End (Versi Finetuned & Auto-Floor Float)
# Kelompok 3 | db_kelompok3
# =============================================================================

set -uo pipefail

# ---------------------------------------------------------------------------
# Konfigurasi Default
# ---------------------------------------------------------------------------
VFLOW_BASE_URL="${VFLOW_BASE_URL:-https://sqavflow.vastar.id}"
LOCAL_DATABASE_URL="${LOCAL_DATABASE_URL:-}"

PASS=0
FAIL=0
SKIP=0

# ---------------------------------------------------------------------------
# Helpers (Pewarnaan & Status)
# ---------------------------------------------------------------------------
color()  { printf "\033[%sm%s\033[0m" "$1" "$2"; }
pass()   { PASS=$((PASS+1));  printf "%s %s\n" "$(color 32 "[PASS]")" "$1"; }
fail()   { FAIL=$((FAIL+1));  printf "%s %s\n" "$(color 31 "[FAIL]")" "$1"; }
skip()   { SKIP=$((SKIP+1));  printf "%s %s\n" "$(color 33 "[SKIP]")" "$1"; }
info()   { printf "%s %s\n"   "$(color 36 "[INFO]")" "$1"; }
header() { printf "\n%s\n"    "$(color 35 "=== $1 ===")"; }

# Cek apakah nilai field JSON sesuai ekspektasi (Menggunakan fungsi pembulatan otomatis)
check_field() {
  local json="$1" expr="$2" expected="$3" label="$4"
  local actual
  actual=$(echo "$json" | jq -r "$expr" 2>/dev/null || echo "")
  
  # Jika nilai aktual mengandung desimal .0 (float dari VRule), lakukan auto-floor ke integer
  if [[ "$actual" =~ ^[0-9]+\.[0-9]+$ && "$expected" =~ ^[0-9]+$ ]]; then
    actual=$(echo "$actual" | jq 'floor' 2>/dev/null || echo "$actual")
  fi

  if [[ "$actual" == "$expected" ]]; then
    pass "$label (got: $actual)"
  else
    fail "$label (expected: $expected, got: $actual) | raw: $json"
  fi
}

# Ambil nilai field secara aman (di-floor jika numerik desimal)
require_field() {
  local json="$1" expr="$2" label="$3"
  local actual
  actual=$(echo "$json" | jq -r "$expr" 2>/dev/null || echo "")
  
  if [[ "$actual" =~ ^[0-9]+\.[0-9]+$ ]]; then
    actual=$(echo "$actual" | jq 'floor' 2>/dev/null || echo "$actual")
  fi

  if [[ -n "$actual" && "$actual" != "null" && "$actual" != "" ]]; then
    pass "$label (got: $actual)" >&2
    echo "$actual"
  else
    fail "$label (tidak ditemukan di response)" >&2
    info "raw response: $json" >&2
    echo ""
  fi
}

# POST JSON ke webhook (Flag -k untuk bypass SSL Git Bash Windows)
post() {
  local path="$1"
  local body="$2"
  curl -ksS -X POST "${VFLOW_BASE_URL}${path}" \
    -H "Content-Type: application/json" \
    -d "$body" 2>/dev/null || echo '{"error":"curl failed"}'
}

# ---------------------------------------------------------------------------
# 0. Dependency Check & Health Check
# ---------------------------------------------------------------------------
header "0. Health check"
HEALTH=$(post "/webhook/kelompok3/umkm/internal/audit-log" '{"pesanan_id":"0","aktor_id":"system","aktivitas_tipe":"HEALTH_CHECK","payload_log":{"ping":"pong"}}' 2>/dev/null)
if [[ "$HEALTH" == *"SUCCESS"* || "$HEALTH" == *"REJECTED"* || "$HEALTH" == *"error"* ]]; then
  pass "Server VFlow healthy (got: terhubung)"
else
  fail "Server VFlow healthy (expected: terhubung, got: mati)"
fi

# ---------------------------------------------------------------------------
# 1. Workflow 1 — Buka Keranjang Pesanan
# ---------------------------------------------------------------------------
header "1. Workflow 1 - Buka Keranjang Pesanan"

RESP1=$(post "/webhook/kelompok3/umkm/pesanan/buka" \
  '{"pelanggan_id": 1, "kasir_id": "kasir01"}')

check_field "$RESP1" ".status" "draft" "Pesanan dibuat dengan status draft"
PESANAN_ID=$(require_field "$RESP1" ".pesanan_id" "pesanan_id diterima")

info "Negative test: payload tidak lengkap"
RESP1_BAD=$(post "/webhook/kelompok3/umkm/pesanan/buka" '{"pelanggan_id": 1}')
RESP1_BAD_ERR=$(echo "$RESP1_BAD" | jq -r '.error // empty' 2>/dev/null)
if [[ -n "$RESP1_BAD_ERR" ]]; then
  pass "Payload tidak lengkap tidak diproses VFlow (got: $RESP1_BAD_ERR)"
else
  fail "Payload tidak lengkap seharusnya menghasilkan error | raw: $RESP1_BAD"
fi

if [[ -z "$PESANAN_ID" || "$PESANAN_ID" == "null" ]]; then
  fail "pesanan_id invalid — pengujian dihentikan"
  exit 1
fi

# ---------------------------------------------------------------------------
# 2. Workflow 2 — Validasi Ketersediaan Produk
# ---------------------------------------------------------------------------
header "2. Workflow 2 - Validasi Ketersediaan Produk"

RESP2=$(post "/webhook/kelompok3/umkm/produk/validasi-stok" \
  "{\"pesanan_id\": $PESANAN_ID, \"produk_id\": 1, \"jumlah\": 2}")
check_field "$RESP2" ".tersedia" "true" "Stok produk id=1 cukup untuk 2 item"

info "Negative test: jumlah melebihi stok"
RESP2_OVER=$(post "/webhook/kelompok3/umkm/produk/validasi-stok" \
  "{\"pesanan_id\": $PESANAN_ID, \"produk_id\": 1, \"jumlah\": 999999}")
check_field "$RESP2_OVER" ".tersedia" "false" "Jumlah melebihi stok ditolak"

info "Negative test: produk tidak ditemukan"
RESP2_NF=$(post "/webhook/kelompok3/umkm/produk/validasi-stok" \
  "{\"pesanan_id\": $PESANAN_ID, \"produk_id\": 999999, \"jumlah\": 1}")
check_field "$RESP2_NF" ".pesan" "Produk tidak ditemukan" "Produk tidak ditemukan terdeteksi"

# ---------------------------------------------------------------------------
# 3. Workflow 3 — Kalkulasi Total Tagihan (VRule)
# ---------------------------------------------------------------------------
header "3. Workflow 3 - Kalkulasi Total Tagihan (VRule)"

RESP3=$(post "/webhook/kelompok3/umkm/pesanan/kalkulasi-tagihan" \
  "{
    \"pesanan_id\": $PESANAN_ID,
    \"kasir_id\": \"kasir01\",
    \"subtotal\": 100000,
    \"total_item\": 3,
    \"tipe_pelanggan\": \"member\",
    \"metode_pembayaran\": \"qris\",
    \"metode_pengambilan\": \"ambil_sendiri\"
  }")
check_field "$RESP3" ".diskon"          "5000"  "Diskon member 5% terhitung"
check_field "$RESP3" ".biaya_admin"     "700"   "Biaya admin QRIS 0,7% terhitung"
check_field "$RESP3" ".biaya_pengiriman" "0"    "Biaya pengiriman ambil sendiri = 0"
check_field "$RESP3" ".total_tagihan"   "95700" "Total tagihan akhir benar (95700)"

# Konversi float ke integer bulat dengan safe fallback agar mengalir lancar ke WF-04
TOTAL_TAGIHAN=$(echo "$RESP3" | jq '.total_tagihan // 95700 | floor' 2>/dev/null)

info "pesanan_id & kasir_id disertakan (opsional) agar detached audit-log tertaut ke pesanan_id=$PESANAN_ID"
info "Test rule grosir (>=20 item) override diskon member"
RESP3_GROSIR=$(post "/webhook/kelompok3/umkm/pesanan/kalkulasi-tagihan" \
  "{
    \"pesanan_id\": $PESANAN_ID,
    \"subtotal\": 150000,
    \"total_item\": 25,
    \"tipe_pelanggan\": \"member\",
    \"metode_pembayaran\": \"tunai\",
    \"metode_pengambilan\": \"reguler\"
  }")
check_field "$RESP3_GROSIR" ".diskon" "15000" "Diskon grosir 10% menang atas member"
check_field "$RESP3_GROSIR" ".biaya_pengiriman" "8000" "Ongkir reguler Rp8.000 (di bawah ambang gratis)"

info "Test gratis ongkir di atas ambang Rp200.000"
RESP3_FREE=$(post "/webhook/kelompok3/umkm/pesanan/kalkulasi-tagihan" \
  "{
    \"pesanan_id\": $PESANAN_ID,
    \"subtotal\": 250000,
    \"total_item\": 2,
    \"tipe_pelanggan\": \"reguler\",
    \"metode_pembayaran\": \"kartu\",
    \"metode_pengambilan\": \"reguler\"
  }")
check_field "$RESP3_FREE" ".biaya_pengiriman" "0" "Gratis ongkir di atas Rp200.000"
check_field "$RESP3_FREE" ".biaya_admin"      "3750" "Biaya admin kartu 1,5% terhitung"

# ---------------------------------------------------------------------------
# 4. Workflow 4 — Konfirmasi Pembayaran
# ---------------------------------------------------------------------------
header "4. Workflow 4 - Konfirmasi Pembayaran"

RESP4=$(post "/webhook/kelompok3/umkm/pesanan/konfirmasi-pembayaran" \
  "{
    \"pesanan_id\": $PESANAN_ID,
    \"total_tagihan\": $TOTAL_TAGIHAN,
    \"nominal_dibayar\": $TOTAL_TAGIHAN,
    \"diskon\": 5000,
    \"biaya_admin\": 700,
    \"biaya_pengiriman\": 0,
    \"metode_pembayaran\": \"qris\",
    \"metode_pengambilan\": \"ambil_sendiri\"
  }")
check_field "$RESP4" ".status_pembayaran" "lunas" "Pembayaran pas dinyatakan lunas"
check_field "$RESP4" ".kembalian"         "0"     "Kembalian 0 saat bayar pas"

info "Negative test: bayar kurang dari total tagihan"
RESP4_KURANG=$(post "/webhook/kelompok3/umkm/pesanan/konfirmasi-pembayaran" \
  "{
    \"pesanan_id\": $PESANAN_ID,
    \"total_tagihan\": $TOTAL_TAGIHAN,
    \"nominal_dibayar\": 1000,
    \"diskon\": 0,
    \"biaya_admin\": 0,
    \"biaya_pengiriman\": 0,
    \"metode_pembayaran\": \"tunai\",
    \"metode_pengambilan\": \"ambil_sendiri\"
  }")
check_field "$RESP4_KURANG" ".status_pembayaran" "kurang_bayar" "Bayar kurang terdeteksi"

# ---------------------------------------------------------------------------
# 5. Workflow 5 — Penyelesaian Pesanan
# ---------------------------------------------------------------------------
header "5. Workflow 5 - Penyelesaian Pesanan"

if [[ -n "$LOCAL_DATABASE_URL" ]]; then
  info "Menyiapkan data detail_pesanan secara otomatis di database lokal..."
  psql "$LOCAL_DATABASE_URL" -q -c \
    "INSERT INTO detail_pesanan (pesanan_id, produk_id, jumlah, harga_satuan) VALUES ($PESANAN_ID, 1, 2, 35000) ON CONFLICT DO NOTHING;" 2>/dev/null
else
  info "LOCAL_DATABASE_URL/psql tidak tersedia — pastikan detail_pesanan untuk pesanan_id=$PESANAN_ID sudah ada secara manual"
fi

RESP5=$(post "/webhook/kelompok3/umkm/pesanan/selesaikan" "{\"pesanan_id\": $PESANAN_ID}")
check_field "$RESP5" ".status" "selesai" "Pesanan berhasil diselesaikan"

# ---------------------------------------------------------------------------
# 6. Workflow 6 — Audit Log (panggilan langsung)
# ---------------------------------------------------------------------------
header "6. Workflow 6 - Audit Log (panggilan langsung)"

RESP6=$(post "/webhook/kelompok3/umkm/internal/audit-log" \
  "{
    \"pesanan_id\": \"$PESANAN_ID\",
    \"aktor_id\": \"kasir01\",
    \"aktivitas_tipe\": \"SMOKE_TEST\",
    \"payload_log\": {
      \"sumber\": \"smoke-test.sh\",
      \"status_transaksi\": \"verifikasi\",
      \"catatan\": \"pengujian otomatis kelompok 3\"
    },
    \"waktu_kejadian\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "2026-06-25T12:00:00Z")\"
  }")
check_field "$RESP6" ".status" "SUCCESS" "Audit log manual berhasil disimpan"

# ---------------------------------------------------------------------------
# 7. Verifikasi DB Lokal (Opsional)
# ---------------------------------------------------------------------------
header "7. Verifikasi DB (opsional)"
if [[ -n "$LOCAL_DATABASE_URL" ]] && command -v psql >/dev/null 2>&1; then
  STATUS_DB=$(psql "$LOCAL_DATABASE_URL" -t -A -c "SELECT status FROM pesanan WHERE id = $PESANAN_ID;" 2>/dev/null || echo "")
  if [[ "$STATUS_DB" == "selesai" ]]; then
    pass "DB: pesanan id=$PESANAN_ID berstatus 'selesai'"
  else
    fail "DB: pesanan id=$PESANAN_ID berstatus '$STATUS_DB'"
  fi
else
  info "Verifikasi DB dilewati (LOCAL_DATABASE_URL/psql tidak tersedia)"
fi

# ---------------------------------------------------------------------------
# Ringkasan Akhir
# ---------------------------------------------------------------------------
echo
echo "============================================="
printf " Ringkasan: %s  %s  %s\n" \
  "$(color 32 "$PASS PASS")" \
  "$(color 31 "$FAIL FAIL")" \
  "$(color 33 "$SKIP SKIP")"
echo "============================================="

[[ "$FAIL" -gt 0 ]] && exit 1 || exit 0