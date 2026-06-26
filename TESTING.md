# Runbook Testing Kelompok 3

Dokumen ini untuk testing dari sisi anak magang. Layanan bersama sudah
disiapkan oleh pembimbing, jadi repo ini hanya berisi langkah pemakaian.

## 1. Environment

```bash
export VFLOW_BASE_URL="https://sqavflow.vastar.id"
export VFLOW_TENANT="_default"
export VFLOW_ADMIN_KEY="<dari-pembimbing>"
export VFLOW_PACK_SECRET_KEY_B64="<dari-pembimbing>"
export LOGSTREAM_TOKEN="<dari-pembimbing>"
```

Semua request admin memakai header `x-api-key`. Script
`scripts/vflow-admin.sh` otomatis mengirim header itu jika `VFLOW_ADMIN_KEY`
diset.

## 2. Database Lokal

Jalankan PostgreSQL lokal milik Kelompok 3. Untuk migration lokal:

```bash
export LOCAL_DATABASE_URL="postgresql://user:pass@127.0.0.1:5432/db_kelompok3"
psql "$LOCAL_DATABASE_URL" -f db/schema.sql
```

Cek data awal:

```bash
psql "$LOCAL_DATABASE_URL" -c "select id, nama, stok from produk order by id;"
```

## 3. Tunnel DB Client

Jalankan rathole client yang diberikan pembimbing:

```bash
rathole kel3-client.toml
```

Biarkan terminal ini tetap hidup selama provision dan E2E test.

VFlow akan mengakses DB melalui:

```text
db-tunnel.vastar.id:15433
```

Jika ingin cek dari laptop:

```bash
psql "postgresql://user:pass@db-tunnel.vastar.id:15433/db_kelompok3" \
  -c "select current_database();"
```

## 4. Install Connection Pack

Set DSN runtime VFlow. Host harus `db-tunnel.vastar.id:15433`, bukan localhost.

```bash
export KELOMPOK3_DATABASE_URL="postgresql://user:pass@db-tunnel.vastar.id:15433/db_kelompok3"
```

Generate encrypted payload:

```bash
node scripts/make-pack-install.js > pack-install.local.json
```

Install:

```bash
./scripts/vflow-admin.sh packs install pack-install.local.json
```

Expected:

```json
{
  "installed": "kelompok3-umkm",
  "connections": [
    { "name": "primary", "kind": "postgres" }
  ]
}
```

## 5. Compile Rule Pack

```bash
./scripts/vflow-admin.sh rules compile \
  rules/aturan_harga_umkm_v1.vdicl \
  schemas/harga_fact_v1.yaml \
  kelompok3_aturan_harga_umkm_v1
```

Cek rule:

```bash
./scripts/vflow-admin.sh rules list
```

## 6. Provision Workflow

```bash
for f in workflows/*.yaml; do
  echo "== provisioning $f =="
  ./scripts/vflow-admin.sh workflows provision "$f"
done
```

Cek daftar workflow:

```bash
./scripts/vflow-admin.sh workflows list
```

## 7. Test Endpoint Manual

### Buka Keranjang

```bash
curl -sS -X POST "$VFLOW_BASE_URL/webhook/kelompok3/umkm/pesanan/buka" \
  -H "content-type: application/json" \
  -d '{"pelanggan_id":1,"kasir_id":"kasir01"}'
```

### Validasi Stok

```bash
curl -sS -X POST "$VFLOW_BASE_URL/webhook/kelompok3/umkm/produk/validasi-stok" \
  -H "content-type: application/json" \
  -d '{"pesanan_id":1,"produk_id":1,"jumlah":2}'
```

### Kalkulasi Tagihan

```bash
curl -sS -X POST "$VFLOW_BASE_URL/webhook/kelompok3/umkm/pesanan/kalkulasi-tagihan" \
  -H "content-type: application/json" \
  -d '{
    "pesanan_id": "1",
    "kasir_id": "kasir01",
    "subtotal": 100000,
    "total_item": 3,
    "tipe_pelanggan": "member",
    "metode_pembayaran": "qris",
    "metode_pengambilan": "ambil_sendiri"
  }'
```

### Konfirmasi Pembayaran

```bash
curl -sS -X POST "$VFLOW_BASE_URL/webhook/kelompok3/umkm/pesanan/konfirmasi-pembayaran" \
  -H "content-type: application/json" \
  -d '{"pesanan_id":1,"total_tagihan":95700,"nominal_dibayar":95700}'
```

### Penyelesaian Pesanan

Pastikan `detail_pesanan` berisi item untuk `pesanan_id` yang diuji.

```bash
curl -sS -X POST "$VFLOW_BASE_URL/webhook/kelompok3/umkm/pesanan/selesaikan" \
  -H "content-type: application/json" \
  -d '{"pesanan_id":1}'
```

### Audit Log

```bash
curl -sS -X POST "$VFLOW_BASE_URL/webhook/kelompok3/umkm/internal/audit-log" \
  -H "content-type: application/json" \
  -d '{
    "pesanan_id": "1",
    "aktor_id": "kasir01",
    "aktivitas_tipe": "SMOKE_TEST",
    "payload_log": {"sumber":"manual"},
    "waktu_kejadian": "2026-06-23T00:00:00Z"
  }'
```

## 8. Smoke Test Otomatis

```bash
bash test/smoke-test.sh
```

Expected:

```text
Ringkasan: 20 PASS, 0 FAIL
```

Jika ingin verifikasi DB lokal ikut aktif:

```bash
export LOCAL_DATABASE_URL="postgresql://user:pass@127.0.0.1:5432/db_kelompok3"
bash test/smoke-test.sh
```

## 9. Melihat Log VFlow

```bash
curl -N \
  -H "Authorization: Bearer $LOGSTREAM_TOKEN" \
  "$VFLOW_BASE_URL/logs/vflow-server?tail=100&follow=true&timestamps=true"
```

Ambil log terakhir tanpa streaming:

```bash
curl -sS \
  -H "Authorization: Bearer $LOGSTREAM_TOKEN" \
  "$VFLOW_BASE_URL/logs/vflow-server?tail=100&follow=false&timestamps=true"
```

Logstream hanya membaca log runtime yang relevan untuk debugging.

## Troubleshooting

| Gejala | Penyebab paling mungkin | Cek |
|---|---|---|
| `401 unauthorized` di `/api/admin/...` | `VFLOW_ADMIN_KEY` belum diset atau salah | `echo "$VFLOW_ADMIN_KEY"` |
| `401 missing bearer token` di `/logs/...` | `LOGSTREAM_TOKEN` belum diset | `echo "$LOGSTREAM_TOKEN"` |
| `404 no workflow for path` | Workflow belum diupload atau path salah | Pastikan path mulai `/webhook/kelompok3/...` |
| `pack ... not installed` | Connection pack belum diinstall | Jalankan `packs install` |
| `rule_set_id not found` | Rule pack belum dicompile atau id salah | Pakai `kelompok3_aturan_harga_umkm_v1` |
| Connection pack gagal connect DB | Tunnel rathole mati atau DSN salah | Pastikan `rathole kel3-client.toml` masih hidup dan DSN memakai `db-tunnel.vastar.id:15433` |
| Workflow DB error | Schema belum dibuat atau data seed tidak ada | Jalankan `psql "$LOCAL_DATABASE_URL" -f db/schema.sql` |
